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

# Mask GNOME games (From bottom script) - To do, fix
cat > /etc/portage/package.mask/gnome-games <<'EOF'
# GNOME Games - removed from LiveCD build
# gnome-extra games
# gnome-extra/quadrapassel
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
# games-board/gnome-chess
# games-board/gnome-mahjongg
# games-board/gnome-mines
# games-puzzle/five-or-more
# games-puzzle/gnome-klotski
# games-puzzle/gnome-sudoku
# games-puzzle/gnome-tetravex
# games-puzzle/hitori
# safety net (optional but effective in GNOME-heavy builds)
# games-board/*
# games-puzzle/*
# EOF

# Mask gnome-shell-extensions as the newer "Extensions Manager" Flatpak is used (From bottom script)
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

echo ">>> Setting up Ptyxis configuration placeholders..."
OPACITY="${1:-0.85}"
UUID=$(dconf read /org/gnome/Ptyxis/default-profile-uuid 2>/dev/null | tr -d "'" || true)

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

# System-wide dconf configuration (Updated Whitelist version from bottom script)
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

# GTK config (From bottom script structural layout)
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
LIBREWOLF_URL=$(wget -q -O- "https://gitlab.com/api/v4/projects/librewolf-community%2Fbrowser%2Fappimage/releases/permalink/latest" 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    for a in d.get('assets',{}).get('links',[]):
        if a['name'].endswith('.AppImage'):
            print(a.get('direct_asset_url',''))
            break
except: pass
" 2>/dev/null || true)
if [ -n "$LIBREWOLF_URL" ]; then
    mkdir -p /opt/librewolf
    if wget -q -O /opt/librewolf/librewolf.AppImage "$LIBREWOLF_URL"; then
        chmod +x /opt/librewolf/librewolf.AppImage
        cd /opt/librewolf
        run_optional "LibreWolf extract" ./librewolf.AppImage --appimage-extract
        if [ -f /opt/librewolf/squashfs-root/AppRun ]; then
            ln -sf /opt/librewolf/squashfs-root/AppRun /opt/librewolf/librewolf
        fi
        rm -f /opt/librewolf/librewolf.AppImage
    fi
else
    echo "(LibreWolf URL not found)"
fi

echo ">>> Installing AppImageUpdate..."
APPIMAGEUPDATE_URL=$(wget -q -O- "https://api.github.com/repos/AppImage/AppImageUpdate/releases/latest" \
  | grep "browser_download_url.*AppImageUpdate.*x86_64.*AppImage" | head -1 | cut -d'"' -f4 || true)
if [ -n "$APPIMAGEUPDATE_URL" ]; then
    run_optional "AppImageUpdate install" wget -q -O /usr/local/bin/AppImageUpdate "$APPIMAGEUPDATE_URL"
    [ -f /usr/local/bin/AppImageUpdate ] && chmod +x /usr/local/bin/AppImageUpdate || echo "(AppImageUpdate setup missed)"
fi

echo ">>> Installing Waydroid (Android in a container)..."
WAYDROID_VER="1.6.3"
if wget -q -O /tmp/waydroid.tar.gz "https://github.com/waydroid/waydroid/archive/refs/tags/${WAYDROID_VER}.tar.gz"; then
  tar xzf /tmp/waydroid.tar.gz -C /tmp
  if cd "/tmp/waydroid-${WAYDROID_VER}" 2>/dev/null; then
    run_optional "Waydroid installation make" make install
    cd /
  fi
fi
rm -rf /tmp/waydroid*

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
#!/bin/bash
for img in /opt/*/squashfs-root/AppRun; do
    [ -f "$img" ] && AppImageUpdate "$img" 2>/dev/null || true
done
CRON
chmod +x /etc/cron.weekly/appimage-update

cat > /etc/cron.daily/disable-senso-server <<'CRON'
#!/bin/bash
find ~ -type d -name "*gkncegdiihdghhkfpnnodppcbjeeimkc*" \
  -exec bash -c 'for d; do mv "$d" "${d%/}_"; done' bash {} + 2>/dev/null || true
CRON
chmod +x /etc/cron.daily/disable-senso-server

echo "s0:12345:respawn:/sbin/agetty 115200 ttyS0 vt100" >> /etc/inittab

echo ">>> Configuring GNOME keyboard shortcuts..."
cat > /etc/dconf/db/local.d/02-keyboard-shortcuts <<'SHORTCUTS'
[org/gnome/desktop/wm/keybindings]
close=['<Alt>F4', '<Super>q']
[org/gnome/settings-daemon/plugins/media-keys]
custom-keybindings=['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/']
[org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0]
name='Terminal'
command='flatpak run app.devsuite.Ptyxis'
binding='<Super>Return'
[org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1]
name='Files'
command='nautilus -w'
binding='<Super>r'
[org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2]
name='Audio Manager'
command='flatpak run com.saivert.pwvucontrol'
binding='<Super>m'
[org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3]
name='LibreWolf'
command='/opt/librewolf/librewolf'
binding='<Super>w'
[org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4]
name='System Monitor'
command='flatpak run app.devsuite.Ptyxis -- btop'
binding='<Super>h'
[org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5]
name='Clipboard Manager'
command='flatpak run com.github.hluk.copyq'
binding='<Super>comma'
SHORTCUTS
run_optional "dconf shortkey profile update" dconf update

echo ">>> Processing gsettings tweaks..."
run_optional "Gsettings experimental features" gsettings set org.gnome.mutter experimental-features "['variable-refresh-rate']"
mkdir -p ~/Pictures/Screenshots
run_optional "Gsettings auto-save-directory" gsettings set org.gnome.gnome-screenshot auto-save-directory "file://$HOME/Pictures/Screenshots"
run_optional "Gsettings logout-prompt" gsettings set org.gnome.SessionManager logout-prompt false
run_optional "Gsettings primary-paste" gsettings set org.gnome.desktop.interface gtk-enable-primary-paste false
run_optional "Gsettings volume-step" gsettings set org.gnome.settings-daemon.plugins.media-keys volume-step 2
run_optional "Gsettings window-switcher filter" gsettings set org.gnome.shell.window-switcher current-workspace-only false

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

# REMOVED per bottom script: first-login extension enabler setup block

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

# Safer directory execution lookup loop for PAM files
find /etc/pam.d/ -name '*.d' -prune -o -type f -exec sed -i 's/pam_systemd\.so/pam_elogind.so/g' {} + 2>/dev/null || true
find /etc/pam.d/ -name '*.d' -prune -o -type f -exec sed -i 's/systemd-logind/elogind/g' {} + 2>/dev/null || true

# Add services to runlevels safely
rc-update add display-manager default 2>/dev/null || true
rc-update add gdm default 2>/dev/null || true
rc-update add dbus default 2>/dev/null || true
rc-update add elogind default 2>/dev/null || true
rc-update add cronie default 2>/dev/null || true
rc-update add tailscale default 2>/dev/null || true
rc-update add zram-init boot 2>/dev/null || true
run_optional "Start tailscale container service" rc-service tailscale start

mkdir -p /etc/skel/.local/bin
cat >> /etc/bash/bashrc <<'BASHRC'
_local_bin="${HOME}/.local/bin"
[ -d "$_local_bin" ] && PATH="${_local_bin}:${PATH}"
unset _local_bin
BASHRC

# Remove passwords safely
passwd -d root || true
passwd -d livecd || true
mkdir -p /etc/sudoers.d
echo "livecd ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/liveuser

echo ">>> Cleaning up to reduce ISO size..."
rm -rf /var/db/repos/gentoo /var/cache/binpkgs /var/tmp/ccache /var/tmp/portage /var/cache/distfiles 2>/dev/null || true
rm -rf /root/.cache/pip /home/livecd/.cache/pip 2>/dev/null || true
rm -rf /var/cache /home/livecd/var/cache 2>/dev/null || true # Removes binhost
rm -rf /var/lib/flatpak/repo/cache 2>/dev/null || true
find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' ! -name 'locale.alias' -exec rm -rf {} + 2>/dev/null || true
rm -rf /usr/share/gtk-doc /usr/share/info 2>/dev/null || true

echo ">>> LiveCD configuration complete"
