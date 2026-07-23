# Local Media Auto-Upload and Not-Backed-Up Badge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Locally imported media auto-uploads like gallery media does, and media that is not backed up shows a `cloud_off` tile indicator when a media store is attached.

**Architecture:** Four independent slices. A shared pure predicate file (`media_backup_status.dart`) is created first because two later tasks import it. The Files-tab notifier gains an `onMediaCreated` hook mirroring `MediaImportService`. `mediaBadgeStateProvider` gains a settled-state fallback that re-reads the media row rather than trusting the tile's stale snapshot. Backfill drops its photo-only restriction so the new indicator is always clearable.

**Tech Stack:** Flutter 3.x, Riverpod 3, Drift ORM, mockito for generated mocks, `flutter_test`.

**Design spec:** `docs/superpowers/specs/2026-07-23-media-local-upload-badge-design.md`

## Global Constraints

- All Dart code must pass `dart format .` with no changes. Run `dart format .` (whole project, not just changed files) before every commit.
- `flutter analyze` must be clean across the whole project. Never pipe it through `tail` or `head` — that masks the exit code.
- No emojis in code, comments, or documentation.
- No new user-facing strings. The badge stays icon-only; adding text would require translating all 10 non-English locales.
- Immutability: never mutate objects or arrays in place.
- Commit after each task. Do not squash tasks together.
- This work happens in the worktree at `.claude/worktrees/media-local-upload-badge` on branch `worktree-media-local-upload-badge`. Do not `cd` to the main checkout.
- No database schema change. No schema version bump. This plan touches no Drift table definitions.

---

### Task 1: Shared backup-status predicate

Creates the pure predicate both the badge provider (Task 3) and the upload pipeline consume. No Riverpod, no database, so it is directly unit-testable.

**Files:**
- Create: `lib/features/media_store/domain/media_backup_status.dart`
- Modify: `lib/features/media_store/data/media_upload_pipeline.dart:69-73`
- Test: `test/features/media_store/media_backup_status_test.dart`

**Interfaces:**
- Consumes: `MediaItem`, `MediaType`, `MediaSourceType` (all pre-existing).
- Produces:
  - `const Set<MediaSourceType> kUploadableSources`
  - `bool isBackedUp(MediaItem item)`
  - `bool isThumbOnlyMedia(MediaItem item)`

- [ ] **Step 1: Write the failing test**

Create `test/features/media_store/media_backup_status_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/domain/media_backup_status.dart';

void main() {
  MediaItem item({
    MediaType mediaType = MediaType.photo,
    MediaSourceType sourceType = MediaSourceType.localFile,
    DateTime? remoteUploadedAt,
    DateTime? remoteCompressedUploadedAt,
    DateTime? remoteThumbUploadedAt,
  }) => MediaItem(
    id: 'm1',
    mediaType: mediaType,
    sourceType: sourceType,
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    remoteUploadedAt: remoteUploadedAt,
    remoteCompressedUploadedAt: remoteCompressedUploadedAt,
    remoteThumbUploadedAt: remoteThumbUploadedAt,
  );

  final stamp = DateTime(2026, 6, 1);

  group('isBackedUp', () {
    test('false when every remote stamp is null', () {
      expect(isBackedUp(item()), isFalse);
    });

    test('true on remoteUploadedAt alone', () {
      expect(isBackedUp(item(remoteUploadedAt: stamp)), isTrue);
    });

    test('true on remoteCompressedUploadedAt alone', () {
      expect(isBackedUp(item(remoteCompressedUploadedAt: stamp)), isTrue);
    });

    test('a thumb stamp alone does not back up a normal photo', () {
      expect(isBackedUp(item(remoteThumbUploadedAt: stamp)), isFalse);
    });

    test('a connector video is backed up by its thumb stamp alone', () {
      expect(
        isBackedUp(
          item(
            mediaType: MediaType.video,
            sourceType: MediaSourceType.serviceConnector,
            remoteThumbUploadedAt: stamp,
          ),
        ),
        isTrue,
      );
    });

    test('a connector video with no thumb stamp is not backed up', () {
      expect(
        isBackedUp(
          item(
            mediaType: MediaType.video,
            sourceType: MediaSourceType.serviceConnector,
            remoteUploadedAt: stamp,
          ),
        ),
        isFalse,
      );
    });

    test('a local video follows the original-stamp rule, not thumb-only', () {
      expect(
        isBackedUp(
          item(mediaType: MediaType.video, remoteUploadedAt: stamp),
        ),
        isTrue,
      );
      expect(
        isBackedUp(
          item(mediaType: MediaType.video, remoteThumbUploadedAt: stamp),
        ),
        isFalse,
      );
    });
  });

  group('kUploadableSources', () {
    test('includes the three uploadable sources', () {
      expect(
        kUploadableSources,
        containsAll(<MediaSourceType>[
          MediaSourceType.platformGallery,
          MediaSourceType.localFile,
          MediaSourceType.serviceConnector,
        ]),
      );
    });

    test('excludes sources that are never uploaded', () {
      expect(kUploadableSources, isNot(contains(MediaSourceType.networkUrl)));
      expect(
        kUploadableSources,
        isNot(contains(MediaSourceType.manifestEntry)),
      );
      expect(kUploadableSources, isNot(contains(MediaSourceType.signature)));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media_store/media_backup_status_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:submersion/features/media_store/domain/media_backup_status.dart'`

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/media_store/domain/media_backup_status.dart`:

```dart
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

