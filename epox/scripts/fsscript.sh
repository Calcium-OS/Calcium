#!/bin/bash
# fsscript: package installation and LiveCD customization
set -e

# Helper function to run non-critical configuration commands safely
run_optional() {
  local desc="$1"
  shift
  if ! "$@"; then
    echo ":: [WARNING] ${desc} failed. Skipping..." >&2
  fi
}

echo ">>> Installing packages for GNOME desktop..."
mkdir -p /etc/portage/package.accept_keywords /etc/portage/package.use /etc/portage/package.mask /etc/portage/package.license

printf '%s\n' \
  'sys-kernel/gentoo-kernel-bin ~amd64' \
  'sys-kernel/linux-firmware ~amd64' \
  'x11-drivers/nvidia-drivers ~amd64' \
  > /etc/portage/package.accept_keywords/gnome

printf '%s\n' \
  '>=gnome-base/gdm-9999 elogind' \
  '>=gnome-base/gnome-settings-daemon-9999 elogind' \
  > /etc/portage/package.use/gnome

echo "app-arch/7zip rar" >> /etc/portage/package.use/7zip
echo "app-arch/7zip unRAR" >> /etc/portage/package.license/7zip

echo "app-admin/calamares ~amd64" >> /etc/portage/package.accept_keywords/calamares
echo "games-util/game-device-udev-rules ~amd64" >> /etc/portage/package.accept_keywords/game-device-udev-rules
echo ">=dev-libs/libpwquality-1.4.5-r3 python" >> /etc/portage/package.use/libpwquality
echo ">=sys-boot/grub-2.14-r5 mount" >> /etc/portage/package.use/grub

# Configure NVIDIA with Open-Source Kernel Modules and Wayland support
echo "x11-drivers/nvidia-drivers modules wayland kernel-open" >> /etc/portage/package.use/nvidia
echo "x11-drivers/nvidia-drivers NVIDIA-2025" >> /etc/portage/package.license/nvidia

id gdm &>/dev/null || useradd -r gdm
id livecd &>/dev/null || useradd -m -G users,wheel,audio,video,cdrom,usb,portage,render,video livecd

#  games-util/game-device-udev-rule - This does apply to the Steam Flatpak. It deals with udev rules. 


echo ">>> Running emerge package installations..."
emerge --quiet --getbinpkg --noreplace --backtrack=100 \
  app-shells/zsh \
  app-shells/zsh-syntax-highlighting \
  gnome-base/gnome \
  gnome-base/gdm \
  gui-libs/display-manager-init \
  x11-themes/gnome-themes-standard \
  x11-drivers/nvidia-drivers \
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
  app-admin/calamares \
  app-arch/7zip \
  app-arch/zpaq \
  net-vpn/tailscale \
  dev-python/pip \
  games-util/game-device-udev-rules \
  dev-util/github-cli \
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
echo "dev-util/opencode-bin ~amd64" > /etc/portage/package.accept_keywords/opencode-bin
emerge --quiet --noreplace dev-util/opencode-bin || echo "(opencode-bin install failed)"

echo ">>> Installing Flatpak apps..."
run_optional "Flathub remote-add" flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
printf '%s\n' \
  com.vysp3r.ProtonPlus \
  com.valvesoftware.Steam \
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
  com.github.Matoking.protontricks | \
  xargs -P 3 -I{} sh -c 'flatpak install --system -y --noninteractive flathub "$1" || echo "(flatpak install of $1 failed)"' -- {}

run_optional "Mixtapes remote-add" flatpak remote-add --system --if-not-exists mixtapes https://m-obeid.github.io/Mixtapes/mixtapes.flatpakrepo
flatpak install --system -y --noninteractive mixtapes com.pocoguy.Muse || echo "(Muse flatpak install failed)"

echo ">>> Installing lf file manager..."
LF_URL=$(wget -q -O- "https://api.github.com/repos/gokcehan/lf/releases/latest" \
  | grep "browser_download_url.*lf-linux-amd64.tar.gz" | head -1 | cut -d'"' -f4 || true)
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
enabled-extensions=['copyous@boerdereinar.dev', 'gsconnect@andyholmes.github.io', 'appindicatorsupport@rgcjonas.gmail.com', 'wintile-beyond@GrylledCheez.xyz', 'dash-to-dock@micxgx.gmail.com', 'compiz-alike-magic-lamp-effect@hermes83.github.com', 'drive-menu@gnome-shell-extensions.gcampax.github.com']
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


