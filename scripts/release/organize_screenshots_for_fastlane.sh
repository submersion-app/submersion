#!/bin/zsh
# Reorganizes screenshots into Fastlane's required directory structure
#
# Fastlane deliver expects screenshots DIRECTLY in locale folder:
#   screenshots/<locale>/screenshot.png
#
# Fastlane identifies device type by image resolution, not folder structure.
# We keep device prefix in filename to distinguish between devices.
#
# IMPORTANT: App Store rejects PNGs with alpha channels, so we strip them here.
#
# Example:
#   screenshots/en-US/iPhone_6_7_inch_01_dashboard.png
#   screenshots/en-US/iPad_13_inch_01_dashboard.png

set -e

SCREENSHOTS_DIR="screenshots"
LOCALE="en-US"

# Check if screenshots directory exists
if [ ! -d "$SCREENSHOTS_DIR" ]; then
    echo "Error: $SCREENSHOTS_DIR directory not found"
    exit 1
fi

# Create locale directory
mkdir -p "$SCREENSHOTS_DIR/$LOCALE"

# Remove alpha channel from PNG files
# App Store Connect requires screenshots without transparency (IMAGE_ALPHA_NOT_ALLOWED error)
strip_alpha() {
    local file="$1"
    local output="$2"

    # Try ImageMagick first (most reliable)
    if command -v convert &> /dev/null; then
        convert "$file" -background white -alpha remove -alpha off "$output"
        return 0
    fi

    # Fall back to Python with PIL/Pillow
    if command -v python3 &> /dev/null; then
        python3 -c "
from PIL import Image
img = Image.open('$file')
if img.mode == 'RGBA':
    background = Image.new('RGB', img.size, (255, 255, 255))
    background.paste(img, mask=img.split()[3])
    background.save('$output')
else:
    img.convert('RGB').save('$output')
" 2>/dev/null && return 0
    fi

    # Last resort: just copy (will likely fail App Store validation)
    echo "Warning: Could not strip alpha from $file (install ImageMagick or Pillow)"
    cp "$file" "$output"
}

echo "Reorganizing screenshots for Fastlane..."
echo "(Stripping alpha channel for App Store compatibility)"
echo ""

# Process iPhone 6.7" screenshots
if [ -d "$SCREENSHOTS_DIR/iPhone_6_7_inch" ]; then
    echo "Processing iPhone_6_7_inch -> $LOCALE/"

    for file in "$SCREENSHOTS_DIR/iPhone_6_7_inch"/*.png; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            echo "  $filename"
            strip_alpha "$file" "$SCREENSHOTS_DIR/$LOCALE/$filename"
        fi
    done
    echo "  Done!"
fi

# Process iPad 13" screenshots
if [ -d "$SCREENSHOTS_DIR/iPad_13_inch" ]; then
    echo "Processing iPad_13_inch -> $LOCALE/"

    for file in "$SCREENSHOTS_DIR/iPad_13_inch"/*.png; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            echo "  $filename"
            strip_alpha "$file" "$SCREENSHOTS_DIR/$LOCALE/$filename"
        fi
    done
    echo "  Done!"
fi

# Process macOS screenshots
if [ -d "$SCREENSHOTS_DIR/macOS" ]; then
    echo "Processing macOS -> $LOCALE/"

    for file in "$SCREENSHOTS_DIR/macOS"/*.png; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            echo "  $filename"
            strip_alpha "$file" "$SCREENSHOTS_DIR/$LOCALE/$filename"
        fi
    done
    echo "  Done!"
fi

echo ""
echo "Screenshots organized in: $SCREENSHOTS_DIR/$LOCALE/"
echo ""
echo "Contents:"
ls -la "$SCREENSHOTS_DIR/$LOCALE/"
echo ""
echo "You can now upload screenshots:"
echo "  iOS:   cd ios && bundle exec fastlane upload_screenshots"
echo "  macOS: cd macos && bundle exec fastlane upload_screenshots"