/// Source types whose items the upload pipeline will carry to a media
/// store. Shared with [MediaUploadPipeline] so the tile badge and the
/// pipeline can never disagree about what is uploadable.
const Set<MediaSourceType> kUploadableSources = {
  MediaSourceType.platformGallery,
  MediaSourceType.localFile,
  MediaSourceType.serviceConnector,
};

/// Connector videos never download their original in v1 (Lightroom spec:
/// match + thumbnail only), so the store carries only their thumb and
/// their backed-up signal is the thumb stamp rather than the original.
bool isThumbOnlyMedia(MediaItem item) =>
    item.sourceType == MediaSourceType.serviceConnector &&
    item.mediaType == MediaType.video;

/// Whether [item] already exists in the attached media store. Mirrors the
/// pipeline's own dedup check so a tile never reports "not backed up" for
/// an item the pipeline would skip as already uploaded.
bool isBackedUp(MediaItem item) => isThumbOnlyMedia(item)
    ? item.remoteThumbUploadedAt != null
    : item.remoteUploadedAt != null ||
          item.remoteCompressedUploadedAt != null;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media_store/media_backup_status_test.dart`
Expected: PASS, all tests green.

- [ ] **Step 5: Point the pipeline at the shared constant**

In `lib/features/media_store/data/media_upload_pipeline.dart`, add to the import block (keep imports alphabetized within the `package:submersion` group):

```dart
import 'package:submersion/features/media_store/domain/media_backup_status.dart';
```

Delete the `_eligibleSources` field (lines 69-73):

```dart
  static const Set<MediaSourceType> _eligibleSources = {
    MediaSourceType.platformGallery,
    MediaSourceType.localFile,
    MediaSourceType.serviceConnector,
  };
```

In `_isEligible` (line 319-324), change the first line from
`if (!_eligibleSources.contains(item.sourceType)) return false;` to:

```dart
    if (!kUploadableSources.contains(item.sourceType)) return false;
```

Replace the body of `_isThumbOnly` (line 81-83) to delegate, keeping the
existing doc comment above it intact:

```dart
  bool _isThumbOnly(MediaItem item) => isThumbOnlyMedia(item);
```

This is a pure move. Pipeline behavior is unchanged.

- [ ] **Step 6: Run the pipeline tests to prove the move changed nothing**

Run:
```bash
flutter test test/features/media_store/media_upload_pipeline_test.dart test/features/media_store/media_upload_pipeline_video_test.dart test/features/media_store/media_upload_pipeline_override_test.dart test/features/media_store/media_upload_pipeline_quality_test.dart
```
Expected: PASS. If any fail, the move was not pure — fix before continuing.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/media_store/domain/media_backup_status.dart lib/features/media_store/data/media_upload_pipeline.dart test/features/media_store/media_backup_status_test.dart
git commit -m "refactor(media): extract shared backup-status predicate

Moves the pipeline's eligible-source set and thumb-only rule into a pure
domain file so the tile badge can apply the same rules without depending
on the pipeline. Behavior unchanged."
```

