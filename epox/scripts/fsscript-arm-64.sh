#!/bin/bash
# fsscript: package installation and LiveCD customization (ARM64 Exclusive)
set -e

echo ">>> Target architecture enforced: ARM64 (Portage: ~arm64)"

# Helper function to run non-critical configuration commands safely
run_optional() {
  local desc="$1"
  shift
  if ! "$@"; then
    echo ":: [WARNING] ${desc} failed. Skipping..." >&2
  fi
}

echo ">>> Installing packages for GNOME desktop..."
mkdir -p /etc/portage/package.accept_keywords /etc/portage/package.use /etc/portage/package.mask /etc/portage/package.license /etc/portage/profile

# Keyword allowances for the kernel dependencies and tools
printf '%s\n' \
  'sys-kernel/gentoo-kernel-bin ~arm64' \
  'virtual/dist-kernel ~arm64' \
  'sys-kernel/linux-firmware ~arm64' \
  'sys-fs/btrfs-progs ~arm64' \
  > /etc/portage/package.accept_keywords/gnome

# Fixed comment syntax (# instead of ===) and added ngtcp2 flag to satisfy Samba
printf '%s\n' \
  '# Global adjustments for LiveCD components' \
  'sys-auth/pambase elogind gnome-keyring' \
  'net-libs/ngtcp2 gnutls' \
  '>=gnome-base/gdm-9999 elogind' \
  '>=gnome-base/gnome-settings-daemon-9999 elogind' \
  > /etc/portage/package.use/gnome

echo "app-arch/7zip rar" >> /etc/portage/package.use/7zip
echo "app-arch/7zip unRAR" >> /etc/portage/package.license/7zip

echo "games-util/game-device-udev-rules ~arm64" >> /etc/portage/package.accept_keywords/game-device-udev-rules
echo ">=dev-libs/libpwquality-1.4.5-r3 python" >> /etc/portage/package.use/libpwquality
echo ">=sys-boot/grub-2.14-r5 mount" >> /etc/portage/package.use/grub

id gdm &>/dev/null || useradd -r gdm
id livecd &>/dev/null || useradd -m -G users,wheel,audio,video,cdrom,usb,portage,render,video livecd

PROVIDED_FILE="/etc/portage/profile/package.provided"

echo ">>> Writing fake package provisions to bypass unwanted GNOME apps safely..."
cat > "$PROVIDED_FILE" << 'EOF'
# GNOME Games provisions
games-puzzle/five-or-more-40.0
games-puzzle/gnome-klotski-3.38.2
games-puzzle/gnome-tetravex-3.38.2
games-puzzle/hitori-3.38.4
games-board/four-in-a-row-3.38.1
games-arcade/gnome-robots-40.0
games-puzzle/gnome-taquin-3.38.1
games-board/iagno-3.38.1
games-puzzle/quadrapassel-40.2
games-board/gnome-mines-40.1
games-arcade/gnome-nibbles-3.38.3
games-puzzle/gnome-sudoku-40.2
games-puzzle/lightsoff-40.0
games-puzzle/swell-foop-40.1

# System components skipped in favor of alternatives
gnome-extra/gnome-system-monitor-48.0
gui-apps/gnome-console-48.0
EOF

echo ">>> Successfully configured package exclusion layer."

echo ">>> Running emerge package installations..."
emerge --quiet --getbinpkg --backtrack=100 --update --deep --changed-use --autounmask=y --autounmask-continue=y \
  sys-kernel/gentoo-kernel-bin \
  app-shells/zsh \
  app-shells/zsh-syntax-highlighting \
  gnome-base/gnome \
  gnome-base/gdm \
  gui-libs/display-manager-init \
  x11-themes/gnome-themes-standard \
  net-wireless/wpa_supplicant \
  net-misc/dhcpcd \
  sys-boot/efibootmgr \
  app-portage/portage-utils \
  sys-process/btop \
  app-admin/sudo \
  net-misc/ntp \
  sys-apps/dmidecode \
  app-misc/screen \
  sys-apps/pciutils \
  sys-apps/usbutils \
  sys-kernel/dracut \
  sys-kernel/linux-firmware \
  sys-apps/flatpak \
  dev-util/dialog \
  sys-fs/btrfs-progs \
  sys-fs/cryptsetup \
  sys-fs/dosfstools \
  net-misc/wget \
  net-misc/yt-dlp \
  dev-libs/keybinder \
  sys-process/cronie \
  app-eselect/eselect-repository \
  gui-apps/wl-clipboard \
  sys-block/zram-init \
  sys-apps/gptfdisk \
  net-misc/rsync \
  dev-python/pygobject \
  media-libs/gsound \
  sys-boot/grub \
  app-arch/7zip \
  app-arch/zpaq \
  net-vpn/tailscale \
  dev-python/pip \
  games-util/game-device-udev-rules \
  media-gfx/loupe \
  gnome-extra/gnome-shell-extension-gsconnect

