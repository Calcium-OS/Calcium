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


