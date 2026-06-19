# catalyst spec: Gentoo LiveCD with GNOME, OpenRC, Zsh, efistub
# imported from epox/ per agents.md

target: livecd-stage2
version_stamp: gnome-openrc
rel_type: default

profile: default/linux/amd64/23.0/desktop/gnome

snapshot: 20250101
source_subpath: default/stage3-amd64-openrc-latest

portage_confdir: /etc/catalyst/portage

boot/kernel: gentoo
boot/kernel/gentoo/sources: gentoo-sources
boot/kernel/gentoo/config: /repo/epox/kernel/config
boot/kernel/gentoo/extra_modules: efivarfs

livecd/fstype: squashfs
livecd/rootfs: /repo/epox/rootfs-overlay
livecd/iso: /gentoo-gnome-openrc-amd64.iso
livecd/type: gentoo-release-live

livecd/efistub: true
livecd/efi_dir: /boot/EFI
livecd/bootargs: quiet dolvm doroot

livecd/rm: /usr/portage/distfiles
livecd/unmerge: sys-devel/libtool sys-devel/autoconf sys-devel/automake sys-devel/gdb app-text/asciidoc

livecd/users: root/root
livecd/default_user: gentoo
livecd/default_pass: gentoo

livecd/overlay: /repo/epox/rootfs-overlay

livecd/runscript: /repo/epox/scripts/livecd-runscript.sh

livecd/packages:
  - app-shells/zsh
  - sys-apps/openrc
  - gnome-base/gnome
  - gnome-base/gdm
  - gnome-base/gnome-core
  - x11-themes/gnome-themes-standard
  - net-wireless/wpa_supplicant
  - net-misc/dhcpcd
  - sys-fs/squashfs-tools
  - sys-boot/efibootmgr
  - app-portage/portage-utils
  - app-editors/vim
  - sys-process/htop
  - app-admin/sudo
  - net-misc/ntp
  - sys-apps/dmidecode
  - app-misc/screen
  - sys-apps/pciutils
  - sys-apps/usbutils
  - sys-kernel/gentoo-sources