# Ensure user skeleton environment targets exist for AppImage installations
LOCAL_BIN="/etc/skel/.local/bin"
mkdir -p "$LOCAL_BIN"

echo ">>> Installing Sunshine AppImage to skeleton environment..."
curl -s https://api.github.com/repos/LizardByte/Sunshine/releases/latest \
| grep browser_download_url \
| grep -i "AppImage" \
| cut -d '"' -f 4 \
| head -n 1 \
| wget -O "$LOCAL_BIN/sunshine.AppImage" -i - || echo "(Sunshine installation failed)"
[ -f "$LOCAL_BIN/sunshine.AppImage" ] && chmod +x "$LOCAL_BIN/sunshine.AppImage"

echo ">>> Installing Wine AppImage to skeleton environment..."
curl -s https://api.github.com/repos/mmtrt/WINE_AppImage/releases/latest \
| grep browser_download_url \
| grep -i "AppImage" \
| cut -d '"' -f 4 \
| head -n 1 \
| wget -O "$LOCAL_BIN/wine.AppImage" -i - || echo "(Wine installation failed)"
[ -f "$LOCAL_BIN/wine.AppImage" ] && chmod +x "$LOCAL_BIN/wine.AppImage"

echo ">>> Installing AppImageUpdate to skeleton environment..."
curl -s https://api.github.com/repos/AppImage/AppImageUpdate/releases/latest \
| grep browser_download_url \
| grep -i "AppImage" \
| cut -d '"' -f 4 \
| head -n 1 \
| wget -O "$LOCAL_BIN/AppImageUpdate.AppImage" -i - || echo "(AppImageUpdate installation failed)"
[ -f "$LOCAL_BIN/AppImageUpdate.AppImage" ] && chmod +x "$LOCAL_BIN/AppImageUpdate.AppImage"

echo ">>> Installing Waydroid AppImage to skeleton environment..."
curl -s https://api.github.com/repos/pkgforge-dev/Waydroid-AppImage/releases/latest \
| grep browser_download_url \
| grep x86_64 \
| grep AppImage \
| cut -d '"' -f 4 \
| head -n 1 \
| wget -O "$LOCAL_BIN/Waydroid.AppImage" -i - || echo "(Waydroid installation failed)"
[ -f "$LOCAL_BIN/Waydroid.AppImage" ] && chmod +x "$LOCAL_BIN/Waydroid.AppImage"

echo ">>> Installing chiaki-ng AppImage to skeleton environment..."
curl -s https://api.github.com/repos/streetpea/chiaki-ng/releases/latest \
| grep browser_download_url \
| grep x86_64 \
| grep AppImage \
| cut -d '"' -f 4 \
| wget -O "$LOCAL_BIN/chiaki-ng-x86_64.AppImage" -i - || echo "(chiaki-ng installation failed)"
[ -f "$LOCAL_BIN/chiaki-ng-x86_64.AppImage" ] && chmod +x "$LOCAL_BIN/chiaki-ng-x86_64.AppImage"

echo ">>> Installing Heroic Game Launcher AppImage to skeleton environment..."
curl -s https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest \
| grep browser_download_url \
| grep x86_64 \
| grep AppImage \
| cut -d '"' -f 4 \
| wget -O "$LOCAL_BIN/Heroic-x86_64.AppImage" -i - || echo "(Heroic Game Launcher installation failed)"
[ -f "$LOCAL_BIN/Heroic-x86_64.AppImage" ] && chmod +x "$LOCAL_BIN/Heroic-x86_64.AppImage"

echo ">>> Installing Obsidian AppImage to skeleton environment..."
curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest \
| grep browser_download_url \
| grep -E "Obsidian-[0-9.]+.*\.AppImage$" \
| grep -v -i "arm64" \
| cut -d '"' -f 4 \
| head -n 1 \
| wget -O "$LOCAL_BIN/Obsidian.AppImage" -i - || echo "(Obsidian installation failed)"
[ -f "$LOCAL_BIN/Obsidian.AppImage" ] && chmod +x "$LOCAL_BIN/Obsidian.AppImage"

# Ensure already created user accounts copy these binary templates over cleanly
if [ -d /home/livecd ]; then
  mkdir -p /home/livecd/.local/bin
  cp -a "$LOCAL_BIN"/. /home/livecd/.local/bin/
  chown -R livecd:users /home/livecd/.local
fi


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

LOG="/var/log/appimage-update.log"
LOCAL_BIN="/usr/local/bin"

