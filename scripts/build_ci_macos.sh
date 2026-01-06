#!/bin/bash
# CI Build Script for macOS
# =========================
# Builds the app with ad-hoc signing (no developer certificate required)
#
# Features that work: File picker, Bluetooth, networking, sandbox
# Features that don't work: iCloud, Push Notifications (require certificate)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIGS_DIR="$PROJECT_DIR/macos/Runner/Configs"
APP_PATH="$PROJECT_DIR/build/macos/Build/Products/Release/submersion.app"
ENTITLEMENTS="$PROJECT_DIR/macos/Runner/ReleaseCI.entitlements"

cd "$PROJECT_DIR"

echo "=== CI Build for macOS ==="
echo "Using ad-hoc signing with CI entitlements..."

# Swap Release.xcconfig with ReleaseCI.xcconfig
mv "$CONFIGS_DIR/Release.xcconfig" "$CONFIGS_DIR/Release.xcconfig.original"
cp "$CONFIGS_DIR/ReleaseCI.xcconfig" "$CONFIGS_DIR/Release.xcconfig"

# Ensure we restore on exit (success or failure)
cleanup() {
    mv "$CONFIGS_DIR/Release.xcconfig.original" "$CONFIGS_DIR/Release.xcconfig"
    echo "Restored Release.xcconfig"
}
trap cleanup EXIT

# Build with Flutter
flutter build macos --release

# Re-sign with ad-hoc signature to ensure we don't use keychain certificates
# This is necessary because Xcode may still pick up certificates from the local keychain
echo ""
echo "Re-signing with ad-hoc signature..."
codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP_PATH"

echo ""
echo "=== Build Complete ==="
echo "App: $APP_PATH"

# Verify signature
echo ""
echo "Signature verification:"
codesign -dvv "$APP_PATH" 2>&1 | grep -E "Signature|TeamIdentifier" || true

# Verify entitlements
echo ""
echo "Embedded entitlements:"
codesign -d --entitlements - "$APP_PATH" 2>/dev/null | grep -E "files\.user-selected|app-sandbox" || true
