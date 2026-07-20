#!/usr/bin/env bash
# [Patches GCC for a slight performance improment.](https://www.phoronix.com/news/GCC-x86-Generic-Mispredict)

# This will not be needed in GCC 17, Gentoo currently uses ~GCC 15.

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root or with sudo." >&2
  exit 1
fi

PATCH_DIR="/etc/portage/patches/sys-devel/gcc"
PATCH_FILE="${PATCH_DIR}/branch-mispredict.patch"

echo "Creating Portage patch directory..."
mkdir -p "$PATCH_DIR"

echo "Writing final precision unified diff patch to ${PATCH_FILE}..."
cat << 'EOF' > "$PATCH_FILE"
--- a/gcc/config/i386/i386.cc
+++ b/gcc/config/i386/i386.cc
@@ -25215,10 +25215,10 @@
       unsigned cost = seq_cost (seq, true);
 
       if (cost <= if_info->original_cost)
        return true;
 
-      return cost <= (if_info->max_seq_cost + COSTS_N_INSNS (2));
+      return cost <= (if_info->max_seq_cost + COSTS_N_INSNS (2) + 3);
     }
 
   return default_noce_conversion_profitable_p (seq, if_info);
 }
EOF

echo "Patch successfully matched to source layout."
echo "Starting GCC rebuild..."

emerge -1av sys-devel/gcc

# Update Opencode past the version in the GURU repository

INSTALL_DIR="/usr/bin"
BINARY="$INSTALL_DIR/opencode"

case "$(uname -m)" in
    x86_64|amd64)
        ARCH="x64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    *)
        echo "Unsupported architecture: $(uname -m)" >&2
        exit 1
        ;;
esac

URL="https://github.com/anomalyco/opencode/releases/latest/download/opencode-linux-${ARCH}.tar.gz"

echo "Detected architecture: $(uname -m)"
echo "Using OpenCode build: linux-${ARCH}"
echo "Downloading latest release..."

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

curl -fsSL "$URL" -o "$TMP_DIR/opencode.tar.gz"

echo "Extracting..."
tar -xzf "$TMP_DIR/opencode.tar.gz" -C "$TMP_DIR"

echo "Installing to $BINARY..."
sudo install -m 0755 "$TMP_DIR/opencode" "$BINARY"

echo "OpenCode installed successfully:"
"$BINARY" --version

# Change Project Folder icon

set -e

ICON_URL="https://raw.githubusercontent.com/Samu01Tech/gnome-folder-icons/refs/heads/main/apps_folder.svg"
ICON_DIR="/usr/local/share/folder-icons"
ICON_FILE="$ICON_DIR/apps_folder.svg"

echo "Downloading Projects folder icon..."

sudo mkdir -p "$ICON_DIR"
sudo curl -L "$ICON_URL" -o "$ICON_FILE"

echo "Applying icon to users..."

while IFS=: read -r username _ uid _ _ home shell; do
    # Only process regular users (UID >= 1000)
    if [ "$uid" -ge 1000 ] && [ -d "$home" ]; then

        PROJECTS="$home/Projects"

        # Create Projects folder if it doesn't exist
        if [ ! -d "$PROJECTS" ]; then
            echo "Creating $PROJECTS"
            sudo -u "$username" mkdir -p "$PROJECTS"
        fi

        echo "Setting icon for $username..."

        sudo -u "$username" gio set \
            -t string \
            "$PROJECTS" \
            metadata::custom-icon \
            "file://$ICON_FILE"

    fi
done < /etc/passwd

echo "Done!"
