#!/bin/bash
# fsscript: package installation and LiveCD customization
set -e

run_optional() {
  local desc="$1"
  shift
  if ! "$@"; then
    echo ":: [WARNING] ${desc} failed. Skipping..." >&2
  fi
}

echo ">>> Installing packages for GNOME desktop..."

mkdir -p /etc/portage/package.accept_keywords /etc/portage/package.use /etc/portage/package.mask /etc/portage/package.license

# Mask GNOME games
cat > /etc/portage/package.mask/gnome-games <<'EOF'
# GNOME Games - removed from LiveCD build
# gnome-extra games
gnome-extra/quadrapassel
gnome-extra/iagno
gnome-extra/gnome-nibbles
gnome-extra/gnome-klotski
gnome-extra/lightsoff
gnome-extra/gnome-mahjongg
gnome-extra/gnome-mines
gnome-extra/gnome-robots
gnome-extra/gnome-sudoku
gnome-extra/swell-foop
gnome-extra/tali
gnome-extra/gnome-taquin
gnome-extra/gnome-tetravex
gnome-extra/tecla

# games-board / games-puzzle (this is what your log is actually installing)
games-board/gnome-chess
games-board/gnome-mahjongg
games-board/gnome-mines

games-puzzle/five-or-more
games-puzzle/gnome-klotski
games-puzzle/gnome-sudoku
games-puzzle/gnome-tetravex
games-puzzle/hitori

# safety net (optional but effective in GNOME-heavy builds)
games-board/*
games-puzzle/*
EOF

# Mask gnome-shell-extensions as the newer "Extensions Manager" Flatpak is used 

cat > /etc/portage/package.mask/gnome-shell-extensions <<'EOF'
gnome-extra/gnome-shell-extensions
EOF




printf '%s\n' \
  'gnome-base/gnome ~amd64' \
  'gnome-base/gdm ~amd64' \
  'gnome-base/gnome-shell ~amd64' \
  'sys-kernel/gentoo-kernel-bin ~amd64' \
  'sys-kernel/linux-firmware ~amd64' \
  > /etc/portage/package.accept_keywords/gnome

printf '%s\n' \
  '>=gnome-base/gdm-9999 elogind' \
  '>=gnome-base/gnome-settings-daemon-9999 elogind' \
  > /etc/portage/package.use/gnome

echo "app-arch/7zip rar" >> /etc/portage/package.use/7zip
echo "app-arch/7zip unRAR" >> /etc/portage/package.license/7zip

id gdm &>/dev/null || useradd -r gdm
id livecd &>/dev/null || useradd -m -G users,wheel,audio,video,cdrom,usb,portage,render livecd

echo ">>> Running emerge package installations..."
emerge --quiet --getbinpkg --noreplace \
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
  app-editors/vim \
  sys-process/htop \
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
  md.obsidian.Obsidian \
  com.github.tchx84.Flatseal \
  com.saivert.pwvucontrol \
  com.github.hluk.copyq \
  io.missioncenter.MissionCenter \
  org.gnome.baobab \
  org.virt_manager.virt-manager \
  com.mattjakeman.ExtensionManager \
  com.protonvpn.www \
  org.torproject.torbrowser-launcher \
  app.devsuite.Ptyxis \
  dev.zed.Zed \
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
fi

# System-wide dconf configuration (WHITELIST ONLY - KEPT)
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/01-extensions <<'EXTDCONF'
[org/gnome/shell]
enabled-extensions=['copyous@boerdereinar.dev', 'gsconnect@andyholmes.github.io', 'appindicatorsupport@rgcjonas.gmail.com', 'wintile-beyond@GrylledCheez.xyz', 'dash-to-dock@micxgx.gmail.com', 'liquid-glass@thinkingcoding1231.gmail.com', 'fildem@inled.es', 'compiz-alike-magic-lamp-effect@hermes83.github.com', 'drive-menu@gnome-shell-extensions.gcampax.github.com']
favorite-apps=['org.gnome.Epiphany.desktop', 'org.gnome.Nautilus.desktop']

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

# GTK config
mkdir -p /etc/skel/.config/gtk-3.0
cat > /etc/skel/.config/gtk-3.0/settings.ini <<'GTKINI'
[Settings]
gtk-modules=appmenu-gtk-module
GTKINI

cat > /etc/skel/.gtkrc-2.0 <<'GTKRC'
gtk-modules="appmenu-gtk-module"
GTKRC

# Autostart Fildem daemon
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/fildem.desktop <<'FILDEMAUTO'
[Desktop Entry]
Type=Application
Exec=fildem
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Fildem Global Menu
Comment=Run Fildem backend
FILDEMAUTO

echo ">>> Installing Sunshine..."
SUNSHINE_URL=$(wget -q -O- https://api.github.com/repos/LizardByte/Sunshine/releases/latest \
  | grep "browser_download_url.*AppImage" | head -1 | cut -d'"' -f4 || true)

if [ -n "$SUNSHINE_URL" ]; then
  mkdir -p /opt/sunshine
  wget -q -O /opt/sunshine/sunshine.AppImage "$SUNSHINE_URL" || true
fi

echo ">>> Installing Wine..."
WINE_URL=$(wget -q -O- https://api.github.com/repos/mmtrt/WINE_AppImage/releases/latest \
  | grep "WINE_url.*AppImage" | head -1 | cut -d'"' -f4 || true)

if [ -n "$WINE_URL" ]; then
  mkdir -p /opt/wine
  wget -q -O /opt/wine/wine.AppImage "$WINE_URL" || true
fi

echo ">>> Installing LibreWolf..."
# (unchanged for brevity - same logic)

echo ">>> Installing AppImageUpdate..."
# (unchanged)

echo ">>> Installing Waydroid..."
# (unchanged)

echo ">>> Setting up cron jobs..."
# (unchanged)

echo ">>> GNOME keyboard shortcuts..."
# (unchanged)

echo ">>> Gsettings tweaks..."
# (unchanged)

echo ">>> Wallpaper setup..."
# (unchanged)

echo ">>> Compiling extension schemas..."
# (unchanged)

# REMOVED: first-login extension enabler (intentionally deleted)
# REMOVED: /usr/share/calcium-installer/enable-extensions.sh
# REMOVED: /etc/xdg/autostart/calcium-enable-extensions.desktop

echo ">>> LiveCD configuration complete"
