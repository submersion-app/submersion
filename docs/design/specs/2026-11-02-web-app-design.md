# Submersion in a browser: the web app

Date: 2026-11-02
Status: design, awaiting approval
Release: v1.8.4
Related: incremental sync changeset log (`ssv1.*` layout under
`lib/core/services/sync/changeset_log/`), encrypted sync
(`docs/user/encrypted-sync.md`), the June 2026 web attempt (branch
`worktree-web-app`, commit 3078532219d, reference only)

## Intent

A diver is at a computer that cannot run Submersion: a locked-down work
machine, a borrowed laptop, a Chromebook, a friend's desktop. They open a
browser, point it at the sync store their phone and laptop already write to,
and their logbook appears. They look at their dives, fix what needs fixing,
and the edits flow back to every other device. When they close the tab on a
machine they do not trust, nothing of theirs is left behind.

This is Submersion itself in a browser tab: the same screens, the same
features, the same sync engine. It is not a separate "viewer" with a cut-down
interface. The browser becomes one more device in the diver's sync mesh.

Nothing runs on a server. The site is a folder of static files. Each visitor's
browser talks directly to that visitor's own cloud store, so the host of the
site never sees anyone's data. That is what makes it safe to self-host and,
later, safe for a single public copy to serve every user.

## Decisions made with the owner

| # | Question | Decision |
| --- | --- | --- |
| 1 | What is it | The full app running in the browser, not a reduced viewer |
| 2 | Reads or writes | Both, from the first release. The browser is a full sync peer with its own device identity |
| 3 | Backends | S3-compatible, Dropbox, Google Drive and WebDAV. iCloud has no browser API. Git is hidden on the web in this release: the only hosts a browser can reach are self-hosted Gitea or Forgejo, and the port is the most disk-bound of the five. S3 is the owner's daily backend and is verified end to end first |
| 4 | Hosting | Self-hosted only in this release. A hosted copy under submersion.app is a follow-up |
| 5 | Delivery | Everything in one release and one pull request. The owner accepts the review-size and rebase cost; the branch is rebased on main often |
| 6 | Media | The browser never attaches, relinks or removes media. It shows what it can reach read-only; items stored on another device show a placeholder |
| 7 | Credentials | Forgotten when the tab closes by default. A "remember on this device" switch keeps them in browser storage |
| 8 | Identity in the mesh | The browser registers as its own device, named after the browser and platform ("Chrome on Windows") |
| 9 | Hosting bundle | A zip of static files on each release and a hosting guide with header snippets. A Dockerfile ships in the repository for anyone who wants an image; no image is published in this release |
| 10 | Google and Dropbox sign-in | Self-hosters register their own Google client id and paste it in. Dropbox needs no registration (see Backends) |
| 11 | Testing | The existing suite guards native. New VM tests cover the seams, the connect flow and the diagnoser. CI gains a web build job, a headless Chrome job for the browser database and sync against a MinIO container with a real cross-origin policy, and a smoke run of the built bundle in Chromium, Firefox and WebKit |
| 12 | Browsers | Chromium, Firefox and Safari are equal targets. Heavy work runs in a compiled web worker so a large library's first sync streams to disk in all three and never freezes the tab |
| 13 | Google Drive on the web | Accepted as the browser allows it: sign in to Google on each visit, hour-long tokens renewed in the background while signed in, a click when the browser blocks the renewal popup. "Remember on this device" keeps the client id, not the sign-in |
| 14 | Restore and the sample logbook (asked for during the build) | Both work as on desktop. See "Restore and the sample logbook" |
| 15 | Where the sample logbook comes from | Shipped inside the site: the build adds the published package and its photos, about 22 MB, because a page cannot read GitHub release files |
| 16 | Safety before a restore | A copy of the browser's library downloads first, as the desktop app backs up first. Skipped when the browser holds no dives |
| 17 | Encrypted backups | Restored, with the browser's sync key when it matches or the passphrase or recovery code otherwise |

