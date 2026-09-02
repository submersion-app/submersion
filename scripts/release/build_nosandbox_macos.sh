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

# Google Drive's Desktop OAuth client secret is supplied at build time, never
# committed. Google authenticates the Desktop-client token exchange with it and
# rejects sign-in without it ("invalid_request: client_secret is missing"), so a
# build that omits it ships with Google Drive sync disabled. Export
# GOOGLE_DRIVE_CLIENT_SECRET (the same value stored as the repo secret of that
# name) to produce a Drive-capable build. Never echo the value.
DART_DEFINES=()
if [ -n "${GOOGLE_DRIVE_CLIENT_SECRET:-}" ]; then
  DART_DEFINES+=("--dart-define=GOOGLE_DRIVE_CLIENT_SECRET=$GOOGLE_DRIVE_CLIENT_SECRET")
  echo "Google Drive: Desktop client secret supplied (Drive sync enabled)"
else
  echo "Google Drive: GOOGLE_DRIVE_CLIENT_SECRET unset -- Drive sync disabled in this build"
fi

# Build with Flutter first
flutter build macos --release "${DART_DEFINES[@]}"

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
