# Media Section Phase 3 (Repair Engine and Wizard) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the multi-source bulk re-link engine — folder scan with prefix-move detection, photo-library rematch, cloud-backed conversion — behind a 3-step wizard on a new Missing console section, with the single-item Replace link rewired through the same engine.

**Architecture:** A pure match core (`buildRepairProposals` + `detectPrefixMove`) consumes candidates from three `CandidateSource`s; a staged apply (per-row I/O, one DB transaction, then queue enqueues) writes results through sync-safe `MediaRepository` ops. Cloud-backed rows become a first-class `MediaSourceType.mediaStore` whose registered resolver wraps the existing store fallback by composition. Spec: `docs/superpowers/specs/2026-08-05-media-section-design.md` section 6.

**Tech Stack:** Flutter 3.x, Drift, Riverpod (barrel), photo_manager (behind a port), file_picker, crypto (via `sha256OfFile` in `lib/core/services/media_store/store_keys.dart`).

## Global Constraints

Identical to the Phase 1/2 plans (worktree-only, `dart format .` no-op before commits, analyze zero issues, no emojis, l10n in en + ar de es fr he hu it nl pt zh with real translations + `flutter gen-l10n`, Riverpod via barrel, `MaterialApp(locale: Locale('en'))` in widget tests, no Drift under FakeAsync, no Co-Authored-By, full suite after `dive_media_section.dart` edits). Key facts locked in during research:

- Hashing: `sha256OfFile(File) → ({String hash, int sizeBytes})` from `store_keys.dart` — the store's content identity; the engine MUST use it, never a second hash implementation.
- Stamps: `MediaRepository.stampContentIdentity(String mediaId, {required String contentHash, required int sizeBytes})`, `clearRemoteUploaded(id)`, `clearRemoteThumbUploaded(id)`, `clearRemoteCompressed(id)`.
- Queue: `MediaTransferQueueRepository.enqueueUpload({required String mediaId})` (idempotent), provider `mediaTransferQueueRepositoryProvider`.
- Store: `mediaStoreResolverProvider` is `Provider<MediaStoreResolver?>` (null = no store configured); `MediaObjectStore.head(String key) → Future<StoreObjectInfo?>`; object keys via `StoreKeys.objectKey(hash, extension: StoreKeys.extensionFor(originalFilename))`.
- Bookmarks: `ref.read(localMediaPlatformProvider).createBookmark(path)` → blob; `ref.read(localBookmarkStorageProvider).write(ref, blob)` (idempotent overwrite) — the `_replaceLink` idiom at dive_media_section.dart:303.
- Volume state: `VolumeStatus.isVolumeOnline(String path)`; `VerifyResult.volumeOffline` never orphans.
- Phase 2 ops available: `convert`-style sync-safe writes via `_unlinkColumns`; `reassignMediaToDive`; `retainInLibrary` on `MediaItem`.
- Only one exhaustive `switch` over `MediaSourceType` exists (`_effectiveOriginDeviceId`, media_repository.dart); the analyzer flags any others when the enum grows — fix every site it reports in Task 1.

---

### Task 1: `MediaSourceType.mediaStore` + registered resolver

**Files:**
- Modify: `lib/features/media/domain/entities/media_source_type.dart`
- Modify: `lib/features/media/data/repositories/media_repository.dart` (`_effectiveOriginDeviceId` gains a `mediaStore` arm returning `null` — cloud-backed rows are device-portable)
- Create: `lib/features/media/data/resolvers/media_store_source_resolver.dart`
- Modify: `lib/features/media/presentation/providers/media_resolver_providers.dart` (registry gains the arm)
- Test: `test/features/media/data/media_store_source_resolver_test.dart`

**Interfaces:**
- Produces: enum value `MediaSourceType.mediaStore` (doc: "Cloud media store is the source of truth; no local pointer."); class `MediaStoreSourceResolver implements MediaSourceResolver` with constructor `MediaStoreSourceResolver({required MediaStoreResolver? Function() storeResolver})` so the registry can hand it the live nullable provider value.

- [ ] **Step 1: Write the failing test**

