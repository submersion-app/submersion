# Media Store Phase 2 (UX Layer) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Thumbnail objects (fast cross-device grids), a Transfers view, gallery status badges, "Upload existing library" backfill, and network policies — Phase 2 of the Media Store spec (`docs/superpowers/specs/2026-07-10-s3-media-storage-design.md`, sections 9, 10, 14, 17).

**Architecture:** Builds directly on Phase 1 (branch `worktree-s3-media-store`): the upload pipeline gains a best-effort thumbnail step (512 px JPEG uploaded to `smv1/thumbs/<aa>/<hash>.jpg` BEFORE the original), the resolver routes thumbnail requests to thumb objects, the per-device queue becomes observable (drift streams) to power a Transfers page and per-tile badges, and a `NetworkStatusService` + `MediaStorePolicies` gate the worker. Videos become explicitly ineligible for upload until Phase 3's multipart transfer (this also closes a Phase 1 gap where a video would have gone through the whole-bytes path).

**Tech Stack:** Phase 1 media-store stack, plus new dependencies `connectivity_plus` (network type) and `image` (JPEG encoding of resized thumbnails).

## Global Constraints

- Work ONLY in the worktree: `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-store-phase2` (branch `worktree-media-store-phase2`, stacked on `worktree-s3-media-store`). The eventual PR targets `worktree-s3-media-store`, not `main`.
- No schema changes: main DB stays at v103; the local cache DB stays at v2. Everything here is code plus two pubspec dependencies.
- TDD: write the failing test first in every task. Run tests per-file, never the whole suite. Pipe test output through `tail` only with `set -o pipefail`.
- Before every commit: `dart format .` and whole-project `flutter analyze` (CI runs `--fatal-infos`; an info-level lint fails CI).
- No emojis. `LoggerService.forClass(...)` for logging, never `print`.
- Commit messages: conventional, single line, no trailers. Example: `feat(media-store): thumbnail objects in the upload pipeline`.
- New user-facing strings go into ALL 11 arb files in `lib/l10n/arb/` with the translations given in Task 7's script, then `flutter gen-l10n`.
- Phase 2 exit criteria (spec section 17): thumbs uploaded and consumed cross-device; Transfers view and badges reflect queue reality; backfill enqueues a real library; network gating enforced. "Video-off-Wi-Fi" is enforced in Phase 2 by excluding videos from upload eligibility entirely (Phase 3 lifts this with multipart); the `videosOnCellular` preference ships now so Phase 3 only consumes it.
- Phase 1 signatures this plan consumes are verbatim from the Phase 1 branch: `MediaUploadPipeline.process(MediaTransferQueueEntry)`, `MediaTransferQueueRepository` (typedef `MediaTransferQueueEntry = MediaTransferQueueData`), `MediaCacheStore.get/put/stagingFile` + `MediaCacheKind`, `MediaObjectStore`, `StoreKeys.thumbKey(hash)`, `MediaStoreResolver.tryResolveRemote(item, {required bool thumbnail})`, `MediaStoreRuntime`/providers in `lib/features/media_store/presentation/providers/media_store_providers.dart`, `MediaRepository.stampRemoteUploaded/stampContentIdentity/getMediaById`.

---

### Task 1: Dependencies, MediaStorePolicies, video eligibility gate

**Files:**
- Modify: `pubspec.yaml` (dependencies section)
- Create: `lib/core/services/media_store/media_store_policies.dart`
- Modify: `lib/features/media_store/data/media_upload_pipeline.dart` (`_isEligible`, ~line 108)
- Modify: `lib/features/media_store/presentation/providers/media_store_providers.dart` (policies provider + enqueue impl gate)
- Test: `test/core/services/media_store/media_store_policies_test.dart`
- Test: modify `test/features/media_store/media_upload_pipeline_test.dart` (video-ineligibility case)

**Interfaces:**
- Consumes: `SharedPreferences` (mockable via `SharedPreferences.setMockInitialValues`).
- Produces:
```dart
class MediaStorePolicies {
  MediaStorePolicies({SharedPreferences? prefs});
  static const String autoUploadKey = 'media_store_auto_upload';
  static const String photosOnCellularKey = 'media_store_photos_on_cellular';
  static const String videosOnCellularKey = 'media_store_videos_on_cellular';
  Future<bool> autoUpload();            // default true
  Future<void> setAutoUpload(bool value);
  Future<bool> photosOnCellular();      // default true
  Future<void> setPhotosOnCellular(bool value);
  Future<bool> videosOnCellular();      // default false; consumed in Phase 3
  Future<void> setVideosOnCellular(bool value);
}
// media_store_providers.dart gains:
final mediaStorePoliciesProvider = Provider<MediaStorePolicies>(
  (ref) => MediaStorePolicies(),
);
```
- Pipeline `_isEligible` additionally returns false for `MediaType.video` (comment: Phase 3 lifts this with multipart transfer).
- `mediaStoreEnqueueImplProvider` checks `policies.autoUpload()` before enqueueing (backfill and manual retry bypass this by calling the queue/worker directly).

- [ ] **Step 1: Add dependencies**

In `pubspec.yaml` under `dependencies:`, add in alphabetical position:

```yaml
  connectivity_plus: ^6.1.0
  image: ^4.3.0
```

Run: `flutter pub get`
Expected: resolves cleanly. If the resolver reports a version conflict, relax the caret to the highest major it suggests and note it in the commit body.

- [ ] **Step 2: Write the failing policies test**

Create `test/core/services/media_store/media_store_policies_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/media_store/media_store_policies.dart';

void main() {
  test('defaults: autoUpload on, photos-on-cellular on, videos-on-cellular '
      'off', () async {
    SharedPreferences.setMockInitialValues({});
    final policies = MediaStorePolicies(
      prefs: await SharedPreferences.getInstance(),
    );
    expect(await policies.autoUpload(), isTrue);
    expect(await policies.photosOnCellular(), isTrue);
    expect(await policies.videosOnCellular(), isFalse);
  });

  test('setters round-trip', () async {
    SharedPreferences.setMockInitialValues({});
    final policies = MediaStorePolicies(
      prefs: await SharedPreferences.getInstance(),
    );
    await policies.setAutoUpload(false);
    await policies.setPhotosOnCellular(false);
    await policies.setVideosOnCellular(true);
    expect(await policies.autoUpload(), isFalse);
    expect(await policies.photosOnCellular(), isFalse);
    expect(await policies.videosOnCellular(), isTrue);
  });
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `set -o pipefail; flutter test test/core/services/media_store/media_store_policies_test.dart 2>&1 | tail -3`
Expected: FAIL to compile.

- [ ] **Step 4: Implement MediaStorePolicies**

Create `lib/core/services/media_store/media_store_policies.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local transfer policies (design spec section 9). Stored in
/// SharedPreferences like the attach state: policies are per-device
/// choices and must not ride a database restore.
class MediaStorePolicies {
  MediaStorePolicies({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  static const String autoUploadKey = 'media_store_auto_upload';
  static const String photosOnCellularKey = 'media_store_photos_on_cellular';
  static const String videosOnCellularKey = 'media_store_videos_on_cellular';

  Future<SharedPreferences> get _resolved async =>
      _prefs ?? await SharedPreferences.getInstance();

  Future<bool> autoUpload() async =>
      (await _resolved).getBool(autoUploadKey) ?? true;

  Future<void> setAutoUpload(bool value) async =>
      (await _resolved).setBool(autoUploadKey, value);

  Future<bool> photosOnCellular() async =>
      (await _resolved).getBool(photosOnCellularKey) ?? true;

  Future<void> setPhotosOnCellular(bool value) async =>
      (await _resolved).setBool(photosOnCellularKey, value);

  /// Default false. Phase 2 does not upload videos at all; this ships now
  /// so Phase 3's multipart transfer only has to consume it.
  Future<bool> videosOnCellular() async =>
      (await _resolved).getBool(videosOnCellularKey) ?? false;

  Future<void> setVideosOnCellular(bool value) async =>
      (await _resolved).setBool(videosOnCellularKey, value);
}
```

- [ ] **Step 5: Gate videos out of the pipeline**

In `media_upload_pipeline.dart`, `_isEligible` currently rejects only signatures. Change:

```dart
  bool _isEligible(MediaItem item) {
    if (!_eligibleSources.contains(item.sourceType)) return false;
    if (item.mediaType == MediaType.instructorSignature) return false;
    // Videos wait for Phase 3's multipart transfer; the Phase 1 single-shot
    // path would read a whole video into memory.
    if (item.mediaType == MediaType.video) return false;
    final resolver = _registry.resolverFor(item.sourceType);
    return resolver.canResolveOnThisDevice(item);
  }
```

Add to `test/features/media_store/media_upload_pipeline_test.dart` (next to the signature-ineligibility test; the `enqueueLocalFileItem` helper already accepts `mediaType`):

```dart
  test('video rows are ineligible until Phase 3', () async {
    await enqueueLocalFileItem(
      bytes: [3, 3],
      name: 'clip.mp4',
      mediaType: domain.MediaType.video,
    );
    final entry = (await queue.nextPending(DateTime.now()))!;
    expect(await pipeline.process(entry), UploadOutcome.skippedIneligible);
    expect(fakeStore.objects, isEmpty);
  });
```

- [ ] **Step 6: Gate auto-upload at the enqueue bridge**

In `media_store_providers.dart`, add the provider and gate the enqueue implementation:

```dart
final mediaStorePoliciesProvider = Provider<MediaStorePolicies>(
  (ref) => MediaStorePolicies(),
);
```

and change `mediaStoreEnqueueImplProvider`'s body to:

```dart
final mediaStoreEnqueueImplProvider = Provider<void Function(String)>((ref) {
  return (mediaId) {
    unawaited(() async {
      if (!await ref.read(mediaStorePoliciesProvider).autoUpload()) return;
      final runtime = await ref.read(mediaStoreRuntimeProvider.future);
      await runtime?.worker?.enqueueAndKick(mediaId);
    }());
  };
});
```

Add the import for `media_store_policies.dart`.

- [ ] **Step 7: Run tests, format, analyze, commit**

```bash
set -o pipefail
flutter test test/core/services/media_store/media_store_policies_test.dart 2>&1 | tail -3
flutter test test/features/media_store/media_upload_pipeline_test.dart 2>&1 | tail -3
dart format .
flutter analyze
git add -A
git commit -m "feat(media-store): transfer policies and video eligibility gate"
```
Expected: all PASS, `No issues found!`.

---

### Task 2: Queue observability (watch, retry, defer, clear)

**Files:**
- Modify: `lib/features/media_store/data/media_transfer_queue_repository.dart`
- Test: modify `test/features/media_store/media_transfer_queue_repository_test.dart`

**Interfaces:**
- Produces (on `MediaTransferQueueRepository`):
```dart
Stream<List<MediaTransferQueueEntry>> watchEntries();
// transferring first, then pending, failed, done; updatedAt DESC within a state
Stream<MediaTransferQueueEntry?> watchLatestForMedia(String mediaId);
// newest row for that media, any state; null when none
Future<void> retry(int id);
// failed -> pending, attempts 0, nextAttemptAt null, errorMessage cleared
Future<void> defer(int id, DateTime until);
// stays pending, nextAttemptAt = until, attempts NOT incremented
Future<int> deleteDone();          // returns rows removed
Stream<int> watchActiveCount();    // pending + transferring
```

- [ ] **Step 1: Write the failing tests**

Append to `media_transfer_queue_repository_test.dart`:

```dart
  test('watchEntries orders transferring, pending, failed, done', () async {
    final a = await repo.enqueueUpload(mediaId: 'a');
    final b = await repo.enqueueUpload(mediaId: 'b');
    final c = await repo.enqueueUpload(mediaId: 'c');
    final d = await repo.enqueueUpload(mediaId: 'd');
    await repo.markTransferring(b);
    await repo.markDone(c);
    for (var i = 0; i < 5; i++) {
      await repo.markFailed(d, 'x');
    }

    final entries = await repo.watchEntries().first;
    expect(entries.map((e) => e.id).toList(), [b, a, d, c]);
  });

  test('watchLatestForMedia emits the newest row and null when absent',
      () async {
    expect(await repo.watchLatestForMedia('m9').first, isNull);
    final id = await repo.enqueueUpload(mediaId: 'm9');
    final row = await repo.watchLatestForMedia('m9').first;
    expect(row!.id, id);
  });

  test('retry resets a terminally failed entry', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    for (var i = 0; i < 5; i++) {
      await repo.markFailed(id, 'boom');
    }
    expect((await repo.allForTesting()).single.state, 'failed');

    await repo.retry(id);
    final row = (await repo.allForTesting()).single;
    expect(row.state, 'pending');
    expect(row.attempts, 0);
    expect(row.nextAttemptAt, isNull);
    expect(row.errorMessage, isNull);
    expect(await repo.nextPending(DateTime.now()), isNotNull);
  });