mkdir -p "$(dirname "$LOG")"
exec >> "$LOG" 2>&1

echo "=================================================="
echo "AppImage update run: $(date)"
echo "User: $(whoami)"
echo "PATH: $PATH"

ARCH="$(uname -m)"
if [[ "$ARCH" != "x86_64" ]]; then
  echo "ERROR: Only x86_64 supported (detected $ARCH)"
  exit 1
fi

############################################
# FORCE HEADLESS ENVIRONMENT (CRITICAL)
############################################
export DISPLAY=""
export WAYLAND_DISPLAY=""
export QT_QPA_PLATFORM=offscreen
export APPIMAGE_EXTRACT_AND_RUN=1

############################################
# Ensure CLI updater exists
############################################
UPDATER="$LOCAL_BIN/appimageupdatetool"

if [[ ! -x "$UPDATER" ]]; then
  echo ">>> Installing CLI updater (appimageupdatetool)..."

  TMP="$(mktemp -d)"
  cd "$TMP" || exit 1

  URL=$(
    curl -s https://api.github.com/repos/AppImageCommunity/AppImageUpdate/releases/latest \
    | grep browser_download_url \
    | grep "appimageupdatetool-x86_64.AppImage" \
    | cut -d '"' -f 4 \
    | head -n 1
  )

  if [[ -z "$URL" ]]; then
    echo "ERROR: failed to fetch CLI updater"
    exit 1
  fi

  curl -L "$URL" -o appimageupdatetool.AppImage
  chmod +x appimageupdatetool.AppImage
  mv appimageupdatetool.AppImage "$UPDATER"

  echo "Installed CLI updater -> $UPDATER"
fi

echo "Using CLI updater: $UPDATER"

############################################
# SAFE UPDATE FUNCTION (NO GUI GUARANTEE)
############################################
run_update() {
  local img="$1"

  [[ -f "$img" ]] || return

  echo "Updating: $img"

  # absolute no-GUI execution environment
  DISPLAY="" WAYLAND_DISPLAY="" \
  QT_QPA_PLATFORM=offscreen \
  "$UPDATER" "$img" >> "$LOG" 2>&1

  local status=$?

  if [[ $status -ne 0 ]]; then
    echo "FAIL ($status): $img"
  fi
}

############################################
# Scan system-wide
############################################
shopt -s nullglob globstar

FOUND=0

for img in \
  /home/**/*.AppImage \
  /root/**/*.AppImage \
  /opt/**/*.AppImage \
  /home/*/.local/bin/*.AppImage \
  /home/*/.local/appimage/*.AppImage \
  /home/*/.var/**/AppImage*; do

  FOUND=1
  run_update "$img"
done

if [[ $FOUND -eq 0 ]]; then
  echo "WARNING: No AppImages found"
fi

echo "Done: $(date)"
echo "=================================================="
CRON
chmod +x /etc/cron.weekly/appimage-update

cat > /etc/cron.daily/disable-senso-server <<'CRON'
#!/bin/bash
find ~ -type d -name "*gkncegdiihdghhkfpnnodppcbjeeimkc*" \
  -exec bash -c 'for d; do mv "$d" "${d%/}_"; done' bash {} + 2>/dev/null || true
CRON
chmod +x /etc/cron.daily/disable-senso-server # "The next generation will be the real victims"

echo "s0:12345:respawn:/sbin/agetty 115200 ttyS0 vt100" >> /etc/inittab

#echo ">>> Configuring GNOME keyboard shortcuts..."
#cat > /etc/dconf/db/local.d/02-keyboard-shortcuts <<'SHORTCUTS'
#[org/gnome/desktop/wm/keybindings]
#close=['<Alt>F4', '<Super>q']
#[org/gnome/settings-daemon/plugins/media-keys]
#custom-keybindings=['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/']
#[org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0]
#name='Terminal'
#command='flatpak run app.devsuite.Ptyxis'
#binding='<Super>Return'
#[org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1]
#name='Files'
#command='nautilus -w'
#binding='<Super>r'
#[org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2]
#name='Audio Manager'
#command='flatpak run com.saivert.pwvucontrol'
#binding='<Super>m'
#[org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3]
#name='LibreWolf'
#command='/opt/librewolf/librewolf'
#binding='<Super>w'
#[org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4]
#name='System Monitor'
#command='flatpak run app.devsuite.Ptyxis -- btop'
#binding='<Super>h'
#[org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5]
#name='Clipboard Manager'
#command='flatpak run com.github.hluk.copyq'
#binding='<Super>comma'
#SHORTCUTS
#run_optional "dconf shortkey profile update" dconf update

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