```dart
// Fake MediaStoreResolver is concrete: build the wrapper around a closure
// that returns null (no store) or a _FakeStoreResolver whose
// tryResolveRemote returns a FileData for a temp file.
test('resolve returns UnavailableData(unauthenticated) with no store', () async {
  final resolver = MediaStoreSourceResolver(storeResolver: () => null);
  final data = await resolver.resolve(item());
  expect(data, isA<UnavailableData>());
  expect((data as UnavailableData).kind, UnavailableKind.unauthenticated);
});
test('resolve delegates to tryResolveRemote(thumbnail: false)', () async {...});
test('verify: available when stamps present and store configured, '
    'transientError when store missing (never orphans cloud rows)', () async {
  expect(
    await MediaStoreSourceResolver(storeResolver: () => null).verify(item()),
    VerifyResult.transientError,
  );
});
```

`_FakeStoreResolver` extends `MediaStoreResolver`? It has required constructor deps — instead declare the wrapper's dependency as `Future<MediaSourceData?> Function(MediaItem, {required bool thumbnail})?` obtained from the real resolver's `tryResolveRemote` tear-off; the test passes a closure. Adjust the constructor accordingly: `MediaStoreSourceResolver({required RemoteResolve? Function() remote})` where `typedef RemoteResolve = Future<MediaSourceData?> Function(MediaItem item, {required bool thumbnail});`.

- [ ] **Step 2: FAIL run** — `flutter test test/features/media/data/media_store_source_resolver_test.dart --timeout 120s`

- [ ] **Step 3: Implement**

Enum: append `mediaStore` before the `;`. Fix every analyzer-reported switch (known: `_effectiveOriginDeviceId` → `case MediaSourceType.mediaStore: return null;`). Resolver:

```dart
class MediaStoreSourceResolver implements MediaSourceResolver {
  MediaStoreSourceResolver({required this.remote});
  final RemoteResolve? Function() remote;

  @override
  MediaSourceType get sourceType => MediaSourceType.mediaStore;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;

  @override
  Future<MediaSourceData> resolve(MediaItem item) async {
    final fn = remote();
    if (fn == null) {
      return const UnavailableData(kind: UnavailableKind.unauthenticated);
    }
    return await fn(item, thumbnail: false) ??
        const UnavailableData(kind: UnavailableKind.notFound);
  }

  @override
  Future<MediaSourceData> resolveThumbnail(MediaItem item,
      {required Size target}) async {
    final fn = remote();
    if (fn == null) {
      return const UnavailableData(kind: UnavailableKind.unauthenticated);
    }
    return await fn(item, thumbnail: true) ??
        await resolve(item);
  }

  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async => null;

  @override
  Future<VerifyResult> verify(MediaItem item) async {
    if (remote() == null) return VerifyResult.transientError;
    return (item.contentHash != null && item.remoteUploadedAt != null)
        ? VerifyResult.available
        : VerifyResult.notFound;
  }
}
```

(If `UnavailableKind.unauthenticated` does not exist, use the closest non-orphaning kind the enum offers — check `media_source_data.dart`; `verify` is what protects against wrong orphaning either way.) Registry arm:

```dart
MediaSourceType.mediaStore: MediaStoreSourceResolver(
  remote: () => ref.read(mediaStoreResolverProvider)?.tryResolveRemote,
),
```

(import `media_store_providers.dart`; use `ref.read` inside the closure so a store connect/disconnect does not rebuild the registry consumers mid-frame).

- [ ] **Step 4: PASS run** — same file, then `flutter test test/features/media/ --timeout 120s` (enum growth ripples).
- [ ] **Step 5: Commit** — `git add lib/features/media/ test/... && git commit -m "Add mediaStore source type with registered resolver"`

---

