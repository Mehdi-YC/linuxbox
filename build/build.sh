#!/usr/bin/env bash
# Build the Alpine guest image used by index.html.
#
# Requires: docker (or podman), git, python3, zstd, tar.
# Outputs, in the repo root: alpine-fs.json, alpine-rootfs-flat/, image-version.json
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/.build"
V86="$BUILD/v86"
V86_COMMIT=9457e7a2f6890f3133bb6ac0f749e588f63c4c36   # pinned v86
IMAGE=linux-classroom-alpine
CONTAINER=linux-classroom-alpine-container
ROOTFS_TAR="$BUILD/alpine-rootfs.tar"

DOCKER=${DOCKER:-docker}

mkdir -p "$BUILD"

if [ ! -d "$V86/.git" ]; then
  echo "==> cloning v86 (build tooling only)"
  git clone https://github.com/copy/v86.git "$V86"
fi

# v86's image builder is only used for its filesystem tools, so any recent
# checkout works; pin it anyway so builds are repeatable.
if [ "$(git -C "$V86" rev-parse HEAD)" != "$V86_COMMIT" ]; then
  echo "==> checking out v86 $V86_COMMIT"
  git -C "$V86" fetch --quiet origin || true
  git -C "$V86" checkout --quiet "$V86_COMMIT" 2>/dev/null || echo "   (pinned commit unavailable, using $(git -C "$V86" rev-parse --short HEAD))"
fi

echo "==> building docker image (linux/386)"
"$DOCKER" build "$ROOT/build" --platform linux/386 --rm -t "$IMAGE"

echo "==> exporting root filesystem"
"$DOCKER" rm "$CONTAINER" >/dev/null 2>&1 || true
"$DOCKER" create --platform linux/386 -t -i --name "$CONTAINER" "$IMAGE" >/dev/null
"$DOCKER" export "$CONTAINER" -o "$ROOTFS_TAR"
"$DOCKER" rm "$CONTAINER" >/dev/null
# https://github.com/iximiuz/docker-to-linux/issues/19#issuecomment-1242809707
tar -f "$ROOTFS_TAR" --delete ".dockerenv" 2>/dev/null || true

echo "==> converting to v86 9p filesystem"
rm -rf "$ROOT/alpine-rootfs-flat"
python3 "$V86/tools/fs2json.py" --zstd --out "$ROOT/alpine-fs.json" "$ROOTFS_TAR"
mkdir -p "$ROOT/alpine-rootfs-flat"
python3 "$V86/tools/copy-to-sha256.py" --zstd "$ROOTFS_TAR" "$ROOT/alpine-rootfs-flat"

# The page tags saved machines with this hash, so rebuilding the image throws
# away snapshots taken from the old one instead of silently keeping them.
HASH=$(sha256sum "$ROOT/alpine-fs.json" | cut -c1-16)
cat > "$ROOT/image-version.json" <<EOF
{"version":"$HASH","built":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF

echo
echo "image version: $HASH"
du -sh "$ROOT/alpine-fs.json" "$ROOT/alpine-rootfs-flat"
ls -lS "$ROOT/alpine-rootfs-flat" | head -4
echo "done."
