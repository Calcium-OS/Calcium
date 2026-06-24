#!/bin/bash
# fsscript: package installation and LiveCD customization
set -e

echo ">>> Installing packages for GNOME desktop..."

mkdir -p /etc/portage/package.accept_keywords /etc/portage/package.use /etc/portage/package.mask

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

#emerge --quiet --getbinpkg --binpkg-respect-use=n --noreplace \
  #--autounmask=y --autounmask-write=y \


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
  net-vpn/tailscale

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
eselect repository enable guru 2>/dev/null || true
emaint sync -r guru 2>/dev/null || true
echo "dev-util/opencode-bin ~amd64" | sudo tee -a /etc/portage/package.accept_keywords/opencode-bin
emerge --quiet --noreplace dev-util/opencode-bin || echo "(opencode-bin install failed)"

echo ">>> Installing Flatpak apps..."
flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# MERGED Flatpak lists using the faster parallel installation loop from the new script
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
  com.github.Matoking.protontricks
  
  | xargs -P 3 -I{} sh -c 'flatpak install --system -y --noninteractive flathub "$1" 2>/dev/null || echo "(flatpak install of $1 failed)"' -- {}

flatpak remote-add --system --if-not-exists mixtapes https://m-obeid.github.io/Mixtapes/mixtapes.flatpakrepo 2>/dev/null || true
flatpak install --system -y --noninteractive mixtapes com.pocoguy.Muse 2>/dev/null || \
  echo "(Muse flatpak install failed)"

# Add transparency in the Ptyxis terminal TODO - Mask gnome-console


OPACITY="${1:-0.85}"

# Get the default Ptyxis profile UUID
UUID=$(dconf read /org/gnome/Ptyxis/default-profile-uuid | tr -d "'")

if [[ -z "$UUID" ]]; then
    echo "Error: Could not determine Ptyxis profile UUID."
    exit 1
fi

echo "Found Ptyxis profile UUID: $UUID"
echo "Setting opacity to $OPACITY..."

flatpak run --command=gsettings app.devsuite.Ptyxis \
    set "org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/${UUID}/" \
    opacity "$OPACITY"

if [[ $? -eq 0 ]]; then
    echo "Opacity successfully set to $OPACITY"
    echo "You may need to restart Ptyxis for the change to take effect."
else
    echo "Failed to update opacity."
    exit 1
fi

echo ">>> Installing lf file manager..."
LF_URL=$(wget -q -O- "https://api.github.com/repos/gokcehan/lf/releases/latest" \
  | grep "browser_download_url.*lf-linux-amd64.tar.gz" | head -1 | cut -d'"' -f4)
if [ -n "$LF_URL" ]; then
  wget -q -O /tmp/lf.tar.gz "$LF_URL"
  tar xzf /tmp/lf.tar.gz -C /usr/bin/ lf
  chmod +x /usr/bin/lf
  rm -f /tmp/lf.tar.gz
fi

echo ">>> Installing uv..."
wget -q -O- https://astral.sh/uv/install.sh | env UV_UNMANAGED_INSTALL=/usr/local/bin sh -s -- --no-modify-path 2>/dev/null || true

echo ">>> Installing Fildem global menu..."
# FROM NEW SCRIPT: Uses the cleaner installation paths and repository
wget -q -O /tmp/fildem.tar.gz "https://github.com/InledGroup/Fildem/archive/refs/heads/main.tar.gz"
tar xzf /tmp/fildem.tar.gz -C /tmp
FILDEM_DIR=$(ls -d /tmp/Fildem-* /tmp/fildem-* 2>/dev/null | head -1)
if [ -n "$FILDEM_DIR" ]; then
  cd "$FILDEM_DIR"
  pip3 install --break-system-packages --no-deps . 2>/dev/null || true
  if [ -d fildem@inled.es ]; then
    mkdir -p /usr/share/gnome-shell/extensions
    cp -r fildem@inled.es /usr/share/gnome-shell/extensions/
  fi
  cd /
fi
rm -rf /tmp/fildem* /tmp/Fildem-*

# FROM NEW SCRIPT: Refreshed dconf entries including Dark Mode preference and additional extensions
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/01-extensions <<'EXTDCONF'
[org/gnome/shell]
enabled-extensions=['copyous@boerdereinar.dev', 'gsconnect@andyholmes.github.io', 'appindicatorsupport@rgcjonas.gmail.com', 'wintile-beyond@GrylledCheez.xyz', 'dash-to-dock@micxgx.gmail.com', 'liquid-glass@thinkingcoding1231.gmail.com', 'fildem@inled.es', 'compiz-alike-magic-lamp-effect@hermes83.github.com']
favorite-apps=['org.gnome.Epiphany.desktop', 'org.gnome.Nautilus.desktop']

[org/gnome/desktop/interface]
color-scheme='prefer-dark'

[org/gnome/desktop/wm/preferences]
button-layout=':minimize,maximize,close'
EXTDCONF
cat > /etc/dconf/profile/user <<'DCONFPROF'
user-db:user
system-db:local
DCONFPROF
dconf update 2>/dev/null || true