### Task 2: Cloud-backed conversion op

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart`
- Test: `test/features/media/data/media_cloud_backed_test.dart`

**Interfaces:**
- Produces: `Future<void> convertToCloudBacked(List<String> mediaIds)` — for each row WITH `contentHash != null && remoteUploadedAt != null`: `sourceType = 'mediaStore'`, `localPath/bookmarkRef/platformAssetId = null`, `isOrphaned = false`, `lastVerifiedAt = now`; rows missing the stamp pair are skipped (returned count not needed). Sync-safe like `_unlinkColumns`.

- [ ] **Step 1: Failing tests** (harness = Phase 2's `media_unlink_ops_test.dart` style):

```dart
test('converts stamped rows and clears local pointers', () async {
  // createMedia localFile row, then stampContentIdentity + raw UPDATE to set
  // remote_uploaded_at, then convertToCloudBacked(['m1']);
  // expect sourceType mediaStore, localPath/bookmarkRef/platformAssetId null,
  // isOrphaned false.
});
test('skips rows without the stamp pair', () async {
  // unstamped row keeps sourceType localFile.
});
```

- [ ] **Step 2: FAIL run.**
- [ ] **Step 3: Implement** — select rows by id, partition on the stamp pair in Dart, write one `MediaCompanion(sourceType: Value('mediaStore'), localPath: Value(null), bookmarkRef: Value(null), platformAssetId: Value(null), isOrphaned: Value(false), lastVerifiedAt: Value(now), updatedAt: Value(now))` for qualifying ids inside a transaction with per-row `markRecordPending` + `SyncEventBus.notifyLocalChange()` (mirror `_unlinkColumns`).
- [ ] **Step 4: PASS run** — `flutter test test/features/media/data/ --timeout 120s`.
- [ ] **Step 5: Commit** — "Add cloud-backed conversion op".

---

### Task 3: Match core — types, ladder, prefix-move detection

**Files:**
- Create: `lib/features/media/domain/services/media_repair_types.dart`
- Create: `lib/features/media/domain/services/media_repair_matcher.dart`
- Test: `test/features/media/domain/media_repair_matcher_test.dart`

**Interfaces (everything later tasks rely on):**

```dart
enum RepairConfidence { exact, probable, edited, unmatched }

/// One found file/asset/store object that may repair a broken row.
class RepairCandidate {
  const RepairCandidate.file({required this.path, required this.sizeBytes,
      this.hash});                       // folder source
  const RepairCandidate.galleryAsset({required this.assetId,
      required this.sizeBytes, this.hash});  // photo library source
  const RepairCandidate.store({required this.verified});  // store source
  // fields: String? path; String? assetId; int? sizeBytes; String? hash;
  // bool verified (store only);
}

/// A broken row paired with its best candidate and confidence.
class RepairProposal {
  const RepairProposal({required this.item, required this.confidence,
      this.candidate, this.viaPrefixMove = false});
  final MediaItem item;
  final RepairConfidence confidence;
  final RepairCandidate? candidate;   // null iff unmatched
  final bool viaPrefixMove;
}

/// Detected wholesale move: every broken path under [fromPrefix] has a
/// same-suffix file under [toPrefix].
class PrefixMove {
  const PrefixMove({required this.fromPrefix, required this.toPrefix,
      required this.coveredCount});
}

PrefixMove? detectPrefixMove({
  required List<String> brokenPaths,
  required Set<String> foundPaths,
});

/// Pure ladder over an in-memory candidate index. Hash comparison uses
/// item.contentHash when the row has one; a candidate with a hash equal to
/// the row's -> exact; name+size agree but no hash computed -> probable;
/// name matches with a differing hash -> edited; else unmatched.
List<RepairProposal> buildRepairProposals({
  required List<MediaItem> brokenRows,
  required Map<String, List<RepairCandidate>> candidatesByFilename,
  PrefixMove? prefixMove,
  Set<String> foundPaths = const {},
});
```

`detectPrefixMove` algorithm: for each broken path, its filename-with-parent suffixes (split on `/`); try suffix lengths from longest to 1; a candidate mapping is `(brokenPath minus suffix, foundPath minus suffix)` when some found path ends with the same suffix. Count votes per `(from, to)` pair; return the pair covering the most broken paths (>= 2 required, else null). `buildRepairProposals` first resolves prefix-move hits (`foundPaths.contains(toPrefix + relative)` → exact-if-hash-matches-or-unknown → probable, `viaPrefixMove: true`), then falls back to the filename index.

- [ ] **Step 1: Failing tests** — hand-computed vectors:

```dart
test('detects a whole-tree move covering multiple files', () {
  final move = detectPrefixMove(
    brokenPaths: ['/old/Dives/2026/a.jpg', '/old/Dives/2026/b.jpg',
        '/old/Dives/misc/c.mp4'],
    foundPaths: {'/nas/Dives/2026/a.jpg', '/nas/Dives/2026/b.jpg',
        '/nas/Dives/misc/c.mp4'},
  );
  expect(move!.fromPrefix, '/old/Dives');
  expect(move.toPrefix, '/nas/Dives');
  expect(move.coveredCount, 3);
});
test('a single coincidental filename is not a move', () {
  expect(detectPrefixMove(brokenPaths: ['/old/a.jpg'],
      foundPaths: {'/nas/a.jpg'}), isNull);
});
test('ladder: hash equality is exact, name+size without hash is probable, '
    'name with differing hash is edited, no candidate is unmatched', () {
  // one broken row per case; candidatesByFilename built by hand.
});
test('prefix-move hits are marked viaPrefixMove and rank above name matches',
    () { ... });
