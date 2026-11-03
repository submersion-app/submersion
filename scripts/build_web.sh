#!/bin/bash
#
# Builds the browser app into build/web, ready to serve or to zip.
#
# Fetches the pinned sqlite3.wasm, compiles the browser workers, runs the
# Flutter web build without a service worker (a self-hoster who replaces
# the files must not have last release's bundle served from the browser's
# cache) and with the engine loaded from the bundle, not from Google's CDN
# (a self-hosted site must work where gstatic.com does not), drops the worker sources and the compiler sidecars that `flutter
# build web` copies out of web/, adds the sample logbook and the hosting
# files, and checks the bundle.
#
# The sample logbook ships inside the site, in demo/: a page cannot read the
# GitHub release the app downloads it from (issue #4121). Set
# SUBMERSION_WEB_SAMPLE_LOGBOOK=0 to build without it, which hides sample
# mode in that site.
#
# Usage:
#   scripts/build_web.sh [flutter build web options...]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

scripts/web/fetch_sqlite3_wasm.sh
scripts/web/compile_workers.sh
flutter build web --release --pwa-strategy=none --no-web-resources-cdn "$@"

# flutter build web writes flutter_service_worker.js whatever the PWA
# strategy; with none, flutter_bootstrap.js calls load() with no service
# worker settings, so nothing registers it and the file only invites a
# host to cache it. The bundle check refuses it.
rm -f build/web/flutter_service_worker.js
rm -f build/web/drift_worker.dart build/web/compute_worker.dart
rm -f build/web/*.js.deps build/web/*.js.map

cp web_hosting/_headers web_hosting/nginx.conf web_hosting/Caddyfile \
   web_hosting/Dockerfile web_hosting/HOSTING.md build/web/

if [ "${SUBMERSION_WEB_SAMPLE_LOGBOOK:-1}" != "0" ]; then
  rm -rf build/web/demo
  python3 scripts/demo_data/fetch_demo_db.py build/web/demo --web-index
fi

python3 scripts/check_web_bundle.py build/web