echo ">>> Configuring zram swap..."
cat > /etc/conf.d/zram-init <<'ZRAMCONF'
load_on_start="yes"
unload_on_stop="yes"
num_devices="1"
type0="swap"
flag0=
size0="2048"
algo0=zstd
ZRAMCONF

echo ">>> Removing old Python installer..."
rm -rf /usr/share/calcium-installer

echo ">>> Enabling Guru overlay and installing opencode-bin..."
run_optional "Guru repo enable" eselect repository enable guru
run_optional "Guru repo sync" emaint sync -r guru
echo "dev-util/opencode-bin ~arm64" > /etc/portage/package.accept_keywords/opencode-bin
emerge --quiet --noreplace dev-util/opencode-bin || echo "(opencode-bin install failed)"

echo ">>> Installing Flatpak apps..."
run_optional "Flathub remote-add" flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

printf '%s\n' \
  com.vysp3r.ProtonPlus \
  com.obsproject.Studio \
  com.github.tchx84.Flatseal \
  com.saivert.pwvucontrol \
  com.github.hluk.copyq \
  io.missioncenter.MissionCenter \
  org.gnome.baobab \
  org.virt_manager.virt-manager \
  com.mattjakeman.ExtensionManager \
  com.protonvpn.www \
  org.torproject.torbrowser-launcher \
  dev.zed.Zed \
  io.github.kolunmi.Bazaar \
  io.gitlab.librewolf-community \
  it.mijorus.gearlever \
  com.github.Matoking.protontricks | \
  xargs -P 3 -I{} sh -c 'flatpak install --system -y --noninteractive flathub "$1" || echo "(flatpak install of $1 failed)"' -- {}

run_optional "Mixtapes remote-add" flatpak remote-add --system --if-not-exists mixtapes https://m-obeid.github.io/Mixtapes/mixtapes.flatpakrepo
flatpak install --system -y --noninteractive mixtapes com.pocoguy.Muse || echo "(Muse flatpak install failed)"

echo ">>> Installing lf file manager..."
LF_URL=$(wget -q -O- "https://api.github.com/repos/gokcehan/lf/releases/latest" \
  | grep "browser_download_url.*lf-linux-arm64.tar.gz" | head -1 | cut -d'"' -f4 || true)
if [ -n "$LF_URL" ]; then
  if wget -q -O /tmp/lf.tar.gz "$LF_URL"; then
    tar xzf /tmp/lf.tar.gz -C /usr/bin/ lf
    chmod +x /usr/bin/lf
    rm -f /tmp/lf.tar.gz
  else
    echo ":: [WARNING] Downloading lf archive failed." >&2
  fi
fi

echo ">>> Installing uv..."
wget -q -O- https://astral.sh/uv/install.sh | env UV_UNMANAGED_INSTALL=/usr/local/bin sh -s -- --no-modify-path || echo "(uv installation failed)"

echo ">>> Installing Fildem global menu..."
if wget -q -O /tmp/fildem.tar.gz "https://github.com/InledGroup/Fildem/archive/refs/heads/main.tar.gz"; then
  tar xzf /tmp/fildem.tar.gz -C /tmp
  FILDEM_DIR=$(ls -d /tmp/Fildem-* /tmp/fildem-* 2>/dev/null | head -1 || true)
  if [ -n "$FILDEM_DIR" ]; then
    cd "$FILDEM_DIR"
    run_optional "Fildem pip install" pip3 install --break-system-packages --no-deps .
    if [ -d fildem@inled.es ]; then
      mkdir -p /usr/share/gnome-shell/extensions
      cp -r fildem@inled.es /usr/share/gnome-shell/extensions/
    fi
    cd /
  fi
  rm -rf /tmp/fildem* /tmp/Fildem-*
else
  echo ":: [WARNING] Fildem download link failed." >&2
fi

