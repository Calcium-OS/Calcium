#!/usr/bin/env bash
# [Patches GCC for a slight performance improment.](https://www.phoronix.com/news/GCC-x86-Generic-Mispredict)

# This will not be needed in GCC 17, Gentoo currently uses ~GCC 15.

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root or with sudo." >&2
  exit 1
fi

set -e

########################################
# Patch GCC
########################################

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

-      return cost <= (if_info->max_seq_cost + COSTS_INSNS (2));
+      return cost <= (if_info->max_seq_cost + COSTS_INSNS (2) + 3);
     }

   return default_noce_conversion_profitable_p (seq, if_info);
 }
EOF

echo "Patch successfully matched to source layout."
echo "Starting GCC rebuild..."

emerge -1av sys-devel/gcc


########################################
# Update Opencode past the version in the GURU repository
########################################

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
install -m 0755 "$TMP_DIR/opencode" "$BINARY"

echo "OpenCode installed successfully:"
"$BINARY" --version


########################################
# Change Project Folder icon
########################################

ICON_URL="https://raw.githubusercontent.com/Samu01Tech/gnome-folder-icons/refs/heads/main/apps_folder.svg"
ICON_DIR="/usr/local/share/folder-icons"
ICON_FILE="$ICON_DIR/apps_folder.svg"

echo "Downloading Projects folder icon..."

mkdir -p "$ICON_DIR"
curl -L "$ICON_URL" -o "$ICON_FILE"


echo "Creating default Projects folder..."

# Catalyst does not have real desktop users yet.
# Add Projects folder to future users.

mkdir -p /etc/skel/Projects


echo "Installing folder icon..."

mkdir -p /usr/share/icons/hicolor/scalable/places

cp "$ICON_FILE" \
/usr/share/icons/hicolor/scalable/places/folder-projects.svg


########################################
# Update Librewolf icon
########################################

ICON_NAME="io.gitlab.librewolf-community"
ICON_URL="https://upload.wikimedia.org/wikipedia/commons/d/d0/LibreWolf_icon.svg"

ICON_DIR="/usr/share/icons/hicolor/512x512/apps"
SVG="/tmp/${ICON_NAME}.svg"
PNG="$ICON_DIR/${ICON_NAME}.png"

mkdir -p "$ICON_DIR"

echo "Downloading SVG..."
curl -L "$ICON_URL" -o "$SVG"


if command -v rsvg-convert >/dev/null; then
    echo "Converting with librsvg..."
    rsvg-convert -w 512 -h 512 "$SVG" -o "$PNG"

elif command -v magick >/dev/null; then
    echo "Converting with ImageMagick..."
    magick -background none "$SVG" -resize 512x512 "$PNG"

elif command -v convert >/dev/null; then
    echo "Converting with ImageMagick (legacy)..."
    convert -background none "$SVG" -resize 512x512 "$PNG"

else
    echo "Error: Install either librsvg or ImageMagick."
    exit 1
fi

rm -f "$SVG"


if command -v gtk-update-icon-cache >/dev/null; then
    gtk-update-icon-cache /usr/share/icons/hicolor 2>/dev/null || true
fi


if command -v update-desktop-database >/dev/null; then
    update-desktop-database /usr/share/applications 2>/dev/null || true
fi

echo "Installed:"

# End of patches

echo "Done!"