## Goals

- `flutter build web` produces a working Submersion from the single existing
  codebase, with every feature page reachable that does not need hardware.
- It works equally in Chromium, Firefox and Safari, including the first sync
  of a large library.
- The browser connects to the user's existing sync store, rebuilds the
  logbook with the existing merge engine, and publishes its own changes as a
  peer every other device merges.
- Encrypted sync works: the passphrase is entered and used in the browser and
  never leaves it.
- A store that refuses browser requests is diagnosed on the connect screen,
  with the exact rule to add for that provider.
- The reconstructed logbook persists in the browser so a revisit fetches only
  new changes. One action forgets everything.
- A self-hoster downloads one zip, drops it on any static host, and is done.
- The native app's behaviour does not change. Every seam compiles to the same
  code on mobile and desktop.

## Non-goals

- Dive computer downloads over Bluetooth or USB. Fundamental, not deferred.
- Any hardware or OS integration: NFC, nearby devices, Health, the device
  photo library, biometric app lock, background sync.
- A hosted public copy under submersion.app, and shareable read-only links.
  Both are follow-ups with their own sections below.
- A web-specific responsive redesign. The existing desktop layouts are used.
- A signing proxy or any server component.
- Encrypting the browser database at rest. SQLCipher is not available in the
  browser build of SQLite; browser storage is isolated per site and the user
  can forget the device. Stated in the hosting guide.

## Anti-goals

- A web build that silently drifts from native: a page that compiles for the
  web but crashes at runtime on a `Platform` call, or a native feature that
  changes behaviour because of a seam. Architecture guards prevent both.
- Credentials written to browser storage without the user asking for it.
- A browser peer that re-publishes the whole logbook on every visit because
  its identity did not survive a reload.
- A "connection failed" message with no next step. The browser hides the
  reason a cross-origin request failed, so the app has to infer it and say
  what to paste where.

## What works, what does not

The browser rules out more than Bluetooth. The owner has seen this list and
accepted it. Every entry in the first two groups disappears from the UI on
the web or shows a one-line "not available in a browser" state. Nothing
crashes.

**No hardware path**

- Dive computer download and the pages that drive it (Bluetooth, USB).
- NFC tag reading, cylinder and gear passports over NFC, buddy card swap over
  nearby devices. QR scanning stays, since the camera API works in browsers.
- Apple Health and Health Connect import.
- Device photo library, EXIF reading, save to gallery, contacts import for
  buddies.
- Biometric app lock.
- OCR import (on-device model).
- The in-app MCP server (a loopback HTTP server cannot run in a page).

**No background execution or local files**

- Scheduled background sync and reminders. Sync runs while the tab is open,
  on the existing foreground triggers.
- Offline map tile caching. Maps load tiles from the network.
- Importing from another app's SQLite database (MacDive, Subsurface, Diving
  Log and similar). My call, so the first release does not depend on opening
  an uploaded database inside the browser's SQLite. Text and XML formats
  (UDDF, CSV, FIT, SSRF, DL7) import normally through the browser file picker.
- Auto-update. The site shows its version; the host owner updates the bundle.

**Different but equivalent**

- File import and export use the browser file picker and download.
- Restoring a backup reads the file through the picker, and the sample
  logbook comes from the site itself (see "Restore and the sample logbook").
- Printing and PDF export go through the browser.
- Dive site location comes from the browser's location prompt. Reverse
  geocoding is a no-op, as it already is where the geocoder is missing.
- The log file is an in-memory buffer with a download button.
- Full screen uses the browser's full-screen API or is a no-op.

**Everything else works as on desktop**: dive log and detail, profiles,
sites, trips, equipment, buddies and dive centres, certifications,
statistics, insights, planning, compare, data quality, rules, tags, the
change log, settings, and sync itself.

## Backends in a browser

