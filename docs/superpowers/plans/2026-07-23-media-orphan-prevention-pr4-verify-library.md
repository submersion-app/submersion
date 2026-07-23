# Media Orphan Prevention PR 4: Verify Library Sweep Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A reconciliation sweep ("Verify library") that lists the store's
three namespaces, deletes unreferenced blobs behind a 7-day grace window,
reaps stranded S3 multipart sessions, reverse-repairs missing objects, and
runs both manually (settings action) and opportunistically (fleet-wide
30-day cadence via a synced timestamp) — closing the orphan-prevention
program.

**Architecture:** PR 4 of 4 from
`docs/superpowers/specs/2026-07-23-media-store-orphan-prevention-design.md`
(section 6). New `MediaVerifyService` orchestrates: referenced-hash set from
the media table vs `MediaObjectStore.list()` (implemented by all four
adapters, previously uncalled), plus a new `reapStaleUploadSessions` store
member (S3 real via new `S3ApiClient.listMultipartUploads`; others no-op)
and reverse repair through existing stamp-clear methods + `enqueueUpload`.
Fleet cadence rides `media_stores.last_sweep_at` — the program's only
main-DB schema change (nominally **v136**; re-verify the ladder at
execution).

**Tech Stack:** Flutter/Dart, Drift, Riverpod, package:xml (S3),
`InMemoryMediaObjectStore`, `FakeS3Server`.

## Global Constraints

