# Media Sync Phase 0: Harness and Diagnostics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the media sync program its regression net (a two-device harness with the seed scenarios) and its diagnosis path (a media log category, peer device names, a per-row and per-library health report with three entry points) before any behaviour fix ships.

**Architecture:** Two additive layers plus one extraction. The extraction lifts the tile's store-fallback decision out of `MediaItemView` into a pure `MediaTileResolver` so a test can read a tile verdict without pumping a widget. The harness layer is test-only: two in-memory app databases swapped through the existing `DatabaseService` singleton, one shared fake cloud and one shared in-memory object store, per-device fake photo libraries and resolver registries, and the real `SyncService`, `MediaUploadPipeline`, `MediaStoreWorker` and resolvers in between. The diagnostics layer adds `LogCategory.media` with a per-category file floor, a `PeerDeviceNameStore` fed by the changeset reader, an origin device label on the resolvers, and a `MediaHealthReporter` surfaced from the Media info panel, the Media Storage page and the debug log export.

**Tech Stack:** Flutter, Riverpod, Drift (`NativeDatabase.memory()`), `shared_preferences`, `share_plus` through `file_export_utils.dart`, `flutter gen-l10n` with 11 checked-in ARB catalogs.

**Spec:** `docs/superpowers/specs/2026-09-18-media-sync-program-design.md` (sections 3, 4.1 to 4.4, 9 and slices 1 and 2 of section 10).

## Global Constraints

- Each slice is its own PR in its own worktree cut from `origin/main`. Slice 1 is Tasks 1 to 4 (branch `ericgriffin/media-sync-s1-harness`), slice 2 is Tasks 5 to 10 (branch `ericgriffin/media-sync-s2-diagnostics`, cut after slice 1 merges). In a fresh worktree run `git submodule update --init --recursive`, `flutter pub get` and the codegen before anything else. Never edit the main checkout.
- **No em-dashes (U+2014) in any output**: code, comments, commit messages, ARB strings, docs. En-dashes and " - " as prose punctuation are equally forbidden. Hyphens inside compound words and CLI flags are fine.
- **No emojis** in code, comments, or documentation.
- **TDD**: every behaviour gets a failing test before the implementation. Run the named test file after each step; the expected outcome is stated.
- **Immutability**: never mutate an existing list or map in place; build a new one.
- **No app schema change.** Nothing in this plan touches `lib/core/database/database.dart` or the `LocalCacheDatabase` schema. Peer names live in `SharedPreferences`.
- **Originals are never deleted, moved or rewritten** (spec section 9). The harness writes only under its own temp directories.
- File size target 200-400 lines, 800 max. Split a file that would cross 800.
- Run `dart format .` from the worktree root after every task before committing. Run `flutter analyze` on the whole project before each commit; infos are fatal in CI.
- Provider naming: `<noun>Provider` for data, `<noun>NotifierProvider` for mutable state. Import grouping: dart, flutter, packages, local.
- Every new user-visible string goes into all 11 ARB files under `lib/l10n/arb/` (`app_ar`, `app_de`, `app_en`, `app_es`, `app_fr`, `app_he`, `app_hu`, `app_it`, `app_nl`, `app_pt`, `app_zh`), inserted beside the neighbouring key named in the task, followed by `flutter gen-l10n` and committing the regenerated `lib/l10n/generated/*.dart`. A pre-push hook rejects a stale set.
- Commit messages must not contain a `Co-Authored-By` line, a tool name or a session URL. The PR body for slice 1 says `Part of #<tracking issue>`; slice 2 the same.
- After adding any file under `lib/`, run `flutter test test/architecture/` (the guards scan all of `lib/`).

---

## File Structure

**Slice 1: harness**

| Path | Responsibility |
| --- | --- |
| Create `lib/features/media/data/services/media_tile_resolver.dart` | Pure store-fallback decision extracted from `MediaItemView._resolve`: `storeConfirmed`, `TileResolution`, `MediaTileResolver`. |
| Create `lib/features/media/data/services/gallery_asset_reader.dart` | `GalleryAssetReader` seam over photo_manager byte reads, with the production `PhotoManagerAssetReader`. |
| Modify `lib/features/media/data/resolvers/platform_gallery_resolver.dart` | Read bytes through `GalleryAssetReader` instead of `AssetEntity.fromId` inline. |
| Modify `lib/features/media/presentation/widgets/media_item_view.dart:296-410` | Delegate the tail of `_resolve` to `MediaTileResolver`. |
| Modify `lib/features/media/presentation/providers/media_resolver_providers.dart:45-54` | Pass the production reader to the gallery resolver. |
| Create `test/helpers/fake_photo_picker_service.dart` | Hand-rolled `PhotoPickerService` plus `GalleryAssetReader` fake with a mutable asset list and permission. |
| Create `test/helpers/two_device_media_harness.dart` | `TwoDeviceMediaHarness` and `HarnessDevice`. |
| Create `test/features/media/data/services/media_tile_resolver_test.dart` | Unit tests for the extraction. |
| Create `test/features/media/data/resolvers/platform_gallery_resolver_reader_test.dart` | The reader seam serves bytes through a fake. |
| Create `test/features/media/two_device/harness_smoke_test.dart` | S0, the happy path, green on main. |
| Create `test/features/media/two_device/row_sync_scenarios_test.dart` | S1, S2, S3, skipped with the slice that turns them green. |
| Create `test/features/media/two_device/resolution_scenarios_test.dart` | S5, S6, S7. |
| Create `test/features/media/two_device/store_scenarios_test.dart` | S4, S8, S10. |
| Create `test/features/media/two_device/deletion_scenarios_test.dart` | S9. |

**Slice 2: diagnostics**

| Path | Responsibility |
| --- | --- |
| Modify `lib/core/models/log_entry.dart:1-21` | Add `LogCategory.media`. |
| Modify `lib/core/services/logger_service.dart:43,66-103,183-299,302` | Per-category file floor; `forClass` default category. |
| Modify `lib/features/settings/presentation/log_category_display.dart` | Localised name for the new category. |
| Modify `lib/features/settings/presentation/providers/debug_log_providers.dart:45-51,168-198` | Default filter set; bundle the media report into the share. |
| Create `lib/core/services/sync/peer_device_name_store.dart` | `PeerDeviceNameStore` over `SharedPreferences`. |
| Modify `lib/core/services/sync/changeset_log/changeset_reader.dart:155-175` | Record each peer manifest's name. |
| Modify `lib/core/services/sync/sync_service.dart:293-307,4145-4156` | Accept and forward the store; record names during adopt too. |
| Modify `lib/features/settings/presentation/providers/sync_providers.dart:492-502` | `peerDeviceNameStoreProvider`; wire it into `syncServiceProvider`. |
| Modify `lib/features/media/presentation/providers/media_provenance_providers.dart:86-92` | `originDeviceLabelProvider`. |
| Modify `lib/features/media/data/resolvers/local_file_resolver.dart:57,201-205` | `deviceLabel` callback; populate `originDeviceLabel`. |
| Modify `lib/features/media/data/resolvers/platform_gallery_resolver.dart:45-56` | Same, replacing the `const _elsewhere`. |
| Modify `lib/features/media/presentation/providers/media_resolver_providers.dart:45-54,105-121` | Pass `deviceLabel` to both resolvers. |
| Modify `lib/features/media/presentation/widgets/media_info_panel.dart:252-311` | "Linked on" shows the peer's name; "Copy diagnostics" action. |
| Create `lib/features/media/data/services/media_health_report.dart` | `MediaHealthRow`, `MediaHealthReport`, text and JSON rendering. |
| Create `lib/features/media/data/services/media_health_reporter.dart` | `MediaHealthReporter` that assembles rows from the repositories, cache, queue, resolvers and store. |
| Create `lib/features/media/presentation/providers/media_health_providers.dart` | `mediaHealthReporterProvider`. |
| Modify `lib/features/media_store/presentation/pages/media_storage_page.dart:331-357,822-836` | "Export media report" action. |
| Modify `lib/features/settings/presentation/pages/debug_log_viewer_page.dart:137-152` | Pass the library report to `shareLogFile`. |
| Modify the media classes listed in Task 6 | Log under `LogCategory.media`. |
| Tests beside each file, listed per task. | |

---

## Slice 1: the two-device harness

### Task 1: Extract `MediaTileResolver` from `MediaItemView`

**Files:**
- Create: `lib/features/media/data/services/media_tile_resolver.dart`
- Modify: `lib/features/media/presentation/widgets/media_item_view.dart:296-410`
- Test: `test/features/media/data/services/media_tile_resolver_test.dart`

**Interfaces:**
- Consumes: `MediaSourceResolverRegistry.resolverFor(MediaSourceType)` (`lib/features/media/data/services/media_source_resolver_registry.dart:11`), `MediaSourceResolver.resolve(item)` and `resolveThumbnail(item, target:)`, `MediaStoreResolver.tryResolveRemote(item, thumbnail:)` (`lib/features/media/data/resolvers/media_store_resolver.dart:43`).
- Produces, used by Tasks 3 and 9:

```dart
typedef RemoteResolverLookup = Future<MediaStoreResolver?> Function();

bool storeConfirmed(MediaItem item, {required bool thumbnail});

class TileResolution {
  const TileResolution({
    required this.data,
    this.videoPosterMissing = false,
    this.documentRenderable = false,
    this.storeFallbackUsed = false,
    this.nativeFailure,
  });
  final MediaSourceData data;
  final bool videoPosterMissing;
  final bool documentRenderable;
  final bool storeFallbackUsed;
  final UnavailableKind? nativeFailure;
}

class MediaTileResolver {
  MediaTileResolver({
    required MediaSourceResolverRegistry registry,
    required RemoteResolverLookup remote,
  });
  Future<TileResolution> resolve(
    MediaItem item, {
    required bool thumbnail,
    required Size thumbnailTarget,
  });
}
```

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/media/data/services/media_tile_resolver_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/data/services/media_tile_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

import '../../../media_store/support/fake_local_file_resolver.dart';
import '../../../../helpers/in_memory_media_object_store.dart';

/// Remote resolver whose answer the test scripts. Extends the real class so
/// the type the tile resolver consumes is the production one.
class _ScriptedRemote extends MediaStoreResolver {
  _ScriptedRemote({required super.store, required super.cache});
  MediaSourceData? answer;
  Object? throwWith;
  int calls = 0;

  @override
  Future<MediaSourceData?> tryResolveRemote(
    MediaItem item, {
    required bool thumbnail,
  }) async {
    calls++;
    if (throwWith != null) throw throwWith!;
    return answer;
  }
}

MediaItem _item({
  String? contentHash,
  DateTime? remoteUploadedAt,
  DateTime? remoteThumbUploadedAt,
  DateTime? remoteCompressedUploadedAt,
}) => MediaItem(
  id: 'm1',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.localFile,
  localPath: '/nowhere/reef.jpg',
  takenAt: DateTime(2026, 7, 1),
  createdAt: DateTime(2026, 7, 1),
  updatedAt: DateTime(2026, 7, 1),
  contentHash: contentHash,
  remoteUploadedAt: remoteUploadedAt,
  remoteThumbUploadedAt: remoteThumbUploadedAt,
  remoteCompressedUploadedAt: remoteCompressedUploadedAt,
);