Browsers only let a page call another site when that site says so, through
cross-origin resource sharing (CORS) headers on its responses. That single
fact decides each backend's fate.

| Backend | Browser status | What the user does |
| --- | --- | --- |
| S3 and S3-compatible (AWS, Cloudflare R2, Backblaze B2, MinIO, Wasabi, Hetzner and so on) | Works once the bucket has a CORS rule naming the site's address | Pastes the same key, secret, endpoint, bucket and prefix as in the app. Adds the CORS rule the diagnoser prints |
| Dropbox | Works as is. The app already uses the PKCE flow with a pasted code and no redirect address, and Dropbox's API answers browser requests | Signs in to Dropbox in a new tab, copies the code, pastes it |
| Google Drive | Works with a Google client id of type "Web application" whose authorised JavaScript origin is the site's address. The desktop and Android client ids and the compiled-in secret do not apply | Creates a client id in their own Google Cloud project once and pastes it on the connect screen. The hosting guide walks through it |
| WebDAV | Works once the server allows cross-origin requests. Nextcloud and ownCloud need headers added at the reverse proxy; plain Apache and nginx WebDAV need a header block | Adds the header block the diagnoser prints |
| Git | Hidden in this release. GitHub, GitLab and Bitbucket refuse browser requests to git's smart HTTP endpoints, so only a self-hosted Gitea or Forgejo with CORS enabled could work, and the backend spools packs to temp files and classifies socket-level errors a browser never raises. A follow-up | Chooses another backend. The connect screen names Git as unavailable in a browser, with the reason |
| iCloud Drive | Unavailable. There is no browser API | The connect screen says so and names the alternatives |

The connect screen lists iCloud and Git as unavailable on the web, each with
its one-line reason, before the user types anything.

Google Drive deserves one more note. A web client id receives access tokens
that last about an hour and no refresh token; renewing one goes through
Google's sign-in library and may need a user gesture when the browser blocks
popups. So on the web, Google Drive asks the user to sign in to Google on
each visit, renews in the background while they are signed in, and shows a
"Sign in again" row in the sync status when a renewal needs a click. The
connect screen says this before the user chooses Google Drive.

### The diagnoser

When a request is blocked by CORS, the browser reports a generic network
failure and hides the status code. The connect screen's test step therefore
classifies the failure's shape instead of reading a status:

- An opaque failure on the first request, with the site reachable otherwise:
  the store blocks browser requests. Show the rule for that provider with the
  site's own address already filled in.
- An opaque failure only on a write: the CORS rule allows GET but not PUT or
  DELETE. Show the methods to add.
- 403: wrong credentials or a read-only key used for a full connection.
- 404 or an empty listing at the prefix: no sync data here.
- A TLS failure to a custom endpoint: the browser does not trust the
  certificate. Explain that the browser, not the app, decides trust.

The reference branch has an S3 version of this classifier and a browser-safe
HTTP date helper (SigV4 cannot set the `Date` header in a browser and uses
`x-amz-date`). Both are worth re-deriving, not cherry-picking, since the
surrounding code has moved.

Rule templates ship for AWS S3 (JSON), Cloudflare R2, Backblaze B2, MinIO
(`mc` command), and Nextcloud or plain WebDAV behind nginx and Apache. Each
names the site's address, read from `window.location.origin`.

## Connecting

### First run

On a native device the first run opens the setup wizard. On the web the first
run opens the connect screen instead, because the browser's reason to exist
is data that already lives in a sync store. The connect screen is not a new
flow: the setup wizard already has an "existing data from cloud sync" path
(`ExistingDataSource.cloudSync` and `set_up_sync_step.dart`), and the web
first run enters the wizard at that step with the web additions below. My
call: one flow to maintain, and native keeps its wizard unchanged.

1. **Which store holds your dives?** The backend tiles the existing sync
   settings already show, with iCloud and Git marked unavailable and the
   Google Drive sign-in note.
