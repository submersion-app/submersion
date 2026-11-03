# The Web Build

Submersion runs as a web page: the same app, compiled with `dart compile
js`, reading the diver's data from their own sync store and keeping it in
the browser's storage. Nothing runs on a server. This page is how that
build is put together, what keeps it building, and how to run and test it.
The user-facing side is in the [user guide](../user/web-app.md) and the
hosting guide shipped inside the bundle (`web_hosting/HOSTING.md`).

## Platform seams

The browser has no `dart:io`, no isolates, no plugins for hardware, and
`flutter build web` compiles every library `lib/main.dart` reaches, so a
VM-only import anywhere stops the build. Three conventions keep it
building:

- **Facades with an io and a web half.** A file that needs a platform API
  is split into `x.dart`, which only exports, `x_io.dart` and `x_web.dart`:

  ```dart
  export 'x_io.dart' if (dart.library.js_interop) 'x_web.dart';
  ```

  Both halves declare the same names. Examples: `lib/core/platform/`
  `file_saver`, `secure_storage_backend`, `cross_tab_lock`,
  `browser_origin_storage`, `device_capabilities`, `host_platform`, and
  `lib/core/database/` `background_database_connection`,
  `scratch_database`. `test/architecture/web_compile_seams_test.dart`
  fails when a VM-only import appears outside an `_io.dart` half.
- **`HostPlatform`, never `Platform`.** Operating-system checks go through
  `lib/core/platform/host_platform.dart`, whose web half answers from the
  user agent. `test/architecture/host_platform_single_source_test.dart`
  keeps `dart:io`'s `Platform` out of shared code.
- **`DeviceCapabilities`, never `kIsWeb` in a widget.** What a device can
  do is one value, `DeviceCapabilities` (`lib/core/platform/
  device_capabilities_model.dart`), read through
  `deviceCapabilitiesProvider`. The native half reproduces the old
  scattered gates; `DeviceCapabilities.web` is the browser's table. A
  screen that must hide a feature reads one capability field; it never
  asks the platform. Adding a feature the browser lacks means adding a
  field, setting it false in the web table, and gating on it. A whole
  route the browser cannot serve goes in `webUnavailableRoutePrefixes`
  (`lib/core/router/web_unavailable_routes.dart`), which redirects to the
  "not available in a browser" page; a router-backed test checks that
  every prefix is a route the router serves.

The connect flow, the credential stores, the CORS diagnoser and the rest
of the browser-only code live under `lib/core/platform/web/` and the
`web/` subfolders of the settings feature.

## The two workers

Two scripts under `web/` run beside the app, compiled apart from Flutter
by `scripts/web/compile_workers.sh` (`dart compile js -O3`):

- `web/drift_worker.dart` is drift's SQLite worker: it loads
  `sqlite3.wasm`, opens the database in the browser's private file system
  (or IndexedDB where there is none) and registers the app's SQL functions
  on every connection, as the native connection setup does.
- `web/compute_worker.dart` runs what native code runs on isolates:
  inflating and compressing sync payloads, AES-GCM, Argon2id, hashing, and
  streaming a large sync base through a temporary file in the origin
  private file system.

Everything they reach must be plain Dart: no Flutter, no `dart:ui`, no VM
libraries. `test/architecture/web_worker_import_graph_test.dart` walks
their import graphs. They are compiled with `-O3`, not `-O4`:
`web_worker_build_flags_test.dart` guards that, because `-O4` trusts
primitives and would drop the bounds checks the compute worker relies on
when it inflates a payload a peer wrote.

`sqlite3.wasm` is fetched by `scripts/web/fetch_sqlite3_wasm.sh` from the
release pinned in `scripts/web/sqlite3_wasm.lock` (URL and SHA-256). The
module and `package:sqlite3`'s bindings ship together, so
`scripts/web/check_sqlite3_wasm_lock.py` fails CI when the lock names a
release other than pubspec.lock's; bump both at once.

The compiled workers and the module are git-ignored. `flutter build web`
copies everything under `web/` into the bundle, so the build script
removes the worker sources and the `.deps` and `.map` sidecars afterwards
and the bundle check refuses them.

## Building

```bash
scripts/build_web.sh
```

That is the one entry: fetch `sqlite3.wasm`, compile the workers,
`flutter build web --release --pwa-strategy=none`, remove
`flutter_service_worker.js` (Flutter writes it whatever the strategy; the
bootstrap registers nothing, and a cached bundle is what a self-hoster who
replaces the files must not get), copy the hosting files from
`web_hosting/`, and run `scripts/check_web_bundle.py`. The check fails on a
missing file, a `sqlite3.wasm` that is not the lock's build, a service
worker, or a source or sidecar in the bundle.

Submersion's own site builds in its Google web client:

```bash
GOOGLE_WEB_CLIENT_ID=<id>.apps.googleusercontent.com \
GOOGLE_WEB_CLIENT_ORIGINS=https://<the site's address> \
  scripts/build_web.sh
```

