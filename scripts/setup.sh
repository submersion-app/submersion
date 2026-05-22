#!/bin/bash

# Submersion Development Setup Script
# Run this once after cloning the repository

set -e

echo "🏊 Setting up Submersion development environment..."
echo ""

# Get the project root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Configure git hooks
echo "🔗 Configuring git hooks..."
git config core.hooksPath hooks
echo "✅ Git hooks configured"

# Apply vendored libdivecomputer patches (kept in the plugin's patches/ dir).
# The submodule is left modified-in-place; this step is idempotent so it is safe
# to re-run and to run after `git submodule update` resets the submodule.
echo ""
echo "🩹 Applying vendored libdivecomputer patches..."
LIBDC_DIR="$PROJECT_ROOT/packages/libdivecomputer_plugin/third_party/libdivecomputer"
PATCH_DIR="$PROJECT_ROOT/packages/libdivecomputer_plugin/patches"
if [ -d "$PATCH_DIR" ] && [ -d "$LIBDC_DIR/src" ]; then
  for patch in "$PATCH_DIR"/*.patch; do
    [ -e "$patch" ] || continue
    name="$(basename "$patch")"
    if git -C "$LIBDC_DIR" apply --reverse --check "$patch" 2>/dev/null; then
      echo "  already applied: $name"
    elif git -C "$LIBDC_DIR" apply --check "$patch" 2>/dev/null; then
      git -C "$LIBDC_DIR" apply "$patch"
      echo "  applied: $name"
    else
      echo "  ⚠️  skipped (does not apply cleanly): $name"
    fi
  done
  echo "✅ libdivecomputer patches applied"
else
  echo "  (skipped: submodule or patches/ not present)"
fi

# Install Flutter dependencies
echo ""
echo "📦 Installing Flutter dependencies..."
flutter pub get
echo "✅ Dependencies installed"

# Run code generation
echo ""
echo "⚙️  Running code generation (Drift ORM)..."
dart run build_runner build --delete-conflicting-outputs
echo "✅ Code generation complete"

echo ""
echo "🎉 Setup complete! You're ready to develop."
echo ""
echo "Useful commands:"
echo "  flutter run -d macos    # Run on macOS"
echo "  flutter test            # Run tests"
echo "  flutter analyze         # Analyze code"
echo "  dart format lib/ test/  # Format code"