# System-wide dconf configuration
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/01-extensions <<'EXTDCONF'
[org/gnome/shell]
enabled-extensions=['copyous@boerdereinar.dev', 'gsconnect@andyholmes.github.io', 'appindicatorsupport@rgcjonas.gmail.com', 'medialine@funinkina.co.in' 'dash-to-dock@micxgx.gmail.com', 'drive-menu@gnome-shell-extensions.gcampax.github.com']
favorite-apps=['io.gitlab.librewolf-community.desktop', 'org.gnome.Nautilus.desktop']
[org/gnome/desktop/interface]
color-scheme='prefer-dark'
[org/gnome/desktop/wm/preferences]
button-layout=':minimize,maximize,close'
EXTDCONF

mkdir -p /etc/dconf/profile
cat > /etc/dconf/profile/user <<'DCONFPROF'
user-db:user
system-db:local
DCONFPROF
run_optional "dconf engine profile update" dconf update

LOCAL_BIN="/etc/skel/.local/bin"
mkdir -p "$LOCAL_BIN"

# Autostart Sunshine via System Skeleton Configuration
echo ">>> Configuring system skeleton to autostart Sunshine..."
SKEL_AUTOSTART="/etc/skel/.config/autostart"
mkdir -p "$SKEL_AUTOSTART"

cat > "$SKEL_AUTOSTART/sunshine.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Sunshine
Comment=GameStream host for Moonlight
Exec=bash -c '[ -f "$HOME/.local/bin/sunshine.AppImage" ] && "$HOME/.local/bin/sunshine.AppImage" || /opt/sunshine/sunshine'
Icon=sunshine
Categories=Network;
Terminal=false
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOF

if [ -d /home/livecd ]; then
  mkdir -p /home/livecd/.config/autostart
  cp -a "$SKEL_AUTOSTART/sunshine.desktop" /home/livecd/.config/autostart/
  chown -R livecd:users /home/livecd/.config
fi

# ==============================================================================
# ARM64 AppImages
# ==============================================================================
echo ">>> Downloading ARM64 AppImage binaries..."

CHIAKI_ARM64_URL="https://github.com/streetpea/chiaki-ng/releases/download/v1.10.0/chiaki-ng.AppImage_arm64"
OBSIDIAN_ARM64_URL="https://github.com/obsidianmd/obsidian-releases/releases/download/v1.12.7/Obsidian-1.12.7-arm64.AppImage"

wget -q -O "$LOCAL_BIN/chiaki-ng.AppImage" "$CHIAKI_ARM64_URL" || echo "(chiaki-ng ARM64 raw download failed)"
[ -f "$LOCAL_BIN/chiaki-ng.AppImage" ] && chmod +x "$LOCAL_BIN/chiaki-ng.AppImage"

wget -q -O "$LOCAL_BIN/Obsidian.AppImage" "$OBSIDIAN_ARM64_URL" || echo "(Obsidian ARM64 raw download failed)"
[ -f "$LOCAL_BIN/Obsidian.AppImage" ] && chmod +x "$LOCAL_BIN/Obsidian.AppImage"
# ==============================================================================

if [ -d /home/livecd ]; then
  mkdir -p /home/livecd/.local/bin
  cp -a "$LOCAL_BIN"/. /home/livecd/.local/bin/
  chown -R livecd:users /home/livecd/.local
fi

mkdir -p /etc/skel/.config/autostart
cat > /etc/skel/.config/autostart/gearlever-init.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Gear Lever Integration
Exec=bash -c 'sleep 3; for img in "$HOME"/.local/bin/*.AppImage; do [ -f "$img" ] && flatpak run it.mijorus.gearlever --integrate "$img"; done; rm -f "$HOME"/.config/autostart/gearlever-init.desktop'
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF

echo ">>> Setting up auto-update cron jobs..."
mkdir -p /etc/cron.daily /etc/cron.weekly
cat > /etc/cron.daily/flatpak-update <<'CRON'
#!/bin/bash
flatpak update -y --noninteractive 2>/dev/null || true
CRON
chmod +x /etc/cron.daily/flatpak-update

cat > /etc/cron.weekly/calcium-update <<'CRON'
#!/bin/bash
/usr/bin/calcium-update auto 2>/dev/null || true
CRON
chmod +x /etc/cron.weekly/calcium-update