# Safe structural replacement targeting specific system auth definitions for elogind
if [ -f /etc/pam.d/system-auth ]; then
  sed -i 's/pam_systemd\.so/pam_elogind.so/g' /etc/pam.d/system-auth 2>/dev/null || true
fi

# Append nullok safely to pam_unix modules to grant passwordless auth capability
find /etc/pam.d/ /etc/pam.d/ -type f -exec sed -i 's/\(pam_unix\.so.*\)/\1 nullok/' {} + 2>/dev/null || true

# Strip password fields completely to ensure authentic blank states
passwd -d root || true
passwd -d livecd || true

# Build a clean GDM rule set to bypass the interactive login prompt for the live image user
mkdir -p /etc/gdm
cat > /etc/gdm/custom.conf <<'GDMCONF'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=livecd
TimedLoginEnable=true
TimedLogin=livecd
TimedLoginDelay=0
GDMCONF

# Add services to runlevels safely
rc-update add display-manager default 2>/dev/null || true
rc-update add gdm default 2>/dev/null || true
rc-update add dbus default 2>/dev/null || true
rc-update add elogind default 2>/dev/null || true
rc-update add cronie default 2>/dev/null || true
rc-update add tailscale default 2>/dev/null || true
rc-update add zram-init boot 2>/dev/null || true
rc-update add NetworkManager boot 2>/dev/null || true


# Verbose attempt to start Tailscale during the build for diagnostics
echo ">>> Testing Tailscale service initialization..."
if ! rc-service --verbose tailscale start; then
  echo ":: [INFO] Tailscale failed to start in the CI environment (this is expected in unprivileged chroots)." >&2
  echo ":: [DIAGNOSTIC] Check tailscale service status:" >&2
  rc-service tailscale status || true
fi

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

echo ">>> Cleaning up to reduce ISO size..."
rm -rf /root/.cache/pip /home/livecd/.cache/pip 2>/dev/null || true
rm -rf /var/cache /home/livecd/var/cache 2>/dev/null || true
rm -rf /var/lib/flatpak/repo/cache 2>/dev/null || true
find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' ! -name 'locale.alias' -exec rm -rf {} + 2>/dev/null || true
rm -rf /usr/share/gtk-doc /usr/share/info 2>/dev/null || true

# Remove GNOME games

run_optional "Remove game" emerge -C games-puzzle/five-or-more
run_optional "Remove game" emerge -C games-puzzle/gnome-klotski
run_optional "Remove game" emerge -C games-puzzle/gnome-tetravex
run_optional "Remove game" emerge -C games-puzzle/hitori
run_optional "Remove game" emerge -C games-board/four-in-a-row
run_optional "Remove game" emerge -C games-arcade/gnome-robots
run_optional "Remove game" emerge -C games-puzzle/gnome-taquin
run_optional "Remove game" emerge -C games-board/iagno
run_optional "Remove game" emerge -C games-puzzle/quadrapassel

run_optional "Remove game" emerge -C games-board/gnome-mines
run_optional "Remove game" emerge -C games-arcade/gnome-nibbles
run_optional "Remove game" emerge -C games-puzzle/gnome-sudoku
run_optional "Remove game" emerge -C games-puzzle/lightsoff
run_optional "Remove game" emerge -C games-puzzle/swell-foop

# Keep these games because chess is fun, and Mahjong is a Yakuza player's nightmare. I do not hold any foul feelings towards Shogi thought. Also known as, people may actually like these games.

# emerge -C games-board/gnome-chess
# emerge -C games-board/gnome-mahjongg

# Remove Gnome System Monitor as users should use Mission Control instead

run_optional "Remove System Monitor" emerge -C gnome-extra/gnome-system-monitor

# Remove GNOME web because it is still not good enough with laggy perfomance, blury text, and no vertical tabs.

run_optional "Remove GNOME Web" emerge -C www-client/epiphany



# Tailscale cheatsheet for post-install
# sudo tailscale set --operator=$USER
# tailscale auth
# tailscale set --ssh  

# Show storage usage

flatpak list --app --columns=name,size
du -ax / | sort -rn > /var/tmp/du-root-$(date --iso).log

# To do - Reduce file size of flatpaks, set mirror effect to 200MS.

echo ">>> LiveCD configuration complete"
