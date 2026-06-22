import subprocess
import json
import os
import shutil
import glob
from pathlib import Path


class InstallerBackend:
    def get_disks(self):
        result = subprocess.run(
            ["lsblk", "-J", "-o", "NAME,SIZE,TYPE,MODEL,ROTA,TRAN"],
            capture_output=True,
            text=True,
            check=True,
        )
        data = json.loads(result.stdout)
        disks = []
        for dev in data.get("blockdevices", []):
            if dev["type"] != "disk":
                continue
            path = f"/dev/{dev['name']}"
            if not os.path.exists(path):
                continue
            disks.append(
                {
                    "name": dev["name"],
                    "path": path,
                    "size": dev["size"],
                    "model": (dev.get("model") or "").strip(),
                    "rotational": dev.get("rota") == "1",
                    "tran": dev.get("tran") or "",
                }
            )
        disks.sort(key=lambda d: d["name"])
        return disks

    def _run(self, cmd, capture=False):
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError(
                f"Command {' '.join(cmd)} failed (code {result.returncode}):\n"
                f"{result.stderr.strip()}"
            )
        if capture:
            return (result.stdout or "").strip()

    def _get_part_prefix(self, disk_path):
        return disk_path + (
            "p"
            if disk_path.startswith("/dev/nvme") or disk_path.startswith("/dev/mmcblk")
            else ""
        )

    def partition_disk(self, disk_path):
        esp_part = f"{self._get_part_prefix(disk_path)}1"
        root_part = f"{self._get_part_prefix(disk_path)}2"

        self._run(["wipefs", "-a", disk_path])
        self._run(["sgdisk", "-o", disk_path])
        self._run(["sgdisk", "-n", "1:0:+512M", "-t", "1:ef00", disk_path])
        self._run(["sgdisk", "-n", "2:0:0", "-t", "2:8300", disk_path])
        self._run(["sgdisk", "-p", disk_path])
        subprocess.run(["udevadm", "settle"], capture_output=True)
        return {"esp": esp_part, "root": root_part}

    def format_partitions(self, parts):
        self._run(["mkfs.fat", "-F", "32", parts["esp"]])
        self._run(["mkfs.ext4", "-F", parts["root"]])

    def mount_partitions(self, parts, mountpoint):
        os.makedirs(mountpoint, exist_ok=True)
        self._run(["mount", parts["root"], mountpoint])
        boot_dir = os.path.join(mountpoint, "boot")
        os.makedirs(boot_dir, exist_ok=True)
        self._run(["mount", parts["esp"], boot_dir])

    def copy_system(self, mountpoint, progress_callback=None):
        excludes = [
            "--exclude=/proc/*",
            "--exclude=/sys/*",
            "--exclude=/dev/*",
            "--exclude=/run/*",
            "--exclude=/mnt/*",
            "--exclude=/tmp/*",
            "--exclude=/media/*",
            "--exclude=/lost+found",
            "--exclude=/swapfile",
            "--exclude=/boot/*",
            "--exclude=/home/livecd/.cache/*",
            "--exclude=/root/.cache/*",
            "--exclude=/var/cache/*",
            "--exclude=/var/tmp/*",
            "--exclude=/var/db/repos/*",
            "--exclude=/var/log/*",
        ]
        if progress_callback:
            progress_callback("copying", 0, "Starting system copy...")

        proc = subprocess.Popen(
            ["rsync", "-aHAX"] + excludes + ["/", mountpoint + "/"],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
        for line in proc.stdout or []:
            line = line.strip()
            if line and progress_callback:
                progress_callback("copying", 0, line[:120])
        proc.wait()
        if proc.returncode != 0:
            raise RuntimeError(f"rsync failed with code {proc.returncode}")

        for d in ["proc", "sys", "dev", "run"]:
            os.makedirs(os.path.join(mountpoint, d), exist_ok=True)

    def copy_boot_files(self, mountpoint, progress_callback=None):
        if progress_callback:
            progress_callback("copying", 95, "Copying boot files...")
        target_boot = os.path.join(mountpoint, "boot")
        os.makedirs(target_boot, exist_ok=True)
        for entry in os.listdir("/boot"):
            src = os.path.join("/boot", entry)
            dst = os.path.join(target_boot, entry)
            if os.path.isfile(src) and not os.path.islink(src):
                shutil.copy2(src, dst)

        if progress_callback:
            progress_callback("copying", 100, "System copy complete.")

    def generate_fstab(self, mountpoint, parts):
        result = self._run(
            ["blkid", "-s", "UUID", "-o", "value", parts["root"]], capture=True
        )
        root_uuid = result.strip()
        result = self._run(
            ["blkid", "-s", "UUID", "-o", "value", parts["esp"]], capture=True
        )
        esp_uuid = result.strip()

        fstab = (
            f"# /etc/fstab: static file system information\n"
            f"# <file system> <mount point>   <type>  <options>       <dump>  <pass>\n"
            f"UUID={root_uuid}  /               ext4    defaults,noatime      0 1\n"
            f"UUID={esp_uuid}   /boot           vfat    defaults,noatime      0 2\n"
        )
        with open(os.path.join(mountpoint, "etc", "fstab"), "w") as f:
            f.write(fstab)

    def _chroot(self, mountpoint, cmd):
        subprocess.run(["chroot", mountpoint] + cmd, capture_output=True, text=True)

    def configure_system(self, mountpoint, config, progress_callback=None):
        for d in ["proc", "sys", "dev"]:
            subprocess.run(["mount", "--bind", f"/{d}", os.path.join(mountpoint, d)])

        if progress_callback:
            progress_callback("configuring", 10, "Setting hostname...")
        hostname = config.get("hostname", "calcium")
        with open(os.path.join(mountpoint, "etc", "hostname"), "w") as f:
            f.write(hostname + "\n")
        with open(os.path.join(mountpoint, "etc", "conf.d", "hostname"), "w") as f:
            f.write(f'hostname="{hostname}"\n')

        if progress_callback:
            progress_callback("configuring", 25, "Setting up locale...")
        with open(os.path.join(mountpoint, "etc", "locale.conf"), "w") as f:
            f.write('LANG="en_US.UTF-8"\nLC_COLLATE="C"\n')
        with open(os.path.join(mountpoint, "etc", "env.d", "02locale"), "w") as f:
            f.write('LANG="en_US.UTF-8"\nLC_COLLATE="C"\n')
        self._chroot(mountpoint, ["locale-gen"])

        if progress_callback:
            progress_callback("configuring", 40, "Setting timezone...")
        tz = config.get("timezone", "UTC")
        tz_path = os.path.join(mountpoint, "usr", "share", "zoneinfo", tz)
        if os.path.exists(tz_path):
            os.unlink(os.path.join(mountpoint, "etc", "localtime"))
            os.symlink(
                f"/usr/share/zoneinfo/{tz}",
                os.path.join(mountpoint, "etc", "localtime"),
            )
            with open(os.path.join(mountpoint, "etc", "timezone"), "w") as f:
                f.write(tz + "\n")

        if progress_callback:
            progress_callback("configuring", 50, "Creating user...")
        username = config.get("username", "calcium")
        password = config.get("password", "calcium")
        self._chroot(
            mountpoint,
            [
                "useradd",
                "-m",
                "-G",
                "users,wheel,audio,video,cdrom,usb,portage,render",
                "-s",
                "/bin/zsh",
                username,
            ],
        )
        self._chroot(
            mountpoint, ["sh", "-c", f"echo '{username}:{password}' | chpasswd"]
        )

        if progress_callback:
            progress_callback("configuring", 60, "Setting root password...")
        root_pass = config.get("root_password", password)
        self._chroot(mountpoint, ["sh", "-c", f"echo 'root:{root_pass}' | chpasswd"])

        sudoers_d = os.path.join(mountpoint, "etc", "sudoers.d")
        os.makedirs(sudoers_d, exist_ok=True)
        with open(os.path.join(sudoers_d, username), "w") as f:
            f.write(f"{username} ALL=(ALL) ALL\n")

        if progress_callback:
            progress_callback("configuring", 70, "Enabling services...")
        self._chroot(mountpoint, ["rc-update", "add", "gdm", "default"])
        self._chroot(mountpoint, ["rc-update", "add", "dbus", "default"])
        self._chroot(mountpoint, ["rc-update", "add", "elogind", "default"])
        self._chroot(mountpoint, ["rc-update", "add", "dhcpcd", "default"])
        self._chroot(mountpoint, ["rc-update", "add", "zram-init", "boot"])

        if progress_callback:
            progress_callback(
                "configuring", 80, "Setting up Portage and update system..."
            )
        self._setup_portage(mountpoint, config)

        if progress_callback:
            progress_callback("configuring", 85, "Installing bootloader...")
        self._install_bootloader(mountpoint, config)

        for d in ["proc", "sys", "dev"]:
            subprocess.run(["umount", "-l", os.path.join(mountpoint, d)])

        if progress_callback:
            progress_callback("configuring", 100, "Configuration complete.")

    def _setup_portage(self, mountpoint, config):
        portage_dir = os.path.join(mountpoint, "etc", "portage")
        os.makedirs(os.path.join(portage_dir, "repos.conf"), exist_ok=True)
        os.makedirs(os.path.join(portage_dir, "package.accept_keywords"), exist_ok=True)
        os.makedirs(os.path.join(portage_dir, "package.use"), exist_ok=True)

        with open(os.path.join(portage_dir, "repos.conf", "gentoo.conf"), "w") as f:
            f.write("[gentoo]\n")
            f.write("location = /var/db/repos/gentoo\n")
            f.write("sync-type = webrsync\n")
            f.write("auto-sync = yes\n")

        make_conf = os.path.join(portage_dir, "make.conf")
        if not os.path.exists(make_conf):
            with open(make_conf, "w") as f:
                f.write('CHOST="x86_64-pc-linux-gnu"\n')
                f.write('CFLAGS="-march=x86-64 -O2 -pipe"\n')
                f.write('CXXFLAGS="${CFLAGS}"\n')
                f.write('MAKEOPTS="-j$(nproc)"\n')
                f.write(
                    'USE="X gtk gnome dbus udev elogind openrc pam policykit udisks networkmanager bluetooth pulseaudio cups -systemd -consolekit"\n'
                )
                f.write('ACCEPT_LICENSE="*"\n')
                f.write('ACCEPT_KEYWORDS="amd64 ~amd64"\n')
                f.write(
                    'PORTAGE_BINHOST="https://distfiles.gentoo.org/releases/amd64/binpackages/23.0"\n'
                )
                f.write('GENTOO_MIRRORS="https://distfiles.gentoo.org"\n')

        with open(
            os.path.join(portage_dir, "package.accept_keywords", "gnome"), "w"
        ) as f:
            f.write("gnome-base/* ~amd64\n")
            f.write("x11-wm/* ~amd64\n")
            f.write("sys-kernel/gentoo-kernel-bin ~amd64\n")

        cron_daily = os.path.join(mountpoint, "etc", "cron.daily")
        os.makedirs(cron_daily, exist_ok=True)
        with open(os.path.join(cron_daily, "flatpak-update"), "w") as f:
            f.write(
                "#!/bin/bash\nflatpak update -y --noninteractive 2>/dev/null || true\n"
            )
        os.chmod(os.path.join(cron_daily, "flatpak-update"), 0o755)

        cron_weekly = os.path.join(mountpoint, "etc", "cron.weekly")
        os.makedirs(cron_weekly, exist_ok=True)
        with open(os.path.join(cron_weekly, "calcium-update"), "w") as f:
            f.write("#!/bin/bash\n/usr/bin/calcium-update auto 2>/dev/null || true\n")
        os.chmod(os.path.join(cron_weekly, "calcium-update"), 0o755)

    def _install_bootloader(self, mountpoint, config):
        disk_path = config.get("disk_path", "")
        boot_dir = os.path.join(mountpoint, "boot")

        vmlinuz = None
        for pattern in ["vmlinuz-*", "vmlinux-*", "kernel-*"]:
            matches = sorted(glob.glob(os.path.join(boot_dir, pattern)))
            if matches:
                vmlinuz = matches[-1]
                break
        if not vmlinuz and os.path.exists(os.path.join(boot_dir, "vmlinuz")):
            vmlinuz = os.path.join(boot_dir, "vmlinuz")

        initrd = None
        for pattern in ["initramfs-*", "initrd-*", "initramfs-*.img", "initrd-*.img"]:
            matches = sorted(glob.glob(os.path.join(boot_dir, pattern)))
            if matches:
                initrd = matches[-1]
                break
        if not initrd and os.path.exists(os.path.join(boot_dir, "initramfs.img")):
            initrd = os.path.join(boot_dir, "initramfs.img")

        vmlinuz_name = os.path.basename(vmlinuz) if vmlinuz else None
        initrd_name = os.path.basename(initrd) if initrd else None

        disk_num = None
        for p in disk_path, "/dev/sda", "/dev/nvme0n1":
            if os.path.exists(p):
                ref = p
                break
        else:
            ref = disk_path or "/dev/sda"

        result = self._run(
            ["blkid", "-s", "UUID", "-o", "value", self._get_part_prefix(ref) + "2"],
            capture=True,
        )
        root_uuid = result.strip()

        esp_result = self._run(
            [
                "blkid",
                "-s",
                "PARTUUID",
                "-o",
                "value",
                self._get_part_prefix(ref) + "1",
            ],
            capture=True,
        )
        esp_partuuid = esp_result.strip()

        if vmlinuz_name and initrd_name:
            boot_cmdline = f"root=UUID={root_uuid} initrd=\\{initrd_name} quiet ro"
            try:
                self._chroot(
                    mountpoint,
                    [
                        "efibootmgr",
                        "--create",
                        "--disk",
                        ref,
                        "--part",
                        "1",
                        "--label",
                        "Calcium OS",
                        "--loader",
                        f"\\{vmlinuz_name}",
                        "--unicode",
                        boot_cmdline,
                    ],
                )
            except Exception:
                self._install_grub_fallback(mountpoint, ref)
        else:
            self._install_grub_fallback(mountpoint, ref)

    def _install_grub_fallback(self, mountpoint, disk_path):
        self._chroot(
            mountpoint,
            [
                "grub-install",
                "--target=x86_64-efi",
                "--efi-directory=/boot",
                "--bootloader-id=Calcium",
            ],
        )
        self._chroot(mountpoint, ["grub-mkconfig", "-o", "/boot/grub/grub.cfg"])

    def unmount_all(self, mountpoint):
        for sub in ["boot", "proc", "sys", "dev", ""]:
            p = os.path.join(mountpoint, sub)
            subprocess.run(["umount", "-l", p], capture_output=True)

    def complete_installation(self, mountpoint, config, progress_callback=None):
        parts = self.partition_disk(config["disk_path"])
        if progress_callback:
            progress_callback("partitioning", 100, "Partitioning done.")
        self.format_partitions(parts)
        if progress_callback:
            progress_callback("formatting", 100, "Formatting done.")
        self.mount_partitions(parts, mountpoint)
        if progress_callback:
            progress_callback("mounting", 100, "Partitions mounted.")
        self.copy_system(mountpoint, progress_callback)
        self.copy_boot_files(mountpoint, progress_callback)
        self.generate_fstab(mountpoint, parts)
        self.configure_system(
            mountpoint, {**config, "disk_path": config["disk_path"]}, progress_callback
        )
        self.unmount_all(mountpoint)
        if progress_callback:
            progress_callback("finished", 100, "Installation complete!")