void main() {
  late Directory root;
  late LocalCacheDatabase cacheDb;
  late _ScriptedRemote remote;
  late FakeLocalFileResolver native;
  late MediaTileResolver resolver;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('tile_resolver');
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    remote = _ScriptedRemote(
      store: InMemoryMediaObjectStore(),
      cache: MediaCacheStore(database: cacheDb, root: root),
    );
    native = FakeLocalFileResolver();
    resolver = MediaTileResolver(
      registry: MediaSourceResolverRegistry({
        MediaSourceType.localFile: native,
      }),
      remote: () async => remote,
    );
  });

  tearDown(() async {
    await cacheDb.close();
    await root.delete(recursive: true);
  });

  group('storeConfirmed', () {
    test('false without a content hash even when stamped', () {
      expect(
        storeConfirmed(
          _item(remoteUploadedAt: DateTime(2026)),
          thumbnail: false,
        ),
        isFalse,
      );
    });

    test('thumb stamp alone confirms a thumbnail request only', () {
      final item = _item(
        contentHash: 'abc',
        remoteThumbUploadedAt: DateTime(2026),
      );
      expect(storeConfirmed(item, thumbnail: true), isTrue);
      expect(storeConfirmed(item, thumbnail: false), isFalse);
    });

    test('compressed stamp confirms a full request', () {
      final item = _item(
        contentHash: 'abc',
        remoteCompressedUploadedAt: DateTime(2026),
      );
      expect(storeConfirmed(item, thumbnail: false), isTrue);
    });
  });

  group('resolve', () {
    final target = const Size(200, 200);

    test('native success never consults the store', () async {
      native.data = BytesData(bytes: Uint8List.fromList([1, 2, 3]));
      final r = await resolver.resolve(
        _item(contentHash: 'abc', remoteUploadedAt: DateTime(2026)),
        thumbnail: false,
        thumbnailTarget: target,
      );
      expect(r.data, isA<BytesData>());
      expect(r.storeFallbackUsed, isFalse);
      expect(r.nativeFailure, isNull);
      expect(remote.calls, 0);
    });

    test('unconfirmed row keeps the native placeholder untouched', () async {
      native.data = const UnavailableData(
        kind: UnavailableKind.fromOtherDevice,
      );
      final r = await resolver.resolve(
        _item(),
        thumbnail: false,
        thumbnailTarget: target,
      );
      expect((r.data as UnavailableData).kind, UnavailableKind.fromOtherDevice);
      expect(r.storeFallbackUsed, isFalse);
      expect(r.nativeFailure, UnavailableKind.fromOtherDevice);
      expect(remote.calls, 0);
    });

    test('confirmed row served by the store keeps the native failure', () async {
      native.data = const UnavailableData(kind: UnavailableKind.notFound);
      remote.answer = BytesData(bytes: Uint8List.fromList([9]));
      final r = await resolver.resolve(
        _item(contentHash: 'abc', remoteUploadedAt: DateTime(2026)),
        thumbnail: false,
        thumbnailTarget: target,
      );
      expect(r.data, isA<BytesData>());
      expect(r.storeFallbackUsed, isTrue);
      expect(r.nativeFailure, UnavailableKind.notFound);
    });

    test('no store on this device reports the fallback as attempted', () async {
      native.data = const UnavailableData(kind: UnavailableKind.notFound);
      final noStore = MediaTileResolver(
        registry: MediaSourceResolverRegistry({
          MediaSourceType.localFile: native,
        }),
        remote: () async => null,
      );
      final r = await noStore.resolve(
        _item(contentHash: 'abc', remoteUploadedAt: DateTime(2026)),
        thumbnail: false,
        thumbnailTarget: target,
      );
      expect(r.data, isA<UnavailableData>());
      expect(r.storeFallbackUsed, isTrue);
    });

    test('store throw keeps the native placeholder', () async {
      native.data = const UnavailableData(kind: UnavailableKind.notFound);
      remote.throwWith = StateError('boom');
      final r = await resolver.resolve(
        _item(contentHash: 'abc', remoteUploadedAt: DateTime(2026)),
        thumbnail: false,
        thumbnailTarget: target,
      );
      expect(r.data, isA<UnavailableData>());
      expect(r.storeFallbackUsed, isTrue);
      expect(r.nativeFailure, UnavailableKind.notFound);
    });

    test('video thumbnail with no thumb stamp reports a missing poster', () async {
      native.data = const UnavailableData(kind: UnavailableKind.notFound);
      remote.answer = null;
      final video = MediaItem(
        id: 'v1',
        mediaType: MediaType.video,
        sourceType: MediaSourceType.localFile,
        localPath: '/nowhere/reef.mov',
        takenAt: DateTime(2026, 7, 1),
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
        contentHash: 'abc',
        remoteUploadedAt: DateTime(2026),
      );
      final r = await resolver.resolve(
        video,
        thumbnail: true,
        thumbnailTarget: target,
      );
      expect(r.videoPosterMissing, isTrue);
      expect(r.storeFallbackUsed, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/media/data/services/media_tile_resolver_test.dart`
Expected: FAIL, "Target of URI doesn't exist: media_tile_resolver.dart".

- [ ] **Step 3: Write the resolver**

```dart
// lib/features/media/data/services/media_tile_resolver.dart
import 'dart:ui' show Size;

import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

/// Looks up the store-backed resolver for this device, or null when no media
/// store is attached. Deferred so building it (keychain read, store
/// construction) happens only when a row is confirmed uploaded.
typedef RemoteResolverLookup = Future<MediaStoreResolver?> Function();

/// Whether the row's synced stamps say the media store holds bytes for it.
///
/// A thumbnail request is satisfied by the thumb stamp alone because thumbs
/// upload before originals. The compressed stamp counts as confirmation in
/// its own right: an upload quality other than "original" uploads a rendition
/// and leaves [MediaItem.remoteUploadedAt] null permanently.
bool storeConfirmed(MediaItem item, {required bool thumbnail}) =>
    item.contentHash != null &&
    (item.remoteUploadedAt != null ||
        item.remoteCompressedUploadedAt != null ||
        (thumbnail && item.remoteThumbUploadedAt != null));

/// The full verdict for one tile: what to draw and how it was reached.
class TileResolution {
  const TileResolution({
    required this.data,
    this.videoPosterMissing = false,
    this.documentRenderable = false,
    this.storeFallbackUsed = false,
    this.nativeFailure,
  });

  final MediaSourceData data;

  /// The store holds this video but no poster was ever stamped, so the tile
  /// shows the movie icon rather than a failure.
  final bool videoPosterMissing;

  /// The store handed back a rendered page-1 poster for a document.
  final bool documentRenderable;

  /// Whether the store was consulted at all (including "no store here").
  final bool storeFallbackUsed;

  /// The native source's failure, kept even when the store covered for it,
  /// because the orphan flag is about the origin.
  final UnavailableKind? nativeFailure;
}

/// The store-fallback decision `MediaItemView` makes for every tile, as a
/// pure object so tests and diagnostics can ask for a verdict without a
/// widget tree.
class MediaTileResolver {
  MediaTileResolver({
    required MediaSourceResolverRegistry registry,
    required RemoteResolverLookup remote,
  }) : _registry = registry,
       _remote = remote;

  final MediaSourceResolverRegistry _registry;
  final RemoteResolverLookup _remote;

  Future<TileResolution> resolve(
    MediaItem item, {
    required bool thumbnail,
    required Size thumbnailTarget,
  }) async {
    final resolver = _registry.resolverFor(item.sourceType);
    final native = thumbnail
        ? await resolver.resolveThumbnail(item, target: thumbnailTarget)
        : await resolver.resolve(item);
    if (native is! UnavailableData) {
      return TileResolution(data: native);
    }
    final nativeFailure = native.kind;
    if (!storeConfirmed(item, thumbnail: thumbnail)) {
      return TileResolution(data: native, nativeFailure: nativeFailure);
    }
    try {
      final remote = await _remote();
      if (remote == null) {
        return TileResolution(
          data: native,
          storeFallbackUsed: true,
          nativeFailure: nativeFailure,
        );
      }
      final served = await remote.tryResolveRemote(item, thumbnail: thumbnail);
      if (served != null) {
        return TileResolution(
          data: served,
          documentRenderable:
              thumbnail && served is FileData && served.isPoster,
          storeFallbackUsed: true,
          nativeFailure: nativeFailure,
        );
      }
      return TileResolution(
        data: native,
        videoPosterMissing:
            thumbnail && item.isVideo && item.remoteThumbUploadedAt == null,
        storeFallbackUsed: true,
        nativeFailure: nativeFailure,
      );
    } catch (_) {
      return TileResolution(
        data: native,
        storeFallbackUsed: true,
        nativeFailure: nativeFailure,
      );
    }
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/media/data/services/media_tile_resolver_test.dart`
Expected: PASS, 9 tests.

- [ ] **Step 5: Delegate from the widget**

In `lib/features/media/presentation/widgets/media_item_view.dart`, add the import `package:submersion/features/media/data/services/media_tile_resolver.dart`. Then replace everything in `_resolve` from the line `final native = widget.thumbnail` (line 296) through the closing brace of the method (line 410) with:

```dart
    final tile = await MediaTileResolver(
      registry: ref.read(mediaSourceResolverRegistryProvider),
      remote: () async =>
          (await ref.read(mediaStoreRuntimeProvider.future))?.resolver,
    ).resolve(
      widget.item,
      thumbnail: widget.thumbnail,
      thumbnailTarget: widget.targetSize ?? kDefaultThumbnailTarget,
    );
    return (
      data: tile.data,
      videoPosterMissing: tile.videoPosterMissing,
      documentRenderable: tile.documentRenderable,
      storeFallbackUsed: tile.storeFallbackUsed,
      nativeFailure: tile.nativeFailure,
    );
  }
```

Keep the long comment block that explains the store gate; move it above the new call so the reasoning stays with the code. The local `resolver` variable obtained earlier in `_resolve` is still used by the document branch above line 296; if the analyzer reports it unused after the edit, the document branch does not use it and the variable can be removed.

- [ ] **Step 6: Run the widget's existing tests**

Run: `flutter test test/features/media/presentation/media_item_view_store_fallback_test.dart test/features/media/presentation/`
Expected: PASS, same counts as before the edit.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/media/data/services/media_tile_resolver.dart lib/features/media/presentation/widgets/media_item_view.dart test/features/media/data/services/media_tile_resolver_test.dart
git commit -m "refactor(media): extract the tile store-fallback decision into MediaTileResolver"
```

---

### Task 2: `GalleryAssetReader` seam and the fake photo library

**Files:**
- Create: `lib/features/media/data/services/gallery_asset_reader.dart`
- Modify: `lib/features/media/data/resolvers/platform_gallery_resolver.dart:1-56,81-92,159-165,170-186,204-206`
- Modify: `lib/features/media/presentation/providers/media_resolver_providers.dart:45-54`
- Create: `test/helpers/fake_photo_picker_service.dart`
- Test: `test/features/media/data/resolvers/platform_gallery_resolver_reader_test.dart`

**Why:** `PlatformGalleryResolver` reads bytes with `AssetEntity.fromId` inline (four sites). photo_manager has no test backend and `fromId` answers null under `flutter_test`, so no gallery photo can ever produce bytes in a test. The seam is production-neutral: the default reader is the same four calls.

**Interfaces:**
- Produces:

```dart
abstract class GalleryAssetReader {
  Future<Uint8List?> originBytes(String assetId);
  Future<Uint8List?> thumbnailBytes(String assetId, int width, int height);
  Future<bool> exists(String assetId);
  Future<MediaSourceMetadata?> metadata(String assetId);
}
class PhotoManagerAssetReader implements GalleryAssetReader { ... }
```
`PlatformGalleryResolver` gains `GalleryAssetReader? assetReader` (defaults to `PhotoManagerAssetReader()`).

```dart
class FakeGalleryAsset {
  const FakeGalleryAsset({required this.id, required this.bytes, required this.takenAt,
      this.width = 4032, this.height = 3024, this.filename = 'IMG_0001.JPG',
      this.type = AssetType.image});
}
class FakePhotoPickerService implements PhotoPickerService, GalleryAssetReader {
  FakePhotoPickerService({List<FakeGalleryAsset> assets = const [],
      PhotoPermissionStatus permission = PhotoPermissionStatus.authorized,
      bool supportsGalleryBrowsing = true});
  PhotoPermissionStatus permission;           // mutable per test
  Set<String> hiddenFromLimitedAccess;        // ids outside the user's subset
  void add(FakeGalleryAsset asset); void remove(String id);
}
```

- [ ] **Step 1: Write the failing test**

```dart
// test/features/media/data/resolvers/platform_gallery_resolver_reader_test.dart
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/resolvers/platform_gallery_resolver.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

import '../../../../helpers/fake_photo_picker_service.dart';

void main() {
  late LocalCacheDatabase cacheDb;
  late FakePhotoPickerService gallery;
  late PlatformGalleryResolver resolver;
  final taken = DateTime(2026, 7, 1, 10, 30);
  final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));

  setUp(() {
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    gallery = FakePhotoPickerService(
      assets: [FakeGalleryAsset(id: 'A-1', bytes: bytes, takenAt: taken)],
    );
    resolver = PlatformGalleryResolver(
      resolutionService: AssetResolutionService(
        cacheRepository: LocalAssetCacheRepository(database: cacheDb),
        photoPickerService: gallery,
      ),
      assetReader: gallery,
    );
  });

  tearDown(() => cacheDb.close());

  MediaItem row(String assetId) => MediaItem(
    id: 'm-$assetId',
    platformAssetId: assetId,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    originalFilename: 'IMG_0001.JPG',
    takenAt: taken,
    createdAt: taken,
    updatedAt: taken,
  );

  test('serves origin bytes through the reader', () async {
    final data = await resolver.resolve(row('A-1'));
    expect(data, isA<BytesData>());
    expect((data as BytesData).bytes, bytes);
  });

  test('verify answers available through the reader', () async {
    expect(await resolver.verify(row('A-1')), VerifyResult.available);
  });

  test('an id the library never had is notFound', () async {
    final data = await resolver.resolve(row('Z-9'));
    expect((data as UnavailableData).kind, UnavailableKind.notFound);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/media/data/resolvers/platform_gallery_resolver_reader_test.dart`
Expected: FAIL, "The named parameter 'assetReader' isn't defined" and a missing helper file.

- [ ] **Step 3: Write the seam**

```dart
// lib/features/media/data/services/gallery_asset_reader.dart
import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';

/// Byte and metadata reads against the platform photo library, keyed by the
/// LOCAL asset id [AssetResolutionService] resolved.
///
/// Exists so the gallery resolver can run against a fake library in tests:
/// photo_manager has no test backend and `AssetEntity.fromId` answers null
/// under flutter_test, which looks exactly like a deleted photo.
abstract class GalleryAssetReader {
  Future<Uint8List?> originBytes(String assetId);
  Future<Uint8List?> thumbnailBytes(String assetId, int width, int height);
  Future<bool> exists(String assetId);
  Future<MediaSourceMetadata?> metadata(String assetId);
}

/// Production reader over photo_manager. Exercised on iOS, macOS and Android
/// hosts only.
// coverage:ignore-start
class PhotoManagerAssetReader implements GalleryAssetReader {
  const PhotoManagerAssetReader();

  @override
  Future<Uint8List?> originBytes(String assetId) async {
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) return null;
    return asset.originBytes;
  }

  @override
  Future<Uint8List?> thumbnailBytes(
    String assetId,
    int width,
    int height,
  ) async {
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) return null;
    return asset.thumbnailDataWithSize(ThumbnailSize(width, height));
  }

  @override
  Future<bool> exists(String assetId) async =>
      await AssetEntity.fromId(assetId) != null;

  @override
  Future<MediaSourceMetadata?> metadata(String assetId) async {
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) return null;
    final ll = await asset.latlngAsync();
    return MediaSourceMetadata(
      takenAt: asset.createDateTime,
      latitude: (ll?.latitude == 0.0) ? null : ll?.latitude,
      longitude: (ll?.longitude == 0.0) ? null : ll?.longitude,
      width: asset.width,
      height: asset.height,
      durationSeconds: asset.duration > 0 ? asset.duration : null,
      mimeType: asset.mimeType ?? 'application/octet-stream',
    );
  }
}
// coverage:ignore-end
```

In `platform_gallery_resolver.dart`: remove the `photo_manager` import; import `gallery_asset_reader.dart`; add the constructor parameter `GalleryAssetReader? assetReader` stored as `_reader = assetReader ?? const PhotoManagerAssetReader()`; replace the four `AssetEntity.fromId` blocks:

```dart
    // resolve():
    final bytes = await _reader.originBytes(resolvedId);
    if (bytes == null) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    return BytesData(bytes: bytes, servedFrom: ServedFrom.platformGallery);

    // _thumbBytes():
    Future<Uint8List?> _thumbBytes(String id, int width, int height) =>
        _reader.thumbnailBytes(id, width, height);

    // extractMetadata():
    return _reader.metadata(resolvedId);

    // verify():
    return await _reader.exists(resolvedId)
        ? VerifyResult.available
        : VerifyResult.notFound;
```
Delete the `coverage:ignore` markers around those blocks; the reader carries them now.

In `media_resolver_providers.dart:45-54` add `assetReader: const PhotoManagerAssetReader(),` and the import.

- [ ] **Step 4: Write the fake library**

```dart
// test/helpers/fake_photo_picker_service.dart
import 'dart:typed_data';

import 'package:submersion/features/media/data/services/gallery_asset_reader.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';

/// One photo or video in a fake device library.
class FakeGalleryAsset {
  const FakeGalleryAsset({
    required this.id,
    required this.bytes,
    required this.takenAt,
    this.width = 4032,
    this.height = 3024,
    this.filename = 'IMG_0001.JPG',
    this.type = AssetType.image,
  });

  final String id;
  final Uint8List bytes;
  final DateTime takenAt;
  final int width;
  final int height;

  /// Null models a library listing that carries no title, which PhotoKit
  /// often omits on a peer's fast date-range query.
  final String? filename;
  final AssetType type;

  AssetInfo get info => AssetInfo(
    id: id,
    type: type,
    createDateTime: takenAt,
    width: width,
    height: height,
    filename: filename,
  );
}

/// In-memory photo library standing in for photo_manager on one device.
///
/// Serves both halves of the gallery stack: the candidate search
/// [AssetResolutionService] runs through [PhotoPickerService], and the byte
/// reads [PlatformGalleryResolver] runs through [GalleryAssetReader]. Two
/// devices get two instances; a shared iCloud library is modelled by giving
/// both the same bytes under different ids.
class FakePhotoPickerService implements PhotoPickerService, GalleryAssetReader {
  FakePhotoPickerService({
    List<FakeGalleryAsset> assets = const [],
    this.permission = PhotoPermissionStatus.authorized,
    this.supportsGalleryBrowsing = true,
  }) : _assets = {for (final a in assets) a.id: a};

  final Map<String, FakeGalleryAsset> _assets;
  PhotoPermissionStatus permission;

  /// Ids the user did NOT select under limited access. Invisible to every
  /// query while [permission] is [PhotoPermissionStatus.limited].
  final Set<String> hiddenFromLimitedAccess = {};

  @override
  final bool supportsGalleryBrowsing;

  void add(FakeGalleryAsset asset) => _assets[asset.id] = asset;
  void remove(String id) => _assets.remove(id);

  FakeGalleryAsset? _visible(String id) {
    final asset = _assets[id];
    if (asset == null) return null;
    if (permission == PhotoPermissionStatus.limited &&
        hiddenFromLimitedAccess.contains(id)) {
      return null;
    }
    if (permission == PhotoPermissionStatus.denied ||
        permission == PhotoPermissionStatus.restricted) {
      return null;
    }
    return asset;
  }

  @override
  Future<List<AssetInfo>> getAssetsInDateRange(
    DateTime start,
    DateTime end,
  ) async => [
    for (final a in _assets.values)
      if (_visible(a.id) != null &&
          !a.takenAt.isBefore(start) &&
          !a.takenAt.isAfter(end))
        a.info,
  ];

  @override
  Future<Uint8List?> getThumbnail(String assetId, {int size = 200}) async =>
      _visible(assetId)?.bytes;

  @override
  Future<Uint8List?> getFileBytes(String assetId) async =>
      _visible(assetId)?.bytes;

  @override
  Future<PhotoPermissionStatus> checkPermission() async => permission;

  @override
  Future<PhotoPermissionStatus> requestPermission() async => permission;

  @override
  Future<String?> getFilePath(String assetId) async => null;

  @override
  Future<MediaSourceMetadata?> getAssetMetadata(String assetId) =>
      metadata(assetId);

  // GalleryAssetReader

  @override
  Future<Uint8List?> originBytes(String assetId) async =>
      _visible(assetId)?.bytes;

  @override
  Future<Uint8List?> thumbnailBytes(String assetId, int width, int height) async =>
      _visible(assetId)?.bytes;

  @override
  Future<bool> exists(String assetId) async => _visible(assetId) != null;

  @override
  Future<MediaSourceMetadata?> metadata(String assetId) async {
    final a = _visible(assetId);
    if (a == null) return null;
    return MediaSourceMetadata(
      takenAt: a.takenAt,
      width: a.width,
      height: a.height,
      mimeType: a.type == AssetType.video ? 'video/quicktime' : 'image/jpeg',
    );
  }
}
```
If `PhotoPickerService` declares abstract members beyond the eight listed at `photo_picker_service.dart:88-140` (the analyzer will say so), implement each by throwing `UnimplementedError('not used by the harness')`.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/media/data/resolvers/ test/features/media/data/services/asset_resolution_service_test.dart`
Expected: PASS. The three new tests pass; every existing gallery resolver test still passes because the default reader preserves the old calls.

- [ ] **Step 6: Format, analyze, architecture guards, commit**

```bash
dart format .
flutter analyze
flutter test test/architecture/
git add lib/features/media/data/services/gallery_asset_reader.dart lib/features/media/data/resolvers/platform_gallery_resolver.dart lib/features/media/presentation/providers/media_resolver_providers.dart test/helpers/fake_photo_picker_service.dart test/features/media/data/resolvers/platform_gallery_resolver_reader_test.dart
git commit -m "test(media): read gallery bytes through a seam so a fake library can serve them"
```

---

### Task 3: `TwoDeviceMediaHarness` and the happy path (S0)

**Files:**
- Create: `test/helpers/two_device_media_harness.dart`
- Test: `test/features/media/two_device/harness_smoke_test.dart`

**Interfaces:**
- Consumes: `setUpTestDatabase`/`DatabaseService.instance.setTestDatabase` (`test/helpers/test_database.dart`), `SyncClock.instance.reset()`, `FakeCloudStorageProvider` (`test/helpers/fake_cloud_storage_provider.dart`, NOT the one under `test/support/`), `InMemoryMediaObjectStore`, `StoreMarkerStore.ensure()`, `MediaStoreAttachState.setAttached`, `MediaStorePreflight`, `MediaStoreWorker`, `MediaUploadPipeline`, `MediaTransferQueueRepository`, `LocalAssetCacheRepository`, `AssetResolutionService`, `PlatformGalleryResolver(assetReader:)` (Task 2), `LocalFileResolver`, `MediaTileResolver` (Task 1), `MediaRepository.createMedia`, `SyncService.performSync`, `MediaItemVerifier`, `MediaVerificationSweep`, `DiverRepository.deleteDiverWithReassignment`.
- Produces:

```dart
enum TileOutcome { native, store, unavailable }

class TwoDeviceMediaHarness {
  static Future<TwoDeviceMediaHarness> create();
  final HarnessDevice a; final HarnessDevice b;
  final FakeCloudStorageProvider cloud;
  final InMemoryMediaObjectStore bucket;
  String get storeId;
  Future<void> dispose();
}

class HarnessDevice {
  final String name; late final String deviceId;
  final FakePhotoPickerService gallery;
  final MediaTransferQueueRepository queue;
  final LocalAssetCacheRepository assetCache;
  MediaStoreWorker get worker;                 // rebuilt by relaunch()
  Future<bool> Function() preflight;           // swap to script a failure
  Future<void> activate();
  Future<String> createDive({String diverId = 'diver1', DateTime? at});
  Future<String> linkFile(List<int> bytes, {required String diveId, String name = 'reef.jpg', DateTime? takenAt});
  Future<String> linkGalleryPhoto(FakeGalleryAsset asset, {required String diveId});
  Future<void> enqueueUpload(String mediaId);
  Future<void> drain();
  Future<void> relaunch();                     // new worker over the same queue
  Future<SyncResult> sync({bool expectSuccess = true});
  Future<MediaItem?> media(String id);
  Future<void> setManualElapsed(String id, int seconds);   // a user edit, via the narrow setManualElapsedSeconds write
  Future<bool> isPending(String id);
  Future<TileResolution> tile(String id, {bool thumbnail = false});
  Future<TileOutcome> tileOutcome(String id, {bool thumbnail = false});
  Future<void> checkTile(String id);           // tile + the widget's orphan reconcile
  Future<SweepOutcome> verifyAll();
  Future<void> deleteDiver(String id);
  Future<void> stripStoreStamps(String id);    // clears the three upload timestamps, keeps the hash
}
```

- [ ] **Step 1: Write the smoke test (S0)**

```dart
// test/features/media/two_device/harness_smoke_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/services/media_tile_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

import '../../../helpers/two_device_media_harness.dart';

void main() {
  late TwoDeviceMediaHarness h;

  setUp(() async => h = await TwoDeviceMediaHarness.create());
  tearDown(() => h.dispose());

  test('S0: a file linked and uploaded on A is served from the store on B',
      () async {
    final bytes = List<int>.generate(2048, (i) => (i * 7) % 251);
    final dive = await h.a.createDive();
    final id = await h.a.linkFile(bytes, diveId: dive);
    await h.a.enqueueUpload(id);
    await h.a.drain();
    await h.a.sync();
    await h.b.sync();

    final onB = await h.b.media(id);
    expect(onB, isNotNull, reason: 'the row must arrive by sync');
    expect(onB!.contentHash, isNotNull);
    expect(onB.remoteUploadedAt, isNotNull);

    final tile = await h.b.tile(id);
    expect(tile.storeFallbackUsed, isTrue);
    expect(tile.data, isA<FileData>());
    expect(await (tile.data as FileData).file.readAsBytes(), bytes);
    expect(await h.b.tileOutcome(id), TileOutcome.store);
  });

  test('S0b: the two devices have distinct ids and the same store', () async {
    expect(h.a.deviceId, isNot(h.b.deviceId));
    expect(h.storeId, isNotEmpty);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/media/two_device/harness_smoke_test.dart`
Expected: FAIL, missing `two_device_media_harness.dart`.

- [ ] **Step 3: Write the harness**

```dart
// test/helpers/two_device_media_harness.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/media_store/store_marker.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/resolvers/local_file_resolver.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/data/resolvers/platform_gallery_resolver.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/data/services/exif_extractor.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/data/services/media_item_verifier.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/data/services/media_tile_resolver.dart';
import 'package:submersion/features/media/data/services/media_verification_sweep.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_orphan_reconciler.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_store_preflight.dart';
import 'package:submersion/features/media_store/data/media_store_worker.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';
import 'package:submersion/features/settings/domain/entities/cloud_provider_type.dart';

import 'fake_cloud_storage_provider.dart';
import 'fake_photo_picker_service.dart';
import 'in_memory_media_object_store.dart';

/// What a grid tile would draw for a row on this device.
enum TileOutcome { native, store, unavailable }

/// Bookmark storage that never resolves: the harness runs the plain-path
/// branch of [LocalFileResolver] on every host.
class _NullBookmarkStorage extends LocalBookmarkStorage {
  _NullBookmarkStorage() : super(storage: null as dynamic);

  @override
  Future<Uint8List?> read(String ref) async => null;
}

/// Two complete devices sharing one sync backend and one media store.
///
/// The app database and the sync clock are process singletons, so the two
/// devices take turns: every [HarnessDevice] operation calls [activate]
/// first, which swaps its database into [DatabaseService] and resets the
/// clock. Nothing here is concurrent; that is a limitation of the app's
/// singletons, not of the scenarios.
///
/// Shared on purpose: the fake cloud (the sync folder), the object store
/// (the bucket) and, because SharedPreferences is process-global, the media
/// store attach state. Both devices are attached to the same store id, which
/// is the configuration every scenario needs.
class TwoDeviceMediaHarness {
  TwoDeviceMediaHarness._(this.cloud, this.bucket, this.storeId);

  final FakeCloudStorageProvider cloud;
  final InMemoryMediaObjectStore bucket;
  final String storeId;
  late final HarnessDevice a;
  late final HarnessDevice b;

  static Future<TwoDeviceMediaHarness> create() async {
    SharedPreferences.setMockInitialValues({});
    final cloud = FakeCloudStorageProvider();
    final bucket = InMemoryMediaObjectStore();
    final marker = (await StoreMarkerStore(store: bucket).ensure()).marker;
    final attach = MediaStoreAttachState();
    await attach.setAttached(
      marker.storeId,
      providerType: CloudProviderType.s3,
    );
    final h = TwoDeviceMediaHarness._(cloud, bucket, marker.storeId);
    h.a = await HarnessDevice._create(h, 'Device A', attach);
    h.b = await HarnessDevice._create(h, 'Device B', attach);
    return h;
  }

  Future<void> dispose() async {
    await a._dispose();
    await b._dispose();
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  }
}

class HarnessDevice {
  HarnessDevice._(this._harness, this.name, this._attach);

  final TwoDeviceMediaHarness _harness;
  final String name;
  final MediaStoreAttachState _attach;

  late final AppDatabase db;
  late final LocalCacheDatabase cacheDb;
  late final Directory root;
  late final String deviceId;
  late final FakePhotoPickerService gallery;
  late final MediaCacheStore cache;
  late final MediaTransferQueueRepository queue;
  late final LocalAssetCacheRepository assetCache;
  late final MediaSourceResolverRegistry registry;
  late final MediaStoreResolver storeResolver;
  late final MediaTileResolver tileResolver;
  late MediaStoreWorker worker;

  /// The preflight the worker consults before every entry. Defaults to the
  /// production [MediaStorePreflight]; a scenario replaces it to script a
  /// marker failure on one device.
  late Future<bool> Function() preflight;

  static Future<HarnessDevice> _create(
    TwoDeviceMediaHarness h,
    String name,
    MediaStoreAttachState attach,
  ) async {
    final d = HarnessDevice._(h, name, attach);
    d.db = AppDatabase(NativeDatabase.memory());
    d.cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    d.root = await Directory.systemTemp.createTemp('two_device_${name.hashCode}');
    d.gallery = FakePhotoPickerService();
    await d.activate();
    d.deviceId = await SyncRepository().getDeviceId();
    await d.db.into(d.db.divers).insert(
      const DiversCompanion(
        id: Value('diver1'),
        name: Value('diver1'),
        isDefault: Value(true),
        createdAt: Value(0),
        updatedAt: Value(0),
      ),
    );
    await d.db.into(d.db.divers).insert(
      const DiversCompanion(
        id: Value('diver2'),
        name: Value('diver2'),
        createdAt: Value(0),
        updatedAt: Value(0),
      ),
    );
    d.cache = MediaCacheStore(
      database: d.cacheDb,
      root: Directory('${d.root.path}/cache')..createSync(),
    );
    d.queue = MediaTransferQueueRepository(database: d.cacheDb);
    d.assetCache = LocalAssetCacheRepository(database: d.cacheDb);
    d.registry = MediaSourceResolverRegistry({
      MediaSourceType.platformGallery: PlatformGalleryResolver(
        resolutionService: AssetResolutionService(
          cacheRepository: d.assetCache,
          photoPickerService: d.gallery,
        ),
        assetReader: d.gallery,
      ),
      MediaSourceType.localFile: LocalFileResolver(
        bookmarkStorage: _NullBookmarkStorage(),
        platform: LocalMediaPlatform(),
        exifExtractor: ExifExtractor(),
        localDeviceId: () async => d.deviceId,
      ),
    });
    d.storeResolver = MediaStoreResolver(store: h.bucket, cache: d.cache);
    d.tileResolver = MediaTileResolver(
      registry: d.registry,
      remote: () async => d.storeResolver,
    );
    d.preflight = MediaStorePreflight(
      attachState: attach,
      store: h.bucket,
      attachedStoreId: h.storeId,
    ).call;
    d.worker = d._buildWorker();
    return d;
  }

  MediaStoreWorker _buildWorker() => MediaStoreWorker(
    queue: queue,
    pipeline: MediaUploadPipeline(
      mediaRepository: MediaRepository(),
      queue: queue,
      store: _harness.bucket,
      registry: registry,
      cache: cache,
    ),
    preflight: () => preflight(),
  );

  /// Makes this device the live one. Idempotent and cheap.
  Future<void> activate() async {
    DatabaseService.instance.setTestDatabase(db);
    SyncClock.instance.reset();
  }

  Future<String> createDive({String diverId = 'diver1', DateTime? at}) async {
    await activate();
    final when = (at ?? DateTime(2026, 7, 1, 10)).millisecondsSinceEpoch;
    final id = 'dive-${name.hashCode}-${DateTime.now().microsecondsSinceEpoch}';
    await db.into(db.dives).insert(
      DivesCompanion(
        id: Value(id),
        diverId: Value(diverId),
        diveDateTime: Value(when),
        createdAt: Value(when),
        updatedAt: Value(when),
      ),
    );
    await SyncRepository().markRecordPending(
      entityType: 'dives',
      recordId: id,
      localUpdatedAt: when,
    );
    return id;
  }

  Future<String> linkFile(
    List<int> bytes, {
    required String diveId,
    String name = 'reef.jpg',
    DateTime? takenAt,
  }) async {
    await activate();
    final dir = Directory('${root.path}/files')..createSync(recursive: true);
    final file = File('${dir.path}/$name')..writeAsBytesSync(bytes);
    final when = takenAt ?? DateTime(2026, 7, 1, 10, 30);
    final created = await MediaRepository().createMedia(
      MediaItem(
        id: '',
        diveId: diveId,
        mediaType: name.endsWith('.mov') ? MediaType.video : MediaType.photo,
        sourceType: MediaSourceType.localFile,
        filePath: file.path,
        localPath: file.path,
        originalFilename: name,
        takenAt: when,
        createdAt: when,
        updatedAt: when,
      ),
    );
    return created.id;
  }

  Future<String> linkGalleryPhoto(
    FakeGalleryAsset asset, {
    required String diveId,
  }) async {
    await activate();
    gallery.add(asset);
    final created = await MediaRepository().createMedia(
      MediaItem(
        id: '',
        diveId: diveId,
        platformAssetId: asset.id,
        mediaType: asset.type == AssetType.video
            ? MediaType.video
            : MediaType.photo,
        sourceType: MediaSourceType.platformGallery,
        originalFilename: asset.filename,
        takenAt: asset.takenAt,
        createdAt: asset.takenAt,
        updatedAt: asset.takenAt,
      ),
    );
    return created.id;
  }

  Future<void> enqueueUpload(String mediaId) async {
    await activate();
    await queue.enqueueUpload(mediaId: mediaId);
  }

  /// One full, awaited drain. Never `enqueueAndKick`: its background drain is
  /// nondeterministic in a test.
  Future<void> drain() async {
    await activate();
    await worker.drain();
  }

  /// Models the app being killed and relaunched: the queue survives, the
  /// worker does not.
  Future<void> relaunch() async {
    await activate();
    worker.dispose();
    worker = _buildWorker();
  }

  Future<SyncResult> sync({bool expectSuccess = true}) async {
    await activate();
    final result = await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: _harness.cloud,
    ).performSync();
    if (expectSuccess && !result.isSuccess) {
      throw StateError('$name sync failed: ${result.status} ${result.message}');
    }
    return result;
  }

  Future<MediaItem?> media(String id) async {
    await activate();
    return MediaRepository().getMediaById(id);
  }

  /// A plain user edit on the row, for last-writer-wins scenarios. The
  /// narrow write, as the app's own editor uses: a whole-row update from a
  /// snapshot could write stale upload facts back over newer ones.
  Future<void> setManualElapsed(String id, int seconds) async {
    await activate();
    await MediaRepository().setManualElapsedSeconds(id, seconds);
  }

  Future<bool> isPending(String id) async {
    await activate();
    final row = await db.customSelect(
      "SELECT sync_status FROM sync_records "
      "WHERE entity_type = 'media' AND record_id = ?",
      variables: [Variable.withString(id)],
    ).getSingleOrNull();
    return row?.read<String>('sync_status') == 'pending';
  }

  Future<TileResolution> tile(String id, {bool thumbnail = false}) async {
    await activate();
    final row = (await MediaRepository().getMediaById(id))!;
    return tileResolver.resolve(
      row,
      thumbnail: thumbnail,
      thumbnailTarget: const Size(200, 200),
    );
  }

  Future<TileOutcome> tileOutcome(String id, {bool thumbnail = false}) async {
    final r = await tile(id, thumbnail: thumbnail);
    if (r.data is UnavailableData) return TileOutcome.unavailable;
    return r.storeFallbackUsed ? TileOutcome.store : TileOutcome.native;
  }

  /// What `MediaItemView` does after resolving: reconcile the orphan flag
  /// and, when the verdict changed, write it (which marks the row pending).
  Future<void> checkTile(String id) async {
    await activate();
    final repo = MediaRepository();
    final row = (await repo.getMediaById(id))!;
    final r = await tile(id);
    final desired = reconciledOrphanFlag(
      currentlyOrphaned: row.isOrphaned,
      failure: r.nativeFailure,
    );
    if (desired == null) return;
    await repo.markVerified(id, isOrphaned: desired, verifiedAt: DateTime.now());
  }

  Future<SweepOutcome> verifyAll() async {
    await activate();
    final repo = MediaRepository();
    return MediaVerificationSweep(
      repository: repo,
      verifier: MediaItemVerifier(registry: registry, repository: repo),
    ).run();
  }

  Future<void> deleteDiver(String id) async {
    await activate();
    await DiverRepository().deleteDiverWithReassignment(id);
  }

  /// Simulates upload stamps that never arrived or were dropped by a merge.
  /// The content hash stays: it is what a store probe addresses the object
  /// by, and losing it is a different (unrecoverable) failure.
  Future<void> stripStoreStamps(String id) async {
    await activate();
    await db.customStatement(
      'UPDATE media SET remote_uploaded_at = NULL, '
      'remote_thumb_uploaded_at = NULL, '
      'remote_compressed_uploaded_at = NULL WHERE id = ?',
      [id],
    );
  }

  Future<void> _dispose() async {
    worker.dispose();
    await cacheDb.close();
    await db.close();
    if (root.existsSync()) await root.delete(recursive: true);
  }
}
```

Names verified against main: `LocalBookmarkStorage({FlutterSecureStorage? storage})`, `LocalMediaPlatform()` and `ExifExtractor()` under `lib/features/media/data/services/`; `DiverRepository()` takes only an optional reclaimer; `MediaRepository.setManualElapsedSeconds(String id, int? seconds)` is the narrow edit at `media_repository.dart:362`; `CloudProviderType` is declared in `lib/core/data/repositories/sync_repository.dart`. `DiversCompanion.isDefault` exists because `deleteDiverWithReassignment` orders survivors by it. Both devices share one real disk, so wrap `drain`, `tile`, `checkTile` and `verifyAll` in an `IOOverrides.runZoned` whose `createFile` returns a `Fake`-based `File` that reports absent for any path under the other device's root (a subclass of `IOOverrides` must be `final`); otherwise device B reads device A's originals off the disk and the store fallback is never exercised.

- [ ] **Step 4: Run the smoke test**

Run: `flutter test test/features/media/two_device/harness_smoke_test.dart`
Expected: PASS, 2 tests. If S0 fails at "the row must arrive by sync", the media row was not published: check that `createMedia` marked it pending (it does at `media_repository.dart:329`) and that both devices' `sync()` ran in the order A then B. If it fails at the tile, print `tile.nativeFailure` and `h.bucket.objects.keys`.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add test/helpers/two_device_media_harness.dart test/features/media/two_device/harness_smoke_test.dart
git commit -m "test(media): add a two-device harness running the real sync, upload and resolve stack"
```

---

### Task 4: Seed scenarios S1 to S10

**Files:**
- Create: `test/features/media/two_device/row_sync_scenarios_test.dart` (S1, S2, S3)
- Create: `test/features/media/two_device/resolution_scenarios_test.dart` (S5, S6, S7)
- Create: `test/features/media/two_device/store_scenarios_test.dart` (S4, S8, S10)
- Create: `test/features/media/two_device/deletion_scenarios_test.dart` (S9)

**Method:** each scenario is written to assert the spec's behaviour. Run it once WITHOUT the `skip:` to confirm it is red on main and copy the failing expectation line into the PR body under "Red on main". Then commit it with `skip: 'Media sync program Sn: turns green in slice <k>'`. The slice that fixes it deletes the skip. S6 (burst pair on a shared library) asserts only on the bytes each tile serves, so it compiles today; slice 8 gives `FakeGalleryAsset` a `cloudId` and stamps it at link time when it turns the scenario green.

`flutter_test` has no expected-failure marker; a skipped test with a reason naming its slice is the convention this program uses, and the PR body is the proof it was red.

- [ ] **Step 1: Row-sync scenarios**

```dart
// test/features/media/two_device/row_sync_scenarios_test.dart
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/two_device_media_harness.dart';

void main() {
  late TwoDeviceMediaHarness h;
  final bytes = List<int>.generate(1024, (i) => (i * 13) % 251);

  setUp(() async => h = await TwoDeviceMediaHarness.create());
  tearDown(() => h.dispose());

  test(
    'S1: a pending row on B still receives the upload stamps A published',
    () async {
      final dive = await h.a.createDive();
      final id = await h.a.linkFile(bytes, diveId: dive);
      await h.a.sync();
      await h.b.sync();
      // B touches the row (the per-tile verified write) before A's stamps land.
      await h.b.setManualElapsed(id, 30);
      expect(await h.b.isPending(id), isTrue);

      await h.a.enqueueUpload(id);
      await h.a.drain();
      await h.a.sync();
      await h.b.sync();

      final onB = await h.b.media(id);
      expect(onB!.remoteUploadedAt, isNotNull,
          reason: 'the peer update must merge into the pending row, not skip');
      expect(onB.contentHash, isNotNull);
      expect(onB.manualElapsedSeconds, 30,
          reason: 'the local edit must survive the merge');
    },
    skip: 'Media sync program S1: turns green in slice 3 (engine merge rule)',
  );

  test(
    'S2: Check all on a healthy foreign library marks nothing pending',
    () async {
      final dive = await h.a.createDive();
      final id = await h.a.linkFile(bytes, diveId: dive);
      await h.a.sync();
      await h.b.sync();
      // Publish clears B's own marks from the pull; now the library is at rest.
      await h.b.sync();
      expect(await h.b.isPending(id), isFalse);

      final outcome = await h.b.verifyAll();
      expect(outcome.inconclusive, 1,
          reason: 'B cannot read A\'s file: inconclusive, not missing');
      expect(await h.b.isPending(id), isFalse,
          reason: 'an inconclusive verify must not write the row');
    },
    skip: 'Media sync program S2: turns green in slice 4 (quiet verification)',
  );

  test(
    'S3: an older edit arriving later does not overwrite the newer one',
    () async {
      final dive = await h.a.createDive();
      final id = await h.a.linkFile(bytes, diveId: dive);
      await h.a.sync();
      await h.b.sync();

      await h.b.setManualElapsed(id, 50); // older edit, offline
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await h.a.setManualElapsed(id, 100); // newer edit
      await h.a.sync();
      await h.b.sync(); // B publishes its stale 50
      await h.a.sync(); // A pulls it

      expect((await h.a.media(id))!.manualElapsedSeconds, 100,
          reason: 'A\'s row is not pending, so today the blind upsert takes 50');
      expect((await h.b.media(id))!.manualElapsedSeconds, 100,
          reason: 'B must converge on the newer value too');
    },
    skip: 'Media sync program S3: turns green in slice 3 (engine merge rule)',
  );
}
```

- [ ] **Step 2: Resolution scenarios**

```dart
// test/features/media/two_device/resolution_scenarios_test.dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

import '../../../helpers/fake_photo_picker_service.dart';
import '../../../helpers/two_device_media_harness.dart';

void main() {
  late TwoDeviceMediaHarness h;
  final taken = DateTime(2026, 7, 1, 10, 30);
  final photo = Uint8List.fromList(List<int>.generate(512, (i) => i % 251));

  setUp(() async => h = await TwoDeviceMediaHarness.create());
  tearDown(() => h.dispose());

  test(
    'S5: a gallery photo B does not have reads as from another device and '
    'never orphans the row',
    () async {
      final dive = await h.a.createDive();
      final id = await h.a.linkGalleryPhoto(
        FakeGalleryAsset(id: 'A-1', bytes: photo, takenAt: taken),
        diveId: dive,
      );
      await h.a.sync();
      await h.b.sync();

      final tile = await h.b.tile(id);
      expect((tile.data as UnavailableData).kind,
          UnavailableKind.fromOtherDevice,
          reason: 'B never had this photo; it is not evidence it was deleted');

      await h.b.checkTile(id);
      expect((await h.b.media(id))!.isOrphaned, isFalse);
      await h.b.sync();
      await h.a.sync();
      expect((await h.a.media(id))!.isOrphaned, isFalse,
          reason: 'a peer must never plant the orphan flag');
      // Note for slice 7: gallery rows are inserted with a null
      // originDeviceId (media_repository.dart _effectiveOriginDeviceId), so
      // origin-aware verdicts need the origin stamped on gallery rows too.
    },
    skip: 'Media sync program S5: turns green in slice 7 (origin-aware verdicts)',
  );

  test(
    'S6: a burst pair shot in the same second resolves to the right frame '
    'on a peer sharing the photo library',
    () async {
      final frame1 = Uint8List.fromList(List<int>.generate(512, (i) => i % 251));
      final frame2 = Uint8List.fromList(
        List<int>.generate(512, (i) => (i * 7) % 251),
      );
      final dive = await h.a.createDive();
      final id1 = await h.a.linkGalleryPhoto(
        FakeGalleryAsset(id: 'A-b1', bytes: frame1, takenAt: taken),
        diveId: dive,
      );
      final id2 = await h.a.linkGalleryPhoto(
        FakeGalleryAsset(id: 'A-b2', bytes: frame2, takenAt: taken),
        diveId: dive,
      );
      // Same iCloud library on B: same photos, different local ids, and no
      // titles in the listing, so filename cannot break the tie.
      h.b.gallery.add(
        FakeGalleryAsset(id: 'B-b1', bytes: frame1, takenAt: taken, filename: null),
      );
      h.b.gallery.add(
        FakeGalleryAsset(id: 'B-b2', bytes: frame2, takenAt: taken, filename: null),
      );
      await h.a.sync();
      await h.b.sync();

      final t1 = await h.b.tile(id1);
      final t2 = await h.b.tile(id2);
      expect(t1.data, isA<BytesData>(),
          reason: 'a shared cloud identifier tells the frames apart');
      expect((t1.data as BytesData).bytes, frame1);
      expect((t2.data as BytesData).bytes, frame2);
    },
    skip: 'Media sync program S6: turns green in slice 8 (cloud identifier)',
  );

  test(
    'S7: limited photo access on the origin device is inconclusive, not missing',
    () async {
      final dive = await h.b.createDive();
      final id = await h.b.linkGalleryPhoto(
        FakeGalleryAsset(id: 'B-7', bytes: photo, takenAt: taken),
        diveId: dive,
      );
      expect(await h.b.tileOutcome(id), TileOutcome.native);

      // The user later grants limited access and this photo is outside the
      // selected subset.
      h.b.gallery.permission = PhotoPermissionStatus.limited;
      h.b.gallery.hiddenFromLimitedAccess.add('B-7');
      await h.b.assetCache.clearEntry(id);

      final tile = await h.b.tile(id);
      expect((tile.data as UnavailableData).kind, UnavailableKind.accessDenied);
      await h.b.checkTile(id);
      expect((await h.b.media(id))!.isOrphaned, isFalse);
    },
    skip: 'Media sync program S7: turns green in slice 9 (Android limited access)',
  );
}
```

- [ ] **Step 3: Store scenarios**

```dart
// test/features/media/two_device/store_scenarios_test.dart
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/two_device_media_harness.dart';

void main() {
  late TwoDeviceMediaHarness h;
  final bytes = List<int>.generate(1024, (i) => (i * 3) % 251);

  setUp(() async => h = await TwoDeviceMediaHarness.create());
  tearDown(() => h.dispose());

  test(
    'S4: a foreign row whose stamps were lost is still served from the '
    'attached store',
    () async {
      final dive = await h.a.createDive();
      final id = await h.a.linkFile(bytes, diveId: dive);
      await h.a.enqueueUpload(id);
      await h.a.drain();
      await h.a.sync();
      await h.b.sync();
      await h.b.stripStoreStamps(id);

      expect(await h.b.tileOutcome(id), TileOutcome.store,
          reason: 'the bytes are in the store B is attached to');
    },
    skip: 'Media sync program S4: turns green in slice 11 (store gate probe)',
  );

  test(
    'S8: a throwing preflight suspends the worker with a visible reason',
    () async {
      final dive = await h.a.createDive();
      final id = await h.a.linkFile(bytes, diveId: dive);
      h.a.preflight = () async => throw StateError('marker unreadable');
      await h.a.enqueueUpload(id);
      await h.a.drain();

      expect(h.a.worker.isSuspended, isTrue);
      final summary = await h.a.queue.watchSummary().first;
      expect(summary.waitingReason, isNotNull,
          reason: 'the Transfers page must be able to say why nothing moves');
    },
    skip: 'Media sync program S8: turns green in slice 10 (queue visibility)',
  );

  test(
    'S10: a row stranded in transferring by a kill is retried on relaunch',
    () async {
      final dive = await h.a.createDive();
      final id = await h.a.linkFile(bytes, diveId: dive);
      await h.a.enqueueUpload(id);
      final entry = (await h.a.queue.allForTesting()).single;
      await h.a.queue.markTransferring(entry.id); // the process died here

      await h.a.relaunch();
      await h.a.drain();

      expect((await h.a.media(id))!.remoteUploadedAt, isNotNull,
          reason: 'drain must reclaim stranded rows before selecting pending');
    },
    skip: 'Media sync program S10: turns green in slice 10 (queue visibility)',
  );
}
```

- [ ] **Step 4: Deletion scenario**

```dart
// test/features/media/two_device/deletion_scenarios_test.dart
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/two_device_media_harness.dart';

void main() {
  late TwoDeviceMediaHarness h;
  final bytes = List<int>.generate(1024, (i) => (i * 5) % 251);

  setUp(() async => h = await TwoDeviceMediaHarness.create());
  tearDown(() => h.dispose());

  test(
    'S9: deleting a diver removes their media everywhere and queues the '
    'blob delete',
    () async {
      final dive = await h.a.createDive(diverId: 'diver1');
      final id = await h.a.linkFile(bytes, diveId: dive);
      await h.a.enqueueUpload(id);
      await h.a.drain();
      await h.a.sync();
      await h.b.sync();
      expect(await h.b.media(id), isNotNull);

      await h.a.deleteDiver('diver1');
      expect(await h.a.media(id), isNull,
          reason: 'linked only to the deleted diver\'s dive');
      final deletes = (await h.a.queue.allForTesting())
          .where((e) => e.direction == 'delete');
      expect(deletes, hasLength(1),
          reason: 'the uploaded copy must be scheduled for removal');

      await h.a.sync();
      await h.b.sync();
      expect(await h.b.media(id), isNull,
          reason: 'the tombstone must reach the peer');
    },
    skip: 'Media sync program S9: turns green in slice 6 (diver delete cascade)',
  );
}
```

- [ ] **Step 5: Prove each scenario red**

For each of the four files, temporarily comment out the `skip:` lines, run the file, and record the first failing `expect` line per scenario:

Run: `flutter test test/features/media/two_device/row_sync_scenarios_test.dart`
Expected: S1 fails at `remoteUploadedAt isNotNull`; S2 fails at the second `isPending isFalse`; S3 fails at `manualElapsedSeconds 100` on A.

Run: `flutter test test/features/media/two_device/resolution_scenarios_test.dart`
Expected: S5 fails at `fromOtherDevice` (actual `notFound`); S6 fails at `isA<BytesData>` (actual `UnavailableData`, the two candidates are ambiguous); S7 fails at `accessDenied` (actual `notFound`).

Run: `flutter test test/features/media/two_device/store_scenarios_test.dart`
Expected: S4 fails at `TileOutcome.store` (actual `unavailable`); S8 fails at `isSuspended isTrue`; S10 fails at `remoteUploadedAt isNotNull`.

S8 is red by design: a preflight throw leaves the row untouched and the worker unsuspended today, which is the seam. It asserts through two members that already exist, `MediaStoreWorker.isSuspended` and `MediaTransferSummary.waitingReason`, and slice 10 (spec 7.1) makes the worker record the suspension with a reason and surface it through exactly those two, so the scenario needs no new API to turn green.

Run: `flutter test test/features/media/two_device/deletion_scenarios_test.dart`
Expected: S9 fails at the first `media(id) isNull` or at the blob-delete count.

If a scenario is GREEN on main, do not skip it: it means the seam is already closed, note that in the PR body, and leave the test active as a regression guard. If a scenario fails for a reason other than the expected assertion (a throw in the harness), fix the harness, not the scenario.

Restore the `skip:` lines.

- [ ] **Step 6: Run the whole two-device folder and commit**

Run: `flutter test test/features/media/two_device/`
Expected: 2 passed (S0, S0b), 10 skipped.

```bash
dart format .
flutter analyze
git add test/features/media/two_device/
git commit -m "test(media): seed the media sync program scenarios S1 to S10 against the two-device harness"
```

`FakeGalleryAsset.filename` must be `String?` for S6's title-less listing; make it nullable in Task 2's fake (the `AssetInfo.filename` it feeds is already nullable).

```bash
```

Open the slice 1 PR with body `Part of #<tracking issue>` and the "Red on main" list. Slice 2 starts from a fresh worktree after it merges.

---

## Slice 2: diagnostics

### Task 5: `LogCategory.media` with a per-category file floor

**Files:**
- Modify: `lib/core/models/log_entry.dart:1-21`
- Modify: `lib/core/services/logger_service.dart:43,66-88,102-103,278`
- Modify: `lib/features/settings/presentation/log_category_display.dart`
- Modify: `lib/features/settings/presentation/widgets/log_entry_tile.dart:95-101` (`_categoryColor`, an exhaustive switch)
- Modify: `lib/features/settings/presentation/providers/debug_log_providers.dart:45-51`
- Modify: all 11 `lib/l10n/arb/app_*.arb`, key `enum_logCategory_media` after `enum_logCategory_database` (en at line 6766)
- Test: `test/core/services/logger_service_test.dart`, `test/core/models/log_entry_test.dart`

- [ ] **Step 1: Write the failing tests**

Add to `test/core/models/log_entry_test.dart`:

```dart
  test('media category round-trips through its tag', () {
    expect(LogCategory.media.tag, 'MED');
    expect(LogCategory.fromTag('MED'), LogCategory.media);
  });
```

Add to `test/core/services/logger_service_test.dart`, inside the group that already configures a fake `LogFileService` (copy its setup; the file has one):

```dart
  test('media info lines reach the file when verbose logging is off', () async {
    LoggerService.configureFileLogging(fileService, verbose: false);
    LoggerService.forClass(Object).info(
      'resolver breadcrumb',
      category: LogCategory.media,
    );
    LoggerService.forClass(Object).info('app breadcrumb');
    await LoggerService.flushPendingWrites();
    expect(fileService.lines.join('\n'), contains('resolver breadcrumb'));
    expect(fileService.lines.join('\n'), isNot(contains('app breadcrumb')));
  });

  test('a category floor never raises the verbose floor', () async {
    LoggerService.configureFileLogging(fileService, verbose: true);
    LoggerService.forClass(Object).debug(
      'media debug',
      category: LogCategory.media,
    );
    await LoggerService.flushPendingWrites();
    expect(fileService.lines.join('\n'), contains('media debug'));
  });
```
`fileService.lines` is whatever the existing fake in that test file exposes for written lines; use its name.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/models/log_entry_test.dart test/core/services/logger_service_test.dart`
Expected: FAIL, "Undefined name 'media'".

- [ ] **Step 3: Implement**

`log_entry.dart`: add `media('MED', 'Media'),` after the `database` value.

`logger_service.dart`:

```dart
  /// Categories whose breadcrumbs are worth having in a user's exported log
  /// even when verbose logging is off. The floor is a ceiling on the global
  /// one: it can only admit more, never less.
  static const Map<LogCategory, LogLevel> _categoryFileFloors = {
    LogCategory.media: LogLevel.info,
  };

  static bool _persists(
    LogLevel level,
    bool alwaysPersist, {
    required LogCategory category,
  }) {
    if (alwaysPersist) return true;
    final global = _minimumFileLevel;
    final own = _categoryFileFloors[category];
    final floor = (own != null && own.index < global.index) ? own : global;
    return level.index >= floor.index;
  }
```
Update all three call sites: `configureFileLogging` line 81 becomes `_persists(line.entry.level, line.alwaysPersist, category: line.entry.category)`, `infoInOrder` line 151 becomes `_persists(LogLevel.info, alwaysPersist, category: category)` (it already has the category in hand), and `_log` line 278 becomes `_persists(level, alwaysPersist, category: category)`. Add a third test case that emits through `infoInOrder` with the media category and asserts the line reached the file.

`log_category_display.dart`: add `LogCategory.media => l10n.enum_logCategory_media,`. `log_entry_tile.dart` `_categoryColor`: add `LogCategory.media => Colors.cyan,` (the switch is exhaustive with no default, so the build breaks without it).

`debug_log_providers.dart:45-51`: add `LogCategory.media,` to the default `activeCategories` set.

ARBs: add `"enum_logCategory_media": "Media"` in all 11 files right after `enum_logCategory_database`. Translations: ar "الوسائط", de "Medien", es "Multimedia", fr "Médias", he "מדיה", hu "Média", it "Media", nl "Media", pt "Mídia", zh "媒体". Then `flutter gen-l10n`.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/core/models/log_entry_test.dart test/core/services/logger_service_test.dart test/features/settings/presentation/`
Expected: PASS. If a settings test enumerates categories and asserts a count of 5, update it to 6 with the new value.

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib/core/models/log_entry.dart lib/core/services/logger_service.dart lib/features/settings/presentation/log_category_display.dart lib/features/settings/presentation/providers/debug_log_providers.dart lib/l10n/ test/core/
git commit -m "feat(logging): add a media log category that reaches the exported log at info"
```

---

### Task 6: Route media breadcrumbs to the new category

**Files:**
- Modify: `lib/core/services/logger_service.dart:302` (`forClass`)
- Modify: `lib/features/media/data/services/asset_resolution_service.dart:53`
- Modify: `lib/features/media/data/resolvers/local_file_resolver.dart` (its `_log`)
- Modify: `lib/features/media/data/resolvers/platform_gallery_resolver.dart` (add a `_log` if none)
- Modify: `lib/features/media/data/resolvers/media_store_resolver.dart:32`, `lib/features/media_store/data/media_store_worker.dart`, `media_store_preflight.dart`, `media_upload_pipeline.dart`, `lib/features/media/data/services/media_item_verifier.dart` (their `_log` declarations)
- Test: `test/core/services/logger_service_test.dart`

- [ ] **Step 1: Failing test**

```dart
  test('forClass can pin a default category', () async {
    final seen = <LogEntry>[];
    final sub = LoggerService.logStream.listen(seen.add);
    LoggerService.forClass(Object, category: LogCategory.media).info('hello');
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(seen.single.category, LogCategory.media);
  });
```
`LoggerService.logStream` is the public stream the viewer reads (backed by `_logStreamController`); use its actual getter name from the file.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/services/logger_service_test.dart`
Expected: FAIL, "The named parameter 'category' isn't defined".

- [ ] **Step 3: Implement**

In `logger_service.dart`: the constructor stays `const`, because `log_environment.dart:159` and `background_service.dart:157` construct `const LoggerService(...)`. It becomes `const LoggerService(this._name, {this.category = LogCategory.app});` with `final LogCategory category;` (an initializing formal keeps it const). `forClass` becomes `static LoggerService forClass(Type type, {LogCategory category = LogCategory.app}) => LoggerService(type.toString(), category: category);`, and each public method's `LogCategory category = LogCategory.app` parameter becomes `LogCategory? category` passed to `_log` as `category: category ?? this.category`. Treat `infoInOrder` at line 144 the same way.

In each media file listed above change the logger declaration to, for example:

```dart
final _log = LoggerService.forClass(
  AssetResolutionService,
  category: LogCategory.media,
);
```
adding `import 'package:submersion/core/models/log_entry.dart';` where missing. Do not touch the message strings.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/core/services/logger_service_test.dart test/features/media/ test/features/media_store/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib/core/services/logger_service.dart lib/features/media lib/features/media_store test/core/services/logger_service_test.dart
git commit -m "feat(logging): log the media resolvers, verifier and transfer worker under the media category"
```

---

### Task 7: `PeerDeviceNameStore`, fed by the changeset reader

**Files:**
- Create: `lib/core/services/sync/peer_device_name_store.dart`
- Modify: `lib/core/services/sync/changeset_log/changeset_reader.dart:106-115,170-175`
- Modify: `lib/core/services/sync/sync_service.dart:293-307` and the `_changesetReader.pull(` call, and `_collectEpochBaseSources` after the manifest parses (line 4156)
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart:492-502`
- Test: `test/core/services/sync/peer_device_name_store_test.dart`, `test/core/services/sync/changeset_reader_peer_names_test.dart`

**Interfaces:**
- Produces:

```dart
class PeerDeviceNameStore {
  PeerDeviceNameStore(SharedPreferences prefs);
  static const prefsKey = 'sync_peer_device_names';
  Map<String, String> all();
  String? nameFor(String deviceId);
  Future<void> record(String deviceId, String name);
  /// Emits the full map after every change, so a label built before a sync
  /// learned a name updates without being recreated.
  Stream<Map<String, String>> get changes;
  void dispose();
}
final peerDeviceNameStoreProvider = Provider<PeerDeviceNameStore>(...);
/// The live map: seeded with the store's current contents, then every change.
final peerDeviceNamesProvider = StreamProvider<Map<String, String>>(...);
```
`ChangesetReader.pull` gains `PeerDeviceNameStore? peerNames`; `SyncService` gains `PeerDeviceNameStore? peerNames`.

- [ ] **Step 1: Failing tests**

```dart
// test/core/services/sync/peer_device_name_store_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/sync/peer_device_name_store.dart';

void main() {
  test('records and reads back a peer name', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PeerDeviceNameStore(await SharedPreferences.getInstance());
    expect(store.nameFor('dev-a'), isNull);
    await store.record('dev-a', "Eric's MacBook");
    expect(store.nameFor('dev-a'), "Eric's MacBook");
    expect(store.all(), {'dev-a': "Eric's MacBook"});
  });

  test('a later name replaces the earlier one', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PeerDeviceNameStore(await SharedPreferences.getInstance());
    await store.record('dev-a', 'old');
    await store.record('dev-a', 'new');
    expect(store.nameFor('dev-a'), 'new');
  });

  test('ignores an empty name', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PeerDeviceNameStore(await SharedPreferences.getInstance());
    await store.record('dev-a', '');
    expect(store.nameFor('dev-a'), isNull);
  });

  test('changes emits the full map after each record', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PeerDeviceNameStore(await SharedPreferences.getInstance());
    final seen = <Map<String, String>>[];
    final sub = store.changes.listen(seen.add);
    await store.record('dev-a', 'A');
    await store.record('dev-b', 'B');
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(seen, [
      {'dev-a': 'A'},
      {'dev-a': 'A', 'dev-b': 'B'},
    ]);
  });
}
```

```dart
// test/core/services/sync/changeset_reader_peer_names_test.dart
// Two devices through the real SyncService against one FakeCloudStorageProvider,
// copying the setUp of test/features/dive_log/integration/consolidation_sync_roundtrip_test.dart:44-74.
// Device A publishes, then its manifest is rewritten with a deviceName the
// way test/helpers/changeset_test_helpers.dart restampPeerSchemaVersion rewrites
// schemaVersion (add a sibling helper restampPeerDeviceName(cloud, deviceId, name)
// there). Device B syncs with a PeerDeviceNameStore injected.
//
//   expect(store.nameFor(deviceAId), "Eric's MacBook");
```
Write the full test following that recipe; the helper is a copy of `restampPeerSchemaVersion` that sets `deviceName` on the decoded manifest JSON before re-uploading.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/services/sync/peer_device_name_store_test.dart test/core/services/sync/changeset_reader_peer_names_test.dart`
Expected: FAIL, missing file and missing parameter.

- [ ] **Step 3: Implement**

```dart
// lib/core/services/sync/peer_device_name_store.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The display names peers published on their sync manifests, keyed by
/// device id, so the app can say "From Eric's MacBook" without a cloud read.
///
/// Manifests are the only place a peer's name lives; the sync layer keeps
/// this map current on every pull and every adopt. A device that never
/// published a name has no entry, and callers fall back to a generic label.
class PeerDeviceNameStore {
  PeerDeviceNameStore(this._prefs);

  static const prefsKey = 'sync_peer_device_names';
  final SharedPreferences _prefs;

  Map<String, String> all() {
    final raw = _prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return const {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const {};
    return {
      for (final e in decoded.entries)
        if (e.key is String && e.value is String) e.key as String: e.value as String,
    };
  }

  String? nameFor(String deviceId) => all()[deviceId];

  Future<void> record(String deviceId, String name) async {
    if (name.isEmpty) return;
    final current = all();
    if (current[deviceId] == name) return;
    final next = {...current, deviceId: name};
    await _prefs.setString(prefsKey, jsonEncode(next));
    _changes.add(next);
  }

  final _changes = StreamController<Map<String, String>>.broadcast();

  Stream<Map<String, String>> get changes => _changes.stream;

  void dispose() => _changes.close();
}
```

`changeset_reader.dart`: add `PeerDeviceNameStore? peerNames,` to `pull`'s named parameters; after `peerName = manifestName;` (line 173) add `await peerNames?.record(peerId, manifestName);`.

`sync_service.dart`: constructor gains `PeerDeviceNameStore? peerNames,` stored in `final PeerDeviceNameStore? _peerNames;`; pass `peerNames: _peerNames` at the `_changesetReader.pull(` call; in `_collectEpochBaseSources`, right after the `try { manifest = SyncManifest.fromBytes(...) } catch (_) { continue; }` block, add:

```dart
      final publishedName = manifest.deviceName;
      if (publishedName != null && publishedName.isNotEmpty) {
        await _peerNames?.record(deviceId, publishedName);
      }
```

`sync_providers.dart`:

```dart
/// Names peers published on their manifests, for labels that must not wait
/// on a cloud listing.
final peerDeviceNameStoreProvider = Provider<PeerDeviceNameStore>((ref) {
  final store = PeerDeviceNameStore(ref.watch(sharedPreferencesProvider));
  ref.onDispose(store.dispose);
  return store;
});

/// The live name map: the store's contents now, then every change, so a
/// label already on screen updates when a sync learns a name.
final peerDeviceNamesProvider = StreamProvider<Map<String, String>>((ref) async* {
  final store = ref.watch(peerDeviceNameStoreProvider);
  yield store.all();
  yield* store.changes;
});
```
Add `import 'dart:async';` to the store file.
and `peerNames: ref.watch(peerDeviceNameStoreProvider),` inside `syncServiceProvider`.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/core/services/sync/`
Expected: PASS, including every existing reader and service test (the parameter is optional).

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib/core/services/sync/peer_device_name_store.dart lib/core/services/sync/changeset_log/changeset_reader.dart lib/core/services/sync/sync_service.dart lib/features/settings/presentation/providers/sync_providers.dart test/core/services/sync/ test/helpers/changeset_test_helpers.dart
git commit -m "feat(sync): remember the names peers publish on their manifests"
```

---

### Task 8: Name the origin device on placeholders and the info panel

**Files:**
- Modify: `lib/features/media/data/resolvers/local_file_resolver.dart:57-75,201-205`
- Modify: `lib/features/media/data/resolvers/platform_gallery_resolver.dart:45-56` and the two `return _elsewhere;` sites
- Modify: `lib/features/media/presentation/providers/media_resolver_providers.dart:45-54,105-121`
- Modify: `lib/features/media/presentation/providers/media_provenance_providers.dart:86-92`
- Modify: `lib/features/media/presentation/widgets/media_info_panel.dart:252-300`
- Test: `test/features/media/data/resolvers/local_file_resolver_test.dart`, `test/features/media/data/resolvers/platform_gallery_resolver_test.dart`, `test/features/media/presentation/widgets/media_info_panel_test.dart` (create if absent)

**Interfaces:**
- Both resolvers gain `Future<String?> Function(String deviceId)? deviceLabel`.
- Produces `originDeviceLabelProvider = Provider.family<String?, String>` in `media_provenance_providers.dart` (synchronous: the store is a prefs map).

- [ ] **Step 1: Failing tests**

In `local_file_resolver_test.dart`, next to the existing "desktop row on a phone resolver" test (around line 859), add:

```dart
  test('a foreign-origin miss names the device when a label is known', () async {
    final r = LocalFileResolver(
      bookmarkStorage: _NullBookmarkStorage(),
      platform: LocalMediaPlatform(),
      exifExtractor: ExifExtractor(),
      localDeviceId: () async => 'phone',
      deviceLabel: (id) async => id == 'desk' ? "Eric's MacBook" : null,
    );
    final data = await r.resolve(
      _item(localPath: '/nonexistent/reef.jpg', originDeviceId: 'desk'),
    );
    expect(data, isA<UnavailableData>());
    final u = data as UnavailableData;
    expect(u.kind, UnavailableKind.fromOtherDevice);
    expect(u.originDeviceLabel, "Eric's MacBook");
  });
```
`_item` is whatever row builder that test file already uses; pass `originDeviceId` through it.

In `platform_gallery_resolver_test.dart`, next to the `hasPhotoLibrary: false` test (around line 141):

```dart
  test('a no-library host names the origin device when known', () async {
    final r = PlatformGalleryResolver(
      resolutionService: service,
      hasPhotoLibrary: false,
      deviceLabel: (id) async => 'iPhone 16 Pro',
    );
    final data = await r.resolve(rowWithOrigin('phone-id')) as UnavailableData;
    expect(data.kind, UnavailableKind.fromOtherDevice);
    expect(data.originDeviceLabel, 'iPhone 16 Pro');
  });

  test('a null origin gets the anonymous placeholder', () async {
    final r = PlatformGalleryResolver(
      resolutionService: service,
      hasPhotoLibrary: false,
      deviceLabel: (id) async => 'never called',
    );
    final data = await r.resolve(rowWithOrigin(null)) as UnavailableData;
    expect(data.originDeviceLabel, isNull);
  });
```
`service` and a row builder exist in that file; add `rowWithOrigin(String?)` beside them if there is none.

Info panel widget test: pump `MediaInfoPanel(item: rowLinkedOn('desk'))` inside a `ProviderScope` overriding `currentDeviceIdProvider` to `'phone'`, `originDeviceLabelProvider('desk')` to `"Eric's MacBook"`, `mediaByIdProvider` to the row, and `settingsProvider` per `test/helpers/mock_providers.dart`; expect `find.text("Eric's MacBook")`. A second case with the override returning null expects the existing "Another device" string. A third case overrides `peerDeviceNamesProvider` with a `StreamController` and asserts the label changes from "Another device" to the name after the controller emits, without rebuilding the panel.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/data/resolvers/ test/features/media/presentation/widgets/media_info_panel_test.dart`
Expected: FAIL, "The named parameter 'deviceLabel' isn't defined".

- [ ] **Step 3: Implement**

`local_file_resolver.dart`: constructor parameter `Future<String?> Function(String deviceId)? deviceLabel` stored as `_deviceLabel`. Replace line 204's `return const UnavailableData(kind: UnavailableKind.fromOtherDevice);` with:

```dart
      return UnavailableData(
        kind: UnavailableKind.fromOtherDevice,
        originDeviceLabel: await _labelFor(item.originDeviceId),
      );
```
and add:

```dart
  /// The published name of [deviceId], or null when unknown or unset. Never
  /// throws: a label is decoration on a placeholder, not a verdict.
  Future<String?> _labelFor(String? deviceId) async {
    final lookup = _deviceLabel;
    if (deviceId == null || lookup == null) return null;
    try {
      return await lookup(deviceId);
    } catch (_) {
      return null;
    }
  }
```

`platform_gallery_resolver.dart`: same parameter and helper; delete `static const _elsewhere` and replace both `return _elsewhere;` with `return await _elsewhereFor(item);` where:

```dart
  Future<UnavailableData> _elsewhereFor(MediaItem item) async =>
      UnavailableData(
        kind: UnavailableKind.fromOtherDevice,
        originDeviceLabel: await _labelFor(item.originDeviceId),
      );
```

`media_provenance_providers.dart`:

```dart
/// The published name of the device that linked a row, for "From {device}"
/// labels. Null when the peer never published one; callers keep the generic
/// wording.
final originDeviceLabelProvider = Provider.family<String?, String>(
  (ref, deviceId) => ref.watch(peerDeviceNamesProvider).value?[deviceId],
);
```

`media_resolver_providers.dart`: pass `deviceLabel: (id) async => ref.read(peerDeviceNameStoreProvider).nameFor(id),` to both resolver constructors (a resolver answers per resolution, so a read of the current map is right there; the live stream matters for widgets already on screen).

`media_info_panel.dart:294-300`: the "Linked on" value becomes

```dart
            value: (thisDevice == null || deviceId == thisDevice)
                ? l10n.media_info_thisDevice
                : (ref.watch(originDeviceLabelProvider(deviceId)) ??
                      l10n.media_info_otherDevice),
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/media/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib/features/media test/features/media
git commit -m "feat(media): name the device a photo was linked on instead of saying another device"
```

---

### Task 9: `MediaHealthReporter`

**Files:**
- Create: `lib/features/media/data/services/media_health_report.dart`
- Create: `lib/features/media/data/services/media_health_reporter.dart`
- Create: `lib/features/media/presentation/providers/media_health_providers.dart`
- Test: `test/features/media/data/services/media_health_report_test.dart`, `test/features/media/data/services/media_health_reporter_test.dart`

**Interfaces:**
- Consumes: `MediaRepository.getMediaById`, `MediaRepository.getAllBySourceTypes(...)` (`media_repository.dart:607`, the whole-library read; pass every `MediaSourceType` value in the collection type its signature takes), `SyncRepository.getPendingRecords()`, `LocalAssetCacheRepository.getCacheEntry`/`isExpired`, `MediaTransferQueueRepository.watchLatestForMedia(id).first`, `MediaSourceResolverRegistry.resolverFor(type).resolve(item)`, `MediaStoreAttachState.attachedStoreId()`, `StoreMarkerStore(store:).read()`, `MediaObjectStore.head(key)` (`media_object_store.dart:45`) with `StoreKeys.objectKey` (`store_keys.dart:16`), `PeerDeviceNameStore.nameFor`.
- Produces:

```dart
class MediaHealthRow {
  const MediaHealthRow({
    required this.mediaId, required this.sourceType, this.originalFilename,
    required this.takenAt, this.diveId, this.siteId,
    this.originDeviceId, this.originDeviceName, this.linkedHere,   // bool?: null when the origin is unknown
    this.contentHash, this.contentSizeBytes, this.remoteUploadedAt,
    this.remoteThumbUploadedAt, this.remoteCompressedUploadedAt,
    required this.isOrphaned, this.lastVerifiedAt, this.hlc, required this.pending,
    this.filePath, this.localPath, this.platformAssetId,   // the source pointer
    this.cachedAssetId, this.cacheMethod, this.cacheAttempts, this.cacheExpired,
    this.cacheNextRetryAt,               // resolvedAt plus the backoff step for attemptCount
    required this.resolverVerdict,       // 'available' or the UnavailableKind name
    this.storeObjectExists,              // null when not probed
    this.storeObjectTier,                // 'original', 'rendition' or 'thumbnail' when it exists
    this.queueState, this.queueAttempts, this.queueNextAttemptAt, this.queueError,
    this.queueWaiting,                   // true when nextAttemptAt is in the future
  });
  Map<String, Object?> toJson();
  String toText();                       // one block, key: value per line
}

class MediaHealthReport {
  const MediaHealthReport({required this.generatedAt, required this.deviceId,
      this.deviceName, this.attachedStoreId, this.markerStoreId,
      required this.rows});
  Map<String, Object?> toJson();
  String toText();                       // header then every row's toText
}

class MediaHealthReporter {
  MediaHealthReporter({
    required MediaRepository mediaRepository,
    required SyncRepository syncRepository,
    required LocalAssetCacheRepository assetCache,
    required MediaTransferQueueRepository queue,
    required MediaSourceResolverRegistry registry,
    required MediaStoreAttachState attachState,
    required Future<MediaObjectStore?> Function() store,   // never the runtime
    required Future<String> Function() localDeviceId,
    required Future<String?> Function() localDeviceName,   // this device is not in the peer map
    required String? Function(String deviceId) deviceName, // peers, from the manifest names
    DateTime Function()? now,
  });
  /// One-row report with the same header (device, attached store, marker),
  /// so the clipboard diagnostics carry the store verdict too.
  Future<MediaHealthReport> forItem(MediaItem item, {bool probeStore = false});
  Future<MediaHealthReport> forLibrary({bool probeStore = false});
}

final mediaHealthReporterProvider = Provider<MediaHealthReporter>(...);
```

- [ ] **Step 1: Failing tests**

`media_health_report_test.dart`: build a `MediaHealthRow` with every field set, assert `toJson()` keys are exactly the field names in snake_case, `toText()` contains `media_id: m1`, `resolver_verdict: fromOtherDevice`, and that a null `storeObjectExists` renders as `store_object: not probed`. Build a `MediaHealthReport` with two rows and assert the text starts with `Submersion media health report`, contains `device: <id> (<name>)`, `attached_store:` and `marker_store:` lines, and both row blocks separated by a blank line.

`media_health_reporter_test.dart`: reuse the two-device harness. Scenario: A links a file, uploads, syncs; B syncs. Build a reporter for B from the harness pieces (`MediaRepository()`, `SyncRepository()`, `h.b.assetCache`, `h.b.queue`, `h.b.registry`, `MediaStoreAttachState()`, `() async => h.bucket`, `() async => h.b.deviceId`, `() async => 'Device B'`, `(id) => id == h.a.deviceId ? 'Device A' : null`). Assert on `forItem(row, probeStore: true)`: one row with `linkedHere` false, `originDeviceName` 'Device A', `resolverVerdict` 'fromOtherDevice', `contentHash` non-null, `hlc` non-null, `filePath` equal to A's path, `storeObjectExists` true, `pending` false, `queueState` null, and the report's `attachedStoreId == markerStoreId == h.storeId`. Then `forLibrary()` has one row. A second test on A: `linkedHere` true, `resolverVerdict` 'available', `queueState` 'done'. A third test: a row with a null `originDeviceId` reports `linkedHere` null and its text says `origin_device: unknown`. A fourth: a row whose cache entry is `unresolved` with `attemptCount` 1 reports `cacheNextRetryAt` equal to `resolvedAt` plus 3 days, and with `attemptCount` 2 plus 7 days (the repository indexes its ladder by `attemptCount`). A fifth: on device A, the report header and the row's `originDeviceName` carry the local device name, resolved through `localDeviceName`, not the peer map.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/data/services/media_health_report_test.dart test/features/media/data/services/media_health_reporter_test.dart`
Expected: FAIL, missing files.

- [ ] **Step 3: Implement the value objects**

`media_health_report.dart` holds the two classes above, plus:

```dart
String _ts(DateTime? t) => t?.toUtc().toIso8601String() ?? 'null';
```
`toText()` for a row emits, in this order, one `key: value` line each: `media_id`, `source_type`, `original_filename`, `pointer` (the file path, local path or platform asset id, whichever the source type uses), `taken_at`, `dive_id`, `site_id`, `origin_device` (`unknown` when the id is null; otherwise the id plus the name in parentheses when known, plus ` (this device)` when `linkedHere` is true), `content_hash`, `content_size_bytes`, `remote_uploaded_at`, `remote_thumb_uploaded_at`, `remote_compressed_uploaded_at`, `is_orphaned`, `last_verified_at`, `hlc`, `pending`, `cache` (method, asset id, attempts, `expired`/`fresh`, next retry time, or `none`), `resolver_verdict`, `store_object` (`exists as <tier>`, `missing` or `not probed`), `queue` (state, attempts, `waiting until <time>` when `queueWaiting`, error, or `none`). `toJson()` uses the same keys with typed values, ISO 8601 UTC strings for dates.

The report header: `Submersion media health report`, `generated_at`, `device: <id> (<name or unnamed>)`, `attached_store`, `marker_store`, `rows: <count>`, blank line, rows joined by a blank line.

- [ ] **Step 4: Implement the reporter**

```dart
// lib/features/media/data/services/media_health_reporter.dart  (shape; fill from the interfaces above)
class MediaHealthReporter {
  // constructor stores every dependency

  Future<MediaHealthReport> forItem(MediaItem item, {bool probeStore = false}) async {
    final me = await _localDeviceId();
    final pendingIds = (await _syncRepository.getPendingRecords())
        .where((r) => r.entityType == 'media')
        .map((r) => r.recordId)
        .toSet();
    final row = await _row(item, me: me, pending: pendingIds.contains(item.id), probeStore: probeStore);
    return _report(me, [row]);   // same header as the library report
  }

  Future<MediaHealthReport> forLibrary({bool probeStore = false}) async {
    final me = await _localDeviceId();
    final pendingIds = ...same...;
    final items = await _mediaRepository.getAllBySourceTypes(
        MediaSourceType.values.toSet());
    final rows = <MediaHealthRow>[
      for (final item in items)
        await _row(item, me: me, pending: pendingIds.contains(item.id), probeStore: probeStore),
    ];
    return _report(me, rows);
  }

  Future<MediaHealthReport> _report(String me, List<MediaHealthRow> rows) async {
    final attached = await _attachState.attachedStoreId();
    String? marker;
    final store = await _store();
    if (store != null) {
      try { marker = (await StoreMarkerStore(store: store).read())?.storeId; } catch (_) {}
    }
    return MediaHealthReport(generatedAt: _now(), deviceId: me, deviceName: await _localDeviceName(),
        attachedStoreId: attached, markerStoreId: marker, rows: rows);
  }

  Future<MediaHealthRow> _row(MediaItem item, {required String me, required bool pending, required bool probeStore}) async {
    final cache = await _assetCache.getCacheEntry(item.id);
    final cacheExpired = cache == null ? null : await _assetCache.isExpired(item.id);
    // The repository keeps its ladder private and indexes it by attemptCount
    // directly (local_asset_cache_repository.dart:104-108); mirror both here
    // and cover them with the fourth reporter test so a change to one shows
    // up in the other. resolvedAt is epoch milliseconds.
    const ladder = [Duration(hours: 24), Duration(days: 3), Duration(days: 7)];
    final cacheNextRetryAt = (cache == null || cache.resolutionMethod != 'unresolved')
        ? null
        : DateTime.fromMillisecondsSinceEpoch(cache.resolvedAt)
            .add(ladder[cache.attemptCount.clamp(0, ladder.length - 1)]);
    final hlc = await _mediaRepository.getSyncHlc(item.id);
    String verdict;
    try {
      final data = await _registry.resolverFor(item.sourceType).resolve(item);
      verdict = data is UnavailableData ? data.kind.name : 'available';
    } catch (e) {
      verdict = 'error: $e';
    }
    // The pipeline stores an original under objectKey, a compressed-only
    // upload under renditionKey and a thumb under thumbKey, so the namespace
    // follows the stamps. With no stamps at all (the lost-stamp case) every
    // namespace is probed, in that order, so the row stays diagnosable.
    bool? exists;
    String? tier;
    if (probeStore && item.contentHash != null) {
      final store = await _store();
      if (store != null) {
        final hash = item.contentHash!;
        final ext = StoreKeys.extensionFor(item.originalFilename);
        final candidates = <(String, String)>[
          if (item.remoteUploadedAt != null)
            ('original', StoreKeys.objectKey(hash, extension: ext)),
          if (item.remoteCompressedUploadedAt != null)
            ('rendition', StoreKeys.renditionKey(hash, ext: ext)),
          if (item.remoteThumbUploadedAt != null)
            ('thumbnail', StoreKeys.thumbKey(hash)),
        ];
        final probes = candidates.isNotEmpty
            ? candidates
            : [
                ('original', StoreKeys.objectKey(hash, extension: ext)),
                ('rendition', StoreKeys.renditionKey(hash, ext: ext)),
                ('thumbnail', StoreKeys.thumbKey(hash)),
              ];
        try {
          exists = false;
          for (final (name, key) in probes) {
            if (await store.head(key) != null) {
              exists = true;
              tier = name;
              break;
            }
          }
        } catch (_) {
          exists = null;
        }
      }
    }
    final entry = await _queue.watchLatestForMedia(item.id).first;
    final nextAttempt = entry?.nextAttemptAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(entry!.nextAttemptAt!);
    final origin = item.originDeviceId;
    return MediaHealthRow(
      mediaId: item.id, sourceType: item.sourceType.name, originalFilename: item.originalFilename,
      takenAt: item.takenAt, diveId: item.diveId, siteId: item.siteId,
      originDeviceId: origin,
      originDeviceName: origin == null
          ? null
          : (origin == me ? await _localDeviceName() : _deviceName(origin)),
      linkedHere: origin == null ? null : origin == me,
      filePath: item.filePath, localPath: item.localPath, platformAssetId: item.platformAssetId,
      contentHash: item.contentHash, contentSizeBytes: item.contentSizeBytes,
      remoteUploadedAt: item.remoteUploadedAt, remoteThumbUploadedAt: item.remoteThumbUploadedAt,
      remoteCompressedUploadedAt: item.remoteCompressedUploadedAt,
      isOrphaned: item.isOrphaned, lastVerifiedAt: item.lastVerifiedAt, hlc: hlc, pending: pending,
      cachedAssetId: cache?.localAssetId, cacheMethod: cache?.resolutionMethod,
      cacheAttempts: cache?.attemptCount, cacheExpired: cacheExpired,
      cacheNextRetryAt: cacheNextRetryAt,
      resolverVerdict: verdict, storeObjectExists: exists, storeObjectTier: tier,
      queueState: entry?.state, queueAttempts: entry?.attempts,   // the table column is `attempts`
      queueNextAttemptAt: nextAttempt,
      queueWaiting: nextAttempt != null && nextAttempt.isAfter(_now()),
      queueError: entry?.errorMessage,
    );
  }
}
```
`StoreKeys.extensionFor` (`store_keys.dart:51`) is the same helper the upload pipeline uses at `media_upload_pipeline.dart:226` and `:244`; it answers `bin` for a filename without an extension, so an extensionless object is still addressable and the probe always runs. Pass `renditionKey` the same `ext` the pipeline passes at `media_upload_pipeline.dart:185`; read that call and copy its derivation if it differs from the original's extension. `MediaItem` does not carry `hlc`; add the narrow read `Future<String?> getSyncHlc(String id)` to `MediaRepository` (a `selectOnly` of the `hlc` column by id, next to `getDisplayLabels`) with a unit test beside the existing origin-device repository tests, and use it here.

`media_health_providers.dart`:

```dart
final mediaHealthReporterProvider = Provider<MediaHealthReporter>((ref) {
  return MediaHealthReporter(
    mediaRepository: ref.watch(mediaRepositoryProvider),
    syncRepository: SyncRepository(),
    assetCache: ref.watch(localAssetCacheRepositoryProvider),
    queue: ref.watch(mediaTransferQueueRepositoryProvider),
    registry: ref.watch(mediaSourceResolverRegistryProvider),
    attachState: ref.watch(mediaStoreAttachStateProvider),
    store: () => ref.read(attachedMediaObjectStoreProvider.future),
    localDeviceId: () => SyncRepository().getDeviceId(),
    localDeviceName: () async =>
        (await SyncDeviceMetadata(SyncRepository()).resolve()).name,
    deviceName: (id) => ref.read(peerDeviceNamesProvider).value?[id],
  );
});
```

Building `mediaStoreRuntimeProvider` starts a transfer drain and an opportunistic verification sweep, so a diagnostics read must never construct it. Extract the store construction the runtime provider does inline (`media_store_providers.dart:409-440`: attach state, then the account path through `buildMediaObjectStoreForAccount` or the legacy path through `buildMediaObjectStore`) into

```dart
/// The attached media store's adapter, or null when nothing is attached or
/// the provider cannot be built right now. Side-effect free: no worker, no
/// drain, no sweep. The runtime provider builds on top of this.
final attachedMediaObjectStoreProvider = FutureProvider<MediaObjectStore?>(...);
```

and make `mediaStoreRuntimeProvider` watch it instead of repeating the construction. The existing runtime provider tests must pass unchanged.

```dart
```
Use the existing provider names for the cache repository, queue repository and attach state (search `media_store_providers.dart` and `media_resolver_providers.dart`; each exists under a `<noun>Provider` name).

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/media/data/services/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
flutter analyze
flutter test test/architecture/
git add lib/features/media/data/services/media_health_report.dart lib/features/media/data/services/media_health_reporter.dart lib/features/media/presentation/providers/media_health_providers.dart test/features/media/data/services/
git commit -m "feat(media): build a per-row and per-library media health report"
```

---

### Task 10: The three entry points

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_info_panel.dart:259-276,604-623`
- Modify: `lib/features/media_store/presentation/pages/media_storage_page.dart:68-72,331-357,822-836`
- Modify: `lib/features/settings/presentation/providers/debug_log_providers.dart:168-198`
- Modify: `lib/features/settings/presentation/pages/debug_log_viewer_page.dart:137-152`
- Modify: all 11 ARBs
- Test: `test/features/media/presentation/widgets/media_info_panel_test.dart`, `test/features/media_store/presentation/pages/media_storage_page_test.dart` (extend the existing one), `test/features/settings/presentation/providers/debug_log_providers_test.dart`

**Strings** (en; translate in the other 10, alphabetical beside the named neighbour):

| Key | en | Beside |
| --- | --- | --- |
| `media_info_actionCopyDiagnostics` | Copy diagnostics | `media_info_actionCopyPath` |
| `media_info_diagnosticsCopied` | Diagnostics copied | `media_info_referenceCopied` |
| `settings_mediaStorage_report_action` | Export media report | `settings_mediaStorage_verify_action` |
| `settings_mediaStorage_report_running` | Building the media report | `settings_mediaStorage_verify_running` |
| `settings_mediaStorage_report_done` | Media report exported | `settings_mediaStorage_verify_summary` |
| `settings_mediaStorage_report_note` | The report lists file paths and device names. Nothing is sent anywhere. | `settings_mediaStorage_report_action` |

- [ ] **Step 1: Failing tests**

Info panel: pump the panel with `mediaHealthReporterProvider` overridden by a reporter whose `forItem` returns a fixed one-row report (subclass `MediaHealthReporter` in the test and override `forItem`), tap `find.text('Copy diagnostics')`, and assert the clipboard received text containing both `attached_store:` and `media_id:` using `TestDefaultBinaryMessengerBinding` to capture `Clipboard.setData` (the pattern any existing copy-to-clipboard test in `test/features/` uses; search for `SystemChannels.platform` in test/).

Media Storage page: in the existing page test, override `mediaHealthReporterProvider` with a reporter whose `forLibrary` returns a report with one row, tap `find.byKey(const Key('media-export-report'))`, and assert the injected file-export seam received a filename `submersion-media-report.txt`. If the page test has no seam for `saveAndShareFile`, add an optional `Future<String> Function(String content, String fileName, String mimeType, {Rect? sharePositionOrigin})? exportFile` constructor parameter on `MediaStoragePage` defaulting to `saveAndShareFile` and override it in the test.

Debug log providers: extend the existing `shareLogFile` test (or add one using its fakes) to call `shareLogFile(service, l10n, mediaReport: 'report text')` and assert the share received two files, the second named `submersion-media-report.txt`.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/presentation/widgets/media_info_panel_test.dart test/features/media_store/presentation/pages/media_storage_page_test.dart test/features/settings/presentation/providers/debug_log_providers_test.dart`
Expected: FAIL on missing strings, key and parameter.

- [ ] **Step 3: Implement**

Info panel, in `_OriginSection`'s `actions` list after `_CopyReferenceButton`:

```dart
        _CopyDiagnosticsButton(item: live),
```

```dart
class _CopyDiagnosticsButton extends ConsumerWidget {
  const _CopyDiagnosticsButton({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
    onPressed: () async {
      final messenger = ScaffoldMessenger.of(context);
      final copied = context.l10n.media_info_diagnosticsCopied;
      final report = await ref
          .read(mediaHealthReporterProvider)
          .forItem(item, probeStore: true);
      await Clipboard.setData(ClipboardData(text: report.toText()));
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(copied)));
    },
    child: Text(context.l10n.media_info_actionCopyDiagnostics),
  );
}
```

Media Storage page: a `_exporting` flag folded into `_actionInFlight`, a handler mirroring `_verify`:

```dart
  Future<void> _exportReport() async {
    final l10n = context.l10n;
    final anchor = shareAnchorFrom(context);
    setState(() => _exporting = true);
    try {
      final report = await ref.read(mediaHealthReporterProvider).forLibrary();
      await widget.exportFile(
        report.toText(),
        'submersion-media-report.txt',
        'text/plain',
        sharePositionOrigin: anchor,
      );
      if (mounted) _showSnack(l10n.settings_mediaStorage_report_done);
    } catch (e) {
      if (mounted) _showSnack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
```
and, directly under the Verify button block:

```dart
              FilledButton.tonal(
                key: const Key('media-export-report'),
                onPressed: _actionInFlight ? null : _exportReport,
                child: Text(
                  _exporting
                      ? l10n.settings_mediaStorage_report_running
                      : l10n.settings_mediaStorage_report_action,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.settings_mediaStorage_report_note,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
```

`debug_log_providers.dart`: `shareLogFile` gains `String? mediaReport`; when non-null, write it to `'${tempDir.path}/submersion-media-report.txt'` and append `XFile(reportPath, mimeType: 'text/plain')` to `files`. `debug_log_viewer_page.dart:138-152`: before calling `shareLogFile`, build the report with `await ref.read(mediaHealthReporterProvider).forLibrary()` inside a try that falls back to null on any error (a diagnostics failure must not block the log share), and pass it as `mediaReport: report?.toText()`.

Add the six strings to all 11 ARBs and run `flutter gen-l10n`.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/media/ test/features/media_store/ test/features/settings/`
Expected: PASS.

- [ ] **Step 5: Commit and open the slice 2 PR**

```bash
dart format .
flutter analyze
git add lib/features/media/presentation/widgets/media_info_panel.dart lib/features/media_store/presentation/pages/media_storage_page.dart lib/features/settings/presentation/providers/debug_log_providers.dart lib/features/settings/presentation/pages/debug_log_viewer_page.dart lib/l10n/ test/features/
git commit -m "feat(media): export the media health report from the info panel, Media Storage and the debug log"
```

PR body: `Part of #<tracking issue>`, and a note that `shareLogFile` still bypasses the Linux `canShareFiles` gate (pre-existing, out of scope, filed as a follow-up issue).

---

## Self-review against the spec

- **4.1 harness**: Tasks 1 to 3 build it; Task 4 seeds all ten scenarios, S6 included, since S6 asserts on served bytes and needs no new column to compile. `advanceClock` and `killDuringTransfer` from the spec's API list: the worker has no injectable clock, so `advanceClock` is dropped for Phase 0 (no seed scenario needs it); `killDuringTransfer` is `markTransferring` plus `relaunch`.
- **4.2 health report**: Task 9 (fields, including the source pointer, `hlc`, the cache's next retry time and the queue's waiting state the spec lists), Task 10 (three entry points, privacy note). The single-row report carries the same store header as the library report, so the clipboard diagnostics show the store verdict. `probeStore` defaults to false for the library report.
- **4.3 log plumbing**: Tasks 5 and 6. The per-category floor never raises the verbose floor.
- **4.4 named origin device**: Tasks 7 and 8. The spec said "sync device registry"; on main that registry is a cloud listing, so the plan persists names from manifests instead (no schema, no network read on the render path).
- **Section 9 safety**: no task deletes or moves user files; the harness writes under `systemTemp` only; `PeerDeviceNameStore` stores names only.
- **Placeholders**: none. Two names are flagged as "verify against the tree" (`updateMedia`, the three resolver dependency import paths) because they are pre-existing symbols whose exact spelling the executor confirms with one grep; the design does not depend on them.
- **Type consistency**: `TileResolution`, `TileOutcome`, `HarnessDevice.tile/tileOutcome/checkTile`, `PeerDeviceNameStore.nameFor/record`, `MediaHealthReporter.forItem/forLibrary`, `originDeviceLabelProvider` are spelled the same in every task that uses them.