```

- [ ] **Steps 2-4: FAIL run, implement per the algorithm above, PASS run** — `flutter test test/features/media/domain/media_repair_matcher_test.dart --timeout 120s`.
- [ ] **Step 5: Commit** — "Add repair match core with prefix-move detection".

---

### Task 4: FolderCandidateSource

**Files:**
- Create: `lib/features/media/data/services/repair/folder_candidate_source.dart`
- Test: `test/features/media/data/repair/folder_candidate_source_test.dart` (real temp dirs)

**Interfaces:**

```dart
abstract class CandidateSource {
  /// Candidate files/assets keyed by lowercase filename, plus the full found
  /// path set for prefix-move detection (empty for non-folder sources).
  Future<CandidateHarvest> harvest(List<MediaItem> brokenRows);
}
class CandidateHarvest {
  const CandidateHarvest({required this.byFilename, this.foundPaths = const {}});
  final Map<String, List<RepairCandidate>> byFilename;
  final Set<String> foundPaths;
}

class FolderCandidateSource implements CandidateSource {
  FolderCandidateSource({required this.roots});   // absolute directory paths
  final List<String> roots;
  /// Hashes [candidate] lazily (sha256OfFile) and returns an updated copy.
  static Future<RepairCandidate> withHash(RepairCandidate candidate);
}
```

Harvest walks each root with `Directory(root).list(recursive: true, followLinks: false)`, indexing regular files by lowercase basename with size from `FileStat`; no hashing during harvest (on-demand only, via `withHash` which the apply stage and edited-detection use).

- [ ] **Step 1: Failing tests** — create a temp tree (`Directory.systemTemp.createTemp`) with nested files; assert harvest indexes by lowercase name with sizes, collects foundPaths, skips symlinks; `withHash` fills the sha256 (compare against `sha256OfFile` called directly).
- [ ] **Steps 2-4: FAIL, implement, PASS** — `flutter test test/features/media/data/repair/ --timeout 120s`.
- [ ] **Step 5: Commit** — "Add folder candidate source".

---

### Task 5: PhotoLibraryCandidateSource behind a port

**Files:**
- Create: `lib/features/media/data/services/repair/gallery_candidate_port.dart` (abstract: `Future<List<GalleryAssetInfo>> assetsInWindow(DateTime start, DateTime end)`; `class GalleryAssetInfo { String assetId; int? sizeBytes; DateTime? takenAt; }` + a photo_manager-backed impl modeled on the query idiom in `lib/features/media/data/services/trip_media_scanner.dart` / the gallery scan service)
- Create: `lib/features/media/data/services/repair/photo_library_candidate_source.dart`
- Test: `test/features/media/data/repair/photo_library_candidate_source_test.dart` (fake port)

**Interfaces:**
- Produces: `PhotoLibraryCandidateSource implements CandidateSource`, constructor takes the port. Harvest: for each broken row, query `takenAt +/- 1h`, emit `RepairCandidate.galleryAsset` for assets whose `sizeBytes` matches `item.contentSizeBytes` (when both known) keyed under the row's filename (gallery assets have no path — key by the broken row's own lowercase filename so the ladder pairs them; confidence rules make size-only matches `probable`).

- [ ] **Steps 1-4:** fake-port tests (window bounds honored; size mismatch filtered; result keyed to the row's filename), FAIL, implement, PASS.
- [ ] **Step 5: Commit** — "Add photo library candidate source".

---

### Task 6: StoreCandidateSource

**Files:**
- Create: `lib/features/media/data/services/repair/store_candidate_source.dart`
- Test: `test/features/media/data/repair/store_candidate_source_test.dart`

**Interfaces:**
- Produces: `StoreCandidateSource implements CandidateSource`, constructor `StoreCandidateSource({required Future<StoreObjectInfo?> Function(String key)? head})`. A broken row qualifies when `contentHash != null && remoteUploadedAt != null`; when `head` is non-null it is called with `StoreKeys.objectKey(item.contentHash!, extension: StoreKeys.extensionFor(item.originalFilename))` and `verified = info != null`; when `head` is null (store unreachable/unconfigured) qualification stands with `verified = false`. Candidates keyed by the row's lowercase filename as `RepairCandidate.store(verified: ...)`.

- [ ] **Steps 1-4:** tests (stamp-pair gate; verified flag from a recording fake head; null head → unverified), FAIL, implement, PASS.
- [ ] **Step 5: Commit** — "Add store candidate source".

---

### Task 7: Staged apply — `MediaRepairService`

**Files:**
- Create: `lib/features/media/data/services/repair/media_repair_service.dart`
- Modify: `lib/features/media/data/repositories/media_repository.dart` (one new op, below `convertToCloudBacked`)
- Test: `test/features/media/data/repair/media_repair_service_test.dart`

**Interfaces:**

```dart
/// One accepted proposal's DB write, prepared by Stage A.
class RepairWrite {
  const RepairWrite({required this.mediaId, this.newLocalPath,
      this.newBookmarkRef, this.newPlatformAssetId, this.toGallery = false});
}
// MediaRepository:
Future<void> applyRepairWrites(List<RepairWrite> writes);
// - one transaction; per row: localPath (and filePath := '' when the legacy
//   column held the broken path), bookmarkRef, platformAssetId + sourceType
//   flip to platformGallery when toGallery, isOrphaned=false,
//   lastVerifiedAt=now, updatedAt=now, markRecordPending; notifyLocalChange.

