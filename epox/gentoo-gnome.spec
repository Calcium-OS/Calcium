# catalyst spec: Gentoo LiveCD with GNOME, OpenRC, Zsh, efistub
# imported from epox/ per agents.md

target: livecd-stage2
version_stamp: gnome-openrc
rel_type: default

profile: default/linux/amd64/23.0/desktop/gnome

snapshot_treeish: stable
subarch: amd64
source_subpath: default/stage3-amd64-openrc-latest

portage_confdir: /etc/catalyst/portage
binrepo_path: /x86-64

boot/kernel: gentoo
boot/kernel/gentoo/distkernel: yes
boot/kernel/gentoo/sources: sys-kernel/gentoo-kernel-bin

livecd/fstype: squashfs
livecd/root_overlay: /repo/epox/rootfs-overlay
livecd/iso: /gentoo-gnome-openrc-amd64.iso
livecd/type: generic-livecd
livecd/volid: Gentoo_GNOME_Live

livecd/bootargs: root=live:CDLABEL=Gentoo_GNOME_Live quiet

boot/kernel/gentoo/dracut_args: --xz --no-hostonly -a dmsquash-live -a dm -o i18n -o crypt -I busybox

livecd/rm: /usr/portage/distfiles

livecd/gdm_auto_login: livecd

livecd/fsscript: /repo/epox/scripts/fsscript.sh

livecd/rcadd: gdm|default dbus|default elogind|boot dhcpcd|default netmount|default ntpd|default
