#!/bin/bash
# fsscript: server edition package installation and LiveCD customization
set -e

# Set Profile 1 which is [1] default/linux/amd64/23.0 (stable)
eselect profile list
eselect profile set 1

echo ">>> Installing packages for server edition..."

mkdir -p /etc/portage/package.accept_keywords \
         /etc/portage/package.use \
         /etc/portage/package.license \
         /etc/portage/package.mask

echo "sys-kernel/linux-firmware linux-fw-redistributable" > /etc/portage/package.license/server

# Disable multi-lib/32 bit for whatever is pulling Zlib
echo "sys-libs/zlib -abi_x86_32 -abi_x86_64" >> /etc/portage/package.use/zlib

echo "app-accessibility/at-spi2-core" >> /etc/portage/package.mask/server
echo "sys-apps/systemd" >> /etc/portage/package.mask/server

# Create system accounts
id livecd &>/dev/null || useradd -m -G users,wheel,audio,video,cdrom,usb,portage,render livecd

emerge --quiet --getbinpkg --noreplace \
  net-misc/dhcpcd \
  net-wireless/wpa_supplicant \
  sys-boot/efibootmgr \
  app-portage/portage-utils \
  app-editors/nano \
  sys-process/btop \
  app-admin/doas \
  net-misc/ntp \
  sys-apps/dmidecode \
  app-misc/screen \
  sys-apps/pciutils \
  sys-apps/usbutils \
  sys-kernel/dracut \
  sys-kernel/linux-firmware \
  sys-fs/btrfs-progs \
  sys-fs/cryptsetup \
  sys-fs/dosfstools \
  net-misc/wget \
  sys-process/cronie \
  app-eselect/eselect-repository \
  sys-apps/gptfdisk \
  net-misc/rsync \
  net-misc/openssh \
  net-vpn/tailscale \
  sys-boot/grub

echo ">>> Applying Copy Fail / Dirty Frag / Fragnesia mitigations..."

mkdir -p /etc/modprobe.d
cat > /etc/modprobe.d/lpe-mitigations.conf <<'EOF'
# Copy Fail
blacklist algif_aead
install algif_aead /bin/false

# Dirty Frag / Fragnesia
blacklist esp4
blacklist esp6
blacklist rxrpc

install esp4 /bin/false
install esp6 /bin/false
install rxrpc /bin/false
EOF

# Unload vulnerable modules if loaded
for mod in algif_aead esp4 esp6 rxrpc; do
    if lsmod | awk '{print $1}' | grep -qx "$mod"; then
        modprobe -r "$mod" || true
    fi
done

depmod -a || true

echo ">>> Installing OpenRC mitigation service..."

cat > /etc/init.d/lpe-mitigations <<'EOF'
#!/sbin/openrc-run

description="Copy Fail / Dirty Frag / Fragnesia mitigations"

depend() {
    before net
}

start() {
    ebegin "Applying kernel mitigations"

    for mod in algif_aead esp4 esp6 rxrpc; do
        modprobe -r "$mod" 2>/dev/null || true
    done

    eend 0
}
EOF

chmod +x /etc/init.d/lpe-mitigations
rc-update add lpe-mitigations boot


echo ">>> Configuring OpenRC services..."
rc-update add sshd default
rc-update add dhcpcd default
rc-update add cronie default
rc-update add tailscale default

# Verbose attempt to start Tailscale during the build for diagnostics
echo ">>> Testing Tailscale service initialization..."
if ! rc-service --verbose tailscale start; then
  echo ":: [INFO] Tailscale failed to start in the CI environment (this is expected in unprivileged chroots)." >&2
  echo ":: [DIAGNOSTIC] Checking tailscale service status:" >&2
  rc-service tailscale status || true
fi

echo ">>> Configuring doas for live user..."
touch /etc/doas.conf
chown root:root /etc/doas.conf
chmod 0400 /etc/doas.conf

echo "permit persist :wheel" >> /etc/doas.conf

# echo ">>> Removing passwords..."
# passwd -d root
# passwd -d livecd

echo 'root:root' | chpasswd
echo 'livecd:livecd' | chpasswd

echo ">>> Cleaning up..."
rm -rf /var/db/repos/gentoo \
       /var/cache/binpkgs \
       /var/tmp/ccache \
       /var/tmp/portage \
       /var/cache/distfiles 2>/dev/null || true

find /usr/share/locale \
     -mindepth 1 \
     -maxdepth 1 \
     ! -name 'en*' \
     ! -name 'locale.alias' \
     -exec rm -rf {} + 2>/dev/null || true

echo ">>> Server LiveCD configuration complete"