class RepairApplyReport {
  const RepairApplyReport({required this.relinked, required this.cloudBacked,
      required this.reuploadsQueued, required this.failed,
      required this.skipped});
  final int relinked; final int cloudBacked; final int reuploadsQueued;
  final int failed; final int skipped;
}

class MediaRepairService {
  MediaRepairService({
    required this.repository,          // MediaRepository
    required this.queue,               // MediaTransferQueueRepository
    required this.createBookmark,      // Future<Uint8List> Function(String path)? (null off-macOS/iOS)
    required this.writeBookmark,       // Future<void> Function(String ref, Uint8List blob)?
  });

  /// Applies accepted proposals. Stage A: per-row I/O (hash verify for
  /// probable -> promotes to exact or demotes+skips as changed-on-disk;
  /// bookmark regeneration; failures collect). Stage B: one
  /// applyRepairWrites transaction. Stage C: edited rows re-stamp identity,
  /// clear remote stamps, enqueueUpload; store proposals convertToCloudBacked.
  Future<RepairApplyReport> apply(List<RepairProposal> accepted);
}
```

Stage A per proposal (file candidates): compute `sha256OfFile` of the candidate path; if the row has a `contentHash`: equal → exact-apply; differing → if the proposal was accepted as `edited`, keep (record for Stage C: new hash+size); if it was `probable`, DEMOTE: count as `skipped` (changed-on-disk) and drop. Rows without any `contentHash` apply as-is. Bookmark: when `createBookmark != null`, regenerate under `item.bookmarkRef ?? Uuid().v4()` (the `_replaceLink` idiom); a bookmark failure marks that row `failed` and continues. Gallery candidates skip hashing (size already gated) and produce `toGallery: true` writes.

- [ ] **Step 1: Failing tests** — real temp files + in-memory DB (Phase 2 harness):

```dart
test('exact file proposal rewrites the path and clears isOrphaned', () async {
  // seed localFile row with contentHash = sha256 of a temp file's bytes,
  // isOrphaned true, localPath pointing nowhere; propose the temp file as
  // exact; apply; expect localPath == temp path, isOrphaned false,
  // report.relinked == 1.
});
test('probable proposal whose bytes differ is skipped as changed-on-disk',
    () async { ... report.skipped == 1, row untouched ... });
