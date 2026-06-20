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
boot/kernel/gentoo/sources: gentoo-sources
boot/kernel/gentoo/config: /repo/epox/kernel/config

livecd/fstype: squashfs
livecd/root_overlay: /repo/epox/rootfs-overlay
livecd/iso: /gentoo-gnome-openrc-amd64.iso
livecd/type: generic-livecd

livecd/bootargs: quiet

livecd/rm: /usr/portage/distfiles

livecd/users: gentoo

livecd/fsscript: /repo/epox/scripts/fsscript.sh

livecd/rcadd: gdm|default dbus|default elogind|boot dhcpcd|default netmount|default ntpd|default