2. **Credentials**, using the existing per-backend configuration widgets
   from Settings, with the web additions: the Google client id field, and
   the "remember on this device" switch (off by default).
3. **Passphrase**, if the store is encrypted, with the same wording as the
   native prompt. Never stored unless "remember" is on.
4. **Test and connect.** Runs the diagnoser, then the first sync with the
   existing progress reporting. On success the app opens on the dive list.

A secondary link, **Continue without a sync store**, leads to the normal
setup wizard. My call: the native app allows a device without sync, and
hiding that path on the web would make "full functionality" untrue.

### Afterwards

Settings shows the same Sync pages as native. Web-only rows appear in the
Sync section: the storage implementation in use (see Persistence), the
"remember on this device" switch, and **Forget this device**, which wipes
the database, the credentials and the device identity. The sync device list
on every other device shows the browser like any other peer, and forgetting
it from there works the same way.

### Credential storage

Secure storage on the web is browser local storage with light obfuscation,
not a keychain. So the web secure-storage seam has two modes:

- **Session (default):** an in-memory store. Closing the tab forgets
  everything, including the passphrase.
- **Remembered:** the secure-storage web implementation, in local storage,
  scoped to the site's address.

The switch moves existing entries between the two stores. The passphrase
follows the credentials. For Google Drive the remembered entry is the client
id and the chosen account; the sign-in itself cannot be kept (see Backends).

## Identity in the mesh

The device id is minted into the `sync_metadata` table on first sync, exactly
as native does, so it lives in the browser database and survives reloads for
as long as the database does. Forgetting the device deletes the database and
therefore the id; the next connection is a new device, which is correct.

The device name on native comes from a platform channel or the hostname.
Neither exists in a browser. The web variant of the display-name service
derives "Chrome on Windows", "Safari on macOS", "Firefox on Linux" from the
user agent, with "Browser" as the fallback. The name is derived, not
editable: the app has no device rename today, for any device.

Two tabs of the same site share one browser database and one device id.
Drift serialises database access across tabs. Publishing gets a Web Locks
lease so two tabs never write the same changeset sequence number.

## Architecture

```
Presentation   features/*/presentation      reused; capability object hides
Domain         */domain                      reused untouched
Sync core      core/services/sync            reused: serializer, HLC, changeset
                                             log, merge engine, crypto
Persistence    core/database                 NEW web variant: WasmDatabase
Platform       core/platform (new) + seams   NEW: web implementations behind
                                             conditional imports
```

Three kinds of change, in order of how many files they touch.

### 1. Compile blockers: conditional imports

Only a handful of imports stop `flutter build web` outright: `dart:ffi`, the
FFI API of `package:sqlite3`, `drift/native.dart`, `objectbox` through
`flutter_map_tile_caching`, and the native-only local packages
(`libdivecomputer_plugin`, `submersion_saf`, `submersion_ocr`,
`submersion_nl`, `submersion_transcoder`). Each gets the seam the repo
already uses for file sharing: a facade file that exports the native
implementation by default and the web implementation when
`dart.library.js_interop` is defined. New seams use `js_interop`, not the
deprecated `dart.library.html` the existing seam uses; the existing one is
moved to `js_interop` in passing.

Native code behind each seam is moved, not edited. The web implementation
reports `isSupported == false` or provides the browser equivalent.

### 2. Runtime hazards: `dart:io` on the web

`dart:io` compiles on the web and throws at runtime. 248 files import it,
mostly for `Platform.isX`, `File` and `Directory`. Seaming each file is the
wrong shape. Instead:

- Every `Platform.isX`, `Platform.operatingSystem` and
  `Platform.localHostname` read in `lib/` moves to one web-safe helper built
  on `defaultTargetPlatform` and `kIsWeb` (`lib/shared/utils/device_kind.dart`
  already starts this). An architecture guard in `test/architecture/` bans
  `Platform.` reads outside that helper, so the ban holds after the merge.
