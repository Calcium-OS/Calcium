#!/bin/bash
# fsscript: package installation and LiveCD customization
# imported from epox/ per agents.md
set -e

echo ">>> Installing packages for GNOME desktop..."

# Unmask and configure USE flags for target packages
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

# Install all desktop packages
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
  sys-kernel/dracut

echo ">>> Configuring LiveCD environment..."

# Set Zsh as default shell
chsh -s /bin/zsh root
if id gentoo &>/dev/null; then
  chsh -s /bin/zsh gentoo
fi

# Configure GDM for OpenRC
cat > /etc/conf.d/gdm <<'GDM'
DISPLAYMANAGER="gdm"
GDM_WAYLAND=1
GDM_XSESSION=/etc/X11/Sessions/gnome
GDM

# Sudo for live user
mkdir -p /etc/sudoers.d
echo "gentoo ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/liveuser

echo ">>> LiveCD configuration complete"
