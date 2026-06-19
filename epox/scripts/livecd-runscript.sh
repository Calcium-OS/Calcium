#!/bin/bash
# livecd-runscript: post-build customization for Gentoo LiveCD
# Sets up OpenRC, Zsh as default shell, GNOME display manager
# imported from epox/ per agents.md

echo "Configuring LiveCD environment..."

# Set Zsh as default shell for root and gentoo user
chsh -s /bin/zsh root
if id gentoo &>/dev/null; then
  chsh -s /bin/zsh gentoo
fi

# Configure OpenRC for GNOME
cat > /etc/rc.conf <<'RC'
rc_parallel="YES"
rc_interactive="NO"
RC

# Enable necessary OpenRC services
rc-update add elogind boot
rc-update add dbus default
rc-update add gdm default
rc-update add dhcpcd default
rc-update add netmount default
rc-update add ntpd default

# Configure GDM for OpenRC
cat > /etc/conf.d/gdm <<'GDM'
DISPLAYMANAGER="gdm"
GDM_WAYLAND=1
GDM_XSESSION=/etc/X11/Sessions/gnome
GDM

# Zsh configuration
cat > /etc/zsh/zshrc <<'ZSHRC'
autoload -Uz compinit promptinit
compinit
promptinit
prompt gentoo
setopt autocd extendedglob notify
bindkey -e
export EDITOR=vim
export BROWSER=firefox
ZSHRC

# Sudo configuration for live user
echo "gentoo ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/liveuser

echo "LiveCD environment configured: OpenRC + GNOME + Zsh"
