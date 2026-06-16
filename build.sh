#!/usr/bin/env bash
#
# Build Prism and assemble a real, ad-hoc-signed macOS .app bundle.
#
#   ./build.sh            # release build → build/Prism.app
#   ./build.sh debug      # debug build (faster compile)
#
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-release}"
APP_NAME="Prism"
APP_DIR="build/${APP_NAME}.app"

echo "▸ swift build ($CONFIG)…"
swift build -c "$CONFIG" --product "$APP_NAME"

BIN_DIR="$(swift build -c "$CONFIG" --product "$APP_NAME" --show-bin-path)"
BIN="${BIN_DIR}/${APP_NAME}"

echo "▸ assembling ${APP_DIR}…"
rm -rf "$APP_DIR"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "$BIN" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp Resources/Info.plist "${APP_DIR}/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "${APP_DIR}/Contents/Resources/AppIcon.icns"
fi
if [ -d Resources/Fonts ]; then
    mkdir -p "${APP_DIR}/Contents/Resources/Fonts"
    cp Resources/Fonts/*.otf "${APP_DIR}/Contents/Resources/Fonts/" 2>/dev/null || true
fi

SIGN_ID="${PRISM_SIGN_IDENTITY:-Prism Local Signing}"
if security find-identity -p codesigning 2>/dev/null | grep -q "$SIGN_ID"; then
    echo "▸ codesign (stable identity: $SIGN_ID)…"
    codesign --force --deep --entitlements Resources/Prism.entitlements --sign "$SIGN_ID" "$APP_DIR"
else
    echo "▸ ad-hoc codesign…"
    codesign --force --deep --entitlements Resources/Prism.entitlements --sign - "$APP_DIR" \
        || codesign --force --deep --sign - "$APP_DIR"
    echo "  ⚠︎  Ad-hoc signed: macOS will re-ask for Screen Recording on every rebuild."
    echo "     Run ./Tools/setup-signing.sh once so the permission sticks."
fi
# Strip any quarantine flag so the app isn't run from a randomized (translocated)
# path, which would also defeat TCC's per-app memory.
xattr -dr com.apple.quarantine "$APP_DIR" 2>/dev/null || true

echo "✓ built ${APP_DIR}"
echo "  run with:  open \"${APP_DIR}\"   (or ./run.sh)"
