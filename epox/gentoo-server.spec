# catalyst spec: Gentoo LiveCD (Server Edition, OpenRC + Zsh)
# imported from epox/ per agents.md

target: livecd-stage2
version_stamp: server-openrc
rel_type: default

profile: default/linux/amd64/23.0

snapshot_treeish: stable
subarch: amd64
source_subpath: default/stage3-amd64-openrc-latest

portage_confdir: /etc/catalyst/portage-server
binrepo_path: /x86-64

boot/kernel: gentoo
boot/kernel/gentoo/distkernel: yes
boot/kernel/gentoo/sources: sys-kernel/gentoo-kernel-bin

livecd/fstype: squashfs
livecd/fsops: -c zstd
livecd/root_overlay: /repo/epox/rootfs-overlay
livecd/iso: /gentoo-server-openrc-amd64.iso
livecd/type: generic-livecd
livecd/volid: Gentoo_Server_Live

livecd/bootargs: root=live:CDLABEL=Gentoo_Server_Live console=ttyS0,115200 quiet

boot/kernel/gentoo/dracut_args: --gzip --no-hostonly -a dmsquash-live -a dm -o i18n -o crypt -I busybox

livecd/rm: /var/cache/distfiles /var/cache/binpkgs /var/tmp/ccache /var/db/repos/gentoo /var/tmp/portage /usr/portage/distfiles

livecd/fsscript: /repo/epox/scripts/fsscript-server.sh

livecd/rcadd: sshd|default dhcpcd|default tailscale|default cronie|default