test('edited acceptance re-stamps identity, clears remote stamps, and '
    'enqueues an upload', () async {
  // row with old contentHash + remote_uploaded_at set; accepted edited
  // proposal for a temp file with different bytes; after apply:
  // contentHash == new hash, remoteUploadedAt null, queue holds an upload
  // row for the media id (query media_transfer_queue via the queue repo).
});
test('store proposal converts to cloud-backed', () async { ... });
test('bookmark failure fails that row only', () async {
  // createBookmark throws for one of two proposals; report.failed == 1,
  // relinked == 1.
});
```

- [ ] **Steps 2-4: FAIL, implement, PASS** — `flutter test test/features/media/data/repair/ test/features/media/data/ --timeout 120s`.
- [ ] **Step 5: Commit** — "Add staged repair apply service".

---

### Task 8: Repair providers + wizard state

**Files:**
- Create: `lib/features/media/presentation/providers/media_repair_providers.dart`
- Test: `test/features/media/presentation/media_repair_providers_test.dart`

**Interfaces:**

```dart
class RepairWizardConfig {
  const RepairWizardConfig({this.folderRoots = const [],
      this.usePhotoLibrary = false, this.useStore = true});
}
class RepairWizardState {
  // idle -> harvesting -> review(proposals, prefixMove) -> applying ->
  // done(report); plus error(Object).
}
final repairWizardProvider =
    StateNotifierProvider.autoDispose<RepairWizardNotifier, RepairWizardState>;
