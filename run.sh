#!/usr/bin/env bash
#
# Build (debug by default) and launch Prism.app.
#
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-debug}"
./build.sh "$CONFIG"

# Relaunch cleanly if already running.
osascript -e 'quit app "Prism"' >/dev/null 2>&1 || true
open "build/Prism.app"
echo "✓ launched — look for the Prism item in the menu bar."