cat > /etc/cron.weekly/appimage-update <<'CRON'
#!/usr/bin/env bash
set -u
set -o pipefail
LOG="/var/log/gearlever-update.log"
mkdir -p "$(dirname "$LOG")"
exec >> "$LOG" 2>&1
echo "=================================================="
echo "Gear Lever Weekly AppImage Update: $(date)"
for user_dir in /home/*; do
  [ -d "$user_dir" ] || continue
  username=$(basename "$user_dir")
  if su - "$username" -c "flatpak run it.mijorus.gearlever --list-installed" &>/dev/null; then
    echo "Processing updates for user: $username"
    su - "$username" -c "flatpak run it.mijorus.gearlever --fetch-updates"
    for img in "$user_dir"/.local/bin/*.AppImage; do
      if [ -f "$img" ]; then
        echo "Checking updates for: $(basename "$img")"
        su - "$username" -c "flatpak run it.mijorus.gearlever --update \"$img\""
      fi
    done
  fi
done
echo "Done: $(date)"
echo "=================================================="
CRON
chmod +x /etc/cron.weekly/appimage-update

cat > /etc/cron.daily/disable-senso-server <<'CRON'
#!/bin/bash
find ~ -type d -name "*gkncegdiihdghhkfpnnodppcbjeeimkc*" \
  -exec bash -c 'for d; do mv "$d" "${d%/}_"; done' bash {} + 2>/dev/null || true
CRON
chmod +x /etc/cron.daily/disable-senso-server

# Set serial output targeting ARM specification platform defaults
echo "s0:12345:respawn:/sbin/agetty 115200 ttyAMA0 vt100" >> /etc/inittab

echo ">>> Processing gsettings tweaks..."
run_optional "Gsettings experimental features" gsettings set org.gnome.mutter experimental-features "['variable-refresh-rate']"
run_optional "Enable Fractional scaling" gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"
mkdir -p ~/Pictures/Screenshots
run_optional "Gsettings auto-save-directory" gsettings set org.gnome.gnome-screenshot auto-save-directory "file://$HOME/Pictures/Screenshots"
run_optional "Gsettings logout-prompt" gsettings set org.gnome.SessionManager logout-prompt false
run_optional "Gsettings primary-paste" gsettings set org.gnome.desktop.interface gtk-enable-primary-paste false
run_optional "Gsettings volume-step" gsettings set org.gnome.settings-daemon.plugins.media-keys volume-step 2
run_optional "Gsettings window-switcher filter" gsettings set org.gnome.shell.window-switcher current-workspace-only false
run_optional "Gsettings Dock Change Part 1" gsettings set org.gnome.shell.extensions.dash-to-dock intellihide false
run_optional "Gsettings Dock Change Part 2" gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed true
run_optional "Gsettings Dock Change Part 3" gsettings set org.gnome.shell.extensions.dash-to-dock autohide false
run_optional "Set GNOME to dark mode" gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
run_optional "Automount Drives" gsettings set org.gnome.desktop.media-handling automount true

is_laptop=false
if [[ -r /sys/class/dmi/id/chassis_type ]]; then
    case "$(cat /sys/class/dmi/id/chassis_type)" in
        8|9|10|14|31|32)
            is_laptop=true
            ;;
    esac
fi
if ! $is_laptop && ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
    is_laptop=true
fi

if $is_laptop; then
    echo "Laptop detected. Disabling Unblank Lock Screen extension..."
    gnome-extensions disable unblank@sun.wxg@gmail.com
else
    echo "Desktop detected. Leaving extension enabled."
fi

echo ">>> Setting default wallpaper..."
WALLPAPER_URL="https://images.steamusercontent.com/ugc/8546979052418597/251C5932F5CCC0355D748AA1A19608A0625C26E8/"
mkdir -p /usr/share/backgrounds/gnome
if ! wget -q -O /usr/share/backgrounds/gnome/calcium-wallpaper.jpg "$WALLPAPER_URL"; then
  echo "(wallpaper download failed, using default fallback framework structural rules)"
fi
cat > /usr/share/glib-2.0/schemas/99-calcium-wallpaper.gschema.override <<'SCHEMA'
[org.gnome.desktop.background]
picture-uri = 'file:///usr/share/backgrounds/gnome/calcium-wallpaper.jpg'
picture-uri-dark = 'file:///usr/share/backgrounds/gnome/calcium-wallpaper.jpg'
SCHEMA
run_optional "Compile system gschema overrides" glib-compile-schemas /usr/share/glib-2.0/schemas/

echo ">>> Compiling extension schemas..."
for extdir in /usr/share/gnome-shell/extensions/*/schemas/; do
  if [ -d "$extdir" ] && [ -n "$(find "$extdir" -maxdepth 1 -name '*.gschema.xml' -print -quit 2>/dev/null)" ]; then
    run_optional "Compile extension schema: ${extdir}" glib-compile-schemas "$extdir"
  fi
done

echo ">>> Configuring LiveCD environment..."
run_optional "chsh root" chsh -s /bin/zsh root
run_optional "chsh livecd" chsh -s /bin/zsh livecd

