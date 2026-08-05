# divelogs.de Sync — Phase 4 (Dive Pictures) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sync dive photos with divelogs.de for matched dives — pull remote pictures into a dive's local media (deduped by SHA-256 content hash), push local photos for dives that have no remote pictures yet.

**Architecture:** The dive sync planner starts reporting matched remote↔local pairs. A `DivelogsPhotoSyncService` (function-injected dependencies, fully unit-testable) walks each pair: downloads remote pictures with usable URLs, hashes them, attaches new ones via the existing `MediaImportService.importLocalFileForDive` path, and pushes local photos via multipart `POST /pictures/{dive_id}` — but only for dives with zero remote pictures (the create-only duplicate guard, since remote content hashes don't exist). The sync page gains a Photos section.

**Tech Stack:** Same as Phases 1–3 plus `package:crypto` (`sha256`, already a dependency via `store_keys.dart`). No schema migration.

**Spec:** `docs/superpowers/specs/2026-07-16-divelogs-de-sync-design.md` (Phase 4).

## Global Constraints

- Same as Phases 1–3 (metric, wall-clock UTC, format/analyze clean, no emojis, no attribution, l10n all 11 locales + `flutter gen-l10n`, per-file tests, `--no-verify` push, backup-test full-suite flake protocol).
- API (verified from OpenAPI): `GET /pictures/{dive_id}` (response shape UNDOCUMENTED), `POST /pictures/{dive_id}` multipart with required binary field `imagefile`, `DELETE /pictures/{picture_id}` (never used — create-only).
- Picture download URLs are unconfirmed: parse each picture row tolerantly; rows whose URL cannot be resolved to an absolute http(s) URI are counted and surfaced as "skipped", never fetched by guessed paths.
- Create-only, both directions. Pull dedup: SHA-256 of downloaded bytes vs hashes of the dive's existing local photos (computed on the fly — there is no DB hash lookup). Push guard: only for matched dives whose remote picture list is EMPTY (remote hashes don't exist, so count-zero is the only safe duplicate guard).
- **Certification scans are OUT of scope** (deliberate deviation from the spec's "pictures" phase breadth): their download URL scheme is undocumented and the API only accepts scans at certification creation. Revisit when Rainer answers open question 9; record this in the code comment on the photo service.
- Photos sync only from the sync page, after a compare (pairs come from the compare); the import wizard flow is untouched.
- One-button flow over all matched pairs (no per-dive photo checkboxes) — the same deliberate simplification as gear/certs: the count-zero push guard and hash-dedup pull make the operation safe to run wholesale, and per-dive selection can be added on user feedback. The spec's "dives the user selects" is satisfied at the coarser granularity of the explicit button press.

---

### Task 1: Picture model + API endpoints

**Files:**
- Modify: `lib/core/services/divelogs/divelogs_models.dart`
- Modify: `lib/core/services/divelogs/divelogs_api_client.dart`
- Test: extend `divelogs_models_test.dart` and `divelogs_api_client_test.dart`

**Interfaces:**
- Produces:
  - `class DivelogsPicture { final String? id; final Uri? url; static DivelogsPicture? fromJson(Map<String, dynamic>); }` — `url` is the first of `url`/`link`/`href`/`imageurl` that parses as an absolute http(s) URI (`Uri.tryParse` + `isScheme('http')||isScheme('https')`); a bare filename yields `url == null` (row kept, counted as unusable by callers); a row with neither id nor any recognized key yields null.
  - On the client:
    - `Future<List<DivelogsPicture>> getPictures(String diveId)` — GET `/pictures/$diveId` via `_get`, rows via `_rows(decoded, '/pictures', const ['pictures'])`, null models skipped.
    - `Future<Uint8List> downloadPictureBytes(Uri url)` — plain authorized GET via `_http.get(url, headers: {'Authorization': 'Bearer $token'})` with the standard 401-invalidate-retry-once loop (absolute URL, so NOT through `_send`'s path builder); non-2xx → `DivelogsApiException`; returns `response.bodyBytes`.
    - `Future<void> postPicture(String diveId, {required List<int> bytes, required String filename})` — multipart POST to `/pictures/$diveId` with `http.MultipartFile.fromBytes('imagefile', bytes, filename: filename)`, request rebuilt per attempt for the 401 retry (same loop as `postCertification`).

- [ ] **Step 1: Write failing tests** — model: url picked from `url` then `link`; bare-filename row keeps id with null url; junk row → null. Client: `getPictures` parses an array and a `{pictures: [...]}` wrapper; `downloadPictureBytes` sends the bearer header to the EXACT absolute URL and returns bytes, retries once on 401; `postPicture` sends multipart with an `imagefile` file part (use the `_CapturingClient` from the existing cert tests — assert `captured.files.single.field == 'imagefile'` and filename) and retries once on 401. Full test code in the established file styles.
- [ ] **Step 2: Run red, implement, run green** — `flutter test test/core/services/divelogs/`.
- [ ] **Step 3: Commit** — `feat: add divelogs.de picture endpoints with tolerant URL parsing`

---

### Task 2: Matched pairs on the dive sync planner

**Files:**
- Modify: `lib/features/divelogs_sync/domain/services/divelogs_sync_planner.dart`
- Test: extend `divelogs_sync_planner_test.dart`

**Interfaces:**
- Produces: `class DivelogsMatchedDive { final String remoteId; final String localDiveId; final DateTime localTime; }` and `DivelogsSyncPlan` gains `final List<DivelogsMatchedDive> matchedPairs;` (populated where `matched++` happens today: `remoteId: entry.id`, `localDiveId: best.id`, `localTime: best.entryTime ?? best.dateTime`). `matchedCount` stays (== `matchedPairs.length`) so existing callers are untouched.

- [ ] **Step 1: Extend a test** — the existing "matched pairs are neither pulled nor pushed" test additionally asserts `plan.matchedPairs.single.remoteId == 'r1'` and `.localDiveId == 'l1'`.
- [ ] **Step 2: Run red, implement, run green** — `flutter test test/features/divelogs_sync/domain/services/divelogs_sync_planner_test.dart`.
- [ ] **Step 3: Commit** — `feat: expose matched remote-local dive pairs from the sync planner`

---

### Task 3: `DivelogsPhotoSyncService`

**Files:**
- Create: `lib/features/divelogs_sync/domain/services/divelogs_photo_sync_service.dart`
- Test: `test/features/divelogs_sync/domain/services/divelogs_photo_sync_service_test.dart`

**Interfaces:**
- Consumes: Task 1 endpoints, Task 2 `DivelogsMatchedDive`, `MediaItem`/`MediaType` (`lib/features/media/domain/entities/media_item.dart`), `sha256` from `package:crypto`.
- Produces:

```dart
class PhotoSyncResult {
  final int pulled;
  final int pulledDuplicates;   // downloaded but hash-matched existing
  final int skippedNoUrl;       // rows without a usable absolute URL
  final int pushed;
  final String? error;          // partial-failure message, stops the run
  bool get failed => error != null;
}

class DivelogsPhotoSyncService {
  DivelogsPhotoSyncService({
    required DivelogsApiClient api,
    required Future<List<MediaItem>> Function(String diveId) getLocalMedia,
    required Future<Uint8List?> Function(MediaItem item) resolveLocalBytes,
    required Future<void> Function({
      required Uint8List bytes,
      required String filename,
      required String diveId,
      required DateTime takenAt,
    }) attachToDive,
  });

  Future<PhotoSyncResult> sync(
    List<DivelogsMatchedDive> pairs, {
    void Function(int done, int total)? onProgress,
  });
}
```

- Function-injected dependencies keep the service free of repository/resolver plumbing (the page wires them in Task 4); `resolveLocalBytes` returns null for unresolvable items (they simply don't contribute a hash and are never pushed).
- Per pair, in order:
  1. `remote = await api.getPictures(pair.remoteId)`; split into `withUrl` / `withoutUrl` (count the latter into `skippedNoUrl`).
  2. `local = await getLocalMedia(pair.localDiveId)` filtered to `mediaType == MediaType.photo`; `localHashes = { sha256 of each resolveLocalBytes(item) that returns non-null }`.
  3. Pull: for each remote picture with a URL — `bytes = await api.downloadPictureBytes(url)`; `hash = sha256.convert(bytes).toString()`; if `localHashes` contains it → `pulledDuplicates++`; else `attachToDive(bytes:, filename: <last URL path segment, fallback 'divelogs_<pictureId>.jpg'>, diveId: pair.localDiveId, takenAt: pair.localTime)`, add the hash to `localHashes`, `pulled++`.
  4. Push: only when `remote.isEmpty` and the dive has local photos — for each local photo whose `resolveLocalBytes` returns bytes: `api.postPicture(pair.remoteId, bytes:, filename: item.originalFilename ?? '<item.id>.jpg')`, `pushed++`.
  5. `onProgress(pairIndex + 1, pairs.length)` after each pair.
- A `DivelogsApiException` anywhere stops the run and returns partial counts with the message (stateless convergence: re-running skips already-pulled photos by hash and already-pictured dives by the count-zero guard).

- [ ] **Step 1: Write the failing test** — fake `api` via `_CapturingClient`-style MockClient serving `/api/pictures/<id>` GET (with `url` fields pointing at a fake host also served by the mock returning distinct bytes) and POST; in-memory `getLocalMedia`/`resolveLocalBytes`/`attachToDive` recording calls. Cases: (a) pull attaches a new photo and reports `pulled == 1`, filename from the URL path; (b) a remote picture whose bytes hash-match an existing local photo is counted in `pulledDuplicates` and not attached; (c) rows without a usable URL count into `skippedNoUrl`; (d) push happens only when the remote list is empty — one pair with remote pictures gets no POST, one pair with zero remote pictures POSTs each resolvable local photo (`pushed` counts, `imagefile` field asserted); (e) a 500 mid-run stops and reports partial counts + error. Full test code in the established style.
- [ ] **Step 2: Run red, implement, run green** — `flutter test test/features/divelogs_sync/`.
- [ ] **Step 3: Commit** — `feat: add create-only divelogs.de photo sync with hash dedup`

---

### Task 4: Sync page Photos section + l10n

**Files:**
- Modify: `lib/features/divelogs_sync/presentation/pages/divelogs_sync_page.dart`
- Modify: `lib/l10n/arb/app_en.arb` + all 10 non-English arb files
- Test: extend `divelogs_sync_page_test.dart`

**Interfaces:**
- Consumes: Tasks 1–3; `mediaRepositoryProvider` + `MediaRepository.getMediaForDive` (`lib/features/media/presentation/providers/media_providers.dart:7`), `mediaImportServiceProvider` + `MediaImportService.importLocalFileForDive` (`lib/features/media/presentation/providers/photo_picker_providers.dart:239`), `MediaSourceResolverRegistry` (`lib/features/media/data/services/media_source_resolver_registry.dart` — check its provider/construction at the import sites and reuse; `resolve` returns the sealed `MediaSourceData`: use `FileData.file.readAsBytes()`, `BytesData.bytes`, null otherwise).
- Page wiring:
  - `_compare` already stores the plan; it now also keeps `_plan!.matchedPairs`.
  - New `_syncPhotos()`: guards on a non-empty `matchedPairs`; builds the service with `attachToDive` writing bytes to a temp file (`Directory.systemTemp.createTemp('divelogs_photo')` → `File('<dir>/<filename>')..writeAsBytes`) then `importLocalFileForDive(sourceFile: file, diveId: diveId, takenAt: takenAt)`; runs with a progress indicator (`_photoSyncDone/_photoSyncTotal`); stores `PhotoSyncResult? _lastPhotoResult`; does NOT re-compare (photos don't change the dive diff).
  - Photos section in `_buildPlan` (after gear/certs): "Photos" header; "Sync photos for {count} matched dives" button (disabled when `matchedPairs` empty or `_syncingPhotos`); result line "Pulled {pulled} photos, pushed {pushed}." plus optional captions for `pulledDuplicates` (already present), `skippedNoUrl`, and the failure message.

New l10n keys (en; translate into all 10 locales with proper diacritics, placeholders typed):

```json
"divelogsSync_photosHeader": "Photos",
"divelogsSync_photosButton": "Sync photos for {count} matched dives",
"divelogsSync_photosSyncing": "Syncing photos with divelogs.de...",
"divelogsSync_photosDone": "Pulled {pulled} photos, pushed {pushed}.",
"divelogsSync_photosDuplicates": "{count} photos were already present (matched by content).",
"divelogsSync_photosNoUrl": "{count} remote pictures had no downloadable link and were skipped.",
"divelogsSync_photosFailed": "Photo sync stopped: {error}"
```

- [ ] **Step 1: Extend the widget test** — MockClient additionally serves `GET /api/pictures/<id>` (empty list) plus one test where a matched pair exists (reuse the compare seeding from the existing matched-dive test), the Photos button shows "Sync photos for 1 matched dives", tapping it calls the pictures endpoint and renders "Pulled 0 photos, pushed 0." (empty both sides keeps the widget test light — service-level behavior is covered by Task 3). Full test in the file's style.
- [ ] **Step 2: Run red, implement page + l10n, `flutter gen-l10n`, run green** — `flutter test test/features/divelogs_sync test/l10n && flutter analyze`.
- [ ] **Step 3: Commit** — `feat: sync dive photos from the divelogs.de sync page`

---

### Task 5: Verification sweep

- [ ] **Step 1:** `dart format . && flutter analyze` — clean.
- [ ] **Step 2:** `flutter test test/core/services/divelogs test/features/divelogs_sync test/features/import_wizard test/features/universal_import/data/services` — all PASS.
- [ ] **Step 3:** Full suite in the background (unmasked exit code); apply the flake protocol from memory `flaky-backup-tests-full-suite` to any backup/setup failure.
- [ ] **Step 4:** Commit fixes if any. Do not push (user-triggered; branch carries PR #603).

## Deferred (do NOT build now)

- Certification scan pull/push (undocumented URLs; creation-only upload — revisit on Rainer's answer to open question 9).
- `DELETE /pictures` (create-only model).
- Video/media-store integration beyond the standard `importLocalFileForDive` path (the media-store upload enqueue fires automatically via `onMediaCreated`).

## Open assumptions (confirm with Rainer, do not block)

- `GET /pictures/{dive_id}` rows carry an absolute image URL under `url`/`link`/`href`/`imageurl` (rows without one are skipped and surfaced).
- Downloading picture bytes accepts the same bearer token.
- `POST /pictures/{dive_id}` accepts JPEG/PNG originals of typical camera size.
