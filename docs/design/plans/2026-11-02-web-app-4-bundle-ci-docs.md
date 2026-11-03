# Web App Plan 4: Bundle, CI, Release and Documentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every release attaches `Submersion-<tag>-Web.zip` with a hosting guide, a Dockerfile builds in CI, three CI jobs guard the web build, the browser suite and a three-browser smoke run against MinIO, and the user and developer docs describe the web app.

**Architecture:** `scripts/build_web.sh` becomes the one entry for a web build: fetch `sqlite3.wasm` by pinned hash, compile the two workers, `flutter build web --release --pwa-strategy=none`, copy the hosting files, and check the bundle. `ci.yaml` gains `web-build`, `web-tests` and `web-smoke` jobs, all added to the success gate. `build-all.yml` gains `build-web`, whose zip flows through `release.yml` like every other `Submersion-*` asset. Docs add a user page, a developer page and the hosting guide shipped inside the zip.

**Tech Stack:** GitHub Actions (`ubuntu-latest`, `services:` for MinIO), `flutter test --platform chrome`, Python 3 Playwright (`chromium`, `firefox`, `webkit`), `python3 -m http.server` subclass for COOP/COEP headers, nginx in `nginx:alpine` for the Dockerfile, `docsify` user docs conventions checked by `scripts/check_docs_links.py`.

**Spec:** `docs/design/specs/2026-11-02-web-app-design.md` (sections "Hosting bundle", "Testing", "Security", "Persistence" for the headers).

## Global Constraints

- Everything in Plan 1's Global Constraints.
- Every new CI job is listed in `ci-success.needs` (`scripts/check_ci_success_gate.py` fails otherwise) and uses `./.github/actions/setup-flutter` (`scripts/check_flutter_setup_retried.py` fails on a direct `subosito` call).
- Browser and smoke jobs assert that no test was skipped and that at least one ran (`scripts/check_no_skipped_tests.py` for Flutter reports; the smoke runner exits 1 on zero tests).
- New Python check scripts get a `_test.py` and a `coverage run --append` line in the `script-tests` job.
- `.github/flutter-version.txt` is the only Flutter version source.
- `docs/user/` stays flat; every new page is linked from `_sidebar.md`; `scripts/check_docs_links.py` passes.
- Nothing is verified with a local container; the Dockerfile builds in CI.
- No container image is published in this release.

## Review Focus

1. A stale service worker serving last release's bundle after a self-hoster updates the files. Task 1 builds with `--pwa-strategy=none` and `check_web_bundle.py` fails if `flutter_service_worker.js` is present.
2. A host that cannot set COOP/COEP (GitHub Pages) and a user who reads the guide as "required". Task 2's `HOSTING.md` says the headers are recommended, lists the storage path used without them, and Task 7's user page repeats it.
3. The release validation's hard-coded asset list missing the zip so a tag "succeeds" without it. Task 5 adds `Web.zip` to `release.yml`'s `EXPECTED` and `promote.yml`'s loop, and the test for `check_release_assets` (if one exists) or a `grep` step in the workflow asserts the entry.
4. The smoke job passing because Flutter never rendered and Playwright found nothing to assert. Task 4's runner waits for the Flutter semantics root and fails after 60 s; each browser must reach the dive list with five dives.
5. `bundle_tests.py` picking `test/web/` files into a VM shard where `@TestOn('browser')` skips them silently. Task 3 adds `--exclude-dir` and a unit test, and the shard step passes `--exclude-dir test/web`.

---

### Task 1: The build script and bundle check

