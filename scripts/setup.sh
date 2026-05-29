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

# libdivecomputer is vendored as a fork submodule
# (submersion-app/libdivecomputer, branch submersion-patches) that already
# includes our parser patches, so there is no patch step here. Fetch it with
# `git submodule update --init --recursive`.

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