- File and directory work that is reachable on the web goes through the
  platform layer (below). File and directory work that only runs behind a
  hidden feature may keep its `dart:io` import; the guard allows it in files
  the capability object marks native-only. The builder keeps that list short
  and explicit.
- `HttpOverrides`, the proxy resolver and the Windows root store are
  native-only and sit behind the bootstrap seam.

### 2b. Runtime hazards: `dart:isolate` on the web

`dart:isolate` also compiles on the web and throws on `Isolate.spawn` and
`Isolate.run`. Twenty files use them, and several sit on the browser's
critical path: the base parse worker that a first sync of a large library
runs through (`changeset_log/base_parse_worker.dart`,
`base_parse_client.dart`), `lib/core/utils/off_isolate.dart` (inflating
changesets and manifests above 256 KiB), the shared-library field
signatures, backup encryption, the PDF page renderer, planner background
results and the UDDF dump codec.

The owner chose equal support for Chromium, Firefox and Safari, including a
large library's first sync. Running that work inline would freeze the tab
and, in Safari, hold the whole base in memory, because Safari only writes to
OPFS from inside a worker. So the web build gets a **compute worker**:

- `web/compute_worker.dart`, compiled with `dart compile js` alongside the
  database worker. It is pure Dart: the same Flutter-free guard applies.
- `off_isolate.dart` becomes the seam. Its native implementation keeps
  `Isolate.run`; its web implementation posts the job to the compute worker
  and awaits the reply. Every caller above is already written against that
  helper or moves onto it, so the job set is a closed list of named,
  serialisable jobs rather than arbitrary closures.
- The base sink writes its OPFS temp file from inside the compute worker
  through a synchronous access handle, which is the one OPFS write path all
  three browsers share. The parse job reads it back the same way.
- Progress flows back over the same channel, so the first-sync screen keeps
  updating while the worker runs.

Jobs that are small on every realistic library (a single manifest, one
changeset) may run inline on the web when the builder measures them as such;
the seam makes that a per-job choice.

### 3. The platform layer

`lib/core/platform/` holds small interfaces with a native and a web
implementation each, chosen by conditional import and exposed through
Riverpod providers so tests inject either:

| Interface | Native | Web |
| --- | --- | --- |
| App directories (support, documents, temp, logs) | `path_provider` | OPFS paths and an in-memory log buffer |
| Secure store | `flutter_secure_storage` | session store or local storage (see Credential storage) |
| File picking and saving | `file_picker`, share sheet | browser file input and download |
| Database connection | `NativeDatabase` on a background isolate | `WasmDatabase` in a worker |
| Device display name | platform channel or hostname | user agent client hints |
| Capabilities | everything true that the OS supports | the table in "What works" |

The capability object is the one place the UI asks "can this device do X".
Pages, nav destinations, menu items and settings rows consult it rather than
`kIsWeb`. Native builds answer from the OS as they do today; the existing
scattered `kIsWeb` reads move to it.

### Entry point

`lib/main.dart` stays the only entry point, so `flutter build web` and
`flutter run -d chrome` need no flags. Its bootstrap becomes a seam:
`bootstrap_io.dart` keeps today's sequence (HTTP overrides, Windows
directory migration, path_provider, log file); `bootstrap_web.dart` opens
the browser database, builds the web platform layer and decides between the
connect screen and the app. Both hand the same root provider overrides to
`SubmersionRestart`.

### Persistence

The database is Drift's `WasmDatabase` over `sqlite3.wasm`, in the browser's
origin private file system (OPFS). Drift probes the browser and picks the
best implementation it supports:

- OPFS in a shared worker, the fastest. Needs the site served with
  `Cross-Origin-Opener-Policy: same-origin` and
  `Cross-Origin-Embedder-Policy` headers.
