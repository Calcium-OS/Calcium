#!/bin/bash
# fsscript: package installation and LiveCD customization
set -e

echo ">>> Installing packages for GNOME desktop..."

mkdir -p /etc/portage/package.accept_keywords /etc/portage/package.use

printf '%s\n' \
  'gnome-base/gnome ~amd64' \
  'gnome-base/gdm ~amd64' \
  'gnome-base/gnome-shell ~amd64' \
  'sys-kernel/gentoo-kernel-bin ~amd64' \
  > /etc/portage/package.accept_keywords/gnome

printf '%s\n' \
  '>=gnome-base/gdm-9999 elogind' \
  '>=gnome-base/gnome-settings-daemon-9999 elogind' \
  > /etc/portage/package.use/gnome

emerge --quiet --getbinpkg --noreplace \
  app-shells/zsh \
  gnome-base/gnome \
  gnome-base/gdm \
  x11-themes/gnome-themes-standard \
  net-wireless/wpa_supplicant \
  net-misc/dhcpcd \
  sys-boot/efibootmgr \
  app-portage/portage-utils \
  app-editors/vim \
  sys-process/htop \
  app-admin/sudo \
  net-misc/ntp \
  sys-apps/dmidecode \
  app-misc/screen \
  sys-apps/pciutils \
  sys-apps/usbutils \
  sys-kernel/dracut \
  sys-apps/flatpak \
  dev-util/dialog \
  sys-fs/cryptsetup \
  sys-fs/dosfstools \
  net-misc/wget

echo ">>> Creating livecd user..."
useradd -m -s /bin/zsh -G users,wheel,audio,video,cdrom,usb,portage livecd

echo ">>> Installing ProtonPlus via Flatpak..."
flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --system -y --noninteractive flathub com.vysp3r.ProtonPlus 2>/dev/null || \
  echo "(flatpak install failed — ProtonPlus will need first-boot install)"

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

echo ">>> Setting default wallpaper..."
WALLPAPER_URL="https://images.steamusercontent.com/ugc/8546979052418597/251C5932F5CCC0355D748AA1A19608A0625C26E8/"
mkdir -p /usr/share/backgrounds/gnome
wget -q -O /usr/share/backgrounds/gnome/calcium-wallpaper.jpg "$WALLPAPER_URL"

cat > /usr/share/glib-2.0/schemas/99-calcium-wallpaper.gschema.override <<'SCHEMA'
[org.gnome.desktop.background]
picture-uri = 'file:///usr/share/backgrounds/gnome/calcium-wallpaper.jpg'
picture-uri-dark = 'file:///usr/share/backgrounds/gnome/calcium-wallpaper.jpg'
SCHEMA
glib-compile-schemas /usr/share/glib-2.0/schemas/

echo ">>> Configuring LiveCD environment..."

# Set Zsh as default shell
chsh -s /bin/zsh root
chsh -s /bin/zsh livecd

cat > /etc/conf.d/gdm <<'GDM'
DISPLAYMANAGER="gdm"
GDM_WAYLAND=1
GDM_XSESSION=/etc/X11/Sessions/gnome
GDM

# Remove passwords
passwd -d root
passwd -d livecd

# Sudo for live user
mkdir -p /etc/sudoers.d
echo "livecd ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/liveuser

echo ">>> LiveCD configuration complete"
