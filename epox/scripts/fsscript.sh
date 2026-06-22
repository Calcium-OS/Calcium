#!/bin/bash
# fsscript: package installation and LiveCD customization
set -e

echo ">>> Installing packages for GNOME desktop..."

mkdir -p /etc/portage/package.accept_keywords /etc/portage/package.use

printf '%s\n' \
  'gnome-base/* ~amd64' \
  'x11-wm/* ~amd64' \
  'media-libs/gsound ~amd64' \
  'sys-kernel/gentoo-kernel-bin ~amd64' \
  'sys-kernel/linux-firmware ~amd64' \
  > /etc/portage/package.accept_keywords/gnome

printf '%s\n' \
  '>=gnome-base/gdm-9999 elogind' \
  '>=gnome-base/gnome-settings-daemon-9999 elogind' \
  >> /etc/portage/package.use/gnome

printf '%s\n' \
  'gnome-base/gnome-extra-apps -games' \
  >> /etc/portage/package.use/gnome

printf '%s\n' \
  'gnome-extra/gnome-extensions-app' \
  > /etc/portage/package.mask/gnome-extensions

emerge --quiet --getbinpkg --noreplace \
  app-shells/zsh \
  app-shells/zsh-syntax-highlighting \
  gnome-base/gnome \
  gnome-base/gdm \
  x11-themes/gnome-themes-standard \
  net-wireless/wpa_supplicant \
  net-misc/dhcpcd \
  sys-boot/efibootmgr \
  app-portage/portage-utils \
  app-editors/vim \
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
  sys-fs/cryptsetup \
  sys-fs/dosfstools \
  net-misc/wget \
  net-misc/yt-dlp \
  sys-process/cronie \
  app-eselect/eselect-repository \
  gui-apps/wl-clipboard \
  sys-block/zram-init \
  sys-apps/gptfdisk \
  net-misc/rsync \
  dev-python/pygobject \
  app-containers/lxc \
  media-libs/gsound

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
emerge --quiet --noreplace dev-util/opencode-bin || echo "(opencode-bin install failed)"

echo ">>> Creating system users..."
id gdm &>/dev/null || useradd -r gdm
useradd -m -s /bin/zsh -G users,wheel,audio,video,cdrom,usb,portage,render livecd

echo ">>> Installing Flatpak apps..."
flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# TODO - Change DNS to 1.1.1.1 as well.
# Tor: "The next generation will be the real victims"
printf '%s\n' \
  com.vysp3r.ProtonPlus \
  com.valvesoftware.Steam \
  com.obsproject.Studio \
  md.obsidian.Obsidian \
  com.github.tchx84.Flatseal \
  com.saivert.pwvucontrol \
  io.missioncenter.MissionCenter \
  org.gnome.baobab \
  org.virt_manager.virt-manager \
  com.mattjakeman.ExtensionManager \
  com.protonvpn.www \
  org.torproject.torbrowser-launcher \
  app.devsuite.Ptyxis \
  | xargs -P 3 -I{} sh -c 'flatpak install --system -y --noninteractive flathub "$1" 2>/dev/null || echo "(flatpak install of $1 failed)"' -- {}

flatpak remote-add --system --if-not-exists mixtapes https://m-obeid.github.io/Mixtapes/mixtapes.flatpakrepo 2>/dev/null || true
flatpak install --system -y --noninteractive mixtapes com.pocoguy.Muse 2>/dev/null || \
  echo "(Muse flatpak install failed)"

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

# Enable extension via system dconf database
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

echo ">>> Installing Zed text editor..."
curl -fsSL https://zed.dev/install.sh 2>/dev/null | sh -s -- --no-modify-path 2>/dev/null || echo "(Zed install failed)"

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

# Enable serial console for headless VM testing (CI)
echo "s0:12345:respawn:/sbin/agetty 115200 ttyS0 vt100" >> /etc/inittab

echo ">>> Configuring GNOME keyboard shortcuts..."
cat > /etc/dconf/db/local.d/02-keyboard-shortcuts <<'SHORTCUTS'
[org/gnome/desktop/wm/keybindings]
close=['<Alt>F4', '<Super>q']

[org/gnome/settings-daemon/plugins/media-keys]
custom-keybindings=['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/']

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
SHORTCUTS
dconf update 2>/dev/null || true

echo ">>> Setting default wallpaper..."
WALLPAPER_URL="https://images.steamusercontent.com/ugc/8546979052418597/251C5932F5CCC0355D748AA1A19608A0625C26E8/"
mkdir -p /usr/
