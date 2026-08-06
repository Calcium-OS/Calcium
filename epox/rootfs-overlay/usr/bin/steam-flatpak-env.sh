#!/usr/bin/env bash
set -euo pipefail

APP_ID="com.valvesoftware.Steam"

# Detect GPU vendors from PCI IDs
HAS_NVIDIA=0
HAS_AMD=0
HAS_INTEL=0

if command -v lspci >/dev/null 2>&1; then
    while IFS= read -r line; do
        case "$line" in
            *NVIDIA*)
                HAS_NVIDIA=1
                ;;
            *AMD*|*Advanced\ Micro\ Devices*)
                HAS_AMD=1
                ;;
            *Intel*)
                HAS_INTEL=1
                ;;
        esac
    done < <(lspci -nn | grep -Ei 'VGA|3D|Display')
fi

# Common overrides
ARGS=(
    "--env=DXVK_STATE_CACHE=1"
)

# NVIDIA
if [[ $HAS_NVIDIA -eq 1 ]]; then
    ARGS+=(
	"--env=__GL_SHADER_DISK_CACHE=1"
        "--env=__GL_SHADER_DISK_CACHE_SIZE=120000000000"   # 120 GB
    )
fi

# Mesa (AMD RADV / Intel ANV)
if [[ $HAS_AMD -eq 1 || $HAS_INTEL -eq 1 ]]; then
    ARGS+=(
	"--env=MESA_SHADER_CACHE_MAX_SIZE=120G"
    )
fi

flatpak override --user "${ARGS[@]}" "$APP_ID"

echo "Applied Steam Flatpak overrides:"
flatpak override --user --show "$APP_ID"



