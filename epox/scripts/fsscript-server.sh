#!/bin/bash
# fsscript: server edition package installation and LiveCD customization
set -e

echo ">>> Installing packages for server edition..."

mkdir -p /etc/portage/package.accept_keywords /etc/portage/package.use

printf '%s\n' \
  'sys-kernel/gentoo-kernel-bin ~amd64' \
  'sys-kernel/linux-firmware ~amd64' \
  > /etc/portage/package.accept_keywords/server

# Create system accounts
id livecd &>/dev/null || useradd -m -G users,wheel,audio,video,cdrom,usb,portage,render livecd

emerge --quiet --getbinpkg --binpkg-respect-use=n --noreplace \
  app-shells/zsh \
  app-shells/zsh-syntax-highlighting \
  net-misc/dhcpcd \
  net-wireless/wpa_supplicant \
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

echo ">>> Setting up Zsh as default shell..."
chsh -s /bin/zsh root
chsh -s /bin/zsh livecd

echo ">>> Configuring OpenRC services..."
rc-update add sshd default
rc-update add dhcpcd default
rc-update add tailscale default
rc-update add cronie default

echo ">>> Configuring sudo for live user..."
mkdir -p /etc/sudoers.d
echo "livecd ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/liveuser

echo ">>> Removing passwords..."
passwd -d root
passwd -d livecd

echo ">>> Cleaning up..."
rm -rf /var/db/repos/gentoo /var/cache/binpkgs /var/tmp/ccache /var/tmp/portage /var/cache/distfiles 2>/dev/null || true
find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' ! -name 'locale.alias' -exec rm -rf {} + 2>/dev/null || true

echo ">>> Server LiveCD configuration complete"
