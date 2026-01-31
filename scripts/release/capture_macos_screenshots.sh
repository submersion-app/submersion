#!/bin/bash
#
# macOS Screenshot Capture Script
#
# Captures screenshots of the Submersion app on macOS using native screencapture.
# Navigates through the app's main screens using AppleScript.
#
# Usage:
#   ./scripts/release/capture_macos_screenshots.sh [--output-dir DIR]
#
# Required permissions (System Settings > Privacy & Security):
#   - Screen Recording: Required for screencapture to work
#   - Accessibility: Required for clicking UI elements
# After granting permissions, restart your terminal app.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Default values
OUTPUT_DIR="$PROJECT_ROOT/screenshots/macOS"
APP_NAME="Submersion"
WINDOW_WAIT_TIMEOUT=30
SCREENSHOT_INDEX=0

# App Store Connect required screenshot dimensions (pixels):
# 1280×800, 1440×900, 2560×1600, 2880×1800
#
# On Retina displays (2x), AppleScript uses POINTS not pixels.
# screencapture outputs at native resolution (2x), so:
# - For 2560×1600 pixel output, set window to 1280×800 points
# - For 2880×1800 pixel output, set window to 1440×900 points
SCREENSHOT_WIDTH=1280   # points (will produce 2560px on Retina)
SCREENSHOT_HEIGHT=800   # points (will produce 1600px on Retina)

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "macOS Screenshot Capture"
echo "========================"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Check dependencies first (before spending time on build)
check_cliclick() {
  if ! command -v cliclick &> /dev/null; then
    echo ""
    echo "Error: cliclick is required but not installed."
    echo "Flutter apps don't respond to AppleScript synthetic clicks."
    echo ""
    echo "Install with Homebrew:"
    echo "  brew install cliclick"
    echo ""
    exit 1
  fi
}
check_cliclick

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Build the macOS app
echo "Building macOS app..."
cd "$PROJECT_ROOT"
flutter build macos --release 2>&1 || {
  echo "Error: Failed to build macOS app"
  exit 1
}

APP_PATH="$PROJECT_ROOT/build/macos/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
  echo "Error: App not found at $APP_PATH"
  exit 1
fi

echo "App built successfully"
echo ""

# Function to get window bounds using AppleScript
get_window_bounds() {
  osascript << 'EOF' 2>/dev/null
tell application "System Events"
  tell process "Submersion"
    if (count of windows) > 0 then
      set winPos to position of window 1
      set winSize to size of window 1
      set x to item 1 of winPos as integer
      set y to item 2 of winPos as integer
      set w to item 1 of winSize as integer
      set h to item 2 of winSize as integer
      return (x as text) & "," & (y as text) & "," & (w as text) & "," & (h as text)
    end if
  end tell
end tell
EOF
}

# Function to resize window to exact App Store dimensions
resize_window() {
  local width="$1"
  local height="$2"
  osascript << EOF 2>/dev/null
tell application "System Events"
  tell process "Submersion"
    if (count of windows) > 0 then
      -- First move to safe position (top-left, below menu bar)
      set position of window 1 to {0, 25}
      delay 0.2
      -- Then resize
      set size of window 1 to {$width, $height}
    end if
  end tell
end tell
EOF
  sleep 0.5
}

# Function to capture a screenshot
capture_screenshot() {
  local name="$1"
  SCREENSHOT_INDEX=$((SCREENSHOT_INDEX + 1))
  local padded_index=$(printf "%02d" $SCREENSHOT_INDEX)
  local filename="macOS_${padded_index}_${name}"
  local filepath="$OUTPUT_DIR/$filename.png"

  # Bring app to front
  osascript -e "tell application \"$APP_NAME\" to activate" 2>/dev/null
  sleep 0.5

  # Get window bounds
  local bounds
  bounds=$(get_window_bounds)

  if [ -n "$bounds" ]; then
    IFS=',' read -r x y w h <<< "$bounds"
    if screencapture -R "${x},${y},${w},${h}" -o "$filepath" 2>/dev/null; then
      echo "📸 $filename"
      return 0
    fi
  fi

  # Fallback: capture entire screen
  if screencapture -o "$filepath" 2>/dev/null; then
    echo "📸 $filename (full screen)"
    return 0
  fi

  echo "❌ Failed: $filename - grant Screen Recording permission"
  return 1
}

# Function to click at absolute screen position using cliclick
# (AppleScript clicks don't work with Flutter's Metal/Skia rendering)
click_at_abs() {
  local x="$1"
  local y="$2"
  cliclick c:"$x","$y"
  sleep 0.3
}

# Function to click at position relative to window
click_at() {
  local rel_x="$1"
  local rel_y="$2"

  local bounds
  bounds=$(get_window_bounds)

  if [ -z "$bounds" ]; then
    echo "Warning: Could not get window bounds"
    return 1
  fi

  IFS=',' read -r win_x win_y win_w win_h <<< "$bounds"

  local abs_x=$((win_x + rel_x))
  local abs_y=$((win_y + rel_y))

  click_at_abs "$abs_x" "$abs_y"
}

