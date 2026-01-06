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

# Build
flutter build macos --release

echo ""
echo "=== Build Complete ==="
echo "App: build/macos/Build/Products/Release/submersion.app"

# Verify entitlements
echo ""
echo "Embedded entitlements:"
codesign -d --entitlements - build/macos/Build/Products/Release/submersion.app 2>/dev/null | grep -E "files\.user-selected|app-sandbox" || true