- OPFS in a dedicated worker with Web Locks. No headers needed.
- IndexedDB, for browsers without OPFS (older Safari, some private modes).
- In memory, as the last resort, with a warning that nothing persists.

Settings shows which one is active. The hosting guide recommends the headers
and ships them for each host, and says that without them the app still
works. The embedder header blocks cross-origin images and tiles that lack
their own CORS headers; the builder chooses between the `credentialless`
embedder mode and per-request CORS attributes and records the choice in the
hosting guide.

The web database is created at the current schema version by Drift's own
migration strategy. There is no upgrade ladder to run, because every web
database was created by a Submersion web build; version to version upgrades
run through the same `MigrationStrategy` native uses. The raw SQLite
pre-open checks (`PRAGMA user_version`, `PRAGMA cipher_version`) are native
only. The `before_open` backstops run on both.

### The database worker

Drift's OPFS implementations run SQLite inside a web worker, and that worker
is a separately compiled JavaScript file, not part of the Flutter build. Every
connection the app opens registers three Dart SQL functions
(`lib/core/database/app_sql_functions.dart`), and queries fail without them,
so the worker has to register them too. Today that file's import chain reaches
`dart:ui`, which a worker cannot load. My call, with the alternative rejected:

- The three functions and their dependency chain become Flutter-free pure
  Dart (the chain runs through `DiveEnvironment` and the tank configuration
  classifier). An architecture guard asserts the worker entry point's import
  closure contains no `package:flutter` or `dart:ui` import.
- `web/drift_worker.dart` registers the functions through Drift's
  `setupAllDatabases` hook and is compiled with `dart compile js` by
  `scripts/build_web.sh` and by the CI web job, right before
  `flutter build web`. The compiled worker is a build output and is never
  committed. `flutter build web` itself still needs no flags.
- The rejected alternative, SQLite on the main thread with no worker, would
  lose both OPFS implementations and leave IndexedDB as the best storage.

Large libraries stream their base files to a temporary file today. On the
web that sink writes to an OPFS file from the compute worker, never to
memory. This is the single most important porting point for memory safety,
since browser tabs have less headroom than phones.

### Encryption

End-to-end sync encryption derives its key with Argon2id through
`package:cryptography`. The Flutter accelerator plugin for it has no web
build, so the browser uses the pure Dart path. The builder measures the
derivation time in Chrome and, if it exceeds a few seconds, shows progress
rather than changing parameters: the parameters are part of the on-storage
format and shared with every other device.

### Media

`MediaSourceType` already names where each item lives. On the web:

| Source | Shown | Why |
| --- | --- | --- |
| `mediaStore` | Yes | The media store lives in the sync backend the browser is connected to |
| `networkUrl`, `manifestEntry` | Yes, when the host allows browser requests | Plain HTTP fetches |
| `serviceConnector` (Lightroom, Immich) | Yes, when the connector's host allows browser requests and the account is signed in on this device | Same as native, over fetch |
| `localFile`, `platformGallery` | Placeholder: "Stored on another device" | The path or asset only exists there |
| `signature` | Yes | Embedded bytes |

No add, relink, remove, caption-edit of media, people tags or metadata
write-back. The media section header, gallery and media map are read-only.
Media statistics count what exists, as native does.

### Restore and the sample logbook

Added during the build at the owner's request: the site restores a backup
and opens the sample logbook as the desktop app does.

**One seam for both.** drift creates a browser database from bytes when the
database does not exist yet (`initializeDatabase`).
`BackgroundDatabaseConnection.installImage` writes an image under a name no
tab has open, with the header's journal mode set to rollback (a browser file
system has no shared memory for WAL), and checks that it opens.

