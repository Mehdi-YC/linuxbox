#!/usr/bin/env bash
# Build the guest filesystem that index.html serves.
#
# Outputs, next to index.html (this directory):
#   alpine-fs.json  alpine-rootfs-flat/  image-version.json
#
# Needs docker (or podman), git, python3 and zstd. Set DOCKER=podman to use
# podman. The files are generated, not tracked, so a clone stays small.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$ROOT/build/build.sh"

echo
echo "Guest files are ready in $ROOT"
echo "Serve this directory, for example:"
echo "  python3 -m http.server 8000"