- Branch `worktree-media-orphan-pr4` FROM `worktree-media-orphan-pr3`
  (needs the coordinator, queue delete direction, and repo helpers).
  PR base = `worktree-media-orphan-pr3`; merge bottom-up
  (#697 -> #702 -> #704 -> this). Worktree init: submodules, pub get,
  build_runner; verify the libdivecomputer gitlink matches origin/main.
- Schema: grep `currentSchemaVersion = ` on the branch AND current
  origin/main before claiming the version; the ladder note says v136 but
  v135 (color accents) may have merged — claim the next free number and
  update the exact-latest tripwire convention (new test owns `== N`, relax
  the previous owner to `greaterThanOrEqualTo`).
- l10n: new keys in ALL 11 arb locales + `flutter gen-l10n` (generated
  files are tracked).
- `dart format .` clean; `flutter analyze` clean. No emojis.
- PR description: substantive summary only; no attribution/session links.

---

### Task 1: `S3ApiClient.listMultipartUploads` + fake server support

**Files:**
- Modify: `lib/core/services/cloud_storage/s3/s3_api_client.dart`
- Modify: `test/helpers/fake_s3_server.dart`
- Test: `test/core/services/cloud_storage/s3/s3_multipart_test.dart` (append)

**Interfaces:**
- Produces:

```dart
class S3MultipartUploadInfo {
  final String key; // wire key (includes any configured prefix)
  final String uploadId;
  final DateTime initiated;
  const S3MultipartUploadInfo({
    required this.key,
    required this.uploadId,
    required this.initiated,
  });
}

Future<List<S3MultipartUploadInfo>> listMultipartUploads({String prefix = ''});
```

- [ ] **Step 1: Fake server support.** In `fake_s3_server.dart`: record an
  `initiated` timestamp per session (extend `_sessions` to a small record
  holding parts + key + initiated; the abort/complete/part handlers index
  the same way). Add a settable `DateTime Function() now` field
  (default `DateTime.now`) so tests control `initiated`. Handle
  `GET` with `qp.containsKey('uploads')` (no `uploadId`): respond with
  `ListMultipartUploadsResult` XML listing each live session as
  `<Upload><Key>...</Key><UploadId>...</UploadId><Initiated>ISO8601</Initiated></Upload>`,
  `IsTruncated` false. Place the branch BEFORE the generic
  `list-type` / object-GET handling.

- [ ] **Step 2: Failing test** (append to `s3_multipart_test.dart`,
  mirroring its client construction):

```dart
test('listMultipartUploads returns live sessions with initiated times',
    () async {
  // start two multipart sessions via createMultipartUpload, complete one
  final keep = await client.createMultipartUpload('smv1/objects/aa/a.mp4',
      contentType: 'video/mp4');
  final done = await client.createMultipartUpload('smv1/objects/bb/b.mp4',
      contentType: 'video/mp4');
  final etag = await client.uploadPart('smv1/objects/bb/b.mp4',
      uploadId: done, partNumber: 1, bytes: Uint8List.fromList([1]));
  await client.completeMultipartUpload('smv1/objects/bb/b.mp4',
      uploadId: done, parts: [S3PartInfo(partNumber: 1, etag: etag)]);

  final uploads = await client.listMultipartUploads();
  expect(uploads.map((u) => u.uploadId), [keep]);
  expect(uploads.single.key, contains('smv1/objects/aa/a.mp4'));
});
```

- [ ] **Step 3: Implement** `listMultipartUploads`: GET with query
  `uploads` (empty value) + optional `prefix`, parse with the file's
  existing `XmlDocument` idiom (mirror `_parseListPage`): iterate
  `findAllElements('Upload')`, read `Key`/`UploadId`/`Initiated`
  (`DateTime.parse`). Follow `IsTruncated` with `key-marker` /
  `upload-id-marker` continuation the same way `listObjects` loops its
  token (the fake always returns one page).

- [ ] **Step 4: Run** `flutter test test/core/services/cloud_storage/s3/` —
  PASS. Commit:

```bash
git add lib/core/services/cloud_storage/s3/s3_api_client.dart test/helpers/fake_s3_server.dart test/core/services/cloud_storage/s3/s3_multipart_test.dart
git commit -m "feat(s3): list in-progress multipart uploads"
```

---

### Task 2: `MediaObjectStore.reapStaleUploadSessions`

**Files:**
- Modify: `lib/core/services/media_store/media_object_store.dart` (interface)
- Modify: all five implementors (S3 real; Dropbox/Drive/iCloud no-op
  returning 0 — their sessions self-expire; `InMemoryMediaObjectStore`
  gains a settable `staleSessionCount` the fake returns then zeroes)
- Test: `test/core/services/media_store/s3_media_object_store_abort_test.dart` (append)

**Interfaces:**
- Produces:

```dart
  /// Aborts provider-side resumable upload sessions started before
  /// [olderThan]; returns how many were aborted. Grace-windowed so a
  /// session another device is actively resuming is never reaped.
  /// Providers whose sessions self-expire return 0.
  Future<int> reapStaleUploadSessions({required DateTime olderThan});
```

- [ ] **Step 1: Failing test** (append; uses Task 1's fake-server `now`
  seam to make one session old and one fresh):

```dart
test('reapStaleUploadSessions aborts only sessions older than the cutoff',
    () async {
  server.now = () => DateTime.utc(2026, 7, 1);
  final store = build();
  await store.putFileStartMultipartForTest(); // or start via client directly
  server.now = () => DateTime.utc(2026, 7, 20);
  // second, fresh session via the client
  // reap with olderThan 2026-07-10 -> exactly one aborted
  final n = await store.reapStaleUploadSessions(
    olderThan: DateTime.utc(2026, 7, 10),
  );
  expect(n, 1);
  expect(server.activeMultipartUploadCount, 1);
});
```

(Start both sessions via `S3ApiClient.createMultipartUpload` directly —
no store-level helper needed; drop the placeholder line above.)

- [ ] **Step 2: Implement.** S3: `listMultipartUploads()` filtered to
  `initiated.isBefore(olderThan)` AND keys under `_keyPrefix` +
  `StoreKeys`' `smv1/` root, each aborted via `_abortQuietly`; count
  successes. Others + fake: trivial per the interface note.

- [ ] **Step 3: Run** the abort test file + `flutter analyze` — PASS.
  Commit `feat(media-store): reap stale multipart upload sessions`.

---

### Task 3: MediaRepository verify helpers

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart`
- Test: `test/features/media/data/media_repository_cascade_test.dart` (append)

**Interfaces:**
- Produces:
  - `Future<Set<String>> getAllContentHashes()` — every non-null
    `content_hash` (uploaded or not; the sweep's conservative referenced
    set, same rule as `countRowsWithHash`).
  - `Future<List<({String id, String contentHash, bool hasOriginal, bool hasThumb, bool hasRendition})>> getRemoteStampedSummaries()`
    — rows with a hash and at least one remote stamp, for reverse repair.
  - `Future<void> clearRemoteThumbUploaded(String mediaId)` — mirrors
    `clearRemoteUploaded` (line ~1070) for the thumb stamp.

- [ ] **Step 1: Failing tests** (three compact cases mirroring the file's
  existing fixtures: hashes set collects distinct hashes; summaries
  reports the right booleans per stamp combination; thumb clear nulls
  only the thumb stamp and HLC-stamps the row).
- [ ] **Step 2: Implement** (each mirrors an existing sibling:
  `getAllContentHashes` via `selectOnly` + `isNotNull`, summaries via a
  `select` filtered `contentHash.isNotNull() & (remoteUploadedAt.isNotNull() | remoteThumbUploadedAt.isNotNull() | remoteCompressedUploadedAt.isNotNull())`,
  clear mirrors `clearRemoteUploaded` with the thumb column).
- [ ] **Step 3: Run + commit** `feat(media): verify-sweep repository helpers`.

---

### Task 4: `MediaVerifyService`

**Files:**
- Create: `lib/features/media_store/data/media_verify_service.dart`
- Test: `test/features/media_store/media_verify_service_test.dart` (new)

**Interfaces:**
- Consumes: `MediaObjectStore.list/delete/reapStaleUploadSessions`,
  Task 3 helpers, `MediaTransferQueueRepository.enqueueUpload`,
  `StoreKeys` prefixes.
- Produces:

```dart
class VerifyLibraryReport {
  final int objectsChecked;
  final int orphansRemoved;
  final int bytesReclaimed;
  final int sessionsAborted;
  final int repairsQueued;
  const VerifyLibraryReport({...});
}

class MediaVerifyService {
  MediaVerifyService({
    required MediaObjectStore store,
    required MediaRepository mediaRepository,
    required MediaTransferQueueRepository queue,
    DateTime Function() now = DateTime.now,
  });
  static const graceWindow = Duration(days: 7);
  static const staleSessionAge = Duration(days: 7);
  Future<VerifyLibraryReport> run({void Function(int objectsChecked)? onProgress});
}
```

- [ ] **Step 1: Failing tests** over `InMemoryMediaObjectStore` +
  in-memory DBs. Namespace prefixes: derive from `StoreKeys` (`smv1/objects/`,
  `smv1/thumbs/`, `smv1/renditions/`); hash = filename segment before the
  extension. Cases:
  1. Unreferenced old object (set `store.modified[key]` 30 days back) in
     each namespace is deleted; `bytesReclaimed` sums sizes; referenced
     objects and `smv1/store.json` survive.
  2. Unreferenced YOUNG object (modified now) survives (grace window).
  3. Reverse repair: row stamped `remoteUploadedAt` whose original object
     is absent -> `clearRemoteUploaded` observed (stamp null afterwards),
     `enqueueUpload` row appears, `repairsQueued == 1`. Thumb-stamp and
     rendition-stamp variants clear their own stamps.
  4. `sessionsAborted` passes through the fake's `staleSessionCount`.
  5. Report totals: `objectsChecked` equals listed object count across
     namespaces; `onProgress` fires monotonically.

- [ ] **Step 2: Implement.** Single pass per namespace: stream `list()`,
  count, collect per-tier present-hash sets, delete
  unreferenced-and-older-than-grace objects. Then reverse repair from
  `getRemoteStampedSummaries()` vs the present sets (clear the specific
  stale stamp; one `enqueueUpload` per repaired row — its idempotency
  collapses duplicates). Then `reapStaleUploadSessions`. Every delete via
  a best-effort wrapper (a single failed delete must not abort the run);
  malformed keys (no parseable hash) are counted but never deleted.

- [ ] **Step 3: Run + commit** `feat(media-store): verify library sweep service`.

---

### Task 5: `media_stores.last_sweep_at` (schema vNEXT) + fleet stamp

**Files:**
- Modify: `lib/core/database/database.dart` (column, `currentSchemaVersion`,
  onUpgrade block, beforeOpen backstop — mirror the v130
  `_assertMediaStoreSchema` idempotent-assert idiom)
- Modify: `lib/features/media_store/data/media_stores_repository.dart`
  (`Future<void> stampLastSweep(String storeId, DateTime at)` —
  HLC-stamped via `markRecordPending` like `upsertActive`)
- Test: `test/core/database/migration_vNEXT_media_stores_sweep_test.dart`
  (new; owns the exact-latest tripwire) + repository test append

- [ ] **Step 1:** Grep `currentSchemaVersion = ` on branch and origin/main;
  pick the next free number N (nominally 136). Failing migration test:
  old-version fixture upgrades and gains `last_sweep_at`; fresh DB has it;
  `currentSchemaVersion == N` exact; relax the previous exact-latest
  tripwire to `greaterThanOrEqualTo`.
- [ ] **Step 2:** Implement column (`IntColumn get lastSweepAt => integer().nullable()();`),
  guarded migration + backstop, run build_runner, verify sync export
  carries the new column automatically (whole-row `toJson`; check the
  media_stores serializer arm and its record-ids guard test).
- [ ] **Step 3:** `stampLastSweep` + test. Run migration + sync guard
  suites. Commit `feat(media-store): fleet-wide verify sweep timestamp (schema vN)`.

---

### Task 6: Settings UI — manual Verify Library action + l10n

**Files:**
- Modify: `lib/features/media_store/presentation/pages/media_storage_page.dart`
  (action beside the backfill button, ~line 685)
- Modify: all 11 arb files + `flutter gen-l10n`
- Test: `test/features/media_store/media_storage_page_test.dart` (append)

- [ ] **Step 1: l10n keys** (translate to all 11 locales in the same pass,
  beside the `settings_mediaStorage_backfill_*` keys):
  - `settings_mediaStorage_verify_action`: "Verify library"
  - `settings_mediaStorage_verify_running`: "Verifying media library..."
  - `settings_mediaStorage_verify_summary` (placeholders checked/removed/repaired/aborted):
    "Checked {checked} objects: removed {removed} orphans, queued {repaired} repairs, aborted {aborted} stale uploads"
    (use the `@` placeholder metadata idiom of `settings_mediaStorage_backfill_enqueued`).
- [ ] **Step 2: Failing widget test**: connected-state page shows the
  button; tapping runs an injected fake verify runner and surfaces the
  summary text (mirror the page test's existing service-injection
  pattern; inject a `Future<VerifyLibraryReport> Function()?` seam via
  provider or widget param per that pattern).
- [ ] **Step 3: Implement**: `FilledButton.tonal` gated on a connected
  runtime; while running show the running label (disabled button +
  linear progress mirroring the backfill row); on completion stamp
  `MediaStoresRepository.stampLastSweep` and show the summary in a
  SnackBar. On error: existing error-snackbar idiom of the page.
- [ ] **Step 4: Run page tests + commit**
  `feat(media-store): manual Verify Library action`.

---

### Task 7: Opportunistic auto-run

**Files:**
- Create: pure helper in `media_verify_service.dart`:
  `bool shouldAutoVerify({required DateTime? lastSweepAt, required NetworkKind network, required DateTime now})`
  — true iff network is `NetworkKind.unmetered` AND (`lastSweepAt` null or
  older than 30 days).
- Modify: `lib/features/media_store/presentation/providers/media_store_providers.dart`
  — in the runtime provider, after the initial `worker.drain()` kick:
  read the active descriptor's `lastSweepAt`, and when `shouldAutoVerify`,
  `unawaited` run + `stampLastSweep` on success, all inside try/catch with
  a log line (an auto-sweep failure must never break the runtime).
- Test: unit tests for `shouldAutoVerify` (4 cases: never swept, stale,
  fresh, cellular); runtime wiring covered by an integration-style test
  ONLY if the existing runtime provider tests make it cheap — otherwise
  rely on the pure-function tests + manual smoke, noting it in the PR.

- [ ] Steps: failing tests -> implement -> run media_store suites ->
  commit `feat(media-store): opportunistic 30-day verify sweep`.

---

### Task 8: Verification + PR

- [ ] `dart format .`; `flutter analyze`; targeted suites
  (`test/features/media test/features/media_store test/core`); full
  `flutter test` (isolate-verify known backup flakes before
  `--no-verify`).
- [ ] Push `worktree-media-orphan-pr4`; PR base `worktree-media-orphan-pr3`,
  title "feat(media-store): Verify Library sweep". Body: sweep algorithm
  (grace window, reverse repair, multipart reap), fleet cadence via the
  synced timestamp (schema vN), manual + opportunistic triggers, and the
  program-completion note (all four orphan classes now covered). No
  attribution/session links.

---

## Not in this PR

- Data Quality rule surfacing orphan candidates (superseded by the silent
  sweep decision).
- Bucket lifecycle-rule provisioning (spec section 10 out-of-scope).
- MinIO / live-provider manual smoke (tracked as program follow-up).
