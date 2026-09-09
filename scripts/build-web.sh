#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../frontend"

flutter build web --release "$@"

find web -mindepth 1 -maxdepth 1 ! -name index.html \
  -exec cp -R {} build/web/ \;

echo "synced web/ into build/web/"
