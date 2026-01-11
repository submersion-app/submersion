#!/bin/bash
#
# macOS Screenshot Capture Script
#
# Captures screenshots of the Submersion app on macOS using native screencapture.
# Navigates through the app's main screens using AppleScript.
#
# Usage:
#   ./scripts/capture_macos_screenshots.sh [--output-dir DIR]
#
# Required permissions (System Settings > Privacy & Security):
#   - Screen Recording: Required for screencapture to work
#   - Accessibility: Required for clicking UI elements
# After granting permissions, restart your terminal app.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
OUTPUT_DIR="$PROJECT_ROOT/screenshots/macOS"
APP_NAME="Submersion"
WINDOW_WAIT_TIMEOUT=30
SCREENSHOT_INDEX=0

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

# Function to click at absolute screen position
click_at_abs() {
  local x="$1"
  local y="$2"
  osascript -e "tell application \"System Events\" to click at {$x, $y}" 2>/dev/null
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

# Function to click bottom nav item (0=Dashboard, 1=Dives, 2=Sites, 3=Trips, 4=More)
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
  sleep 1
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

# Wait for app to fully render
echo "Waiting for app to render..."
sleep 3

echo ""
echo "Capturing screenshots..."
echo ""

# 1. Dashboard (initial screen)
capture_screenshot "dashboard"

# 2. Dives
echo "→ Navigating to Dives"
click_bottom_nav 1
sleep 1
capture_screenshot "dive_list"

# 3. Sites
echo "→ Navigating to Sites"
click_bottom_nav 2
sleep 1
capture_screenshot "sites_list"

# 4. More menu
echo "→ Navigating to More"
click_bottom_nav 4
sleep 1
capture_screenshot "more_menu"

# 5. Try Equipment (first item in More menu)
echo "→ Navigating to Equipment"
bounds=$(get_window_bounds)
if [ -n "$bounds" ]; then
  IFS=',' read -r wx wy ww wh <<< "$bounds"
  # Click first menu item (Equipment) - approximately 150px from top
  click_at $((ww / 2)) 150
  sleep 1.5
  capture_screenshot "equipment"

  # 6. Back to More, then Statistics
  echo "→ Navigating to Statistics"
  click_bottom_nav 4
  sleep 0.5
  # Click second menu item (Statistics) - approximately 220px from top
  click_at $((ww / 2)) 220
  sleep 1.5
  capture_screenshot "statistics"
fi

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