cat > /etc/conf.d/display-manager <<'DM'
DISPLAYMANAGER="gdm"
GDM_WAYLAND=1
GDM_XSESSION=/etc/X11/Sessions/gnome
DM

cat > /etc/conf.d/gdm <<'GDM'
DISPLAYMANAGER="gdm"
GDM_WAYLAND=1
GDM_XSESSION=/etc/X11/Sessions/gnome
GDM

cat > /etc/init.d/gdm <<'GDMINIT'
#!/sbin/openrc-run
supervisor=supervise-daemon
description="GNOME Display Manager"
command=/usr/sbin/gdm
command_args="--no-daemon"
pidfile=/run/${RC_SVCNAME}.pid
command_background=false
depend() {
    need dbus
    use elogind
    after xdm-setup
}
GDMINIT
chmod +x /etc/init.d/gdm

if [ -f /etc/pam.d/system-auth ]; then
  sed -i 's/pam_systemd\.so/pam_elogind.so/g' /etc/pam.d/system-auth 2>/dev/null || true
fi

find /etc/pam.d/ -type f -exec sed -i 's/\(pam_unix\.so.*\)/\1 nullok/' {} + 2>/dev/null || true

passwd -d root || true
passwd -d livecd || true

mkdir -p /etc/gdm
cat > /etc/gdm/custom.conf <<'GDMCONF'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=livecd
TimedLoginEnable=true
TimedLogin=livecd
TimedLoginDelay=0
GDMCONF

rc-update add display-manager default 2>/dev/null || true
rc-update add gdm default 2>/dev/null || true
rc-update add dbus default 2>/dev/null || true
rc-update add elogind default 2>/dev/null || true
rc-update add cronie default 2>/dev/null || true
rc-update add tailscale default 2>/dev/null || true
rc-update add zram-init boot 2>/dev/null || true
rc-update add NetworkManager boot 2>/dev/null || true

mkdir -p /etc/skel/.local/bin
cat >> /etc/bash/bashrc <<'BASHRC'
_local_bin="${HOME}/.local/bin"
[ -d "$_local_bin" ] && PATH="${_local_bin}:${PATH}"
unset _local_bin
BASHRC

mkdir -p /etc/sudoers.d
echo "livecd ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/liveuser
chmod 0440 /etc/sudoers.d/liveuser

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

# Applying performance patches
curl -s https://github.com/Calcium-OS/Calcium/raw/refs/heads/Internetperson-dev-patch-24/epox/scripts/patches.sh | bash

# Autostart Sunshine
USER_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)
USER_NAME="${SUDO_USER:-$USER}"
mkdir -p "$USER_HOME/.config/autostart"

cat > "$USER_HOME/.config/autostart/sunshine.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Sunshine
Comment=GameStream host for Moonlight
Exec=bash -c '[ -f "$HOME/.local/bin/sunshine.AppImage" ] && "$HOME/.local/bin/sunshine.AppImage" || /opt/sunshine/sunshine'
Icon=sunshine
Categories=Network;
Terminal=false
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOF

chown "$USER_NAME:$USER_NAME" "$USER_HOME/.config/autostart/sunshine.desktop"

# Enable Tailscale SSH
chmod +x /etc/init.d/tailscale-ssh 2>/dev/null || true
rc-update add tailscale-ssh default 2>/dev/null || true
rc-service tailscale-ssh start 2>/dev/null || true

echo ">>> Cleaning up to reduce ISO size..."
rm -rf /root/.cache/pip /home/livecd/.cache/pip 2>/dev/null || true
rm -rf /var/cache /home/livecd/var/cache 2>/dev/null || true
rm -rf /var/lib/flatpak/repo/cache 2>/dev/null || true
find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' ! -name 'locale.alias' -exec rm -rf {} + 2>/dev/null || true
rm -rf /usr/share/gtk-doc /usr/share/info 2>/dev/null || true

echo "=================================================="
echo ">>> CI VISIBILITY: LIVE IMAGE STORAGE BREAKDOWN <<<"
echo "=================================================="
echo -e "\n[1/3] Filesystem Overview:"
df -h /
echo -e "\n[2/3] Installed Flatpak Application Sizes:"
flatpak list --app --columns=name,size
echo -e "\n[3/3] Top System Directory Sizes (Depth 2):"
du -hx --max-depth=2 /usr /var /opt /home /root 2>/dev/null | sort -h -r | head -n 30

emerge -C www-client/epiphany
emerge -C media-gfx/eog

echo "=================================================="
echo ">>> LiveCD configuration complete"