**Restore.** The picker reads the backup into memory. An encrypted backup
(SBE1) opens with the browser's sync key when the key ids match, or with the
passphrase or recovery code the dialog asks for: AES-GCM runs in Web Crypto
and Argon2id in the compute worker. The image must be SQLite with a schema
no newer than this build. When the browser's library holds dives, a copy of
it downloads first as `submersion-backup-before-restore-<stamp>.db`. The
image is installed under a new name (`submersion_<millis>`) and opened
through the normal open, which runs the upgrade ladder for an older backup.
Only then does a preference point the browser at it, so a tab closed
halfway leaves the old library in place. The previous database is deleted
on a later launch, once no tab holds it. Sync is re-baselined as on desktop:
the device id and epoch are kept, and the merge or replace choice is the
same dialog. The site's other tabs reload.

The entry points are the desktop's: Settings > Backups, first run's
"I have existing data", and Set up this device.

**The sample logbook.** GitHub release files send no CORS header, so a page
cannot download the package the desktop app does. `scripts/build_web.sh`
fetches the newest package this build can open, verifies its SHA-256 and
unpacks it into the bundle's `demo/` folder, with an index
(`demo/demo.json`) naming the database, its size and hash, and the photos.
The site reads the index from its own origin. Without one (a host who
deleted the folder, or a build run with `SUBMERSION_WEB_SAMPLE_LOGBOOK=0`)
the entry points stay hidden, as they do on desktop when the manifest
cannot be reached.

Entering fetches the database from the site, checks its hash, installs it
as `submersion_demo` and prepares it as desktop does (dates moved, units
applied). Sample photos become links to `demo/photos/` on the site, which
the browser shows like any other web photo. The demo state and the
preferences snapshot live in local storage instead of files. Entering and
leaving reload the site's other tabs, since they share preferences. Sample
mode seals the same features as on desktop.

## Hosting bundle

Each release adds, next to the existing installers:

- `Submersion-<tag>-Web.zip`: the output of `flutter build web --release`
  plus header snippet files (`_headers` for Cloudflare Pages and Netlify,
  `nginx.conf` and `Caddyfile` fragments, a GitHub Pages note that headers
  cannot be set there) and `HOSTING.md`. The `demo/` folder holds the
  sample logbook; deleting it hides sample mode.
- A `Dockerfile` in the repository that serves the bundle with the headers
  set, for anyone who prefers an image. No image is published in this
  release; publishing one to GitHub Packages is a follow-up that needs
  organisation settings checked first. CI builds the Dockerfile once per run
  so it cannot rot; nothing is verified with a local container.
- `docs/user/web-app.md`, the user-facing guide: what works, how to connect
  each backend, the CORS rules, the Google client id walkthrough and sign-in
  behaviour, "remember on this device", forgetting a device, the storage
  note, and browser support.

The web build runs in `build-all.yml` as its own job and the zip flows
through `release.yml` like every other `Submersion-*` asset, including the
checksum file. The app shows the version from the bundle, with no update
check.

## Security

- **Keys in the browser.** A full connection holds a read and write
  credential in page memory. Mitigations: least-privilege scoping to the sync
  prefix, session-only storage by default, and the fact that it is the user's
  own site and own store. The hosting guide says this plainly and recommends
  a key scoped to the prefix.
- **Database not encrypted at rest.** OPFS is isolated to the site's origin
  by the browser. Anyone with the OS user account and the browser profile
  could read it. "Forget this device" exists for that machine. The guide
  says so.
- **The site is static.** Serving it over HTTPS is required for OPFS and for
  the browser APIs; the guide says so. No server code means no server-side
  attack surface and no data at the host.
- **Google client id is public by design.** A web client id has no secret.
  Scoping it to the authorised origin is what protects it.

## Testing

- **Native suite, unchanged, as the regression guard.** Every seam leaves
  the native implementation in place, so a green suite means native did not
  change.
- **New architecture guards** in `test/architecture/`: no `Platform.` reads
  outside the helper; no `dart:ffi` or `drift/native.dart` import outside a
  seam's native file; every capability consulted by the UI exists on both
  implementations.