# Configure GTK modules for appmenu support
mkdir -p /etc/skel/.config/gtk-3.0
cat > /etc/skel/.config/gtk-3.0/settings.ini <<'GTKINI'
[Settings]
gtk-modules=appmenu-gtk-module
GTKINI
cat > /etc/skel/.gtkrc-2.0 <<'GTKRC'
gtk-modules="appmenu-gtk-module"
GTKRC

# Autostart fildem daemon for all users
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
  | grep "browser_download_url.*AppImage" | head -1 | cut -d'"' -f4)
if [ -n "$SUNSHINE_URL" ]; then
  mkdir -p /opt/sunshine
  wget -q -O /opt/sunshine/sunshine.AppImage "$SUNSHINE_URL"
  chmod +x /opt/sunshine/sunshine.AppImage
  cd /opt/sunshine
  ./sunshine.AppImage --appimage-extract 2>/dev/null || true
  cd /
  if [ -f /opt/sunshine/squashfs-root/AppRun ]; then
    ln -sf /opt/sunshine/squashfs-root/AppRun /opt/sunshine/sunshine
  fi
  rm -f /opt/sunshine/sunshine.AppImage
fi


echo ">>> Installing Wine..."
WINE_URL=$(wget -q -O- https://api.github.com/repos/mmtrt/WINE_AppImage/releases/latest \
  | grep "WINE_url.*AppImage" | head -1 | cut -d'"' -f4)
if [ -n "$WINE_URL" ]; then
  mkdir -p /opt/wine
  wget -q -O /opt/wine/wine.AppImage "$SUNSHINE_URL"
  chmod +x /opt/sunshine/wine.AppImage
  cd /opt/wine
  ./wine.AppImage --appimage-extract 2>/dev/null || true #  Add wine = Wine.AppImage alias
  cd /
  if [ -f /opt/wine/squashfs-root/AppRun ]; then
    ln -sf /opt/wine/squashfs-root/AppRun /opt/sunshine/sunshine
  fi
  rm -f /opt/wine/wine.AppImage
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
    wget -q -O /opt/librewolf/librewolf.AppImage "$LIBREWOLF_URL" || true
    if [ -f /opt/librewolf/librewolf.AppImage ]; then
        chmod +x /opt/librewolf/librewolf.AppImage
        cd /opt/librewolf
        ./librewolf.AppImage --appimage-extract 2>/dev/null || true
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
  | grep "browser_download_url.*AppImageUpdate.*x86_64.*AppImage" | head -1 | cut -d'"' -f4)
if [ -n "$APPIMAGEUPDATE_URL" ]; then
    wget -q -O /usr/local/bin/AppImageUpdate "$APPIMAGEUPDATE_URL" && \
    chmod +x /usr/local/bin/AppImageUpdate || \
    echo "(AppImageUpdate install failed)"
fi

# FROM NEW SCRIPT: Added Waydroid Container framework
echo ">>> Installing Waydroid (Android in a container)..."
WAYDROID_VER="1.6.3"
wget -q -O /tmp/waydroid.tar.gz "https://github.com/waydroid/waydroid/archive/refs/tags/${WAYDROID_VER}.tar.gz"
tar xzf /tmp/waydroid.tar.gz -C /tmp
cd "/tmp/waydroid-${WAYDROID_VER}" && make install 2>/dev/null || true
cd /
rm -rf /tmp/waydroid*

echo ">>> Setting up auto-update cron jobs..."
mkdir -p /etc/cron.daily /etc/cron.weekly

cat > /etc/cron.daily/flatpak-update <<'CRON'
#!/bin/bash
flatpak update -y --noninteractive 2>/dev/null || true
CRON
chmod +x /etc/cron.daily/flatpak-update

# FROM NEW SCRIPT: Standardized to the custom calcium-update utility framework
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
# Disable Senso Server
# I believe in the children, listen to the kids, bro If the phone ringin', go and get your kids, ho Brother
find ~ -type d -name "*gkncegdiihdghhkfpnnodppcbjeeimkc*" \
  -exec bash -c 'for d; do mv "$d" "${d%/}_"; done' bash {} +
CRON
chmod +x /etc/cron.daily/disable-senso-server

# FROM NEW SCRIPT: Serial console connection patch for automated CI/headless instances
echo "s0:12345:respawn:/sbin/agetty 115200 ttyS0 vt100" >> /etc/inittab

# MERGED keyboard shortcuts targeting Ptyxis alongside system utilities from the old script
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
dconf update 2>/dev/null || true

gsettings set org.gnome.mutter experimental-features "['variable-refresh-rate']" # Enable expermental Variable Refresh Rate support

mkdir -p ~/Pictures/Screenshots
gsettings set org.gnome.gnome-screenshot auto-save-directory "file://$HOME/Pictures/Screenshots"

gsettings set org.gnome.SessionManager logout-prompt false
gsettings set org.gnome.desktop.interface gtk-enable-primary-paste false
gsettings set org.gnome.settings-daemon.plugins.media-keys volume-step 2
gsettings set org.gnome.shell.window-switcher current-workspace-only false # If you want the Alt+Tab shortcut to cycle through all open windows rather than just the windows on your current workspace