**Files:**
- Create: `web_hosting/_headers` (Cloudflare Pages and Netlify: `/*` with `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: credentialless`), `web_hosting/nginx.conf` (a `server` block serving `/usr/share/nginx/html`, the two headers, `try_files $uri /index.html`, `application/wasm` type), `web_hosting/Caddyfile` (`header` directive with the two headers, `file_server`), `web_hosting/Dockerfile` (`FROM nginx:alpine`, copies `nginx.conf` and the bundle), `web_hosting/HOSTING.md` (Task 2)
- Modify: `scripts/build_web.sh`: `set -euo pipefail`; `scripts/web/fetch_sqlite3_wasm.sh`; `scripts/web/compile_workers.sh`; `flutter build web --release --pwa-strategy=none "$@"`; `cp web_hosting/{_headers,nginx.conf,Caddyfile,Dockerfile,HOSTING.md} build/web/`; `python3 scripts/check_web_bundle.py build/web`
- Create: `scripts/check_web_bundle.py` (asserts present: `index.html`, `flutter_bootstrap.js`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js`, `compute_worker.js`, `version.json`, `_headers`, `nginx.conf`, `Caddyfile`, `Dockerfile`, `HOSTING.md`; asserts absent: `flutter_service_worker.js`, any `*.dart.js.map`; asserts `sqlite3.wasm` sha256 equals the lock) and `scripts/check_web_bundle_test.py`
- Modify: `web/index.html` (title `Submersion`, description, `apple-mobile-web-app-title`), `web/manifest.json` (name `Submersion`, short name `Submersion`, `orientation: any`)
- Modify: `.github/workflows/ci.yaml` `script-tests` job: add `check_web_bundle.py` and `check_sqlite3_wasm_lock.py` to `guards=` and their coverage lines

- [ ] **Step 1: Write `check_web_bundle_test.py`** (a temp dir with all required files passes; missing `drift_worker.js` fails; a present `flutter_service_worker.js` fails; a wrong wasm hash fails)
- [ ] **Step 2: Implement the check, the hosting files and the script; run** `scripts/build_web.sh` **locally; expected: exit 0 and `build/web/` passes the check**
- [ ] **Step 3: Commit** `build(web): one build script with hosting files and a bundle check`

---

### Task 2: Hosting guide

**Files:**
- Create: `web_hosting/HOSTING.md`: what the zip is; the HTTPS requirement; the two headers, what they buy (fastest storage) and that the app works without them on a slower path shown in Settings; `credentialless` rather than `require-corp` so map tiles and remote photos load, and when to switch; per-host sections for a plain folder behind nginx, Caddy, Cloudflare Pages, Netlify, GitHub Pages (no headers possible, still works), an S3 website bucket (no headers, still works); the Dockerfile usage (`docker build -t submersion-web .` from the bundle folder, `docker run -p 8080:80`); the CORS section pointing to the user guide's per-store rules with the origin placeholder; the security notes from the spec (credentials in the browser, database not encrypted at rest, Forget this device); updating: replace the files, no caches to clear because there is no service worker
- Test: `scripts/check_docs_links.py` (the guide lives outside `docs/`, so links into `docs/user/web-app.md` must be absolute GitHub URLs; the check only validates `docs/` references)

- [ ] **Step 1: Write the guide, run** `python3.14 scripts/check_docs_links.py`
- [ ] **Step 2: Commit** `docs(web): hosting guide shipped inside the web bundle`

---

### Task 3: CI job 1 and 2: web build guard and the browser suite

**Files:**
- Modify: `scripts/bundle_tests.py` gains `--exclude-dir PATH` (repeatable; `discover()` skips files under it) and `scripts/bundle_tests_test.py` gains a case
- Modify: `.github/workflows/ci.yaml`:
  - `test` job's "Run tests" step passes `--exclude-dir test/web`
  - new job `web-build` (`needs: [changes, codegen]`, `if: needs.changes.outputs.code == 'true'`, `ubuntu-latest`, 30 min): checkout with submodules, read Flutter version, `setup-flutter`, pub cache, `flutter pub get`, download and unpack `generated-code`, `scripts/build_web.sh`, `docker build -f build/web/Dockerfile build/web` (no push), upload artifact `web-bundle` from `build/web`, 5 days retention
  - new job `web-tests` (same needs, `ubuntu-latest`, 30 min) with `services:` `minio` (`minio/minio:latest`, `server /data`, ports `9000:9000`, env `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD`, `MINIO_API_CORS_ALLOW_ORIGIN: "*"`) and `minio-nocors` (same image on `9001:9000`, `MINIO_API_CORS_ALLOW_ORIGIN: https://example.invalid`); steps: Flutter setup as above, `scripts/web/fetch_sqlite3_wasm.sh`, `scripts/web/compile_workers.sh`, create the bucket with `mc` (download the `mc` binary, `mc alias set`, `mc mb`), `dart run tool/seed_sync_library.dart --endpoint http://localhost:9000 --bucket submersion-test --prefix ci --access-key ... --secret-key ...`, then `flutter test --platform chrome test/web --file-reporter "json:web-report.json" --dart-define=MINIO_ENDPOINT=http://localhost:9000 --dart-define=MINIO_NOCORS_ENDPOINT=http://localhost:9001 --dart-define=MINIO_BUCKET=submersion-test --dart-define=MINIO_ACCESS_KEY=... --dart-define=MINIO_SECRET_KEY=...`, then `python3 scripts/check_no_skipped_tests.py web-report.json`
  - both jobs added to `ci-success.needs`
- Create: `test/web/sync/cors_diagnoser_browser_test.dart` (browser: a `testConnection` against `MINIO_NOCORS_ENDPOINT` fails and `diagnose(...)` returns `blockedByCors`; against `MINIO_ENDPOINT` succeeds), which proves the failure shape the VM tests assume
- Test: `scripts/bundle_tests_test.py`; `python3.14 scripts/check_ci_success_gate.py`; `python3.14 scripts/check_flutter_setup_retried.py`

- [ ] **Step 1: Write the `--exclude-dir` test, implement**
- [ ] **Step 2: Write the browser diagnoser test**
- [ ] **Step 3: Add the two jobs; run the two gate scripts locally; push the branch and read both jobs' logs**
- [ ] **Step 4: Commit** `ci(web): build guard and browser suite against MinIO`

---

### Task 4: CI job 3: three-browser smoke with Playwright

**Files:**
- Modify: `lib/core/bootstrap/app_bootstrap_web.dart`: when `Uri.base.queryParameters['a11y'] == '1'`, call `SemanticsBinding.instance.ensureSemantics()` after `runApp` so the Flutter semantics tree is present for Playwright
- Create: `scripts/web/serve_bundle.py` (`http.server` subclass serving a directory with the two headers and `application/wasm`; args `--dir`, `--port`)
- Create: `scripts/web/smoke_test.py` (pytest, Playwright sync API; parametrised over `chromium`, `firefox`, `webkit`): open `http://localhost:8080/?a11y=1`, wait up to 60 s for `[role=application]` or the `flt-semantics-host` element, click the "My own server" tile by accessible name, fill the S3 fields from env, click Check connection, click Download, wait for the dive list to show five dive rows, open the first dive, edit the notes field, save, click Sync, then assert with `boto3` (or `mc ls`) that an object matching `ci/ssv1.*.cs.*.json` whose device id is not `seed-device` appeared; teardown deletes the browser's objects so the next browser starts clean
- Create: `scripts/web/requirements-smoke.txt` (`playwright`, `pytest`, `boto3` pinned)
- Modify: `.github/workflows/ci.yaml`: job `web-smoke` (`needs: [web-build]`, `ubuntu-latest`, 40 min, the same two MinIO services as `web-tests` minus `nocors`): download `web-bundle`, `pip install -r scripts/web/requirements-smoke.txt`, `python -m playwright install --with-deps chromium firefox webkit`, seed the bucket (Dart tool, so the job also sets up Flutter), start `serve_bundle.py` in the background, `python -m pytest scripts/web/smoke_test.py -v --junitxml=smoke.xml`, fail if the junit file has zero tests; add to `ci-success.needs`
- Test: `scripts/web/smoke_test.py` is the test; `scripts/web/serve_bundle_test.py` (headers present on a served file)

- [ ] **Step 1: Write `serve_bundle_test.py`, implement the server**
- [ ] **Step 2: Add the semantics switch, write the smoke test; run it locally against a local MinIO if available, else against `web-tests`'s services by pushing**
- [ ] **Step 3: Add the job; run `check_ci_success_gate.py`; push and read the three browsers' results**
- [ ] **Step 4: Commit** `ci(web): Playwright smoke in Chromium, Firefox and WebKit`

---

### Task 5: Release pipeline

**Files:**
- Modify: `.github/workflows/build-all.yml`: job `build-web` (`ubuntu-latest`, 30 min): checkout with submodules and `ref`, read Flutter version, setup, pub cache (`pub-build-all-*` key), `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs` (with the swap step the Linux job uses), "Override build number" (same perl line), `scripts/build_web.sh`, then `cd build/web && zip -r "$GITHUB_WORKSPACE/Submersion-${TAG_NAME}-Web.zip" .`, upload artifact `web-bundle` with `Submersion-*-Web.zip`, 5 days
- Modify: `.github/workflows/release.yml` `validate-release` `EXPECTED` list adds `Web.zip`
- Modify: `.github/workflows/promote.yml` validation loop adds `Web.zip`
- (`beta.yml` needs no change: it uploads `artifacts/Submersion*`.)
- Modify: `docs/releases/` is not touched (notes are written at release time); `scripts/release/generate_changelog.sh` is checked to confirm it does not enumerate assets
- Test: `python3.14 scripts/check_flutter_setup_retried.py`; a `workflow_dispatch` of `build-all.yml` on the branch with a throwaway `version-tag` to see the zip appear as an artifact

- [ ] **Step 1: Add the job and the two list entries; run the setup-retry check**
- [ ] **Step 2: Dispatch `build-all.yml` on this branch; confirm `web-bundle` holds `Submersion-vX-Web.zip` and the zip's `HOSTING.md` opens**
- [ ] **Step 3: Commit** `ci(release): attach the web bundle to every release`

---

### Task 6: Developer documentation

**Files:**
- Create: `docs/developer/web.md`: how the web build works (the facade pattern, `_io`/`_web`, `HostPlatform`, `DeviceCapabilities`), the two workers and why they are pure Dart, the guards and what each bans, `scripts/build_web.sh`, `flutter run -d chrome`, `flutter test --platform chrome test/web` with the asset copy, how to run MinIO locally for the round-trip test, the smoke runner, and the rule that a feature gate reads `deviceCapabilitiesProvider`
- Modify: `docs/developer/README.md` (or its index file) links the page; `docs/contributing/pull-requests.md` adds `web/`, `web_hosting/` and `lib/core/platform/` to the UI-change paths note where relevant
- Test: `python3.14 scripts/check_docs_links.py`

- [ ] **Step 1: Write, link, run the check, commit** `docs(web): developer guide for the web build`

---

### Task 7: User documentation

**Files:**
- Create: `docs/user/web-app.md`: what the web app is and who it is for; what works and what does not (the spec's three groups in user words); opening it (the hosted address is a follow-up, so this release says "the address your self-hosted copy is served from"); connecting each store with the CORS rule for AWS, R2, B2, MinIO, Nextcloud and plain WebDAV (templates with `https://your-site` as the origin); Dropbox; Google Drive with the client id walkthrough (Google Cloud project, OAuth client of type Web application, authorised JavaScript origin, no secret) and the sign-in-each-visit behaviour; encrypted libraries and the passphrase; "Remember on this device"; where the data lives in the browser, the storage row in Settings and what "slower storage" means; "Forget this device"; browser support (Chromium, Firefox, Safari); media in the browser; downloads and the backup copy
- Modify: `docs/user/_sidebar.md` adds `web-app.md` under **Setup & Data**; `docs/user/installation.md` adds an "In a web browser" H2 pointing to the page; `docs/user/README.md` platform list adds "and any modern web browser"; `docs/user/encrypted-sync.md` gains a short "In a browser" note; `docs/contributing/roadmap.md` moves Web from v2.0 to this release
- Test: `python3.14 scripts/check_docs_links.py`; `flutter test test/docs` if a docs test folder exists

- [ ] **Step 1: Write, link, run the check, commit** `docs(web): user guide for the web app`

---

### Task 8: Whole-branch verification and hand-off to the owner

- [ ] **Step 1:** `dart format .` then `git diff --stat` shows no formatting changes
- [ ] **Step 2:** `flutter analyze` on the whole repo, clean
- [ ] **Step 3:** `flutter test test/architecture test/shared` then `./scripts/run_all_tests.sh`, all green; `scripts/web/compile_workers.sh && flutter test --platform chrome test/web`, green
- [ ] **Step 4:** `scripts/build_web.sh`, exit 0
- [ ] **Step 5:** Rebase on `origin/main`, repeat steps 2 and 3 after the rebase
- [ ] **Step 6:** Hand to the owner: serve `build/web` with `scripts/web/serve_bundle.py --dir build/web --port 8080`, and ask them to connect to their own S3 store (adding the CORS rule the diagnoser prints), confirm their dives appear, edit one, and see the edit on their phone or Mac; then repeat with Dropbox, Google Drive (their own web client id) and WebDAV as they have them. Record the results in the PR description.

---

## Self-review notes

- Spec coverage: bundle and headers (1, 2), build guard and browser suite with MinIO including the diagnoser proof (3), three-browser smoke (4), release assets (5), developer and user docs including the Google walkthrough and the storage note (6, 7), owner verification (8).
- Review Focus coverage: 1 Task 1, 2 Tasks 2 and 7, 3 Task 5, 4 Task 4, 5 Task 3.
- Follow-ups recorded in the spec and not planned here: hosted copy under submersion.app, shareable links, Git on the web, published container image, demo mode on the web, SQLite imports on the web, a read-only mode.
