# catalyst spec: Gentoo LiveCD with GNOME, OpenRC, Zsh, efistub (ARM64)

target: livecd-stage2
version_stamp: gnome-openrc-arm64
rel_type: default

profile: default/linux/arm64/23.0/desktop/gnome

snapshot_treeish: stable
subarch: arm64

source_subpath: default/stage3-arm64-openrc-latest

portage_confdir: /etc/catalyst/portage
binrepo_path: /arm64

boot/kernel: gentoo
boot/kernel/gentoo/distkernel: yes
boot/kernel/gentoo/sources: sys-kernel/gentoo-kernel-bin

livecd/fstype: squashfs
livecd/fsops: -c gzip -b 1M
livecd/root_overlay: /repo/epox/rootfs-overlay
livecd/iso: /gentoo-gnome-openrc-arm64.iso
livecd/type: generic-livecd
livecd/volid: Gentoo_GNOME_Live_ARM64

livecd/bootargs: root=live:CDLABEL=Gentoo_GNOME_Live_ARM64

boot/kernel/gentoo/dracut_args: --zstd --no-hostonly -a dmsquash-live -a dm -o i18n -o crypt -I busybox

livecd/rm: /var/cache/distfiles /var/cache/binpkgs /var/tmp/ccache /var/db/repos/gentoo /var/tmp/portage /usr/portage/distfiles

livecd/fsscript: /repo/epox/scripts/fsscript.sh

livecd/rcadd: gdm|default dbus|default elogind|default cronie|default dhcpcd|default netmount|default ntpd|default