---

### Task 2: Files-tab import enqueues an upload

The actual bug fix. Locally imported media currently never reaches the transfer queue.

**Files:**
- Modify: `lib/features/media/presentation/providers/files_tab_providers.dart:96-110` (constructor), `:230` (`_persistOne`), `:235-242` (provider)
- Test: `test/features/media/presentation/providers/files_tab_providers_test.dart`

**Interfaces:**
- Consumes: `mediaStoreEnqueueProvider` from `lib/features/media_store/presentation/providers/media_store_enqueue_provider.dart`, type `void Function(String mediaId)`.
- Produces: `FilesTabNotifier({..., void Function(String mediaId)? onMediaCreated})`.

- [ ] **Step 1: Write the failing test**

Append inside the top-level `main()` of
`test/features/media/presentation/providers/files_tab_providers_test.dart`,
as a new `group` at the same level as the existing groups:

```dart
  group('commit enqueues each created row for upload', () {
    test('onMediaCreated fires once per persisted row with the saved id', () async {
      final enqueued = <String>[];
      when(mockPlatform.createBookmark(any))
          .thenAnswer((_) async => Uint8List(0));
      when(mockBookmarkStorage.write(any, any)).thenAnswer((_) async {});
      when(mockRepo.createMedia(any))
          .thenAnswer((_) async => _saved('media-1'));

      final notifier = FilesTabNotifier(
        mediaRepository: mockRepo,
        bookmarkStorage: mockBookmarkStorage,
        platform: mockPlatform,
        onMediaCreated: enqueued.add,
      );
      notifier.setFiles(
        [_ef('/a.jpg')],
        match: MatchedSelection(
          matched: {
            'dive-1': [_ef('/a.jpg')],
          },
          unmatched: const [],
        ),
      );

      final ids = await notifier.commit();

      expect(ids, ['media-1']);
      expect(enqueued, ['media-1']);
    });

    test('a null onMediaCreated does not throw', () async {
      when(mockPlatform.createBookmark(any))
          .thenAnswer((_) async => Uint8List(0));
      when(mockBookmarkStorage.write(any, any)).thenAnswer((_) async {});
      when(mockRepo.createMedia(any))
          .thenAnswer((_) async => _saved('media-2'));

      final notifier = FilesTabNotifier(
        mediaRepository: mockRepo,
        bookmarkStorage: mockBookmarkStorage,
        platform: mockPlatform,
      );
      notifier.setFiles(
        [_ef('/b.jpg')],
        match: MatchedSelection(
          matched: {
            'dive-1': [_ef('/b.jpg')],
          },
          unmatched: const [],
        ),
      );

      await expectLater(notifier.commit(), completion(['media-2']));
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/presentation/providers/files_tab_providers_test.dart`
Expected: FAIL — `No named parameter with the name 'onMediaCreated'`

- [ ] **Step 3: Add the hook to the notifier**

In `lib/features/media/presentation/providers/files_tab_providers.dart`,
change the constructor and add the field:

```dart
  FilesTabNotifier({
    required this.mediaRepository,
    required this.bookmarkStorage,
    required this.platform,
    this.onMediaCreated,
  }) : super(FilesTabState.initial());

  final MediaRepository mediaRepository;
  final LocalBookmarkStorage bookmarkStorage;
  final LocalMediaPlatform platform;

  /// Invoked after every successful createMedia so the media store can
  /// enqueue an upload. Null when no store is configured. Mirrors
  /// [MediaImportService.onMediaCreated]; without it, Files-tab imports
  /// never reach the transfer queue and silently stay local-only.
  final void Function(String mediaId)? onMediaCreated;
```

At the end of `_persistOne`, change:

```dart
    final saved = await mediaRepository.createMedia(item);
    return saved.id;
```

to:

```dart
    final saved = await mediaRepository.createMedia(item);
    onMediaCreated?.call(saved.id);
    return saved.id;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/presentation/providers/files_tab_providers_test.dart`
Expected: PASS

- [ ] **Step 5: Wire the provider**

In the same file, add the import (alphabetized in the `package:submersion` group):

```dart
import 'package:submersion/features/media_store/presentation/providers/media_store_enqueue_provider.dart';
```

Change `filesTabNotifierProvider` from:

```dart
final filesTabNotifierProvider =
    StateNotifierProvider<FilesTabNotifier, FilesTabState>(
      (ref) => FilesTabNotifier(
        mediaRepository: ref.read(mediaRepositoryProvider),
        bookmarkStorage: ref.read(localBookmarkStorageProvider),
        platform: ref.read(localMediaPlatformProvider),
      ),
    );
```

to:

```dart
final filesTabNotifierProvider =
    StateNotifierProvider<FilesTabNotifier, FilesTabState>(
      (ref) => FilesTabNotifier(
        mediaRepository: ref.read(mediaRepositoryProvider),
        bookmarkStorage: ref.read(localBookmarkStorageProvider),
        platform: ref.read(localMediaPlatformProvider),
        onMediaCreated: ref.read(mediaStoreEnqueueProvider),
      ),
    );
```

`mediaStoreEnqueueImplProvider` already no-ops when auto-upload is off or
no store is attached, so this stays inert for users without a store.

- [ ] **Step 6: Run the files-tab and photo-picker tests**

Run:
```bash
flutter test test/features/media/presentation/providers/files_tab_providers_test.dart test/features/media/presentation/widgets/files_tab_test.dart
```
Expected: PASS. If `files_tab_test.dart` fails constructing the provider
because no media store providers are available in its container, add
`mediaStoreEnqueueProvider.overrideWithValue((_) {})` to that test's
overrides rather than changing production code.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/media/presentation/providers/files_tab_providers.dart test/features/media/presentation/providers/files_tab_providers_test.dart test/features/media/presentation/widgets/files_tab_test.dart
git commit -m "fix(media): enqueue Files-tab imports for upload

FilesTabNotifier created media rows without calling any enqueue hook, so
locally imported photos and videos silently never auto-uploaded and stayed
local-only until a manual backfill. Adds the onMediaCreated hook the photo
picker and Lightroom paths already use."
```

---

### Task 3: `notBackedUp` badge state

**Files:**
- Modify: `lib/features/media_store/presentation/widgets/media_store_badge.dart`
- Modify: `lib/features/media_store/presentation/providers/media_store_providers.dart:107-135`
- Test: `test/features/media_store/media_store_badge_test.dart`

**Interfaces:**
- Consumes: `isBackedUp`, `kUploadableSources` from Task 1; `mediaStoreAttachStateProvider` and `mediaRepositoryProvider` (pre-existing).
- Produces: `MediaBadgeState.notBackedUp`; `final FutureProvider<bool> mediaStoreAttachedProvider`.

- [ ] **Step 1: Write the failing test**

In `test/features/media_store/media_store_badge_test.dart`, add these
imports to the existing import block:

```dart
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

import 'media_store_badge_test.mocks.dart';
```

Add above `void main()`:

```dart
@GenerateMocks([MediaRepository])
```

Replace the existing `item()` helper with one that takes stamps, and add a
mock repo plus a container factory. The existing `setUp` keeps building
`container` exactly as it does today — those tests must keep passing
unchanged, which proves the degradation guard works.

```dart
  late MockMediaRepository mockRepo;

  MediaItem item({
    MediaSourceType sourceType = MediaSourceType.localFile,
    DateTime? remoteUploadedAt,
  }) => MediaItem(
    id: 'm1',
    mediaType: MediaType.photo,
    sourceType: sourceType,
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    remoteUploadedAt: remoteUploadedAt,
  );

  /// Container with a media repository and an explicit attach answer, for
  /// the settled-state cases. The default `container` from setUp overrides
  /// neither, which is what exercises the degradation guard.
  ProviderContainer attachedContainer({required bool attached}) =>
      ProviderContainer(
        overrides: [
          mediaTransferQueueRepositoryProvider.overrideWithValue(repo),
          mediaRepositoryProvider.overrideWithValue(mockRepo),
          mediaStoreAttachedProvider.overrideWith((ref) async => attached),
        ],
      );
