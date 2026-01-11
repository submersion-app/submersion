#!/bin/bash
#
# App Store Screenshot Capture Script
#
# This script captures screenshots on multiple iOS simulators for App Store submission.
# It boots each simulator, overrides the status bar for consistent appearance,
# runs Flutter integration tests to capture screenshots, and organizes the output.
#
# Usage:
#   ./scripts/capture_screenshots.sh
#
# Requirements:
#   - Xcode with iOS simulators installed
#   - Flutter SDK
#   - Run from the project root directory

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SCREENSHOTS_DIR="$PROJECT_ROOT/screenshots"

# Note: Output directories are created by the ScreenshotHelper in Dart
# Pre-create them here as well for visibility
mkdir -p "$SCREENSHOTS_DIR/iPhone_6_7_inch"
mkdir -p "$SCREENSHOTS_DIR/iPad_13_inch"

# Device configurations
# Format: "Simulator Name Pattern|Output Folder Name"
# Using patterns to match available simulators (names vary by Xcode version)
DEVICES=(
  "iPhone 15 Pro Max|iPhone_6_7_inch"
  "iPad Pro 13-inch|iPad_13_inch"
)

echo "=========================================="
echo "App Store Screenshot Capture"
echo "=========================================="
echo ""
echo "Output directory: $SCREENSHOTS_DIR"
echo ""

# Check for available simulators
echo "Checking available simulators..."
xcrun simctl list devices available | grep -E "(iPhone 16 Pro Max|iPad Pro.*13)" || {
  echo "Warning: Some target simulators may not be available."
  echo "Available iPhone simulators:"
  xcrun simctl list devices available | grep iPhone | head -5
  echo ""
  echo "Available iPad simulators:"
  xcrun simctl list devices available | grep iPad | head -5
  echo ""
}

echo ""

for device_config in "${DEVICES[@]}"; do
  IFS='|' read -r simulator_name output_name <<< "$device_config"

  echo "=========================================="
  echo "Processing: $simulator_name"
  echo "=========================================="

  # Get the device UDID
  DEVICE_UDID=$(xcrun simctl list devices available | grep "$simulator_name" | head -1 | grep -oE "[0-9A-F-]{36}")

  if [ -z "$DEVICE_UDID" ]; then
    echo "Warning: Could not find simulator '$simulator_name'. Skipping..."
    continue
  fi

  echo "Device UDID: $DEVICE_UDID"

  # Boot the simulator
  echo "Booting simulator..."
  xcrun simctl boot "$DEVICE_UDID" 2>/dev/null || true

  # Wait for simulator to fully boot
  echo "Waiting for simulator to boot..."
  sleep 5

  # Override status bar for clean screenshots
  echo "Setting up status bar appearance..."
  xcrun simctl status_bar "$DEVICE_UDID" override \
    --time "9:41" \
    --batteryState charged \
    --batteryLevel 100 \
    --wiFiMode active \
    --wiFiBars 3 \
    --cellularMode active \
    --cellularBars 4 \
    --operatorName "" \
    2>/dev/null || echo "Note: Status bar override may not be supported on this simulator version"

  # Run integration tests with screenshot capture
  # Screenshots are saved directly to screenshots/{device_name}/ by the ScreenshotHelper
  echo "Running screenshot tests..."
  cd "$PROJECT_ROOT"

  SCREENSHOT_DEVICE_NAME="$output_name" flutter test integration_test/screenshots_test.dart \
    -d "$DEVICE_UDID" \
    --dart-define=SCREENSHOT_MODE=true \
    2>&1 || {
      echo "Warning: Screenshot tests encountered issues on $simulator_name"
    }

  # Shutdown simulator
  echo "Shutting down simulator..."
  xcrun simctl shutdown "$DEVICE_UDID" 2>/dev/null || true

  echo "Completed: $simulator_name"
  echo ""
done

echo "=========================================="
echo "Screenshot capture complete!"
echo "=========================================="
echo ""
echo "Screenshots saved to: $SCREENSHOTS_DIR"
echo ""

# List captured screenshots
for device_dir in "$SCREENSHOTS_DIR"/*/; do
  if [ -d "$device_dir" ]; then
    device_name=$(basename "$device_dir")
    count=$(find "$device_dir" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')
    echo "$device_name: $count screenshots"
    if [ "$count" -gt 0 ]; then
      ls -1 "$device_dir"*.png 2>/dev/null | head -5
      if [ "$count" -gt 5 ]; then
        echo "  ... and $((count - 5)) more"
      fi
    fi
    echo ""
  fi
done

echo "Next steps:"
echo "  1. Review screenshots in $SCREENSHOTS_DIR"
echo "  2. Upload to App Store Connect:"
echo "     cd ios && bundle exec fastlane upload_screenshots"