echo ">>> Setting default wallpaper..."
WALLPAPER_URL="https://images.steamusercontent.com/ugc/8546979052418597/251C5932F5CCC0355D748AA1A19608A0625C26E8/"
mkdir -p /usr/share/backgrounds/gnome
wget -q -O /usr/share/backgrounds/gnome/calcium-wallpaper.jpg "$WALLPAPER_URL" || \
  echo "(wallpaper download failed, using default)"

cat > /usr/share/glib-2.0/schemas/99-calcium-wallpaper.gschema.override <<'SCHEMA'
[org.gnome.desktop.background]
picture-uri = 'file:///usr/share/backgrounds/gnome/calcium-wallpaper.jpg'
picture-uri-dark = 'file:///usr/share/backgrounds/gnome/calcium-wallpaper.jpg'
SCHEMA
glib-compile-schemas /usr/share/glib-2.0/schemas/

# FROM NEW SCRIPT: Explicit compilation loops for shell extension assets
echo ">>> Compiling extension schemas..."
for extdir in /usr/share/gnome-shell/extensions/*/schemas/; do
  if [ -n "$(find "$extdir" -maxdepth 1 -name '*.gschema.xml' -print -quit 2>/dev/null)" ]; then
    glib-compile-schemas "$extdir" 2>/dev/null || true
  fi
done

# FROM NEW SCRIPT: Run structural first-login extension enabler scripts
echo ">>> Creating first-login extension enabler..."
mkdir -p /usr/share/calcium-installer
cat > /usr/share/calcium-installer/enable-extensions.sh <<'EXTSCRIPT'
#!/bin/bash
MARKER="${HOME}/.config/calcium-extensions-enabled"
[ -f "$MARKER" ] && exit 0
sleep 2
for ext in /usr/share/gnome-shell/extensions/*; do
  ext_id=$(basename "$ext")
  [ -n "$ext_id" ] && gnome-extensions enable "$ext_id" 2>/dev/null || true
done
touch "$MARKER"
EXTSCRIPT
chmod +x /usr/share/calcium-installer/enable-extensions.sh

cat > /etc/xdg/autostart/calcium-enable-extensions.desktop <<'EXTENABLE'
[Desktop Entry]
Type=Application
Exec=/usr/share/calcium-installer/enable-extensions.sh
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=3
Name=Calcium Enable Extensions
Comment=Enable GNOME Shell extensions on first login
EXTENABLE

echo ">>> Configuring LiveCD environment..."

# Set Zsh as default shell
chsh -s /bin/zsh root
chsh -s /bin/zsh livecd

# FROM NEW SCRIPT: Modern OpenRC display-manager layout configuration
cat > /etc/conf.d/display-manager <<'DM'
DISPLAYMANAGER="gdm"
GDM_WAYLAND=1
GDM_XSESSION=/etc/X11/Sessions/gnome
DM

# PRESERVED PRE-EMPTIVE FIX: Fallback legacy targets for OpenRC environment handling
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

# FROM NEW SCRIPT: Safer directory execution lookup loop for PAM files
find /etc/pam.d/ -name '*.d' -prune -o -type f -exec sed -i 's/pam_systemd\.so/pam_elogind.so/g' {} + 2>/dev/null || true
find /etc/pam.d/ -name '*.d' -prune -o -type f -exec sed -i 's/systemd-logind/elogind/g' {} + 2>/dev/null || true

# Add services to runlevels
rc-update add display-manager default 2>/dev/null || true
rc-update add gdm default 2>/dev/null || true
rc-update add dbus default
rc-update add elogind default
rc-update add cronie default
rc-update add tailscale default 2>/dev/null || true
rc-update add zram-init boot

# FROM NEW SCRIPT: Spin up headless network daemons
rc-service tailscale start 2>/dev/null || true

# FROM NEW SCRIPT: User system profile paths mapping for portable tools
mkdir -p /etc/skel/.local/bin
cat >> /etc/bash/bashrc <<'BASHRC'
_local_bin="${HOME}/.local/bin"
[ -d "$_local_bin" ] && PATH="${_local_bin}:${PATH}"
unset _local_bin
BASHRC

# Remove passwords
passwd -d root
passwd -d livecd

# Sudo for live user
mkdir -p /etc/sudoers.d
echo "livecd ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/liveuser

echo ">>> Cleaning up to reduce ISO size..."
rm -rf /var/db/repos/gentoo /var/cache/binpkgs /var/tmp/ccache /var/tmp/portage /var/cache/distfiles 2>/dev/null || true
rm -rf /root/.cache/pip /home/livecd/.cache/pip 2>/dev/null || true
rm -rf /var/lib/flatpak/repo/cache 2>/dev/null || true
find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' ! -name 'locale.alias' -exec rm -rf {} + 2>/dev/null || true
rm -rf /usr/share/gtk-doc 2>/dev/null || true
rm -rf /usr/share/info 2>/dev/null || true

echo ">>> LiveCD configuration complete"
