#!/bin/zsh
# Reorganizes screenshots into Fastlane's required directory structure
#
# Fastlane deliver expects:
#   screenshots/<locale>/<device_type>/screenshot.png
#
# Example:
#   screenshots/en-US/iPhone 6.7" Display/01_dashboard.png

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

echo "Reorganizing screenshots for Fastlane..."

# Process iPhone 6.7" screenshots
if [ -d "$SCREENSHOTS_DIR/iPhone_6_7_inch" ]; then
    dest_dir="$SCREENSHOTS_DIR/$LOCALE/iPhone 6.7\" Display"
    echo "Processing iPhone_6_7_inch -> iPhone 6.7\" Display"
    mkdir -p "$dest_dir"

    for file in "$SCREENSHOTS_DIR/iPhone_6_7_inch"/*.png; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            # Remove the device prefix
            new_filename="${filename#iPhone_6_7_inch_}"
            echo "  $filename -> $new_filename"
            cp "$file" "$dest_dir/$new_filename"
        fi
    done
    echo "  Done!"
fi

# Process iPad 13" screenshots
if [ -d "$SCREENSHOTS_DIR/iPad_13_inch" ]; then
    dest_dir="$SCREENSHOTS_DIR/$LOCALE/iPad Pro 13\" Display"
    echo "Processing iPad_13_inch -> iPad Pro 13\" Display"
    mkdir -p "$dest_dir"

    for file in "$SCREENSHOTS_DIR/iPad_13_inch"/*.png; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            # Remove the device prefix
            new_filename="${filename#iPad_13_inch_}"
            echo "  $filename -> $new_filename"
            cp "$file" "$dest_dir/$new_filename"
        fi
    done
    echo "  Done!"
fi

echo ""
echo "Screenshots organized in: $SCREENSHOTS_DIR/$LOCALE/"
echo ""
echo "Structure:"
ls -la "$SCREENSHOTS_DIR/$LOCALE/"
echo ""
echo "You can now run: cd ios && bundle exec fastlane upload_screenshots"