# Function to click NavigationRail item (desktop layout, left side)
# Items: 0=Home, 1=Dives, 2=Sites, 3=Trips, 4=Equipment, 5=Statistics, 6=Buddies, etc.
click_nav_rail() {
  local index="$1"

  local bounds
  bounds=$(get_window_bounds)

  if [ -z "$bounds" ]; then
    echo "Warning: Could not get window bounds for nav rail click"
    return 1
  fi

  IFS=',' read -r win_x win_y win_w win_h <<< "$bounds"

  # NavigationRail is on the left, ~72px wide (collapsed) or ~190px (extended)
  # At >=1200px (our 1280px window), rail is extended with collapse button at top
  # Flutter NavigationRail items are ~56px tall in Material 3
  # Leading collapse button: ~48px, plus some padding
  local rail_x=36  # Center of collapsed rail icons
  local item_height=50
  local top_offset=60  # Collapse button + minimal padding

  local nav_y=$((top_offset + (item_height * index) + (item_height / 2)))

  echo "  Clicking nav rail item $index at ($rail_x, $nav_y)"
  click_at "$rail_x" "$nav_y"
  sleep 2.5
}

# Legacy function for mobile layout (kept for reference)
click_bottom_nav() {
  local index="$1"

  local bounds
  bounds=$(get_window_bounds)

  if [ -z "$bounds" ]; then
    return 1
  fi

  IFS=',' read -r win_x win_y win_w win_h <<< "$bounds"

  # Bottom nav: 5 items, ~80px tall from bottom
  local nav_y=$((win_h - 40))
  local item_width=$((win_w / 5))
  local item_x=$(( (item_width * index) + (item_width / 2) ))

  click_at "$item_x" "$nav_y"
  sleep 2.5
}

# Kill any existing instance
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 1

# Launch the app
echo "Launching app..."
open "$APP_PATH"
sleep 2

# Activate the app (required for window detection)
osascript -e "tell application \"$APP_NAME\" to activate" 2>/dev/null
sleep 1

# Wait for window
echo "Waiting for app window..."
elapsed=0
while [ $elapsed -lt $WINDOW_WAIT_TIMEOUT ]; do
  bounds=$(get_window_bounds)
  if [ -n "$bounds" ]; then
    echo "Window detected: $bounds"
    break
  fi
  sleep 1
  elapsed=$((elapsed + 1))
  # Keep trying to activate
  osascript -e "tell application \"$APP_NAME\" to activate" 2>/dev/null
done

if [ $elapsed -ge $WINDOW_WAIT_TIMEOUT ]; then
  echo "Error: Timeout waiting for app window"
  echo "Make sure Accessibility permission is granted to your terminal"
  pkill -x "$APP_NAME" 2>/dev/null || true
  exit 1
fi

# Resize window to App Store dimensions (points → 2x pixels on Retina)
echo "Resizing window to ${SCREENSHOT_WIDTH}x${SCREENSHOT_HEIGHT} points (→ $((SCREENSHOT_WIDTH * 2))x$((SCREENSHOT_HEIGHT * 2)) pixels on Retina)..."
resize_window "$SCREENSHOT_WIDTH" "$SCREENSHOT_HEIGHT"

# Verify the resize worked
bounds=$(get_window_bounds)
if [ -n "$bounds" ]; then
  IFS=',' read -r x y w h <<< "$bounds"
  echo "Window resized to: ${w}x${h}"
  if [ "$w" -ne "$SCREENSHOT_WIDTH" ] || [ "$h" -ne "$SCREENSHOT_HEIGHT" ]; then
    echo "Warning: Window size (${w}x${h}) doesn't match target (${SCREENSHOT_WIDTH}x${SCREENSHOT_HEIGHT})"
    echo "This may be due to minimum window size constraints in the app."
  fi
fi

# Wait for app to fully render
echo "Waiting for app to render..."
sleep 3

echo ""
echo "Capturing screenshots..."
echo ""

# Desktop layout uses NavigationRail on left side
# Rail items: 0=Home, 1=Dives, 2=Sites, 3=Trips, 4=Equipment, 5=Statistics

# 1. Home/Dashboard (initial screen)
capture_screenshot "dashboard"

# 2. Dives
echo "→ Navigating to Dives"
click_nav_rail 1
sleep 2
capture_screenshot "dive_list"

# 3. Dive Detail - click on first dive in the list
echo "→ Selecting first dive for detail view"
bounds=$(get_window_bounds)
if [ -n "$bounds" ]; then
  IFS=',' read -r wx wy ww wh <<< "$bounds"
  # Master-detail layout: NavigationRail (~80px) | List (~300px) | Detail (rest)
  # Click in the LIST pane, not the detail pane
  # List pane starts at ~80px and is ~300px wide, so center is ~230px from left
  list_x=230
  click_at "$list_x" 150
  sleep 2
  capture_screenshot "dive_detail"
fi

# 4. Sites
echo "→ Navigating to Sites"
click_nav_rail 2
sleep 2
capture_screenshot "sites_list"

# 5. Trips
echo "→ Navigating to Trips"
click_nav_rail 3
sleep 2
capture_screenshot "trips"

# 6. Equipment
echo "→ Navigating to Equipment"
click_nav_rail 4
sleep 2
capture_screenshot "equipment"

# 7. Statistics
echo "→ Navigating to Statistics"
click_nav_rail 5
sleep 2
capture_screenshot "statistics"

echo ""
echo "=========================================="
echo "Screenshot capture complete!"
echo "=========================================="
echo ""
echo "Screenshots saved to: $OUTPUT_DIR"
ls -1 "$OUTPUT_DIR"/*.png 2>/dev/null | while read f; do echo "  $(basename "$f")"; done
echo ""

# Quit the app
echo "Closing app..."
osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null || pkill -x "$APP_NAME" 2>/dev/null || true

echo "Done."