```

Update `setUp` to add `mockRepo = MockMediaRepository();` before the
container is built.

Generalize `expectBadge` to take an optional container so the new cases can
pass their own:

```dart
  Future<void> expectBadge(
    MediaItem i,
    MediaBadgeState expected, {
    ProviderContainer? using,
  }) async {
    final c = using ?? container;
    final sub = c.listen(mediaBadgeStateProvider(i), (_, _) {});
    try {
      for (var attempt = 0; attempt < 100; attempt++) {
        if (c.read(mediaBadgeStateProvider(i)).value == expected) return;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fail(
        'badge never reached $expected; '
        'last: ${c.read(mediaBadgeStateProvider(i)).value}',
      );
    } finally {
      sub.close();
    }
  }
```

Now add the new tests:

```dart
  group('settled state reflects backup status', () {
    test('no store attached means an unbacked item stays quiet', () async {
      final c = attachedContainer(attached: false);
      addTearDown(c.dispose);
      when(mockRepo.getMediaById('m1')).thenAnswer((_) async => item());
      await expectBadge(item(), MediaBadgeState.none, using: c);
    });

    test('store attached and unbacked means notBackedUp', () async {
      final c = attachedContainer(attached: true);
      addTearDown(c.dispose);
      when(mockRepo.getMediaById('m1')).thenAnswer((_) async => item());
      await expectBadge(item(), MediaBadgeState.notBackedUp, using: c);
    });

    test('store attached and already backed up stays quiet', () async {
      final c = attachedContainer(attached: true);
      addTearDown(c.dispose);
      when(mockRepo.getMediaById('m1')).thenAnswer(
        (_) async => item(remoteUploadedAt: DateTime(2026, 6)),
      );
      await expectBadge(item(), MediaBadgeState.none, using: c);
    });

    test('an ineligible source never shows notBackedUp', () async {
      final c = attachedContainer(attached: true);
      addTearDown(c.dispose);
      final net = item(sourceType: MediaSourceType.networkUrl);
      when(mockRepo.getMediaById('m1')).thenAnswer((_) async => net);
      await expectBadge(net, MediaBadgeState.none, using: c);
    });

    test('an active transfer outranks notBackedUp', () async {
      final c = attachedContainer(attached: true);
      addTearDown(c.dispose);
      when(mockRepo.getMediaById('m1')).thenAnswer((_) async => item());
      final id = await repo.enqueueUpload(mediaId: 'm1');
      await expectBadge(item(), MediaBadgeState.queued, using: c);
      await repo.markTransferring(id);
      await expectBadge(item(), MediaBadgeState.transferring, using: c);
    });

    test(
      'a completed upload clears the badge using the fresh row, not the '
      'stale tile snapshot',
      () async {
        final c = attachedContainer(attached: true);
        addTearDown(c.dispose);
        // The tile still holds the pre-upload snapshot.
        final stale = item();
        when(mockRepo.getMediaById('m1')).thenAnswer((_) async => stale);
        final id = await repo.enqueueUpload(mediaId: 'm1');
        await expectBadge(stale, MediaBadgeState.queued, using: c);

        // The pipeline stamps the row before marking the queue row done.
        when(mockRepo.getMediaById('m1')).thenAnswer(
          (_) async => item(remoteUploadedAt: DateTime(2026, 6)),
        );
        await repo.markDone(id);

        await expectBadge(stale, MediaBadgeState.none, using: c);
      },
    );

    test('an unavailable media repository degrades to none', () async {
      // `container` from setUp overrides neither the media repository nor
      // the attach state, so the settled-state computation throws and the
      // guard must swallow it.
      await expectBadge(item(), MediaBadgeState.none);
    });
  });
```

Finally extend the widget test list at
`test/features/media_store/media_store_badge_test.dart` so `notBackedUp`
renders an avatar — change the `for (final state in [...])` list to:

```dart
    for (final state in [
      MediaBadgeState.queued,
      MediaBadgeState.transferring,
      MediaBadgeState.failed,
      MediaBadgeState.notBackedUp,
    ]) {
```

- [ ] **Step 2: Generate mocks, then run the test to verify it fails**

Run:
```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/features/media_store/media_store_badge_test.dart
```
Expected: FAIL — `notBackedUp` is not a member of `MediaBadgeState`, and
`mediaStoreAttachedProvider` is undefined.

- [ ] **Step 3: Add the enum member and the badge arm**

In `lib/features/media_store/presentation/widgets/media_store_badge.dart`,
extend the enum and its doc comment:

```dart
/// Transfer status of one media item, for tile overlays. Quiet on
/// success: an item that is backed up, or that has no store to back up
/// to, renders nothing (design spec section 9).
enum MediaBadgeState { none, queued, transferring, failed, notBackedUp }
```

Add the `notBackedUp` arm to the switch. Order matters only for
readability here; the priority ladder lives in the provider:

```dart
    final (icon, background) = switch (state) {
      MediaBadgeState.failed => (Icons.error_outline, scheme.errorContainer),
      MediaBadgeState.transferring => (
        Icons.cloud_upload,
        scheme.primaryContainer,
      ),
      MediaBadgeState.notBackedUp => (
        Icons.cloud_off,
        scheme.surfaceContainerHighest,
      ),
      _ => (Icons.schedule, scheme.surfaceContainerHighest),
    };
```

- [ ] **Step 4: Add the attach provider and the settled-state fallback**

In `lib/features/media_store/presentation/providers/media_store_providers.dart`,
add the import:

```dart
import 'package:submersion/features/media_store/domain/media_backup_status.dart';
```

Add the attach provider directly above `mediaBadgeStateProvider`:

```dart
/// Whether this device has any media store attached. Deliberately not
/// mediaStoreRuntimeProvider: that constructs the full runtime and kicks a
/// queue drain, which must not happen merely because a media grid scrolled
/// a thumbnail into view. One SharedPreferences read is all the badge needs.
final FutureProvider<bool> mediaStoreAttachedProvider = FutureProvider<bool>((
  ref,
) async {
  final attachState = ref.watch(mediaStoreAttachStateProvider);
  return await attachState.attachedStoreId() != null;
});
```

Replace `mediaBadgeStateProvider` (lines 107-135) in full, doc comment
included, since the old comment's claim that upload stamps are never
consulted is now wrong:

```dart
/// Per-tile badge status. Transient transfer state outranks persistent
/// backup state: failed > transferring > queued > notBackedUp > none.
///
/// A failed, transferring, or pending queue row maps straight through. A
/// done or absent row is a settled item, and settles to notBackedUp only
/// when a store is attached, the source is uploadable, and the item has no
/// upload stamps.
///
/// The settled check re-reads the row rather than trusting [item]: the
/// tile's snapshot comes from mediaForDiveProvider, a FutureProvider that
/// an upload's stamp write does not invalidate, so the snapshot goes stale
/// the moment an upload completes. Re-reading is race-free because the
/// pipeline calls stampRemoteUploaded before markDone, so the emission
/// reporting done always follows the stamp write.
///
/// Defensive against an uninitialized local cache database or an absent
/// media repository (widget tests): any error reads as none.
final mediaBadgeStateProvider =
    StreamProvider.family<MediaBadgeState, MediaItem>((ref, item) async* {
      // Every ref.watch happens before the first await of the row stream:
      // watching after an async gap in an async* body is a Riverpod hazard.
      // The StateError guard covers an uninitialized local cache database,
      // which is the normal case in widget tests.
      final MediaTransferQueueRepository queue;
      try {
        queue = ref.watch(mediaTransferQueueRepositoryProvider);
      } on StateError {
        yield MediaBadgeState.none;
        return;
      }

      final eligible = kUploadableSources.contains(item.sourceType);
      bool attached;
      try {
        attached = await ref.watch(mediaStoreAttachedProvider.future);
      } on Object {
        attached = false;
      }

      // Re-evaluated per settled emission so a just-completed upload
      // clears the badge without waiting for the tile snapshot to refresh.
      Future<MediaBadgeState> settled() async {
        if (!attached || !eligible) return MediaBadgeState.none;
        try {
          final fresh = await ref
              .read(mediaRepositoryProvider)
              .getMediaById(item.id);
          if (fresh == null || isBackedUp(fresh)) return MediaBadgeState.none;
          return MediaBadgeState.notBackedUp;
        } on Object {
          return MediaBadgeState.none;
        }
      }

      await for (final row in queue.watchLatestForMedia(item.id)) {
        switch (row?.state) {
          case 'failed':
            yield MediaBadgeState.failed;
          case 'transferring':
            yield MediaBadgeState.transferring;
          case 'pending':
            yield MediaBadgeState.queued;
          default:
            yield await settled();
        }
      }
    });
```

`media_transfer_queue_repository.dart` (for `MediaTransferQueueRepository`)
and `media_providers.dart` (for `mediaRepositoryProvider`) are already
imported in this file at lines 26 and 19. Do not add duplicate imports.

- [ ] **Step 5: Run the badge tests to verify they pass**

Run: `flutter test test/features/media_store/media_store_badge_test.dart`
Expected: PASS, including the pre-existing tests that were not modified.

- [ ] **Step 6: Run the wider media-store suite for regressions**

Run: `flutter test test/features/media_store/`
Expected: PASS. `media_store_providers_test.dart` and
`media_store_end_to_end_test.dart` are the likeliest to notice the provider
rewrite. If one fails because its container lacks a media repository, that
is the degradation guard not firing — fix the guard, not the test.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/media_store/presentation/widgets/media_store_badge.dart lib/features/media_store/presentation/providers/media_store_providers.dart test/features/media_store/media_store_badge_test.dart test/features/media_store/media_store_badge_test.mocks.dart
git commit -m "feat(media): show a not-backed-up badge on media tiles

Adds MediaBadgeState.notBackedUp, shown only when a store is attached and
the item's source is uploadable. Settled state re-reads the media row
rather than the tile's snapshot, which mediaForDiveProvider does not
refresh when an upload stamps the row."
```

---

### Task 4: Backfill covers non-connector videos

Without this, a local video imported before Task 2 shows `cloud_off` permanently: import-time enqueue only helps new imports, and backfill would skip it.

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart:920-944`
- Test: `test/features/media/data/media_repository_backfill_scope_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: no signature change. `getBackfillCandidateIds()` keeps returning `Future<List<String>>`; only its predicate widens.

- [ ] **Step 1: Write the failing test**

Append inside `main()` of
`test/features/media/data/media_repository_backfill_scope_test.dart`:

```dart
  group('videos are backfill candidates', () {
    test('an unbacked localFile video is a candidate', () async {
      await insertDive('dive-v1');
      final video = await repo.createMedia(
        item(
          'clip.mp4',
          diveId: 'dive-v1',
          mediaType: MediaType.video,
          sourceType: MediaSourceType.localFile,
        ),
      );
      expect(await repo.getBackfillCandidateIds(), contains(video.id));
    });

    test('an unbacked platformGallery video is a candidate', () async {
      await insertDive('dive-v2');
      final video = await repo.createMedia(
        item(
          'clip2.mp4',
          diveId: 'dive-v2',
          mediaType: MediaType.video,
          sourceType: MediaSourceType.platformGallery,
        ),
      );
      expect(await repo.getBackfillCandidateIds(), contains(video.id));
    });

    test('a video that already uploaded is not a candidate', () async {
      await insertDive('dive-v3');
      final video = await repo.createMedia(
        item(
          'clip3.mp4',
          diveId: 'dive-v3',
          mediaType: MediaType.video,
          sourceType: MediaSourceType.localFile,
        ),
      );
      await repo.stampRemoteUploaded(video.id, uploadedAt: DateTime(2026, 6));
      expect(
        await repo.getBackfillCandidateIds(),
        isNot(contains(video.id)),
      );
    });
  });
```

The signature is
`stampRemoteUploaded(String mediaId, {required DateTime uploadedAt})`
(`media_repository.dart:890-893`).

Add a regression test in the same group pinning the connector case, since
this is the branch that could silently loop forever:

```dart
    test(
      'a connector video with an uploaded thumb is not re-enqueued',
      () async {
        await insertDive('dive-v4');
        final video = await repo.createMedia(
          item(
            'connector.mp4',
            diveId: 'dive-v4',
            mediaType: MediaType.video,
            sourceType: MediaSourceType.serviceConnector,
          ),
        );
        await repo.stampRemoteThumbUploaded(
          video.id,
          uploadedAt: DateTime(2026, 6),
        );
        expect(
          await repo.getBackfillCandidateIds(),
          isNot(contains(video.id)),
        );
      },
    );
```

`stampRemoteThumbUploaded` has the same shape as `stampRemoteUploaded`:
`stampRemoteThumbUploaded(String mediaId, {required DateTime uploadedAt})`
(`media_repository.dart:947-950`).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/data/media_repository_backfill_scope_test.dart`
Expected: FAIL — the two "is a candidate" tests fail because the query
restricts every source branch to `fileType = 'photo'`. The already-uploaded
and connector-thumb tests pass already.

- [ ] **Step 3: Widen the query**

In `lib/features/media/data/repositories/media_repository.dart`, change
`getBackfillCandidateIds` from:

```dart
            ((_db.media.remoteUploadedAt.isNull() &
                    _db.media.remoteCompressedUploadedAt.isNull() &
                    _db.media.fileType.equals('photo') &
                    _db.media.sourceType.isIn([
                      'platformGallery',
                      'localFile',
                      'serviceConnector',
                    ])) |
```

to:

```dart
            // Photos from any uploadable source.
            ((_db.media.remoteUploadedAt.isNull() &
                    _db.media.remoteCompressedUploadedAt.isNull() &
                    _db.media.fileType.equals('photo') &
                    _db.media.sourceType.isIn([
                      'platformGallery',
                      'localFile',
                      'serviceConnector',
                    ])) |
                // Gallery and local videos upload their original, so a
                // missing original stamp is their backfill signal. Without
                // this branch a local video could never be uploaded after
                // the fact and would show a permanent not-backed-up badge.
                //
                // serviceConnector is deliberately absent: connector videos
                // are thumb-only and never get remoteUploadedAt, so
                // including them here would re-enqueue them on every
                // backfill run forever. They are covered by the thumb
                // branch below.
                (_db.media.remoteUploadedAt.isNull() &
                    _db.media.remoteCompressedUploadedAt.isNull() &
                    _db.media.fileType.equals('video') &
                    _db.media.sourceType.isIn([
                      'platformGallery',
                      'localFile',
                    ])) |
```

The existing thumb-only branch that follows is unchanged.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/data/media_repository_backfill_scope_test.dart`
Expected: PASS, including all pre-existing assertions in that file.

- [ ] **Step 5: Run the backfill service tests**

Run: `flutter test test/features/media_store/media_backfill_service_test.dart test/features/media/data/`
Expected: PASS

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/media/data/repositories/media_repository.dart test/features/media/data/media_repository_backfill_scope_test.dart
git commit -m "fix(media): include videos in upload backfill candidates

Backfill restricted gallery and local-file candidates to photos, so a
local video could never be uploaded after the fact and would show a
permanent not-backed-up badge. Connector videos keep their thumb-only
branch."
```

---

### Task 5: Full-suite verification

**Files:**
- Modify: none expected.

**Interfaces:**
- Consumes: everything from Tasks 1-4.
- Produces: nothing.

- [ ] **Step 1: Regenerate code**

Branch merges and new mock annotations can leave Drift and mockito output
stale. Run:

```bash
dart run build_runner build --delete-conflicting-outputs
```
Expected: completes, "wrote N outputs".

- [ ] **Step 2: Format the whole project**

Run: `dart format .`
Expected: either "0 changed" or a list of reformatted files. If files
changed, stage them.

- [ ] **Step 3: Analyze the whole project**

Run: `flutter analyze`
Expected: "No issues found!". Do not pipe through `tail` — infos are fatal
in CI.

- [ ] **Step 4: Run the full test suite**

Run: `flutter test`
Expected: all tests pass. If a test outside `features/media` and
`features/media_store` fails, check whether it is a known flaky
(backup-related tests are flaky under the full suite) by re-running that
file alone before investigating.

- [ ] **Step 5: Commit any formatting or regeneration fallout**

```bash
git add -A
git commit -m "chore(media): formatting and codegen after badge work"
```

Skip this step if nothing changed.

---

## Manual verification

Automated tests cannot cover the on-device behavior. After Task 5, verify by hand on macOS:

```bash
flutter run -d macos
```

1. With no media store attached, open a dive with local photos. Expect no
   overlay icons at all.
2. Attach a media store (Settings, Photos and Media, Media Storage). Return
   to the dive. Expect a `cloud_off` icon on each not-yet-uploaded tile.
3. Run "Upload existing library". Expect tiles to move through `schedule`
   then `cloud_upload`, then go blank as each completes — without leaving
   and re-entering the dive. That last part is the stale-snapshot fix.
4. Import a new photo through the Files tab. Expect it to enqueue and
   upload on its own, with no manual backfill.
