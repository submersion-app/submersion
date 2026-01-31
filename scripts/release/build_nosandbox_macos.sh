#!/bin/bash
# No-Sandbox Build Script for macOS
# ==================================
# Builds the app WITHOUT sandbox restrictions for GitHub distribution.
#
# This build:
#   - Has full file system access (no sandbox)
#   - Works on any Mac without entitlement issues
#   - CANNOT be distributed via Mac App Store
#   - May trigger Gatekeeper warnings (right-click → Open to bypass)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
APP_PATH="$PROJECT_DIR/build/macos/Build/Products/Release/submersion.app"
ENTITLEMENTS="$PROJECT_DIR/macos/Runner/ReleaseNoSandbox.entitlements"

cd "$PROJECT_DIR"

echo "=== No-Sandbox Build for macOS ==="
echo "Building for GitHub distribution (no sandbox)..."

# Build with Flutter first
flutter build macos --release

# Re-sign with ad-hoc signature and no-sandbox entitlements
echo ""
echo "Re-signing with no-sandbox entitlements..."
codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP_PATH"

echo ""
echo "=== Build Complete ==="
echo "App: $APP_PATH"

# Verify signature
echo ""
echo "Signature verification:"
codesign -dvv "$APP_PATH" 2>&1 | grep -E "Signature|TeamIdentifier" || true

# Verify entitlements (should show sandbox = false)
echo ""
echo "Embedded entitlements:"
codesign -d --entitlements - "$APP_PATH" 2>/dev/null | grep -E "app-sandbox" || true
