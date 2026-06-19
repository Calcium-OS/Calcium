# epox - Gentoo LiveCD configuration

Configuration files for building a Gentoo ISO with:
- GNOME desktop environment
- OpenRC init system
- Zsh shell
- EFISTUB boot

## Structure

```
epox/
├── catalyst.conf              # Catalyst main config
├── gentoo-gnome.spec           # Build spec for livecd-stage2
├── kernel/
│   └── config                  # Linux kernel config with efistub
├── portage/
│   ├── make.conf               # Global Portage settings
│   ├── package.use/
│   │   └── gnome               # Package-specific USE flags
│   └── package.accept_keywords/
│       └── gnome               # ~amd64 keywords for GNOME
├── scripts/
│   ├── build-iso.sh            # Entrypoint build script
│   └── livecd-runscript.sh     # Post-build environment setup
└── README.md
```

All configs are imported by catalyst at build time.
