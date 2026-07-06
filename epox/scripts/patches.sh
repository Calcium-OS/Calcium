#!/usr/bin/env bash
set -euo pipefail

# To be ran after all packages are setup in the desktop build, but before installation.



# [GCC performance patch](https://www.phoronix.com/news/GCC-x86-Generic-Mispredict)

OVERLAY="/var/db/repos/local"
CATEGORY="sys-devel"
PACKAGE="gcc"

if [[ $EUID -ne 0 ]]; then
    echo "Run this script as root."
    exit 1
fi

VERSION=$(portageq best_visible / ${CATEGORY}/${PACKAGE})

if [[ -z "$VERSION" ]]; then
    echo "Could not determine installed GCC version."
    exit 1
fi

PV="${VERSION##*/}"

echo "Using GCC package: $PV"

mkdir -p "${OVERLAY}/${CATEGORY}/${PACKAGE}"

echo "Copying ebuild..."
cp -a "/var/db/repos/gentoo/${CATEGORY}/${PACKAGE}/." \
      "${OVERLAY}/${CATEGORY}/${PACKAGE}/"

mkdir -p "${OVERLAY}/${CATEGORY}/${PACKAGE}/files"

PATCH="${OVERLAY}/${CATEGORY}/${PACKAGE}/files/generic-branch-mispredict.patch"

cat > "$PATCH" <<'EOF'
diff --git a/gcc/config/i386/x86-tune-costs.h b/gcc/config/i386/x86-tune-costs.h
index cc9de64394e073cfe86b5c3d91b26aeb9434b8fd..bc3bb69434919d855a6a81e40cb93653cad3297b 100644
--- a/gcc/config/i386/x86-tune-costs.h
+++ b/gcc/config/i386/x86-tune-costs.h
@@ -4274,7 +4274,7 @@ struct processor_costs generic_cost = {
   "16",                                        /* Func alignment.  */
   4,                                   /* Small unroll limit.  */
   2,                                   /* Small unroll factor.  */
-  COSTS_N_INSNS (2),                   /* Branch mispredict scale.  */
+  COSTS_N_INSNS (2) + 3,               /* Branch mispredict scale.  */
 };
EOF

EBUILD="${OVERLAY}/${CATEGORY}/${PACKAGE}/${PV}.ebuild"

if ! grep -q "generic-branch-mispredict.patch" "$EBUILD"; then
    perl -0pi -e '
        s/src_prepare\(\)\s*\{\n/src_prepare() {\n    eapply "${FILESDIR}"\/generic-branch-mispredict.patch\n/s
    ' "$EBUILD"
fi

echo "Regenerating Manifest..."
cd "${OVERLAY}/${CATEGORY}/${PACKAGE}"
ebuild "${PV}.ebuild" manifest

echo
echo "Done."
echo
echo "To build:"
echo "    emerge -1av ${CATEGORY}/${PACKAGE}"


# Increase shader cache size

CONFIG_DIR="$HOME/.config/environment.d"
CONFIG_FILE="$CONFIG_DIR/gaming.conf"

# Create the directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Write the configuration
cat > "$CONFIG_FILE" <<'EOF'
# enforce RADV vulkan implementation - Should be enabled by default
# AMD_VULKAN_ICD=RADV

__GL_SHADER_DISK_CACHE_SIZE=120000000000

# Increase AMD's/Intel's? shader cache size to 12GB
MESA_SHADER_CACHE_MAX_SIZE=120G
EOF

echo "Configuration written to: $CONFIG_FILE"