The client must be a "Web application" client in the same Google Cloud
project as the installed apps' clients, since Drive's app folder belongs
to the project (`GoogleDriveClientConfig`), with each address in
`GOOGLE_WEB_CLIENT_ORIGINS` listed as an authorised JavaScript origin. The
build uses it only at those addresses; anywhere else, and in a build
without it, the connect step asks for a client id of the user's own.

To run the app in a browser during development:

```bash
scripts/web/fetch_sqlite3_wasm.sh
scripts/web/compile_workers.sh
flutter run -d chrome
```

The page loads `sqlite3.wasm`, `drift_worker.js` and `compute_worker.js`
from the site root, which is why the two scripts come first; rerun
`compile_workers.sh` after changing anything a worker reaches.

To serve a built bundle the way a configured host would (the two
cross-origin isolation headers, `application/wasm`):

```bash
python3 scripts/web/serve_bundle.py --dir build/web --port 8080
```

## Storage

The database is drift's `WasmDatabase` over `sqlite3.wasm`. Drift probes
the browser and picks the best storage it supports: the origin private
file system in a shared worker, then OPFS in a dedicated worker behind
Web Locks, then IndexedDB, then memory. Which OPFS mode a browser gets is
not a matter of speed alone. Chromium cannot spawn a dedicated worker
from a shared worker, so it never offers the first, and the second needs
`SharedArrayBuffer`, which only a cross-origin isolated page has. So
Chrome with the hosting headers (`Cross-Origin-Opener-Policy: same-origin`
and `Cross-Origin-Embedder-Policy: credentialless`) runs the locked OPFS
mode, and Chrome without them runs IndexedDB. `BackgroundDatabaseConnection`'s
web half records the
choice in `WebDatabaseStatusHolder`; the Cloud Sync page shows it as the
Browser storage row.

drift 2.35.3 is the floor. In 2.34.3 the locked OPFS mode hung the first
nested write transaction (the first run's diver insert never returned:
the inner commit released the navigator lock, the outer commit threw and
its rollback waited forever, drift issue #3870, fixed in 2.35.2), and
IndexedDB kept the writes of a transaction in memory until a later
statement ran, so a reload straight after a save lost them (#3864, fixed
in 2.35.1). The browser suite runs on IndexedDB, since `flutter test`
serves without the headers; the smoke job's server sends them, so its
first-run test is what exercises the locked mode.

Forget this device wipes the browser through `WebForgetDeviceService`:
sync off, secrets and preferences cleared, the database closed and then
deleted through drift's probe (`deleteStoredDatabases`, which covers OPFS
and IndexedDB alike), the sync temp files removed, the site's other tabs
told over a `BroadcastChannel` so they reload too, then a reload. A
database that survives deletion stops the wipe and is reported, never
reloaded over.

A backup in the browser is a copy, not a file read: drift keeps the file
where a page cannot read it and SQLite's page table is not compiled in, so
`readDatabaseImage` (`lib/core/database/database_image.dart`) replays the
schema into a scratch database (a second `sqlite3.wasm` over an in-memory
file system in the page), copies every row, then the indexes, triggers and
views, and hands the bytes to `FileSaver` as a download.

A restore works the other way round (`DatabaseServiceBrowserRestore`).
`BackgroundDatabaseConnection.installImage` creates a database from bytes
through drift's `initializeDatabase`, with the header set to a rollback
journal, under a new name (`submersion_<millis>`, see
`web_library_paths.dart`). The browser's preference
(`web_library_database_path`) moves to it only once it opens, so the old
library survives a tab closed halfway or a backup that fails to open. The
replaced library is deleted at once, or at a later launch when another tab
held it, and the other tabs are told to reload over the site's
`BroadcastChannel`, which a tab never hears from itself.

drift's probe lists every OPFS database but only the IndexedDB database it
is asked about. `storedDatabaseNames` therefore asks
`indexedDB.databases()` as well, and probes the names the app knows for a
browser that cannot list. Forget this device deletes everything it finds.

The sample logbook ships in the bundle's `demo/` folder
(`fetch_demo_db.py --web-index`): a page cannot read the GitHub release the
native app downloads from. `BundledDemoManifestClient` reads
`demo/demo.json`, `BundledDemoPackageInstaller` fetches the gzipped
database, inflates it in the compute worker, checks its hash and installs
it as `submersion_demo`, and the sample photos become links to
`demo/photos/`. Demo mode's state and preferences snapshot live in local
storage (`demo_state_store_web.dart`).

Sync's temp files live in OPFS through the compute worker. A browser that
refuses OPFS (a private window, or WebKit under Playwright) falls back to
`MemoryOpfsFiles` through `FallbackOpfsFiles`, so sync still runs and a large
library is the only thing that suffers. An export cannot outlive its page, so
a browser never records a resumable base publish: `ResumableBasePublishStore`
is not persistent there, and a base publish that dies starts over.

