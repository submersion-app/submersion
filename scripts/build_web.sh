#!/bin/bash
#
# Builds the browser app into build/web.
#
# First version: the Flutter web build alone. The browser database work adds
# the SQLite WebAssembly fetch and the worker compilation, and the bundle work
# adds the hosting files and the bundle check.
#
# Usage:
#   scripts/build_web.sh [flutter build web options...]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

flutter build web --release "$@"
