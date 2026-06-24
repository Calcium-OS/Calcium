#!/bin/bash
# Gentoo ISO build script using catalyst
# imported from epox/ per agents.md
set -euo pipefail

CATALYST_STOREDIR="${CATALYST_STOREDIR:-/var/tmp/catalyst}"
SPEC_FILE="${SPEC_FILE:-/repo/epox/gentoo-gnome.spec}"
STAGE3_BASE="${STAGE3_BASE:-https://distfiles.gentoo.org/releases/amd64/autobuilds}"

echo "==> Setting up catalyst"

mkdir -p "$CATALYST_STOREDIR"/builds/default
mkdir -p /etc/catalyst

if [ ! -f /etc/catalyst/catalyst.conf ]; then
  cp /repo/epox/catalyst.conf /etc/catalyst/catalyst.conf
fi

echo "==> Downloading seed stage3"
SEED_PATH="$CATALYST_STOREDIR/builds/default/stage3-amd64-openrc-latest.tar.xz"
if [ ! -f "$SEED_PATH" ]; then
  LATEST=$(wget -q -O - "$STAGE3_BASE/latest-stage3-amd64-openrc.txt" | sed -n '/^[0-9]/p' | head -1 | cut -d' ' -f1)
  wget -q "$STAGE3_BASE/$LATEST" -O /tmp/seed-stage3.tar.xz
  cp /tmp/seed-stage3.tar.xz "$SEED_PATH"
  echo "Seed: $LATEST"
fi

echo "==> Running catalyst"
catalyst -f "$SPEC_FILE"

echo "==> Build complete"
ls -lh /*.iso 2>/dev/null || ls -lh "$CATALYST_STOREDIR"/iso/*.iso 2>/dev/null || true