## Tests

Browser tests live under `test/web/` and are `@TestOn('browser')`; the VM
shards leave the directory out (`bundle_tests.py --exclude-dir test/web`).
They load the compiled workers from `test/web/assets/`, which
`compile_workers.sh` stages:

```bash
scripts/web/compile_workers.sh
scripts/web/test_web.sh --allow-skips
```

The script runs one directory of `test/web/` per Chrome: one Chrome
loading every file loses its connection after about nine suites,
serially too, while each directory passes on its own. Without
`--allow-skips` it fails on any skipped test.

The tests under `test/web/sync/` that talk to a store skip, saying so,
without the `MINIO_*` defines. To run them locally against MinIO:

```bash
docker run -d --name minio -p 9000:9000 \
  -e MINIO_ROOT_USER=minioadmin -e MINIO_ROOT_PASSWORD=minioadmin \
  -e MINIO_API_CORS_ALLOW_ORIGIN='*' \
  pgsty/minio:RELEASE.2026-08-04T00-00-00Z server /data
docker run -d --name minio-nocors -p 9001:9000 \
  -e MINIO_ROOT_USER=minioadmin -e MINIO_ROOT_PASSWORD=minioadmin \
  -e MINIO_API_CORS_ALLOW_ORIGIN='https://example.invalid' \
  pgsty/minio:RELEASE.2026-08-04T00-00-00Z server /data
AWS_ACCESS_KEY_ID=minioadmin AWS_SECRET_ACCESS_KEY=minioadmin \
  AWS_DEFAULT_REGION=us-east-1 \
  aws --endpoint-url http://localhost:9000 s3 mb s3://submersion-test
```

Seed the library the round trip pulls (two divers, a site, a buddy, five
dives with profiles, published under the device id `seed-device`), then
run the suite with the defines:

```bash
flutter test tool/seed_sync_library_test.dart \
  --dart-define=MINIO_ENDPOINT=http://localhost:9000 \
  --dart-define=MINIO_BUCKET=submersion-test \
  --dart-define=MINIO_ACCESS_KEY=minioadmin \
  --dart-define=MINIO_SECRET_KEY=minioadmin
scripts/web/test_web.sh \
  --dart-define=MINIO_ENDPOINT=http://localhost:9000 \
  --dart-define=MINIO_NOCORS_ENDPOINT=http://localhost:9001 \
  --dart-define=MINIO_BUCKET=submersion-test \
  --dart-define=MINIO_ACCESS_KEY=minioadmin \
  --dart-define=MINIO_SECRET_KEY=minioadmin
```

The seeder is a Flutter test run as a tool, like `tool/demo_data/`,
because the sync stack needs the Flutter binding.

The three-browser smoke (`scripts/web/smoke_test.py`) drives Chromium,
Firefox and WebKit with Playwright through two first runs against a served
bundle: one with no store (the connect step's offer, a name, the remaining
steps, and the first write landing on the dashboard, which is the commit
drift 2.34.3 hung on the locked OPFS mode), and one that connects to the
same store, downloads the seeded library, edits a dive and publishes:

```bash
python3 -m pip install -r scripts/web/requirements-smoke.txt
python3 -m playwright install --with-deps chromium firefox webkit
python3 scripts/web/serve_bundle.py --dir build/web --port 8080 &
MINIO_ENDPOINT=http://localhost:9000 MINIO_BUCKET=submersion-test \
MINIO_ACCESS_KEY=minioadmin MINIO_SECRET_KEY=minioadmin \
python3 -m pytest scripts/web/smoke_test.py -v
```

It opens the page with `?a11y=1`, which the web bootstrap reads to keep
Flutter's semantics tree on from the first frame; Playwright finds every
tile, field and button through that tree.

## CI

- `web-build` runs `scripts/build_web.sh`, builds the bundle's Dockerfile
  once so it cannot rot (never pushed) and uploads `build/web` as the
  `web-bundle` artifact.
- `web-tests` starts two MinIO containers (one admitting every origin, one
  admitting only another site, which proves the CORS diagnoser's failure
  shape in a real browser), seeds the library and runs the browser suite,
  failing on any skipped test.
- `web-smoke` serves `web-build`'s artifact and runs the Playwright smoke
  in the three browsers, failing on a junit file with no tests. It is
  advisory for now (exempt in `scripts/check_ci_success_gate.py`) until it
  passes in Chromium and Firefox on the runner, issue #4186.
- `build-all`'s `build-web` job zips the bundle as
  `Submersion-<tag>-Web.zip`, which the release workflow attaches and
  validates like every other asset.

`web-build` and `web-tests` sit in the `ci-success` gate (`web-smoke`
rejoins it with #4186), and `script-tests` covers
`check_web_bundle.py`, `check_sqlite3_wasm_lock.py` and `serve_bundle.py`.