class RepairWizardNotifier extends StateNotifier<RepairWizardState> {
  Future<void> harvest(RepairWizardConfig config);   // loads missing rows via
      // MediaLibraryRepository.getPage(health: missing) pages, filters out
      // volume-offline rows (VolumeStatus), builds sources, runs
      // detectPrefixMove + buildRepairProposals -> review state
  void toggleProposal(String mediaId);               // checked set; exact and
      // probable pre-checked, edited and unmatched unchecked
  Future<void> applyChecked();                       // MediaRepairService.apply
}
final mediaRepairServiceProvider = Provider<MediaRepairService>((ref) { ... });
```

- [ ] **Steps 1-4:** notifier tests over fakes (a fake CandidateSource injected via a visible-for-testing `buildSources` override on the notifier constructor; harvest produces review with pre-checked exact/probable; applyChecked forwards only checked ids; volume-offline rows excluded via an injected `Future<bool> Function(String path)` volume probe), FAIL, implement, PASS.
- [ ] **Step 5: Commit** — "Add repair wizard state and providers".

---

### Task 9: Missing console section + wizard UI

**Files:**
- Create: `lib/features/media/presentation/pages/media_missing_view.dart`
- Create: `lib/features/media/presentation/pages/media_repair_wizard_page.dart`
- Modify: `lib/features/media/presentation/widgets/media_console_scaffold.dart` (`MediaConsoleSection.missing` between unlinked and transfers; icon `Icons.warning_amber_outlined`; label `media_console_missing`)
- Modify: `lib/features/media/presentation/pages/media_section_page.dart` (section body + `missingCountProvider` badge)
- Modify: l10n arbs + gen-l10n — keys: `media_console_missing` "Missing", `media_missing_empty` "No missing files", `media_missing_offlineVolumes` "{count} on offline volumes", `media_missing_repair` "Repair...", `media_repair_title` "Repair missing files", `media_repair_stepScope` "Sources", `media_repair_stepReview` "Review", `media_repair_stepApply` "Apply", `media_repair_addFolder` "Add folder...", `media_repair_usePhotoLibrary` "Search photo library", `media_repair_useStore` "Use cloud media store", `media_repair_scan` "Scan", `media_repair_prefixMove` "Folder move detected: {from} to {to} covers {count} files", `media_repair_confidence_exact` "Exact", `media_repair_confidence_probable` "Name and size", `media_repair_confidence_edited` "Edited file", `media_repair_confidence_unmatched` "No candidate", `media_repair_apply` "Re-link {count} files", `media_repair_summary` "{relinked} re-linked, {cloudBacked} cloud-backed, {reuploads} re-uploads queued, {failed} failed, {skipped} skipped"
- Test: `test/features/media/presentation/media_missing_view_test.dart`, `test/features/media/presentation/media_repair_wizard_test.dart`

**Interfaces:**
- Missing view: `MediaLibraryNotifier` pinned to `MediaHealthFilter.missing` (the Phase 2 inbox pattern verbatim, new provider `missingViewProvider`), tiles via `MediaLibraryTile`, an offline-volumes info banner (count computed by an injected volume probe provider), and a `media_missing_repair` button pushing `MediaRepairWizardPage`.
- Wizard page: a `Stepper`-free 3-pane flow driven by `repairWizardProvider` state: scope pane (folder chips via `FilePicker.platform.getDirectoryPath()`, photo-library and store switches, Scan button → `harvest`), review pane (prefix-move callout, `CheckboxListTile` per proposal grouped by confidence, `media_repair_apply` button → `applyChecked`), summary pane (`media_repair_summary` + close).

- [ ] **Steps 1-4:** widget tests with the notifier overridden by seeded states (review state with one proposal per confidence → checkbox defaults asserted; tapping apply forwards; summary text renders from a done state; missing view shows empty state and banner), FAIL, implement, PASS — `flutter test test/features/media/presentation/ --timeout 120s`.
- [ ] **Step 5: Commit** — "Add Missing section and repair wizard".

---

### Task 10: Rewire single-item Replace link through the engine

**Files:**
- Modify: `lib/features/media/presentation/widgets/dive_media_section.dart` (`_replaceLink` at :303 — keep the picker, then build a single `RepairProposal` and route through `MediaRepairService.apply` so hash verification and stamp/queue behavior are engine-owned; picked file with bytes differing from `contentHash` shows a confirm dialog using existing delete-confirm styling with new keys `media_diveMediaSection_replaceEditedTitle` "File contents differ" / `media_diveMediaSection_replaceEditedContent` "This file's contents differ from the original. Re-linking will re-upload it to your media store." / reuse `common_action_cancel` + `media_diveMediaSection_unlinkButton`-style accept "Re-link")
- Modify: l10n arbs + gen-l10n (the two new keys, all 11 locales)
- Test: extend `test/features/media/data/repair/media_repair_service_test.dart` with a single-proposal path equivalent (the UI path itself stays under the existing coverage:ignore desktop-only block)

- [ ] **Step 1:** implement the rewire: `_replaceLink` becomes: pick file → `sha256OfFile` → confidence = exact when hashes match or row unhashed, else show the confirm dialog → accepted ⇒ `RepairProposal(confidence: edited)` → `mediaRepairServiceProvider.apply([proposal])` → `notifier.refresh()`.
- [ ] **Step 2:** run the FULL suite (`flutter test --timeout 120s`) — `dive_media_section.dart` gate; rerun known flaky files in isolation before concluding regression.
- [ ] **Step 3: Commit** — "Route single-item Replace link through the repair engine".

---

### Task 11: Final sweep

- [ ] `dart format .` (no-op), `flutter analyze` (zero), `flutter test --timeout 120s` full suite; commit stragglers.

---

## Plan self-review notes (already applied)

- Spec section 6 coverage: engine + three sources (T3-T6), ladder incl. edited re-upload path (T3, T7), staged apply A/B/C (T7), mediaStore type + registered resolver + conversion (T1, T2), wizard 3 steps + prefix callout + confidence grouping (T8, T9), Missing view with volume-offline informational bucket + badge (T9, badge via Phase 1 missingCountProvider), Replace-link rewire (T10). Ambiguity rules (same-hash multi-candidate prefers prefix-map) are inherent to proposal ordering in T3.
- Deviations recorded: per-row Browse escape hatch in review deferred to the Missing view's existing single-item Replace link path (T10) rather than a fourth wizard control; HEAD-unverified store conversions annotate via the `verified` flag on the candidate (surfaced as subtitle text in review) rather than a separate state.
- Type consistency: `CandidateSource.harvest → CandidateHarvest`, `RepairCandidate`, `RepairProposal`, `RepairConfidence`, `PrefixMove`, `RepairWrite`, `RepairApplyReport`, `MediaRepairService.apply`, `applyRepairWrites`, `convertToCloudBacked` used consistently across T3-T10.