  test('defer postpones without consuming an attempt', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    final until = DateTime.now().add(const Duration(minutes: 10));
    await repo.defer(id, until);
    expect(await repo.nextPending(DateTime.now()), isNull);
    final row = (await repo.allForTesting()).single;
    expect(row.attempts, 0);
    expect(row.state, 'pending');
    expect(
      await repo.nextPending(until.add(const Duration(seconds: 1))),
      isNotNull,
    );
  });

  test('deleteDone removes only completed rows and watchActiveCount tracks '
      'pending plus transferring', () async {
    final a = await repo.enqueueUpload(mediaId: 'a');
    final b = await repo.enqueueUpload(mediaId: 'b');
    await repo.markDone(a);
    await repo.markTransferring(b);
    expect(await repo.watchActiveCount().first, 1);
    expect(await repo.deleteDone(), 1);
    expect((await repo.allForTesting()).length, 1);
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `set -o pipefail; flutter test test/features/media_store/media_transfer_queue_repository_test.dart 2>&1 | tail -3`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

Append to `MediaTransferQueueRepository` (drift `watch()` streams re-emit on table changes):

```dart
  /// Transfers view feed: active work first, history last.
  Stream<List<MediaTransferQueueEntry>> watchEntries() {
    final stateRank = CaseWhenExpression<int>(
      cases: [
        CaseWhen(
          _db.mediaTransferQueue.state.equals('transferring'),
          then: const Constant(0),
        ),
        CaseWhen(
          _db.mediaTransferQueue.state.equals('pending'),
          then: const Constant(1),
        ),
        CaseWhen(
          _db.mediaTransferQueue.state.equals('failed'),
          then: const Constant(2),
        ),
      ],
      orElse: const Constant(3),
    );
    return (_db.select(_db.mediaTransferQueue)..orderBy([
          (t) => OrderingTerm.asc(stateRank),
          (t) => OrderingTerm.desc(t.updatedAt),
        ]))
        .watch();
  }

  Stream<MediaTransferQueueEntry?> watchLatestForMedia(String mediaId) {
    return (_db.select(_db.mediaTransferQueue)
          ..where((t) => t.mediaId.equals(mediaId))
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<void> retry(int id) async {
    await (_db.update(
      _db.mediaTransferQueue,
    )..where((t) => t.id.equals(id))).write(
      MediaTransferQueueCompanion(
        state: const Value('pending'),
        attempts: const Value(0),
        nextAttemptAt: const Value(null),
        errorMessage: const Value(null),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Connectivity/policy postponement: unlike markFailed, no attempt is
  /// consumed - the entry is simply not due until [until].
  Future<void> defer(int id, DateTime until) async {
    await (_db.update(
      _db.mediaTransferQueue,
    )..where((t) => t.id.equals(id))).write(
      MediaTransferQueueCompanion(
        nextAttemptAt: Value(until.millisecondsSinceEpoch),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<int> deleteDone() =>
      (_db.delete(_db.mediaTransferQueue)..where((t) => t.state.equals('done')))
          .go();

  Stream<int> watchActiveCount() {
    final count = _db.mediaTransferQueue.id.count();
    final query = _db.selectOnly(_db.mediaTransferQueue)
      ..addColumns([count])
      ..where(_db.mediaTransferQueue.state.isIn(['pending', 'transferring']));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }
```

NOTE: `CaseWhenExpression`/`CaseWhen` come from `package:drift/drift.dart` (already imported). If the installed drift version names them differently, the compiler will say so; the fallback is sorting in Dart after `.watch()` (`list.sort` by a state-rank map then updatedAt desc) - equally acceptable, the table is small.

- [ ] **Step 4: Run to verify it passes**

Run: `set -o pipefail; flutter test test/features/media_store/media_transfer_queue_repository_test.dart 2>&1 | tail -3`
Expected: PASS (10 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add -A
git commit -m "feat(media-store): observable transfer queue with retry and defer"
```

---

### Task 3: NetworkStatusService + worker gating + connectivity-regain drain

**Files:**
- Create: `lib/core/services/media_store/network_status_service.dart`
- Modify: `lib/features/media_store/data/media_store_worker.dart`
- Modify: `lib/features/media_store/presentation/providers/media_store_providers.dart` (runtime wiring)
- Test: `test/core/services/media_store/network_status_service_test.dart`
- Test: modify `test/features/media_store/media_store_end_to_end_test.dart` (gating case)

**Interfaces:**
- Consumes: `package:connectivity_plus` (`Connectivity`, `List<ConnectivityResult>`), Task 1 `MediaStorePolicies`, Task 2 `defer`.
- Produces:
```dart
enum NetworkKind { offline, cellular, unmetered }

class NetworkStatusService {
  NetworkStatusService({Connectivity? connectivity});
  Future<NetworkKind> current();
  Stream<NetworkKind> get changes; // mapped + distinct
  static NetworkKind kindFrom(List<ConnectivityResult> results);
  // wifi/ethernet/vpn -> unmetered; else mobile -> cellular; else offline
}

enum WorkerGate { proceed, deferEntry, stopDraining }

// MediaStoreWorker constructor gains:
//   Future<WorkerGate> Function(MediaTransferQueueEntry entry)? gate,
// drain(): gate == stopDraining -> break; deferEntry -> queue.defer(entry.id,
// now + 10 minutes) and continue to the next entry; proceed -> process.
```
- Runtime wiring (`mediaStoreRuntimeProvider`): builds the gate closure (offline -> stopDraining; cellular photo blocked by `photosOnCellular` -> deferEntry; else proceed) and subscribes `networkStatus.changes` - any transition to a non-offline kind calls `worker.drain()`; the subscription is cancelled in `ref.onDispose`.

- [ ] **Step 1: Write the failing service test**

Create `test/core/services/media_store/network_status_service_test.dart`:

```dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/media_store/network_status_service.dart';

void main() {
  test('kindFrom maps connectivity results', () {
    expect(
      NetworkStatusService.kindFrom([ConnectivityResult.wifi]),
      NetworkKind.unmetered,
    );
    expect(
      NetworkStatusService.kindFrom([ConnectivityResult.ethernet]),
      NetworkKind.unmetered,
    );
    expect(
      NetworkStatusService.kindFrom([
        ConnectivityResult.vpn,
        ConnectivityResult.mobile,
      ]),
      NetworkKind.unmetered,
    );
    expect(
      NetworkStatusService.kindFrom([ConnectivityResult.mobile]),
      NetworkKind.cellular,
    );
    expect(
      NetworkStatusService.kindFrom([ConnectivityResult.none]),
      NetworkKind.offline,
    );
    expect(NetworkStatusService.kindFrom(const []), NetworkKind.offline);
  });
}
```

- [ ] **Step 2: Run to verify it fails, then implement the service**

Run: `set -o pipefail; flutter test test/core/services/media_store/network_status_service_test.dart 2>&1 | tail -3` -> FAIL to compile.

Create `lib/core/services/media_store/network_status_service.dart`:

```dart
import 'package:connectivity_plus/connectivity_plus.dart';

/// Coarse network classification for transfer policies (design spec
/// section 9). Wifi/ethernet/VPN count as unmetered; a VPN's underlying
/// transport is invisible to the app, so it is treated optimistically.
enum NetworkKind { offline, cellular, unmetered }

class NetworkStatusService {
  NetworkStatusService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static NetworkKind kindFrom(List<ConnectivityResult> results) {
    const unmetered = {
      ConnectivityResult.wifi,
      ConnectivityResult.ethernet,
      ConnectivityResult.vpn,
    };
    if (results.any(unmetered.contains)) return NetworkKind.unmetered;
    if (results.contains(ConnectivityResult.mobile)) {
      return NetworkKind.cellular;
    }
    return NetworkKind.offline;
  }

  Future<NetworkKind> current() async =>
      kindFrom(await _connectivity.checkConnectivity());

  Stream<NetworkKind> get changes =>
      _connectivity.onConnectivityChanged.map(kindFrom).distinct();
}
```

NOTE: in connectivity_plus 6.x, `checkConnectivity()` returns `Future<List<ConnectivityResult>>` and `onConnectivityChanged` is `Stream<List<ConnectivityResult>>`. If pub resolved an older 5.x (single result, not list), wrap the single values in lists at the two call sites - `kindFrom` stays list-shaped either way.

Run the test again -> PASS.

- [ ] **Step 3: Write the failing worker-gating test**

Append to `test/features/media_store/media_store_end_to_end_test.dart` (inside `main`, using the same fixtures as the marker-mismatch test):

```dart
  test('gate deferEntry postpones the entry without consuming attempts and '
      'stopDraining halts the queue', () async {
    final mediaRepository = MediaRepository();
    final cache = MediaCacheStore(database: cacheDbA, root: rootA);
    final queue = MediaTransferQueueRepository(database: cacheDbA);
    final resolver = FakeLocalFileResolver();
    final photo = File('${rootA.path}/gate.jpg')..writeAsBytesSync([7]);
    resolver.data = FileData(file: photo);
    final created = await mediaRepository.createMedia(
      domain.MediaItem(
        id: '',
        mediaType: domain.MediaType.photo,
        sourceType: MediaSourceType.localFile,
        filePath: photo.path,
        localPath: photo.path,
        originalFilename: 'gate.jpg',
        takenAt: DateTime(2026, 7, 1),
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      ),
    );
    await queue.enqueueUpload(mediaId: created.id);

    var gateResult = WorkerGate.deferEntry;
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: MediaUploadPipeline(
        mediaRepository: mediaRepository,
        queue: queue,
        store: bucket,
        registry: MediaSourceResolverRegistry({
          MediaSourceType.localFile: resolver,
        }),
        cache: cache,
      ),
      gate: (entry) async => gateResult,
    );

    await worker.drain();
    var row = (await queue.allForTesting()).single;
    expect(row.state, 'pending');
    expect(row.attempts, 0);
    expect(row.nextAttemptAt, isNotNull, reason: 'deferred, not failed');
    expect(bucket.objects, isEmpty);

    gateResult = WorkerGate.stopDraining;
    await worker.drain();
    expect(bucket.objects, isEmpty);
  });
```

Add the needed import at the top of the file: `import 'package:submersion/features/media_store/data/media_store_worker.dart';` is already present; nothing new.

- [ ] **Step 4: Run to verify it fails, then implement the gate**

Run: `set -o pipefail; flutter test test/features/media_store/media_store_end_to_end_test.dart 2>&1 | tail -3` -> FAIL to compile (`WorkerGate` undefined).

In `media_store_worker.dart`:

```dart
/// Per-entry admission decision made just before processing.
enum WorkerGate { proceed, deferEntry, stopDraining }
```

Constructor gains `this._gate` style parameter:

```dart
  MediaStoreWorker({
    required MediaTransferQueueRepository queue,
    required MediaUploadPipeline pipeline,
    Future<bool> Function()? preflight,
    Future<WorkerGate> Function(MediaTransferQueueEntry entry)? gate,
  }) : _queue = queue,
       _pipeline = pipeline,
       _preflight = preflight,
       _gate = gate;

  final Future<WorkerGate> Function(MediaTransferQueueEntry entry)? _gate;

  /// Deferral window for policy/connectivity-blocked entries.
  static const Duration deferWindow = Duration(minutes: 10);
```

and the drain loop body becomes:

```dart
      while (true) {
        final entry = await _queue.nextPending(DateTime.now());
        if (entry == null) break;
        if (_gate != null) {
          final decision = await _gate(entry);
          if (decision == WorkerGate.stopDraining) {
            _log.info('Drain stopped by gate (offline or suspended)');
            break;
          }
          if (decision == WorkerGate.deferEntry) {
            await _queue.defer(entry.id, DateTime.now().add(deferWindow));
            continue;
          }
        }
        await _pipeline.process(entry);
      }
```

- [ ] **Step 5: Wire the gate and the connectivity trigger into the runtime**

In `media_store_providers.dart`, inside `mediaStoreRuntimeProvider` after the `worker` is constructed, replace the plain `MediaStoreWorker(...)` construction with:

```dart
  final policies = ref.watch(mediaStorePoliciesProvider);
  final network = NetworkStatusService();
  final mediaRepository = ref.watch(mediaRepositoryProvider);
  final worker = MediaStoreWorker(
    queue: MediaTransferQueueRepository(),
    pipeline: pipeline,
    preflight: () async {
      final marker = await StoreMarkerStore(store: store).read();
      return marker != null && marker.storeId == attachedId;
    },
    gate: (entry) async {
      final kind = await network.current();
      if (kind == NetworkKind.offline) return WorkerGate.stopDraining;
      if (kind == NetworkKind.cellular) {
        final item = await mediaRepository.getMediaById(entry.mediaId);
        final isVideo = item?.mediaType == MediaType.video;
        final allowed = isVideo
            ? await policies.videosOnCellular()
            : await policies.photosOnCellular();
        if (!allowed) return WorkerGate.deferEntry;
      }
      return WorkerGate.proceed;
    },
  );
  final connectivitySub = network.changes.listen((kind) {
    if (kind != NetworkKind.offline) unawaited(worker.drain());
  });
  ref.onDispose(connectivitySub.cancel);
  unawaited(worker.drain());
```

Add imports: `network_status_service.dart`, `media_store_policies.dart`, and `package:submersion/features/media/domain/entities/media_item.dart` (for `MediaType`).

- [ ] **Step 6: Run, format, analyze, commit**

```bash
set -o pipefail
flutter test test/core/services/media_store/network_status_service_test.dart test/features/media_store/media_store_end_to_end_test.dart 2>&1 | tail -3
flutter test test/features/media_store/ 2>&1 | tail -2
dart format . && flutter analyze
git add -A
git commit -m "feat(media-store): network-aware worker gating and drain triggers"
```
Expected: all PASS, no issues.

---

### Task 4: ThumbnailGenerator

**Files:**
- Create: `lib/features/media_store/data/thumbnail_generator.dart`
- Test: `test/features/media_store/thumbnail_generator_test.dart`

**Interfaces:**
- Consumes: `MediaSourceResolverRegistry.resolverFor(sourceType).resolveThumbnail(item, target: Size)` (gallery items return `BytesData` of JPEG bytes from photo_manager; localFile items fall back to `resolve()` = full-size `FileData`), `MediaCacheStore.stagingFile()`, `package:image` (`decodeImage`, `copyResize`, `encodeJpg`), `dart:ui` `instantiateImageCodec` is NOT used (package:image keeps it isolate-friendly and test-simple).
- Produces:
```dart
class ThumbnailGenerator {
  ThumbnailGenerator({
    required MediaSourceResolverRegistry registry,
    required MediaCacheStore cache,
  });
  static const int maxDimension = 512;
  static const int jpegQuality = 80;
  /// A staged temp file holding a <=512px JPEG, or null on any failure.
  /// Never throws (thumbnails are best-effort; spec section 9 step 4).
  Future<File?> generateFor(MediaItem item);
}
```
Behavior: `resolveThumbnail(item, target: Size(512, 512))` first. `BytesData` -> already a compressed thumbnail, write bytes to a staging file as-is. `FileData` -> decode with `img.decodeImage`, `copyResize` so the longest side is 512 (no upscale), re-encode `encodeJpg(quality: 80)` (re-encoding drops EXIF, including GPS, from the thumb). `UnavailableData`/`NetworkData`/decode failure -> null.

- [ ] **Step 1: Write the failing test**

Create `test/features/media_store/thumbnail_generator_test.dart`. Reuse `FakeLocalFileResolver` (test/features/media_store/support/) and the 1x1 PNG from the fallback widget test:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/thumbnail_generator.dart';

import 'support/fake_local_file_resolver.dart';

const _onePixelPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpe'
    'qz8AAAAASUVORK5CYII=';

void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late MediaCacheStore cache;
  late FakeLocalFileResolver resolver;
  late ThumbnailGenerator generator;

  setUp(() async {
    db = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('thumb_gen_test');
    cache = MediaCacheStore(database: db, root: root);
    resolver = FakeLocalFileResolver();
    generator = ThumbnailGenerator(
      registry: MediaSourceResolverRegistry({
        MediaSourceType.localFile: resolver,
      }),
      cache: cache,
    );
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  MediaItem item() => MediaItem(
    id: 'm1',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    originalFilename: 'reef.png',
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('BytesData passes through untouched (gallery thumbnails are already '
      'compressed)', () async {
    final bytes = base64Decode(_onePixelPngBase64);
    resolver.data = BytesData(bytes: bytes);
    final file = await generator.generateFor(item());
    expect(file, isNotNull);
    expect(await file!.readAsBytes(), bytes);
  });

  test('FileData full-size photos are resized to <=512 and re-encoded as '
      'JPEG', () async {
    // A real 800x600 PNG generated with package:image.
    final large = img.Image(width: 800, height: 600);
    img.fill(large, color: img.ColorRgb8(10, 60, 200));
    final src = File('${root.path}/large.png');
    await src.writeAsBytes(img.encodePng(large), flush: true);
    resolver.data = FileData(file: src);

    final file = await generator.generateFor(item());
    expect(file, isNotNull);
    final decoded = img.decodeImage(await file!.readAsBytes());
    expect(decoded, isNotNull);
    expect(decoded!.width, 512);
    expect(decoded.height, lessThanOrEqualTo(512));
    // JPEG magic bytes.
    final head = await file.openRead(0, 2).first;
    expect(head, [0xFF, 0xD8]);
  });

  test('small images are not upscaled', () async {
    final small = img.Image(width: 64, height: 48);
    img.fill(small, color: img.ColorRgb8(0, 0, 0));
    final src = File('${root.path}/small.png');
    await src.writeAsBytes(img.encodePng(small), flush: true);
    resolver.data = FileData(file: src);

    final file = await generator.generateFor(item());
    final decoded = img.decodeImage(await file!.readAsBytes())!;
    expect(decoded.width, 64);
  });

  test('unavailable source and undecodable bytes yield null', () async {
    resolver.data = const UnavailableData(kind: UnavailableKind.notFound);
    expect(await generator.generateFor(item()), isNull);

    final junk = File('${root.path}/junk.png')
      ..writeAsBytesSync([1, 2, 3, 4]);
    resolver.data = FileData(file: junk);
    expect(await generator.generateFor(item()), isNull);
  });
}
```


- [ ] **Step 2: Run to verify it fails**

Run: `set -o pipefail; flutter test test/features/media_store/thumbnail_generator_test.dart 2>&1 | tail -3`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

Create `lib/features/media_store/data/thumbnail_generator.dart`:

```dart
import 'dart:io';
import 'dart:ui' show Size;

import 'package:image/image.dart' as img;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

/// Best-effort thumbnail production for the upload pipeline (design spec
/// section 9 step 4). Gallery sources hand back pre-compressed thumbnail
/// bytes; file sources are decoded and resized here. Re-encoding drops
/// EXIF (including GPS) from the thumb. Failure never blocks the
/// original's upload: every error path returns null.
class ThumbnailGenerator {
  ThumbnailGenerator({
    required MediaSourceResolverRegistry registry,
    required MediaCacheStore cache,
  }) : _registry = registry,
       _cache = cache;

  final MediaSourceResolverRegistry _registry;
  final MediaCacheStore _cache;
  final _log = LoggerService.forClass(ThumbnailGenerator);

  static const int maxDimension = 512;
  static const int jpegQuality = 80;

  Future<File?> generateFor(MediaItem item) async {
    try {
      final resolver = _registry.resolverFor(item.sourceType);
      final data = await resolver.resolveThumbnail(
        item,
        target: const Size(
          maxDimension.toDouble(),
          maxDimension.toDouble(),
        ),
      );
      switch (data) {
        case BytesData(bytes: final b):
          final staged = await _cache.stagingFile();
          await staged.writeAsBytes(b, flush: true);
          return staged;
        case FileData(file: final f):
          return _resizeToJpeg(await f.readAsBytes());
        case NetworkData():
        case UnavailableData():
          return null;
      }
    } on Exception catch (e) {
      _log.warning('Thumbnail generation failed for ${item.id}: $e');
      return null;
    }
  }

  Future<File?> _resizeToJpeg(List<int> bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final longest = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    final resized = longest > maxDimension
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? maxDimension : null,
            height: decoded.height > decoded.width ? maxDimension : null,
          )
        : decoded;
    final staged = await _cache.stagingFile();
    await staged.writeAsBytes(
      img.encodeJpg(resized, quality: jpegQuality),
      flush: true,
    );
    return staged;
  }
}
```

NOTE: `const Size(maxDimension.toDouble(), ...)` is not a constant expression; write it as `Size(maxDimension.toDouble(), maxDimension.toDouble())` without `const`. (Called out so the first compile error is not a surprise.)

- [ ] **Step 4: Run to verify it passes**

Run: `set -o pipefail; flutter test test/features/media_store/thumbnail_generator_test.dart 2>&1 | tail -3`
Expected: PASS (4 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add -A
git commit -m "feat(media-store): thumbnail generator"
```

---

### Task 5: Thumbnail step in the upload pipeline

**Files:**
- Modify: `lib/features/media_store/data/media_upload_pipeline.dart` (constructor + `process`)
- Modify: `lib/features/media/data/repositories/media_repository.dart` (new stamp method, next to `stampRemoteUploaded`)
- Modify: `lib/features/media_store/presentation/providers/media_store_providers.dart` (pipeline construction)
- Test: modify `test/features/media_store/media_upload_pipeline_test.dart`
- Test: modify `test/features/media/data/media_repository_store_stamps_test.dart`

**Interfaces:**
- Consumes: Task 4 `ThumbnailGenerator.generateFor`.
- Produces:
```dart
// MediaRepository:
Future<void> stampRemoteThumbUploaded(String mediaId, {required DateTime uploadedAt});
// MediaUploadPipeline constructor gains:
//   required ThumbnailGenerator thumbnails,
// process(): after the content-identity stamp and BEFORE the original's
// head/put: generate thumb -> head(thumbKey) dedup -> putFile(thumbKey,
// contentType 'image/jpeg') -> stampRemoteThumbUploaded -> delete staged
// thumb. Wrapped in its own try/catch: thumb failure logs and continues.
```
Thumbs upload BEFORE originals (spec section 9 step 5: remote devices get something renderable fast). The thumb is keyed by the ORIGINAL's content hash (`StoreKeys.thumbKey(digest.hash)`).

- [ ] **Step 1: Write the failing tests**

Repository stamp test - append to `media_repository_store_stamps_test.dart`:

```dart
  test('stampRemoteThumbUploaded round-trips', () async {
    final created = await repository.createMedia(localFileItem('/tmp/t.jpg'));
    await repository.stampRemoteThumbUploaded(
      created.id,
      uploadedAt: DateTime(2026, 7, 10, 13),
    );
    final loaded = await repository.getMediaById(created.id);
    expect(loaded!.remoteThumbUploadedAt, DateTime(2026, 7, 10, 13));
    expect(loaded.remoteUploadedAt, isNull);
  });
```

Pipeline tests - in `media_upload_pipeline_test.dart`, the pipeline construction in `setUp` gains `thumbnails: ThumbnailGenerator(registry: ..., cache: cache)` built over the SAME fake registry instance (extract the registry into a local `registry` variable used by both). Then append:

```dart
  test('thumb object uploads before the original and stamps '
      'remoteThumbUploadedAt', () async {
    final id = await enqueueLocalFileItem(bytes: pngBytes(), name: 'a.png');
    final entry = (await queue.nextPending(DateTime.now()))!;
    expect(await pipeline.process(entry), UploadOutcome.uploaded);

    final item = (await mediaRepository.getMediaById(id))!;
    expect(item.remoteThumbUploadedAt, isNotNull);
    final thumbKey =
        'smv1/thumbs/${item.contentHash!.substring(0, 2)}/'
        '${item.contentHash}.jpg';
    expect(fakeStore.objects.containsKey(thumbKey), isTrue);
    expect(fakeStore.objects, hasLength(2));
  });

  test('thumb failure never blocks the original upload', () async {
    // UnavailableData from resolveThumbnail is impossible with the fake
    // (same data field feeds both) - instead feed undecodable bytes so the
    // resize path fails while the original path still materializes.
    final id = await enqueueLocalFileItem(bytes: [1, 2, 3], name: 'a.jpg');
    final entry = (await queue.nextPending(DateTime.now()))!;
    expect(await pipeline.process(entry), UploadOutcome.uploaded);

    final item = (await mediaRepository.getMediaById(id))!;
    expect(item.remoteUploadedAt, isNotNull);
    expect(item.remoteThumbUploadedAt, isNull);
    expect(fakeStore.objects, hasLength(1));
  });
```

with a file-local helper (the 1x1 PNG used across media-store tests):

```dart
List<int> pngBytes() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpe'
  'qz8AAAAASUVORK5CYII=',
);
```
(add `import 'dart:convert';` and `import 'package:submersion/features/media_store/data/thumbnail_generator.dart';`).

NOTE: the existing happy-path test asserts `fakeStore.objects[key] == [1, 2, 3]` and the store then contains ONE object; with thumbs, `[1,2,3]` is undecodable so no thumb uploads and that assertion still holds. The dedup test's byte payloads are also undecodable - unchanged. Verify both still pass rather than editing them.

- [ ] **Step 2: Run to verify it fails**

Run: `set -o pipefail; flutter test test/features/media_store/media_upload_pipeline_test.dart test/features/media/data/media_repository_store_stamps_test.dart 2>&1 | tail -3`
Expected: FAIL to compile.

- [ ] **Step 3: Implement the repository stamp**

In `media_repository.dart`, directly after `stampRemoteUploaded`:

```dart
  /// Confirms the thumbnail object exists in the media store.
  Future<void> stampRemoteThumbUploaded(
    String mediaId, {
    required DateTime uploadedAt,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.media)..where((t) => t.id.equals(mediaId))).write(
      MediaCompanion(
        remoteThumbUploadedAt: Value(uploadedAt.millisecondsSinceEpoch),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'media',
      recordId: mediaId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }
```

- [ ] **Step 4: Implement the pipeline step**

In `media_upload_pipeline.dart`: add `required ThumbnailGenerator thumbnails,` to the constructor (`_thumbnails` field + import). In `process()`, after the `stampContentIdentity` block and before `final extension = ...`, insert:

```dart
      // Thumb first (spec section 9 step 5): tiny, so remote devices get
      // something renderable while the original uploads. Best-effort - a
      // thumb failure must never block the original.
      if (item.remoteThumbUploadedAt == null) {
        File? thumb;
        try {
          thumb = await _thumbnails.generateFor(item);
          if (thumb != null) {
            final thumbKey = StoreKeys.thumbKey(digest.hash);
            if (await _store.head(thumbKey) == null) {
              await _store.putFile(
                thumbKey,
                thumb,
                contentType: 'image/jpeg',
              );
            }
            await _mediaRepository.stampRemoteThumbUploaded(
              item.id,
              uploadedAt: _now(),
            );
          }
        } on Exception catch (e) {
          _log.warning('Thumb upload failed for ${item.id}: $e');
        } finally {
          if (thumb != null && await thumb.exists()) {
            await thumb.delete();
          }
        }
      }
```

Update the runtime construction in `media_store_providers.dart`:

```dart
  final registry = ref.watch(mediaSourceResolverRegistryProvider);
  final pipeline = MediaUploadPipeline(
    mediaRepository: mediaRepository,
    queue: MediaTransferQueueRepository(),
    store: store,
    registry: registry,
    cache: cache,
    thumbnails: ThumbnailGenerator(registry: registry, cache: cache),
  );
```
(add the `thumbnail_generator.dart` import; `mediaRepository` local already exists from Task 3).

- [ ] **Step 5: Run to verify it passes**

Run: `set -o pipefail; flutter test test/features/media_store/media_upload_pipeline_test.dart test/features/media/data/media_repository_store_stamps_test.dart test/features/media_store/media_store_end_to_end_test.dart 2>&1 | tail -3`
Expected: PASS (the e2e file also constructs pipelines - the compiler will point at its two construction sites; add the same `thumbnails:` argument there).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add -A
git commit -m "feat(media-store): thumbnail objects in the upload pipeline"
```

---

### Task 6: Resolver thumb routing

**Files:**
- Modify: `lib/features/media/data/resolvers/media_store_resolver.dart`
- Test: modify `test/features/media/data/media_store_resolver_test.dart`

**Interfaces:**
- Consumes: Task 5's populated thumb objects; `StoreKeys.thumbKey`; `MediaCacheKind.thumb`.
- Produces: `tryResolveRemote(item, thumbnail: true)` serves the thumb object when `item.remoteThumbUploadedAt != null` (cache -> download -> cache, NO hash verification: the thumb's bytes are derived, the key carries the ORIGINAL's hash), and falls through to the existing original path when no thumb exists or the thumb fetch fails. `thumbnail: false` behavior is unchanged.

- [ ] **Step 1: Write the failing tests**

Append to `media_store_resolver_test.dart`:

```dart
  test('thumbnail requests serve the thumb object and cache it under the '
      'thumb pool', () async {
    final thumbBytes = 'tiny-thumb'.codeUnits;
    final hash = 'a1${'9' * 62}';
    store.objects[StoreKeys.thumbKey(hash)] = thumbBytes;

    final data = await resolver.tryResolveRemote(
      item(hash: hash, uploadedAt: DateTime(2026)).copyWith(
        remoteThumbUploadedAt: DateTime(2026),
      ),
      thumbnail: true,
    );
    expect(data, isA<FileData>());
    expect(await (data! as FileData).file.readAsBytes(), thumbBytes);
    expect(await cache.get(hash, MediaCacheKind.thumb), isNotNull);
    expect(await cache.get(hash, MediaCacheKind.original), isNull);
  });

  test('thumbnail request falls back to the original when no thumb was '
      'uploaded', () async {
    final bytes = 'submersion'.codeUnits;
    final tmp = File('${root.path}/seed2');
    await tmp.writeAsBytes(bytes, flush: true);
    final digest = await sha256OfFile(tmp);
    store.objects[StoreKeys.objectKey(digest.hash, extension: 'jpg')] = bytes;

    final data = await resolver.tryResolveRemote(
      item(hash: digest.hash, uploadedAt: DateTime(2026)),
      thumbnail: true, // no remoteThumbUploadedAt on the item
    );
    expect(data, isA<FileData>());
    expect(await (data! as FileData).file.readAsBytes(), bytes);
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `set -o pipefail; flutter test test/features/media/data/media_store_resolver_test.dart 2>&1 | tail -3`
Expected: the first new test FAILS (thumb key is never consulted; the resolver 404s on the original and returns null).

- [ ] **Step 3: Implement**

In `media_store_resolver.dart`, replace the body of `tryResolveRemote` with:

```dart
    final hash = item.contentHash;
    if (hash == null || item.remoteUploadedAt == null) return null;
    if (thumbnail && item.remoteThumbUploadedAt != null) {
      final thumb = await _fetchThumb(item, hash);
      if (thumb != null) return thumb;
      // Fall through: a missing/broken thumb degrades to the original.
    }
    return _fetchOriginal(item, hash);
```

with the two private methods (`_fetchOriginal` is the existing logic moved verbatim; `_fetchThumb` is new):

```dart
  Future<MediaSourceData?> _fetchThumb(MediaItem item, String hash) async {
    try {
      final cached = await _cache.get(hash, MediaCacheKind.thumb);
      if (cached != null) return FileData(file: cached);
      final staging = await _cache.stagingFile();
      await _store.getFile(StoreKeys.thumbKey(hash), staging);
      // No hash verification: thumb bytes are derived; the key carries the
      // original's hash purely for addressing.
      final file = await _cache.put(hash, MediaCacheKind.thumb, staging);
      return FileData(file: file);
    } on Exception catch (e) {
      _log.warning('Thumb fetch failed for ${item.id}: $e');
      return null;
    }
  }

  Future<MediaSourceData?> _fetchOriginal(MediaItem item, String hash) async {
    try {
      final cached = await _cache.get(hash, MediaCacheKind.original);
      if (cached != null) return FileData(file: cached);

      final staging = await _cache.stagingFile();
      final extension = StoreKeys.extensionFor(item.originalFilename);
      await _store.getFile(
        StoreKeys.objectKey(hash, extension: extension),
        staging,
      );
      final digest = await sha256OfFile(staging);
      if (digest.hash != hash) {
        _log.warning('Store object failed hash verification for ${item.id}');
        await staging.delete();
        return null;
      }
      final file = await _cache.put(hash, MediaCacheKind.original, staging);
      return FileData(file: file);
    } on Exception catch (e) {
      _log.warning('Store fallback failed for ${item.id}: $e');
      return null;
    }
  }
```

- [ ] **Step 4: Run to verify it passes**

Run: `set -o pipefail; flutter test test/features/media/data/media_store_resolver_test.dart test/features/media/presentation/media_item_view_store_fallback_test.dart 2>&1 | tail -3`
Expected: PASS (the widget fallback test exercises `thumbnail: false` and full-view paths - unchanged).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add -A
git commit -m "feat(media-store): thumbnail routing in store resolution"
```

---

### Task 7: Transfers page, route, l10n

**Files:**
- Create: `lib/features/media_store/presentation/pages/transfers_page.dart`
- Modify: `lib/features/media_store/presentation/providers/media_store_providers.dart` (entries provider)
- Modify: `lib/core/router/app_router.dart` (nested route under `media-storage`, ~line 905)
- Modify: `lib/features/media_store/presentation/pages/media_storage_page.dart` (View Transfers tile when connected)
- Modify: all 11 `lib/l10n/arb/app_*.arb` (script below adds Task 7 AND Task 9 keys in one pass)
- Test: `test/features/media_store/transfers_page_test.dart`

**Interfaces:**
- Consumes: Task 2 `watchEntries/retry/deleteDone`, runtime worker for the post-retry kick.
- Produces:
```dart
// media_store_providers.dart:
final mediaTransferEntriesProvider =
    StreamProvider<List<MediaTransferQueueEntry>>(
      (ref) => MediaTransferQueueRepository().watchEntries(),
    );
final mediaTransferQueueRepositoryProvider =
    Provider<MediaTransferQueueRepository>(
      (ref) => MediaTransferQueueRepository(),
    );
class TransfersPage extends ConsumerWidget { const TransfersPage({super.key}); }
// route name 'mediaStorageTransfers', path 'transfers' nested under the
// 'media-storage' GoRoute; pushed via
// context.push('/settings/media-storage/transfers')
```

- [ ] **Step 1: Add the l10n strings (Tasks 7 + 9 together)**

Write this script to the session scratchpad as `add_media_storage_phase2_l10n.py`, run it from the worktree root with `python3`, then run `flutter gen-l10n`. Same mechanics as Phase 1's script (JSON round-trip preserves key order; verify the diff shows only additions plus benign whitespace):

```python
import json
import collections
import os

ARB_DIR = "lib/l10n/arb"

BASE = {
    "settings_mediaStorage_transfers_title": {
        "en": "Transfers", "de": "Uebertragungen", "es": "Transferencias",
        "fr": "Transferts", "it": "Trasferimenti", "nl": "Overdrachten",
        "pt": "Transferencias", "hu": "Atvitelek", "zh": "传输",
        "ar": "عمليات النقل", "he": "העברות",
    },
    "settings_mediaStorage_transfers_entry": {
        "en": "View transfers", "de": "Uebertragungen anzeigen",
        "es": "Ver transferencias", "fr": "Voir les transferts",
        "it": "Vedi trasferimenti", "nl": "Overdrachten bekijken",
        "pt": "Ver transferencias", "hu": "Atvitelek megtekintese",
        "zh": "查看传输", "ar": "عرض عمليات النقل", "he": "הצג העברות",
    },
    "settings_mediaStorage_transfers_empty": {
        "en": "No transfers", "de": "Keine Uebertragungen",
        "es": "Sin transferencias", "fr": "Aucun transfert",
        "it": "Nessun trasferimento", "nl": "Geen overdrachten",
        "pt": "Sem transferencias", "hu": "Nincs atvitel", "zh": "暂无传输",
        "ar": "لا توجد عمليات نقل", "he": "אין העברות",
    },
    "settings_mediaStorage_transfers_retry": {
        "en": "Retry", "de": "Erneut versuchen", "es": "Reintentar",
        "fr": "Reessayer", "it": "Riprova", "nl": "Opnieuw proberen",
        "pt": "Tentar novamente", "hu": "Ujra", "zh": "重试",
        "ar": "إعادة المحاولة", "he": "נסה שוב",
    },
    "settings_mediaStorage_transfers_clearCompleted": {
        "en": "Clear completed", "de": "Abgeschlossene entfernen",
        "es": "Borrar completadas", "fr": "Effacer les termines",
        "it": "Rimuovi completati", "nl": "Voltooide wissen",
        "pt": "Limpar concluidas", "hu": "Befejezettek torlese",
        "zh": "清除已完成", "ar": "مسح المكتملة", "he": "נקה שהושלמו",
    },
    "settings_mediaStorage_transfers_state_pending": {
        "en": "Waiting", "de": "Wartend", "es": "En espera",
        "fr": "En attente", "it": "In attesa", "nl": "Wachten",
        "pt": "Aguardando", "hu": "Varakozik", "zh": "等待中",
        "ar": "في الانتظار", "he": "ממתין",
    },
    "settings_mediaStorage_transfers_state_transferring": {
        "en": "Uploading", "de": "Wird hochgeladen", "es": "Subiendo",
        "fr": "Envoi en cours", "it": "Caricamento", "nl": "Uploaden",
        "pt": "Enviando", "hu": "Feltoltes", "zh": "上传中",
        "ar": "جارٍ الرفع", "he": "מעלה",
    },
    "settings_mediaStorage_transfers_state_done": {
        "en": "Done", "de": "Fertig", "es": "Completado", "fr": "Termine",
        "it": "Completato", "nl": "Klaar", "pt": "Concluido", "hu": "Kesz",
        "zh": "已完成", "ar": "تم", "he": "הושלם",
    },
    "settings_mediaStorage_transfers_state_failed": {
        "en": "Failed", "de": "Fehlgeschlagen", "es": "Fallido",
        "fr": "Echec", "it": "Non riuscito", "nl": "Mislukt", "pt": "Falhou",
        "hu": "Sikertelen", "zh": "失败", "ar": "فشل", "he": "נכשל",
    },
    "settings_mediaStorage_backfill_action": {
        "en": "Upload existing library", "de": "Vorhandene Bibliothek hochladen",
        "es": "Subir biblioteca existente",
        "fr": "Envoyer la bibliotheque existante",
        "it": "Carica libreria esistente", "nl": "Bestaande bibliotheek uploaden",
        "pt": "Enviar biblioteca existente", "hu": "Meglevo konyvtar feltoltese",
        "zh": "上传现有媒体库", "ar": "رفع المكتبة الحالية",
        "he": "העלה ספריה קיימת",
    },
    "settings_mediaStorage_backfill_enqueued": {
        "en": "{count} uploads queued", "de": "{count} Uploads eingereiht",
        "es": "{count} subidas en cola", "fr": "{count} envois en file",
        "it": "{count} caricamenti in coda", "nl": "{count} uploads in wachtrij",
        "pt": "{count} envios na fila", "hu": "{count} feltoltes sorban",
        "zh": "已排队 {count} 个上传", "ar": "{count} عمليات رفع في قائمة الانتظار",
        "he": "{count} העלאות בתור",
    },
    "settings_mediaStorage_policy_autoUpload": {
        "en": "Upload photos automatically", "de": "Fotos automatisch hochladen",
        "es": "Subir fotos automaticamente",
        "fr": "Envoyer les photos automatiquement",
        "it": "Carica foto automaticamente", "nl": "Foto's automatisch uploaden",
        "pt": "Enviar fotos automaticamente",
        "hu": "Fotok automatikus feltoltese", "zh": "自动上传照片",
        "ar": "رفع الصور تلقائيا", "he": "העלה תמונות אוטומטית",
    },
    "settings_mediaStorage_policy_photosOnCellular": {
        "en": "Upload photos on cellular", "de": "Fotos ueber Mobilfunk hochladen",
        "es": "Subir fotos con datos moviles",
        "fr": "Envoyer les photos en cellulaire",
        "it": "Carica foto su rete mobile", "nl": "Foto's uploaden via mobiel",
        "pt": "Enviar fotos pela rede movel",
        "hu": "Fotok feltoltese mobilhalozaton", "zh": "使用蜂窝数据上传照片",
        "ar": "رفع الصور عبر شبكة الجوال", "he": "העלה תמונות ברשת סלולרית",
    },
}

META = {
    "@settings_mediaStorage_backfill_enqueued": {
        "placeholders": {"count": {"type": "int"}}
    }
}

LOCALES = ["en", "de", "es", "fr", "it", "nl", "pt", "hu", "zh", "ar", "he"]
for locale in LOCALES:
    path = os.path.join(ARB_DIR, f"app_{locale}.arb")
    with open(path, encoding="utf-8") as f:
        data = json.load(f, object_pairs_hook=collections.OrderedDict)
    for key, per_locale in BASE.items():
        data[key] = per_locale[locale]
        if locale == "en" and f"@{key}" in META:
            data[f"@{key}"] = META[f"@{key}"]
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"updated {path}")
```

Before running: restore proper diacritics in the de/es/fr/it/hu/pt strings above (Uebertragungen -> Übertragungen, Reessayer -> Réessayer, automaticamente -> automáticamente, Termine -> Terminé, Echec -> Échec, and the Hungarian long vowels: Átvitelek, Újra, Kész, Várakozik, Feltöltés, Meglévő könyvtár feltöltése, Fotók automatikus feltöltése, Fotók feltöltése mobilhálózaton; nl kopieren-style forms are fine as written). The arb files are UTF-8; ASCII-folding is a plan-authoring artifact, not a target state.

Run: `python3 <scratchpad>/add_media_storage_phase2_l10n.py && flutter gen-l10n`
Expected: 11 files updated; `git diff --stat lib/l10n/arb/` shows only additions plus known whitespace normalization.

- [ ] **Step 2: Write the failing widget test**

Create `test/features/media_store/transfers_page_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/pages/transfers_page.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late LocalCacheDatabase db;
  late MediaTransferQueueRepository repo;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    repo = MediaTransferQueueRepository(database: db);
  });

  tearDown(() => db.close());

  Widget app() => ProviderScope(
    overrides: [
      mediaTransferQueueRepositoryProvider.overrideWithValue(repo),
      mediaTransferEntriesProvider.overrideWith(
        (ref) => repo.watchEntries(),
      ),
      mediaStoreRuntimeProvider.overrideWith((ref) async => null),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TransfersPage(),
    ),
  );

  testWidgets('renders empty state, then entries with states', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    expect(find.text('No transfers'), findsOneWidget);

    await tester.runAsync(() async {
      final a = await repo.enqueueUpload(mediaId: 'm-a');
      await repo.enqueueUpload(mediaId: 'm-b');
      for (var i = 0; i < 5; i++) {
        await repo.markFailed(a, 'no route to host');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });

    expect(find.text('Waiting'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('no route to host'), findsOneWidget);
  });

  testWidgets('retry button resets a failed entry', (tester) async {
    late int failedId;
    await tester.runAsync(() async {
      failedId = await repo.enqueueUpload(mediaId: 'm-a');
      for (var i = 0; i < 5; i++) {
        await repo.markFailed(failedId, 'boom');
      }
      await tester.pumpWidget(app());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });

    await tester.tap(find.text('Retry'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });

    final row = (await repo.allForTesting()).single;
    expect(row.state, 'pending');
  });
}
```

- [ ] **Step 3: Run to verify it fails, then implement**

Run: `set -o pipefail; flutter test test/features/media_store/transfers_page_test.dart 2>&1 | tail -3` -> FAIL to compile.

Add the two providers from the Interfaces block to `media_store_providers.dart`. Create `transfers_page.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Queue visibility (design spec section 9): active, waiting, and failed
/// transfers with per-entry retry and a clear-completed action.
class TransfersPage extends ConsumerWidget {
  const TransfersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final entries = ref.watch(mediaTransferEntriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings_mediaStorage_transfers_title),
        actions: [
          IconButton(
            key: const Key('transfers-clear-done'),
            tooltip: l10n.settings_mediaStorage_transfers_clearCompleted,
            icon: const Icon(Icons.clear_all),
            onPressed: () =>
                ref.read(mediaTransferQueueRepositoryProvider).deleteDone(),
          ),
        ],
      ),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) => rows.isEmpty
            ? Center(child: Text(l10n.settings_mediaStorage_transfers_empty))
            : ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    _TransferTile(entry: rows[index]),
              ),
      ),
    );
  }
}

class _TransferTile extends ConsumerWidget {
  const _TransferTile({required this.entry});

  final MediaTransferQueueEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final (icon, label) = switch (entry.state) {
      'transferring' => (
        Icons.cloud_upload,
        l10n.settings_mediaStorage_transfers_state_transferring,
      ),
      'failed' => (
        Icons.error_outline,
        l10n.settings_mediaStorage_transfers_state_failed,
      ),
      'done' => (
        Icons.cloud_done,
        l10n.settings_mediaStorage_transfers_state_done,
      ),
      _ => (
        Icons.schedule,
        l10n.settings_mediaStorage_transfers_state_pending,
      ),
    };
    return ListTile(
      leading: Icon(
        icon,
        color: entry.state == 'failed'
            ? Theme.of(context).colorScheme.error
            : null,
      ),
      title: Text(label),
      subtitle: entry.errorMessage != null
          ? Text(entry.errorMessage!, maxLines: 2)
          : Text(entry.mediaId, maxLines: 1),
      trailing: entry.state == 'failed'
          ? TextButton(
              onPressed: () async {
                await ref
                    .read(mediaTransferQueueRepositoryProvider)
                    .retry(entry.id);
                final runtime = await ref.read(
                  mediaStoreRuntimeProvider.future,
                );
                await runtime?.worker?.drain();
              },
              child: Text(l10n.settings_mediaStorage_transfers_retry),
            )
          : null,
    );
  }
}
```

Router (`app_router.dart`): give the `media-storage` GoRoute a `routes:` list, mirroring `cloud-sync`'s nesting:

```dart
              GoRoute(
                path: 'media-storage',
                name: 'mediaStorage',
                builder: (context, state) => const MediaStoragePage(),
                routes: [
                  GoRoute(
                    path: 'transfers',
                    name: 'mediaStorageTransfers',
                    builder: (context, state) => const TransfersPage(),
                  ),
                ],
              ),
```
(import `transfers_page.dart`). In `media_storage_page.dart`, inside the `if (connected) ...[` block before the disconnect button, add:

```dart
              const SizedBox(height: 8),
              ListTile(
                key: const Key('media-s3-transfers'),
                leading: const Icon(Icons.swap_vert),
                title: Text(l10n.settings_mediaStorage_transfers_entry),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.push('/settings/media-storage/transfers'),
              ),
```
(`context.push` needs `import 'package:go_router/go_router.dart';`).

- [ ] **Step 4: Run, format, analyze, commit**

```bash
set -o pipefail
flutter test test/features/media_store/transfers_page_test.dart 2>&1 | tail -3
dart format . && flutter analyze
git add -A
git commit -m "feat(media-store): transfers view with retry"
```

---

### Task 8: Gallery status badges

**Files:**
- Create: `lib/features/media_store/presentation/widgets/media_store_badge.dart`
- Modify: `lib/features/media_store/presentation/providers/media_store_providers.dart` (badge state provider)
- Modify: `lib/features/media/presentation/widgets/dive_media_section.dart` (tile Stack, MediaItemView at ~line 515)
- Test: `test/features/media_store/media_store_badge_test.dart`

**Interfaces:**
- Consumes: Task 2 `watchLatestForMedia`.
- Produces:
```dart
enum MediaBadgeState { none, queued, transferring, failed }

// media_store_providers.dart:
final mediaBadgeStateProvider =
    StreamProvider.family<MediaBadgeState, MediaItem>((ref, item) { ... });
// Semantics (quiet-on-success, spec section 9): no runtime -> none;
// row failed -> failed; row transferring -> transferring; row pending ->
// queued; otherwise (done, no row, or already uploaded) -> none.

class MediaStoreBadge extends ConsumerWidget {
  const MediaStoreBadge({super.key, required this.item});
  final MediaItem item;
  // renders SizedBox.shrink() for none; otherwise a 20px circle avatar
  // with schedule / cloud_upload / error icon. Key('media-store-badge').
}
```

- [ ] **Step 1: Write the failing test**

Create `test/features/media_store/media_store_badge_test.dart` - drive the provider directly (widget rendering is trivial; the mapping is the logic):

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/widgets/media_store_badge.dart';

void main() {
  late LocalCacheDatabase db;
  late MediaTransferQueueRepository repo;
  late ProviderContainer container;

  MediaItem item() => MediaItem(
    id: 'm1',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    repo = MediaTransferQueueRepository(database: db);
    container = ProviderContainer(
      overrides: [
        mediaTransferQueueRepositoryProvider.overrideWithValue(repo),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<MediaBadgeState> read(MediaItem i) =>
      container.read(mediaBadgeStateProvider(i).future);

  test('no row means none', () async {
    expect(await read(item()), MediaBadgeState.none);
  });

  test('pending row means queued; transferring and failed map through; '
      'done means none', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    expect(await read(item()), MediaBadgeState.queued);

    await repo.markTransferring(id);
    expect(await read(item()), MediaBadgeState.transferring);

    for (var i = 0; i < 5; i++) {
      await repo.markFailed(id, 'x');
    }
    expect(await read(item()), MediaBadgeState.failed);

    await repo.retry(id);
    await repo.markDone(id);
    expect(await read(item()), MediaBadgeState.none);
  });
}
```

The `MediaBadgeState` enum lives in `media_store_badge.dart`. NOTE: `mediaBadgeStateProvider(i).future` on a StreamProvider resolves with the FIRST emission; each assertion above re-reads after a mutation, and drift streams re-query per new listener, so first-emission reads are deterministic here.

- [ ] **Step 2: Run to verify it fails, then implement**

Run -> FAIL to compile. Create `media_store_badge.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

/// Transfer status of one media item, for tile overlays. Quiet on
/// success: steady state renders nothing (design spec section 9).
enum MediaBadgeState { none, queued, transferring, failed }

class MediaStoreBadge extends ConsumerWidget {
  const MediaStoreBadge({super.key, required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref.watch(mediaBadgeStateProvider(item)).value ??
        MediaBadgeState.none;
    if (state == MediaBadgeState.none) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final (icon, background) = switch (state) {
      MediaBadgeState.failed => (Icons.error_outline, scheme.errorContainer),
      MediaBadgeState.transferring => (
        Icons.cloud_upload,
        scheme.primaryContainer,
      ),
      _ => (Icons.schedule, scheme.surfaceContainerHighest),
    };
    return CircleAvatar(
      key: const Key('media-store-badge'),
      radius: 10,
      backgroundColor: background.withValues(alpha: 0.9),
      child: Icon(icon, size: 13),
    );
  }
}
```

Provider in `media_store_providers.dart` (import `media_store_badge.dart`):

```dart
/// Per-tile transfer status. Watches the newest queue row for the item;
/// quiet (none) for done, absent, or already-uploaded rows.
final mediaBadgeStateProvider =
    StreamProvider.family<MediaBadgeState, MediaItem>((ref, item) {
      return ref
          .watch(mediaTransferQueueRepositoryProvider)
          .watchLatestForMedia(item.id)
          .map((row) {
            switch (row?.state) {
              case 'failed':
                return MediaBadgeState.failed;
              case 'transferring':
                return MediaBadgeState.transferring;
              case 'pending':
                return MediaBadgeState.queued;
              default:
                return MediaBadgeState.none;
            }
          });
    });
```

- [ ] **Step 3: Integrate into the dive media tiles**

Read `lib/features/media/presentation/widgets/dive_media_section.dart` around lines 505-545 to see the tile `Stack` (children: `MediaItemView`, selection dimming overlay, selection border overlay). Append as the LAST child of that Stack:

```dart
            Positioned(
              top: 4,
              right: 4,
              child: MediaStoreBadge(item: item),
            ),
```
with the import `package:submersion/features/media_store/presentation/widgets/media_store_badge.dart`.

- [ ] **Step 4: Run, format, analyze, commit**

```bash
set -o pipefail
flutter test test/features/media_store/media_store_badge_test.dart 2>&1 | tail -3
flutter test test/features/media/ 2>&1 | tail -1
dart format . && flutter analyze
git add -A
git commit -m "feat(media-store): per-tile transfer badges"
```
Expected: all PASS (the media suite catches any dive_media_section widget-test fallout; badge provider returns none in those tests because no queue rows exist - but if a dive_media_section test fails on an unexpected provider, override `mediaBadgeStateProvider` is NOT needed: the default `MediaTransferQueueRepository()` hits `LocalCacheDatabaseService.instance.database`, which throws StateError in tests that never initialized it. If that surfaces, make `mediaBadgeStateProvider` defensive: wrap the stream construction in try/catch and return `Stream.value(MediaBadgeState.none)` on StateError - that behavior is correct in production too, where the local cache DB always initializes at startup).

---

### Task 9: Backfill + policy toggles on the Media Storage page

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart` (backfill query)
- Create: `lib/features/media_store/data/media_backfill_service.dart`
- Modify: `lib/features/media_store/presentation/pages/media_storage_page.dart` (connected-state section)
- Modify: `lib/features/media_store/presentation/providers/media_store_providers.dart` (backfill + active-count providers)
- Test: `test/features/media_store/media_backfill_service_test.dart`

**Interfaces:**
- Consumes: Tasks 1-3 (policies, queue, worker), l10n keys from Task 7's script.
- Produces:
```dart
// MediaRepository:
Future<List<String>> getBackfillCandidateIds();
// photos only (fileType 'photo'), sourceType IN (platformGallery,
// localFile), remote_uploaded_at IS NULL, ORDER BY taken_at DESC

class MediaBackfillService {
  MediaBackfillService({
    required MediaRepository mediaRepository,
    required MediaTransferQueueRepository queue,
  });
  Future<int> enqueueAll(); // enqueues every candidate; returns count
}

// media_store_providers.dart:
final mediaBackfillServiceProvider = Provider<MediaBackfillService>(...);
final mediaTransferActiveCountProvider = StreamProvider<int>(
  (ref) => ref.watch(mediaTransferQueueRepositoryProvider).watchActiveCount(),
);
```
Page additions (inside the existing `if (connected) ...[` block): two `SwitchListTile`s bound to `MediaStorePolicies` (local `FutureBuilder`-free pattern: read initial values in `initState` into nullable bools, render switches once loaded, write-through on change), the backfill `FilledButton.tonal` (`Key('media-s3-backfill')`) that calls `enqueueAll()`, shows `settings_mediaStorage_backfill_enqueued(count)` in a SnackBar, then kicks `runtime.worker.drain()`; and a progress row that renders `mediaTransferActiveCountProvider` as `LinearProgressIndicator` + count text while count > 0.

- [ ] **Step 1: Write the failing service test**

Create `test/features/media_store/media_backfill_service_test.dart` (main-DB harness like the pipeline test):

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain;
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_backfill_service.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

import '../../helpers/test_database.dart';

void main() {
  late MediaRepository mediaRepository;
  late LocalCacheDatabase cacheDb;
  late MediaTransferQueueRepository queue;
  late MediaBackfillService service;

  setUp(() async {
    await setUpTestDatabase();
    mediaRepository = MediaRepository();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    queue = MediaTransferQueueRepository(database: cacheDb);
    service = MediaBackfillService(
      mediaRepository: mediaRepository,
      queue: queue,
    );
  });

  tearDown(() async {
    await cacheDb.close();
    await tearDownTestDatabase();
  });

  Future<domain.MediaItem> mediaRow({
    required String name,
    domain.MediaType mediaType = domain.MediaType.photo,
    MediaSourceType sourceType = MediaSourceType.localFile,
    DateTime? takenAt,
    DateTime? uploadedAt,
  }) async {
    final created = await mediaRepository.createMedia(
      domain.MediaItem(
        id: '',
        mediaType: mediaType,
        sourceType: sourceType,
        filePath: '/tmp/$name',
        localPath: '/tmp/$name',
        originalFilename: name,
        takenAt: takenAt ?? DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    if (uploadedAt != null) {
      await mediaRepository.stampRemoteUploaded(
        created.id,
        uploadedAt: uploadedAt,
      );
    }
    return created;
  }

  test('enqueues device-resident photos without a remote stamp, newest '
      'first, skipping videos, signatures, network sources, and uploaded '
      'rows', () async {
    final old = await mediaRow(name: 'old.jpg', takenAt: DateTime(2025));
    final recent = await mediaRow(name: 'new.jpg', takenAt: DateTime(2026, 6));
    await mediaRow(name: 'clip.mp4', mediaType: domain.MediaType.video);
    await mediaRow(name: 'sig.png',
        mediaType: domain.MediaType.instructorSignature);
    await mediaRow(name: 'net.jpg', sourceType: MediaSourceType.networkUrl);
    await mediaRow(name: 'up.jpg', uploadedAt: DateTime(2026, 7));

    final ids = await mediaRepository.getBackfillCandidateIds();
    expect(ids, [recent.id, old.id]);

    expect(await service.enqueueAll(), 2);
    final rows = await queue.allForTesting();
    expect(rows.map((r) => r.mediaId).toSet(), {recent.id, old.id});

    // Idempotent: re-running does not duplicate pending rows.
    expect(await service.enqueueAll(), 2);
    expect((await queue.allForTesting()).length, 2);
  });
}
```

- [ ] **Step 2: Run to verify it fails, then implement**

Run -> FAIL to compile. Repository query (append near `getMediaById`):

```dart
  /// Backfill candidates (design spec section 9): device-resident photos
  /// not yet confirmed in the media store, newest first so recent dives
  /// gain protection soonest.
  Future<List<String>> getBackfillCandidateIds() async {
    final id = _db.media.id;
    final query = _db.selectOnly(_db.media)
      ..addColumns([id])
      ..where(
        _db.media.remoteUploadedAt.isNull() &
            _db.media.fileType.equals('photo') &
            _db.media.sourceType.isIn(['platformGallery', 'localFile']),
      )
      ..orderBy([OrderingTerm.desc(_db.media.takenAt)]);
    final rows = await query.get();
    return rows.map((r) => r.read(id)!).toList();
  }
```

`media_backfill_service.dart`:

```dart
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

/// "Upload existing library" (design spec section 9 trigger 2). Enqueues
/// every eligible photo; enqueueUpload is idempotent per media id, so
/// re-running is safe.
class MediaBackfillService {
  MediaBackfillService({
    required MediaRepository mediaRepository,
    required MediaTransferQueueRepository queue,
  }) : _mediaRepository = mediaRepository,
       _queue = queue;

  final MediaRepository _mediaRepository;
  final MediaTransferQueueRepository _queue;
  final _log = LoggerService.forClass(MediaBackfillService);

  Future<int> enqueueAll() async {
    final ids = await _mediaRepository.getBackfillCandidateIds();
    for (final id in ids) {
      await _queue.enqueueUpload(mediaId: id);
    }
    _log.info('Backfill enqueued ${ids.length} items');
    return ids.length;
  }
}
```
Providers and the page section per the Interfaces block; backfill button handler:

```dart
  Future<void> _backfill() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final count = await ref.read(mediaBackfillServiceProvider).enqueueAll();
      if (!mounted) return;
      _showSnack(l10n.settings_mediaStorage_backfill_enqueued(count));
      final runtime = await ref.read(mediaStoreRuntimeProvider.future);
      unawaited(runtime?.worker?.drain());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
```
(`import 'dart:async';` for `unawaited`).

- [ ] **Step 3: Run, format, analyze, commit**

```bash
set -o pipefail
flutter test test/features/media_store/media_backfill_service_test.dart 2>&1 | tail -3
flutter test test/features/media_store/media_storage_page_test.dart 2>&1 | tail -3
dart format . && flutter analyze
git add -A
git commit -m "feat(media-store): backfill and transfer policy toggles"
```
(the page test's overrides gain nothing: with `mediaStoreRuntimeProvider` -> null the new section stays hidden, and the existing three tests must still pass unchanged).

---

### Task 10: Phase 2 exit verification + stacked PR

**Files:**
- Test: modify `test/features/media_store/media_store_end_to_end_test.dart` (thumb cross-device case)

- [ ] **Step 1: Extend the e2e test**

Append inside `main` (device fixtures already exist):

```dart
  test('device B grid resolves the thumb object, not the original', () async {
    // Device A uploads a real (decodable) photo so a thumb is produced.
    // Reuse the device-A fixtures from the first test verbatim, but write
    // the 1x1 PNG bytes as the photo content; after drain assert
    // remoteThumbUploadedAt != null and bucket contains BOTH keys. Then on
    // device B: tryResolveRemote(thumbnail: true) returns bytes that are
    // VALID JPEG (0xFF 0xD8 magic) and differ from the original PNG bytes,
    // and the B cache now holds a thumb-pool entry but no original-pool
    // entry.
  });
```
Write the test fully (the comment above specifies every assertion; the first e2e test is the template for the fixtures). This is the spec's Phase 2 exit proof: grids on remote devices never pull originals.

- [ ] **Step 2: Full gates**

```bash
set -o pipefail
flutter test test/features/media_store/ test/core/services/media_store/ 2>&1 | tail -1
flutter test test/features/media/ 2>&1 | tail -1
flutter test test/core/services/sync/ 2>&1 | tail -1
flutter test test/features/settings/ 2>&1 | tail -1
dart format . && flutter analyze
```
Expected: all PASS, no issues.

- [ ] **Step 3: Commit, push, stacked PR**

```bash
git add -A && git commit -m "feat(media-store): phase 2 exit coverage"
git push -u origin worktree-media-store-phase2 --no-verify
env -u GITHUB_TOKEN gh pr create \
  --title "feat(media-store): UX layer, phase 2 (thumbnails, transfers, backfill)" \
  --base worktree-s3-media-store --head worktree-media-store-phase2 \
  --body-file <scratchpad>/pr_body_phase2.md
```
The PR body follows the repo template (Summary / Changes / Test Plan / Screenshots), states it is STACKED on PR #550 (merge #550 first; GitHub retargets this PR to main automatically when the base branch is deleted on merge), and lists the same manual items (MinIO smoke, device smoke) plus new ones: badge/transfers walkthrough on macOS.

## Phase 2 exit criteria (spec section 17)

- [ ] Thumbnail objects uploaded before originals; remote grids consume thumbs
- [ ] Transfers view and per-tile badges reflect queue reality (quiet on success)
- [ ] Backfill enqueues the existing photo library, newest first, idempotently
- [ ] Network gating: offline halts the drain; cellular defers photos when disallowed; videos excluded entirely until Phase 3; connectivity regain re-kicks the drain