- **New VM tests**, which cover most of the new code: each web platform
  implementation (injected, exercised with fakes), the capability object's
  web answers and the UI hiding they drive, the connect flow (mode switch,
  remember switch moves entries, passphrase handling, Google client id
  validation), the diagnoser (each failure shape maps to the right message
  and template), the device name derivation from sample user agents, and the
  publish lock.
- **Web build guard**: a `flutter build web --release` job in `ci.yaml`. A
  stray native import is the likeliest regression, and only this catches it.
- **Headless Chrome job** in `ci.yaml`: `flutter test --platform chrome` on a
  small `test/web/` suite that opens a `WasmDatabase`, writes, reloads and
  reads back, then runs a full sync cycle (connect, pull, edit, publish,
  pull from a second device id) against a MinIO service container with a real
  CORS policy. One case runs against MinIO with CORS off and asserts the
  diagnoser's verdict, so the failure shapes the VM tests assume are proven
  in a real browser. The job asserts that nothing was skipped.
- **Three-browser smoke job** in `ci.yaml`: Playwright drives the built
  bundle in Chromium, Firefox and WebKit against the same MinIO container,
  completing connect, first sync of a fixture library large enough to take
  the worker path, one edit and one publish in each. This is the only check
  that exercises Safari's engine, since `flutter test` runs in Chrome alone.
- **Worker guards**: an architecture test that the import closure of each
  worker entry point has no Flutter or `dart:ui` import, and a VM test that
  every compute job round-trips through its message encoding.
- **Owner verification** against the owner's own S3 store before the PR is
  marked ready, and against the other backends the owner uses.

## Reference material

The June 2026 attempt lives on branch `worktree-web-app` (commit
3078532219d, 47 commits on top of v1.5.8). It is a source of ideas and
shapes, not of code: main has moved through hundreds of schema versions and
several sync-layer changes since. Worth reading there:

- `docs/superpowers/specs/2026-06-28-submersion-web-app-design.md` and the
  five phase plans.
- `lib/features/web_viewer/s3_failure_classifier` and
  `http_date_web`, the S3 diagnoser and date helper.
- `web/drift_worker.dart`, `scripts/build_web.sh`,
  `scripts/check_web_assets.py`.
- The commit "replace Platform.isX/operatingSystem with web-safe compat
  helpers", which found the same runtime hazard this design addresses with
  a guard.

## Left to the builder

- The exact interface of each platform-layer class and where the OPFS base
  sink hooks into the existing streaming reader.
- Whether to use `credentialless` or `require-corp` for the embedder header,
  measured against map tiles and connector media.
- The order of the seams in the plan. The old attempt's order (common path,
  dive computer, media, scattered call sites, entry point) worked.
- How the web test suite is laid out so the CI bundler (one isolate per run)
  never picks it up on the VM.
- The compute worker's message encoding and which jobs run inline on the
  web after measurement.
- The MinIO job's fixture: a small synthetic library with two device
  namespaces, created by the existing test helpers, and a larger one for the
  smoke job's worker path.

## Follow-ups (not in this PR)

- **A hosted copy at submersion.app.** The same bundle served from one
  address with the headers set. It needs a Google web client id registered
  for that origin, a privacy note saying the host stores nothing, and the
  CORS templates defaulting to that origin. The static design means the
  bundle itself does not change.
- **Shareable read-only links.** A scoped export of selected dives to a
  public-read object and a credential-free URL that renders it. The old spec
  designed this; it waits for the hosted copy.
- **Git on the web**, for self-hosted Gitea and Forgejo with CORS enabled:
  the pack spool moves to OPFS and the transport learns browser failure
  shapes.
- **A published container image** on GitHub Packages, once the organisation
  allows the workflow token to publish and the owner has made the package
  public after its first push.
- **SQLite-based imports on the web**, by opening the uploaded file in the
  browser's SQLite.
- **A read-only connection mode** for a read-only key, which the hosted copy
  makes more useful.
