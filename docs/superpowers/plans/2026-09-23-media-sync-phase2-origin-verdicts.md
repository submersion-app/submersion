# Media Sync Slice 7: Origin-Aware Gallery Verdicts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A gallery photo a device cannot find is `notFound` only on the device that linked it; everywhere else it is `fromOtherDevice`, so a peer can dim a tile but never orphan the row.

**Architecture:** `PlatformGalleryResolver` learns this device's id (as `LocalFileResolver` already does) and turns a failed search into `fromOtherDevice` unless the row's `originDeviceId` provably names this device. New gallery links record the linking device. A one-time `GalleryOriginBackfill`, run after a successful sync, stamps this device's id on the old gallery rows whose stored asset id still loads here, so peers learn where they live.

**Tech Stack:** Flutter, Dart, Drift over SQLite, `photo_manager` behind `GalleryAssetReader` and `PhotoPickerService`, Riverpod, `flutter_test`, the two-device media harness.

**Spec:** `docs/superpowers/specs/2026-09-18-media-sync-program-design.md`, section 6.1. Sub-issue #2113, part of #2090. Turns scenario S5 green.

## Global Constraints

- `notFound` is the only verdict that orphans a row, and the write syncs to every device (spec 3.2). It is reserved for the device that linked the photo (spec 6.1).
- The reconciler and verifier are unchanged; they already treat `fromOtherDevice` as inconclusive (spec 6.1).
- Owner decision (2026-09-23): a gallery row with **no** origin is never `notFound`, on any device. This replaces the spec's "cache hit" clause, which proved unstable: the first failed thumbnail fetch clears the cached mapping, so the verdict would flip between renders.
- Owner decision (2026-09-23): the backfill runs once **after a successful sync**, never at launch. The origin has no fact group, so a stamp bumps the row clock and republishes the whole row; right after a pull, the window in which it can overwrite a peer's unseen newer edit is smallest.
- Limited photo access is slice 9 (spec 6.3, scenario S7). This slice leaves `accessDenied` handling untouched.
- No schema change: `media.origin_device_id` already exists and syncs.
- Repository rules: no em-dashes anywhere; no mention of Claude, Claude Code or Anthropic in commits, PRs or comments; no emojis in code; `dart format .` before every commit; paths built with `p.join`, never a literal `/tmp`. In the shell steps below, `$SCRATCH` is any scratch directory outside the repository.

## Facts the design rests on

- `PlatformGalleryResolver` (`lib/features/media/data/resolvers/platform_gallery_resolver.dart`) returns `notFound` from `resolve`, `resolveThumbnail` and `verify` on every miss. It answers `fromOtherDevice` only on hosts with no photo library (Windows, Linux).
- `LocalFileResolver` already applies the origin rule for local files: after a failed read, `_importedElsewhere` turns `notFound` into `fromOtherDevice` when `originDeviceId` names another device. It gets this device's id through an injected `localDeviceId` callback.
- `MediaRepository._effectiveOriginDeviceId` returns null for `platformGallery`, so every gallery row today has no origin. `createMedia` is the only path that inserts gallery rows.
- `AssetResolutionService` caches a direct id hit as method `original_id`, but `reresolve` clears it on the first failed thumbnail fetch. That instability is why the owner chose "no origin, never notFound".
- `MediaUploadPipeline` marks a `fromOtherDevice` source done as `skippedIneligible` ("the device that imported this file is the one that uploads it"), so on a peer a missing gallery row stops failing its upload daily.
- `SyncNotifier.performSync` runs best-effort post-sync jobs (the sensor summary sweep, the GPS match sweep) in its success branch. The backfill joins them.

## File Structure

- Modify `lib/features/media/data/resolvers/platform_gallery_resolver.dart`: the `localDeviceId` callback and the origin rule on every miss.
- Modify `lib/features/media/presentation/providers/media_resolver_providers.dart`: wire the callback.
- Modify `test/features/media/data/resolvers/platform_gallery_resolver_test.dart`, `platform_gallery_resolver_extra_test.dart`, `platform_gallery_resolver_reader_test.dart`: the origin rule's tests, and the existing "miss is notFound" tests re-stated for the linking device.
- Modify `lib/features/media/data/repositories/media_repository.dart`: gallery links record their device; two backfill queries.
- Create `test/features/media/data/repositories/media_repository_gallery_origin_test.dart`.
- Create `lib/features/media/data/services/gallery_origin_backfill.dart` and its test.
- Create `lib/features/media/presentation/providers/gallery_origin_backfill_provider.dart`.
- Modify `lib/features/settings/presentation/providers/sync_providers.dart`: run the backfill after a successful sync.
- Modify `test/helpers/two_device_media_harness.dart` and `test/features/media/two_device/resolution_scenarios_test.dart`: wire the device id, unskip S5, add the backfill scenario.
- Modify the spec, section 6.1: record both owner decisions.

---

### Task 1: The gallery resolver answers `notFound` only on the linking device

**Files:**
- Modify: `lib/features/media/data/resolvers/platform_gallery_resolver.dart`
- Modify: `lib/features/media/presentation/providers/media_resolver_providers.dart:47-60`
- Test: `test/features/media/data/resolvers/platform_gallery_resolver_test.dart`, `platform_gallery_resolver_extra_test.dart`, `platform_gallery_resolver_reader_test.dart`

**Interfaces:**
- Produces: `PlatformGalleryResolver({..., Future<String?> Function()? localDeviceId})`. Task 4 passes it in the harness.

- [ ] **Step 1: Write the failing tests**

In `platform_gallery_resolver_test.dart`, add this group at the end of `main()`, before its closing brace:

```dart
  group('a gallery miss is notFound only on the device that linked it', () {
    // notFound orphans the row, and the write syncs to every device. Only
    // the linking device's failed search is evidence the photo is gone
    // (media sync program spec 6.1); anywhere else the device simply never
    // had it.
    PlatformGalleryResolver here({
      Future<String?> Function(String deviceId)? deviceLabel,
    }) => PlatformGalleryResolver(
      resolutionService: _unavailableService(),
      localDeviceId: () async => 'this-device',
      deviceLabel: deviceLabel,
    );

    test('a row linked here is notFound', () async {
      final row = _gallery(assetId: 'A', originDeviceId: 'this-device');
      final data = await here().resolve(row);
      expect((data as UnavailableData).kind, UnavailableKind.notFound);
      final thumb = await here().resolveThumbnail(
        row,
        target: const Size(200, 200),
      );
      expect((thumb as UnavailableData).kind, UnavailableKind.notFound);
      expect(await here().verify(row), VerifyResult.notFound);
    });

    test('a row linked on another device is fromOtherDevice', () async {
      final row = _gallery(assetId: 'A', originDeviceId: 'phone');
      final data = await here().resolve(row);
      expect((data as UnavailableData).kind, UnavailableKind.fromOtherDevice);
      final thumb = await here().resolveThumbnail(
        row,
        target: const Size(200, 200),
      );
      expect((thumb as UnavailableData).kind, UnavailableKind.fromOtherDevice);
      expect(await here().verify(row), VerifyResult.fromOtherDevice);
    });

    test('a row with no origin is never notFound', () async {
      // Linked before gallery rows recorded an origin: no device can prove
      // it is the one that linked it, so none may orphan it.
      final row = _gallery(assetId: 'A');
      final data = await here().resolve(row);
      expect((data as UnavailableData).kind, UnavailableKind.fromOtherDevice);
      expect(await here().verify(row), VerifyResult.fromOtherDevice);
    });

    test('an unknown local device is never notFound', () async {
      final r = PlatformGalleryResolver(
        resolutionService: _unavailableService(),
        localDeviceId: () async => throw StateError('no database yet'),
      );
      final row = _gallery(assetId: 'A', originDeviceId: 'this-device');
      expect(await r.verify(row), VerifyResult.fromOtherDevice);
    });

    test('names the linking device', () async {
      final data =
          await here(
                deviceLabel: (id) async => id == 'phone' ? 'Dive phone' : null,
              ).resolve(_gallery(assetId: 'A', originDeviceId: 'phone'))
              as UnavailableData;
      expect(data.originDeviceLabel, 'Dive phone');
    });

    test('access denied is still accessDenied, whatever the origin', () async {
      final r = PlatformGalleryResolver(
        resolutionService: _accessDeniedService(),
        localDeviceId: () async => 'this-device',
      );
      expect(
        await r.verify(_gallery(assetId: 'A', originDeviceId: 'phone')),
        VerifyResult.accessDenied,
      );
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/media/data/resolvers/platform_gallery_resolver_test.dart`
Expected: compilation FAIL, `No named parameter with the name 'localDeviceId'`.

- [ ] **Step 3: Implement the origin rule**

In `platform_gallery_resolver.dart`, add the import `import 'package:submersion/core/services/logger_service.dart';` to the package imports.

Replace the constructor and add the fields beside it:

```dart
  /// [assetReader] performs the byte and metadata reads once an id is
  /// resolved. Production uses photo_manager; tests inject a fake library.
  ///
  /// [localDeviceId] names this device, so a miss can be judged by where the
  /// row was linked. Fetched lazily, only when a search fails, and memoized
  /// once it succeeds.
  PlatformGalleryResolver({
    required AssetResolutionService resolutionService,
    GalleryThumbnailCache? thumbnailCache,
    bool hasPhotoLibrary = true,
    GalleryAssetReader? assetReader,
    Future<String?> Function(String deviceId)? deviceLabel,
    Future<String?> Function()? localDeviceId,
  }) : _resolutionService = resolutionService,
       _thumbnailCache = thumbnailCache ?? GalleryThumbnailCache(),
       _hasPhotoLibrary = hasPhotoLibrary,
       _reader = assetReader ?? const PhotoManagerAssetReader(),
       _deviceLabel = deviceLabel,
       _localDeviceId = localDeviceId;

  final GalleryAssetReader _reader;
  final Future<String?> Function()? _localDeviceId;

  /// [_localDeviceId]'s answer, memoized once it succeeds. A failed fetch is
  /// not cached, so the next miss asks again.
  String? _knownDeviceId;
  final _log = LoggerService.forClass(
    PlatformGalleryResolver,
    category: LogCategory.media,
  );

  Future<String?> _thisDeviceId() async {
    if (_knownDeviceId != null) return _knownDeviceId;
    final source = _localDeviceId;
    if (source == null) return null;
    try {
      return _knownDeviceId = await source();
    } on Object catch (e) {
      // "Unknown" is not "linked here": a miss then says nothing about the
      // bytes, which is the safe answer when the answer syncs.
      _log.debug('Local device id unavailable', error: e);
      return null;
    }
  }

  /// Whether [item] was provably linked on this device.
  ///
  /// Only then is a failed search evidence the photo is gone. A row linked
  /// elsewhere is one this device never had; a row with no origin was linked
  /// before gallery rows recorded one, and until [GalleryOriginBackfill]
  /// stamps it no device can prove it is the one (media sync program spec
  /// 6.1). Either way the verdict must not orphan a row on every device.
  Future<bool> _linkedHere(MediaItem item) async {
    final origin = item.originDeviceId;
    if (origin == null) return false;
    final local = await _thisDeviceId();
    return local != null && origin == local;
  }

  /// The verdict for a gallery search that came back empty.
  Future<UnavailableData> _missing(MediaItem item) async =>
      await _linkedHere(item)
      ? const UnavailableData(kind: UnavailableKind.notFound)
      : _elsewhereFor(item);
```

Delete the old doc line `///` and the old constructor's doc comment above it (the `/// [assetReader] performs ...` two lines) so the comment is not duplicated, and delete the old `final GalleryAssetReader _reader;` line that followed the old constructor.

In `resolve`, replace both `return const UnavailableData(kind: UnavailableKind.notFound);` that follow the resolution (the `resolvedId == null` return and the `bytes == null` return) with `return _missing(item);`. Leave the first one, for a row with no asset id, unchanged: that is broken data, not a fact about this device.

In `resolveThumbnail`, replace the failure-path return:

```dart
      final status = (await _resolutionService.resolveAssetId(item)).status;
      if (status == ResolutionStatus.accessDenied) {
        return const UnavailableData(kind: UnavailableKind.accessDenied);
      }
      return _missing(item);
```

In `verify`, replace the last four lines:

```dart
    final resolvedId = resolution.localAssetId;
    if (resolvedId != null && await _reader.exists(resolvedId)) {
      return VerifyResult.available;
    }
    return await _linkedHere(item)
        ? VerifyResult.notFound
        : VerifyResult.fromOtherDevice;
```

Update the class doc comment's `_hasPhotoLibrary` paragraph: after "Never [UnavailableKind.notFound]: ..." add the sentence "Hosts with a library follow the same rule for every row they did not link; see [_linkedHere]."

- [ ] **Step 4: Wire the device id in production**

In `media_resolver_providers.dart`, add to `PlatformGalleryResolver(...)` in `platformGalleryResolverProvider`, after `deviceLabel`:

```dart
    // Fetched lazily, only when a search fails, and memoized by the
    // resolver; the provider itself never touches the database.
    localDeviceId: () => SyncRepository().getDeviceId(),
```

- [ ] **Step 5: Run the gallery resolver suites and restate the old miss tests**

Run: `flutter test test/features/media/data/resolvers/`
Expected: the new group passes. These existing tests now FAIL, because each asserts `notFound` for a search miss on a row with no origin, which the new rule makes `fromOtherDevice`:

- `platform_gallery_resolver_test.dart`: `a genuine miss still reports notFound`
- `platform_gallery_resolver_extra_test.dart`: `resolve returns Unavailable.notFound when AssetResolutionService is unavailable` and `verify returns notFound when AssetResolutionService is unavailable` (its `resolveThumbnail` test asserts only `isA<UnavailableData>` and keeps passing)
- `platform_gallery_resolver_reader_test.dart`: `an id the library never had is notFound`, and the `verify` test near line 95

Their intent is "a genuine miss on the device that linked the photo is notFound", which still holds. Restate each for that device: construct its resolver with `localDeviceId: () async => 'this-device'`, and give its row `originDeviceId: 'this-device'`. In the extra and reader files, add an `originDeviceId` parameter to the row helper (`_gallery` / `row`) with default `'this-device'` and add `localDeviceId: () async => 'this-device'` to every `PlatformGalleryResolver(` in the file. Keep every test that asserts `notFound` for a missing or empty asset id unchanged: that path does not consult the origin.

Rerun: `flutter test test/features/media/data/resolvers/`
Expected: all pass.

- [ ] **Step 6: Mutation-check the rule**

```bash
cp lib/features/media/data/resolvers/platform_gallery_resolver.dart "$SCRATCH/platform_gallery_resolver.dart.bak"
```

(a) Make `_linkedHere` return `true` when `origin == null`. Expected: `a row with no origin is never notFound` FAILS. Restore.

(b) Replace `_missing`'s body with `const UnavailableData(kind: UnavailableKind.notFound)`. Expected: `a row linked on another device is fromOtherDevice` FAILS. Restore and rerun: all pass.

- [ ] **Step 7: Commit**

```bash
git add lib/features/media/data/resolvers/platform_gallery_resolver.dart lib/features/media/presentation/providers/media_resolver_providers.dart test/features/media/data/resolvers/
git commit -m "fix(media): a gallery miss is notFound only on the device that linked it"
```

---

### Task 2: New gallery links record the device that made them

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart:248-262` (`_effectiveOriginDeviceId`)
- Test: `test/features/media/data/repositories/media_repository_gallery_origin_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: gallery rows created by `createMedia` carry `originDeviceId`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/media/data/repositories/media_repository_gallery_origin_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../../helpers/test_database.dart';

/// A gallery row's verdict depends on where it was linked (media sync
/// program spec 6.1), so the link has to record it. Store-backed and network
/// rows resolve the same way on every device and still record none.
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  MediaItem item(MediaSourceType type, {String? origin}) => MediaItem(
    id: '',
    mediaType: MediaType.photo,
    sourceType: type,
    platformAssetId: 'A-1',
    originDeviceId: origin,
    takenAt: DateTime(2026, 7, 1),
    createdAt: DateTime(2026, 7, 1),
    updatedAt: DateTime(2026, 7, 1),
  );

  Future<String?> originOf(MediaItem created) async =>
      (await MediaRepository().getMediaById(created.id))!.originDeviceId;

  test('a gallery link records the device that made it', () async {
    final created = await MediaRepository().createMedia(
      item(MediaSourceType.platformGallery),
    );
    expect(await originOf(created), await SyncRepository().getDeviceId());
  });

  test('an origin the caller already names is kept', () async {
    final created = await MediaRepository().createMedia(
      item(MediaSourceType.platformGallery, origin: 'phone'),
    );
    expect(await originOf(created), 'phone');
  });

  test('store-backed and network rows still record none', () async {
    for (final type in [
      MediaSourceType.mediaStore,
      MediaSourceType.networkUrl,
    ]) {
      final created = await MediaRepository().createMedia(item(type));
      expect(await originOf(created), isNull, reason: type.name);
    }
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/media/data/repositories/media_repository_gallery_origin_test.dart`
Expected: `a gallery link records the device that made it` FAILS (`Expected: <device id> Actual: <null>`); the other two pass.

- [ ] **Step 3: Implement**

In `_effectiveOriginDeviceId`, move `case MediaSourceType.platformGallery:` up to join `localFile` and `serviceConnector`, and add a comment:

```dart
    switch (item.sourceType) {
      case MediaSourceType.localFile:
      case MediaSourceType.serviceConnector:
      // Only the linking device holds the stored asset id, and only its
      // failed search may call the photo gone (media sync program spec 6.1).
      case MediaSourceType.platformGallery:
        return _syncRepository.getDeviceId();
      case MediaSourceType.networkUrl:
      case MediaSourceType.manifestEntry:
      case MediaSourceType.signature:
      // Cloud-backed rows resolve through the store on every device.
      case MediaSourceType.mediaStore:
        return null;
    }
```

- [ ] **Step 4: Run the tests and the media repository suites**

Run: `flutter test test/features/media/data/repositories/`
Expected: all pass. A failure here is a test that pinned a gallery row's origin to null; restate it for the new rule, which is the point of this task.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media/data/repositories/media_repository.dart test/features/media/data/repositories/media_repository_gallery_origin_test.dart
git commit -m "feat(media): a gallery link records the device that made it"
```

---

### Task 3: The one-time gallery origin backfill, after a successful sync

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart` (two methods beside `getStoreStampedMediaIdsOwnedBy`)
- Create: `lib/features/media/data/services/gallery_origin_backfill.dart`
- Create: `lib/features/media/presentation/providers/gallery_origin_backfill_provider.dart`
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (the `result.isSuccess` branch of `performSync`)
- Test: `test/features/media/data/services/gallery_origin_backfill_test.dart`

**Interfaces:**
- Produces:
  - `Future<List<({String id, String platformAssetId})>> MediaRepository.getGalleryMediaWithoutOrigin()`
  - `Future<int> MediaRepository.stampOriginDevice(List<({String id, String platformAssetId})> probed, String deviceId)`
  - `class GalleryOriginBackfill { GalleryOriginBackfill({required MediaRepository mediaRepository, required GalleryAssetReader reader, required PhotoPickerService photos, required Future<PhotoPermissionStatus> Function() permissionStatus, required Future<String> Function() deviceId, required SharedPreferences prefs}); static const doneFlagKey; static bool isDone(SharedPreferences); Future<GalleryOriginBackfillOutcome?> run(); }`
  - `typedef GalleryOriginBackfillOutcome = ({int checked, int stamped});`
  - `final galleryOriginBackfillProvider = Provider<Future<void> Function()>(...)`

- [ ] **Step 1: Write the failing tests**

Create `test/features/media/data/services/gallery_origin_backfill_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/gallery_asset_reader.dart';
import 'package:submersion/features/media/data/services/gallery_origin_backfill.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../../helpers/fake_photo_picker_service.dart';
import '../../../../helpers/test_database.dart';

/// Gallery rows linked before links recorded an origin carry none, so no
/// device may call them missing (media sync program spec 6.1). The backfill
/// stamps this device's id on those whose stored asset id still loads here:
/// only the linking device holds that id.
void main() {
  late AppDatabase db;
  late FakePhotoPickerService gallery;
  late SharedPreferences prefs;
  late String me;
  final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
  final taken = DateTime(2026, 7, 1);

  setUp(() async {
    db = await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    gallery = FakePhotoPickerService();
    me = await SyncRepository().getDeviceId();
  });
  tearDown(() async => tearDownTestDatabase());

  /// A gallery row as it was before links recorded an origin.
  Future<String> legacyRow(String assetId) async {
    final id = (await MediaRepository().createMedia(
      MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.platformGallery,
        platformAssetId: assetId,
        takenAt: taken,
        createdAt: taken,
        updatedAt: taken,
      ),
    )).id;
    await db.customStatement(
      'UPDATE media SET origin_device_id = NULL WHERE id = ?',
      [id],
    );
    return id;
  }

  Future<String?> originOf(String id) async =>
      (await MediaRepository().getMediaById(id))!.originDeviceId;

  Future<bool> isPending(String id) async =>
      (await SyncRepository().getPendingRecords()).any(
        (r) => r.entityType == 'media' && r.recordId == id,
      );

  GalleryOriginBackfill backfill({GalleryAssetReader? reader}) =>
      GalleryOriginBackfill(
        mediaRepository: MediaRepository(),
        reader: reader ?? gallery,
        photos: gallery,
        permissionStatus: () async => gallery.permission,
        deviceId: () => SyncRepository().getDeviceId(),
        prefs: prefs,
      );

  // It runs after a sync, unasked. On mobile the service's checkPermission
  // is a request (it shows the OS prompt when access was never decided), so
  // the backfill must only read the status and wait for the gallery flow.
  test('never asks for photo access, only reads it', () async {
    final counting = _CountingPhotoPicker();
    gallery = counting;
    gallery.add(FakeGalleryAsset(id: 'A-1', bytes: bytes, takenAt: taken));
    final id = await legacyRow('A-1');

    expect(await backfill().run(), (checked: 1, stamped: 1));
    expect(await originOf(id), me);
    expect(counting.asks, 0);
  });

  test('stamps the rows whose asset id loads here, and only those', () async {
    gallery.add(FakeGalleryAsset(id: 'A-1', bytes: bytes, takenAt: taken));
    final mine = await legacyRow('A-1');
    final theirs = await legacyRow('B-9');
    await SyncRepository().clearPendingRecords();

    final outcome = await backfill().run();

    expect(outcome, (checked: 2, stamped: 1));
    expect(await originOf(mine), me);
    expect(await isPending(mine), isTrue, reason: 'peers must learn it');
    expect(await originOf(theirs), isNull);
    expect(GalleryOriginBackfill.isDone(prefs), isTrue);
  });

  test('a row that already records an origin is left alone', () async {
    gallery.add(FakeGalleryAsset(id: 'A-1', bytes: bytes, takenAt: taken));
    final id = (await MediaRepository().createMedia(
      MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.platformGallery,
        platformAssetId: 'A-1',
        originDeviceId: 'phone',
        takenAt: taken,
        createdAt: taken,
        updatedAt: taken,
      ),
    )).id;

    final outcome = await backfill().run();

    expect(outcome, (checked: 0, stamped: 0));
    expect(await originOf(id), 'phone');
  });

  test(
    'waits for full photo access, and retries after the next sync',
    () async {
      gallery.add(FakeGalleryAsset(id: 'A-1', bytes: bytes, takenAt: taken));
      final id = await legacyRow('A-1');
      gallery.permission = PhotoPermissionStatus.limited;

      expect(await backfill().run(), isNull);
      expect(await originOf(id), isNull);
      expect(GalleryOriginBackfill.isDone(prefs), isFalse);
    },
  );

  test('a device with no photo library is done at once', () async {
    gallery = FakePhotoPickerService(supportsGalleryBrowsing: false);
    final id = await legacyRow('A-1');

    expect(await backfill().run(), (checked: 0, stamped: 0));
    expect(await originOf(id), isNull);
    expect(GalleryOriginBackfill.isDone(prefs), isTrue);
  });

  test('runs once', () async {
    await backfill().run();
    expect(await backfill().run(), isNull);
  });

  test(
    'a probe that throws skips its row and the pass still completes',
    () async {
      gallery.add(FakeGalleryAsset(id: 'A-1', bytes: bytes, takenAt: taken));
      final good = await legacyRow('A-1');
      final bad = await legacyRow('boom');

      final outcome = await backfill(reader: _ThrowsFor('boom', gallery)).run();

      expect(outcome, (checked: 2, stamped: 1));
      expect(await originOf(good), me);
      expect(await originOf(bad), isNull);
    },
  );

  // A probe that could not answer says nothing about the row. The pass is
  // not complete until every candidate has been probed, so the next sync
  // tries the rest again.
  test('a failed probe leaves the backfill to run again', () async {
    gallery.add(FakeGalleryAsset(id: 'boom', bytes: bytes, takenAt: taken));
    final bad = await legacyRow('boom');

    await backfill(reader: _ThrowsFor('boom', gallery)).run();
    expect(GalleryOriginBackfill.isDone(prefs), isFalse);

    expect(await backfill().run(), (checked: 1, stamped: 1));
    expect(await originOf(bad), me);
    expect(GalleryOriginBackfill.isDone(prefs), isTrue);
  });

  // The candidates are read before a probe loop that can run long. A row
  // the user converts in the meantime (here to a cloud-backed row) no longer
  // points at the asset that was probed, and must not gain a gallery origin.
  test('a row converted during the probe is not stamped', () async {
    gallery.add(FakeGalleryAsset(id: 'A-1', bytes: bytes, takenAt: taken));
    gallery.add(FakeGalleryAsset(id: 'A-2', bytes: bytes, takenAt: taken));
    final converted = await legacyRow('A-1');
    final relinked = await legacyRow('A-2');

    final outcome = await backfill(
      reader: _ChangesDuringProbe(gallery, () async {
        await db.customStatement(
          "UPDATE media SET source_type = 'mediaStore' WHERE id = ?",
          [converted],
        );
        await db.customStatement(
          "UPDATE media SET platform_asset_id = 'A-9' WHERE id = ?",
          [relinked],
        );
      }),
    ).run();

    expect(outcome, (checked: 2, stamped: 0));
    expect(await originOf(converted), isNull);
    expect(await originOf(relinked), isNull);

    // The relinked row is still a gallery row with no origin, under an
    // asset this pass never probed: the pass is not complete, and the next
    // one checks it. The converted row is no longer a candidate at all.
    expect(GalleryOriginBackfill.isDone(prefs), isFalse);
    gallery.add(FakeGalleryAsset(id: 'A-9', bytes: bytes, takenAt: taken));
    expect(await backfill().run(), (checked: 1, stamped: 1));
    expect(await originOf(relinked), me);
    expect(GalleryOriginBackfill.isDone(prefs), isTrue);
  });

  // Rows another device linked probe negative and stay originless; they are
  // answered, and must not keep the pass open forever.
  test('rows that do not load here still let the pass complete', () async {
    await legacyRow('B-9');

    expect(await backfill().run(), (checked: 1, stamped: 0));
    expect(GalleryOriginBackfill.isDone(prefs), isTrue);
  });
}

/// Runs [change] on the first probe, then delegates: the rows move while the
/// backfill is still probing.
class _ChangesDuringProbe implements GalleryAssetReader {
  _ChangesDuringProbe(this.inner, this.change);
  final GalleryAssetReader inner;
  final Future<void> Function() change;
  var _changed = false;

  @override
  Future<bool> exists(String assetId) async {
    if (!_changed) {
      _changed = true;
      await change();
    }
    return inner.exists(assetId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Delegates to [inner] except that probing [id] throws, the way a platform
/// channel can for one asset.
class _ThrowsFor implements GalleryAssetReader {
  _ThrowsFor(this.id, this.inner);
  final String id;
  final GalleryAssetReader inner;

  @override
  Future<bool> exists(String assetId) => assetId == id
      ? Future<bool>.error(StateError('probe failed'))
      : inner.exists(assetId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Counts calls that could show the OS photo prompt on a real device.
class _CountingPhotoPicker extends FakePhotoPickerService {
  var asks = 0;

  @override
  Future<PhotoPermissionStatus> checkPermission() {
    asks++;
    return super.checkPermission();
  }

  @override
  Future<PhotoPermissionStatus> requestPermission() {
    asks++;
    return super.requestPermission();
  }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/media/data/services/gallery_origin_backfill_test.dart`
Expected: compilation FAIL, `Error when reading 'lib/features/media/data/services/gallery_origin_backfill.dart'`.

- [ ] **Step 3: Add the two repository methods**

In `media_repository.dart`, directly after `getStoreStampedMediaIdsOwnedBy`, add:

```dart
  /// Gallery rows that record no origin device, with the asset id each was
  /// linked under: the rows [GalleryOriginBackfill] checks against this
  /// device's library (media sync program spec 6.1).
  Future<List<({String id, String platformAssetId})>>
  getGalleryMediaWithoutOrigin() async {
    final rows =
        await (_db.select(_db.media)..where(
              (t) =>
                  t.sourceType.equals(MediaSourceType.platformGallery.name) &
                  t.originDeviceId.isNull() &
                  t.platformAssetId.isNotNull() &
                  t.platformAssetId.equals('').not(),
            ))
            .get();
    return [
      for (final r in rows) (id: r.id, platformAssetId: r.platformAssetId!),
    ];
  }

  /// Records [deviceId] as the origin of each [probed] row that is still
  /// exactly what was probed: a gallery row, under the same asset id, with
  /// no origin yet. Marks each row it stamps pending so peers learn it.
  /// Returns how many it stamped.
  ///
  /// The origin belongs to no fact group, so this bumps the row clock and
  /// republishes the whole row; the gallery origin backfill runs it only
  /// right after a sync for that reason. The rows are probed before this
  /// runs, and the probe loop can be long: the null guard keeps an origin a
  /// sync delivered meanwhile, and the source and asset guards skip a row
  /// the user converted or relinked meanwhile, which the probe no longer
  /// speaks for.
  Future<int> stampOriginDevice(
    List<({String id, String platformAssetId})> probed,
    String deviceId,
  ) async {
    if (probed.isEmpty) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    var stamped = 0;
    await _db.transaction(() async {
      for (final row in probed) {
        final id = row.id;
        final written =
            await (_db.update(_db.media)..where(
                  (t) =>
                      t.id.equals(id) &
                      t.originDeviceId.isNull() &
                      t.sourceType.equals(
                        MediaSourceType.platformGallery.name,
                      ) &
                      t.platformAssetId.equals(row.platformAssetId),
                ))
                .write(
                  MediaCompanion(
                    originDeviceId: Value(deviceId),
                    updatedAt: Value(now),
                  ),
                );
        if (written == 0) continue;
        stamped++;
        await _syncRepository.markRecordPending(
          entityType: 'media',
          recordId: id,
          localUpdatedAt: now,
        );
      }
    });
    if (stamped > 0) SyncEventBus.notifyLocalChange();
    return stamped;
  }
```

- [ ] **Step 4: Write the backfill**

Create `lib/features/media/data/services/gallery_origin_backfill.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/gallery_asset_reader.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';

/// What one run of [GalleryOriginBackfill] did.
typedef GalleryOriginBackfillOutcome = ({
  /// Gallery rows with no origin that were probed.
  int checked,

  /// Of those, rows whose asset id loads here and were stamped.
  int stamped,
});

/// One-time stamp of this device's id on the gallery rows it linked before
/// gallery links recorded an origin (media sync program spec 6.1).
///
/// A gallery row's origin decides its verdict: only the device that linked
/// it may call a failed search notFound, which orphans the row everywhere.
/// Older rows carry no origin, so no device may call them missing, including
/// the one that linked them. This finds the rows whose stored asset id still
/// loads here, which only the linking device's id does, and stamps them, so
/// that device regains its verdict and every peer learns where they live.
///
/// Runs after a successful sync, never at launch: the origin has no fact
/// group, so a stamp bumps the row clock and republishes the whole row, and
/// a peer's newer edit this device has not pulled yet would lose to the
/// stale copy. Right after a pull that window is as small as it gets.
///
/// Only with full photo access: a limited selection hides photos this device
/// did link, and a pass over a partial library would set the flag over rows
/// it never saw. Flagged in SharedPreferences like
/// `MediaOriginRepublishSweep`, and set only after a complete pass, so a
/// failed or waiting run tries again after the next sync.
class GalleryOriginBackfill {
  GalleryOriginBackfill({
    required MediaRepository mediaRepository,
    required GalleryAssetReader reader,
    required PhotoPickerService photos,
    required Future<PhotoPermissionStatus> Function() permissionStatus,
    required Future<String> Function() deviceId,
    required SharedPreferences prefs,
  }) : _mediaRepository = mediaRepository,
       _reader = reader,
       _photos = photos,
       _permissionStatus = permissionStatus,
       _deviceId = deviceId,
       _prefs = prefs;

  static const String doneFlagKey = 'media_gallery_origin_backfill_v1';

  /// Whether this device has already run the backfill. Cheap, so callers can
  /// ask before building anything it needs.
  static bool isDone(SharedPreferences prefs) =>
      prefs.getBool(doneFlagKey) ?? false;

  final MediaRepository _mediaRepository;
  final GalleryAssetReader _reader;
  final PhotoPickerService _photos;

  /// Reads photo access without asking for it. Not the service's
  /// checkPermission: on mobile that is a request, and this runs after a
  /// sync, unasked, so it must never show the OS prompt. Without full
  /// access it waits for the user to grant it through the gallery flow.
  final Future<PhotoPermissionStatus> Function() _permissionStatus;
  final Future<String> Function() _deviceId;
  final SharedPreferences _prefs;
  final _log = LoggerService.forClass(
    GalleryOriginBackfill,
    category: LogCategory.media,
  );

  /// Runs the backfill, or returns null when it already ran, is waiting for
  /// full photo access, or could not complete (logged; the flag stays unset).
  Future<GalleryOriginBackfillOutcome?> run() async {
    if (isDone(_prefs)) return null;
    try {
      // No photo library here (Windows, Linux): no gallery row was ever
      // linked on this device, so there is nothing of its own to stamp.
      if (!_photos.supportsGalleryBrowsing) {
        await _prefs.setBool(doneFlagKey, true);
        return (checked: 0, stamped: 0);
      }
      if (await _permissionStatus() != PhotoPermissionStatus.authorized) {
        _log.info('Gallery origin backfill waiting for full photo access');
        return null;
      }
      final me = await _deviceId();
      final candidates = await _mediaRepository.getGalleryMediaWithoutOrigin();
      final mine = <({String id, String platformAssetId})>[];
      var unanswered = 0;
      for (final row in candidates) {
        try {
          if (await _reader.exists(row.platformAssetId)) mine.add(row);
        } on Object catch (e) {
          // One asset the platform cannot answer for must not hold the rest
          // back; it stays unstamped, which is the safe state, and keeps the
          // pass from counting as complete.
          unanswered++;
          _log.warning('Could not probe ${row.id}; left unstamped', error: e);
        }
      }
      final stamped = await _mediaRepository.stampOriginDevice(mine, me);
      // Done only once every candidate had an answer, and nothing is left
      // that this pass did not ask about. A probe that failed said nothing
      // about its row; a row relinked during the probe loop is still a
      // candidate, under an asset this pass never probed. Either way the
      // next sync asks again. Rows that answered "not here" stay
      // candidates too, but they were asked, so they do not hold it open.
      final asked = candidates.toSet();
      final unasked = (await _mediaRepository.getGalleryMediaWithoutOrigin())
          .where((row) => !asked.contains(row))
          .length;
      final complete = unanswered == 0 && unasked == 0;
      if (complete) await _prefs.setBool(doneFlagKey, true);
      _log.info(
        'Gallery origin backfill ${complete ? 'done' : 'partial'}: '
        'checked ${candidates.length}, stamped $stamped, '
        'unanswered $unanswered, unasked $unasked',
      );
      return (checked: candidates.length, stamped: stamped);
    } on Object catch (e, stackTrace) {
      _log.error(
        'Gallery origin backfill failed; will retry after the next sync',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `dart format lib test && flutter test test/features/media/data/services/gallery_origin_backfill_test.dart`
Expected: `All tests passed!` (10 tests).

- [ ] **Step 6: The provider and the post-sync hook**

Create `lib/features/media/presentation/providers/gallery_origin_backfill_provider.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/gallery_asset_reader.dart';
import 'package:submersion/features/media/data/services/gallery_origin_backfill.dart';
import 'package:submersion/features/media/data/services/photo_picker_service_mobile.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';

/// Runs [GalleryOriginBackfill] once per device, after a successful sync.
///
/// Checks the done flag first, so every sync after the one that finished it
/// costs one preference read. The sync awaits it inside its single flight,
/// so no second sync overlaps a stamp. Contains its own failures: the sync
/// has already succeeded, and a backfill that could not run must not turn
/// it into an error.
// no-tick: the value is a CLOSURE, not a query result. Every read happens
// inside it at call time via ref.read, so there is no cached row to go stale.
final galleryOriginBackfillProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (GalleryOriginBackfill.isDone(prefs)) return;
      final photos = ref.read(photoPickerServiceProvider);
      await GalleryOriginBackfill(
        mediaRepository: ref.read(mediaRepositoryProvider),
        reader: const PhotoManagerAssetReader(),
        photos: photos,
        // Read, never asked: this runs after a sync, unasked. The desktop
        // service never prompts, so its checkPermission is already a read.
        permissionStatus: photos is PhotoPickerServiceMobile
            ? photos.currentPermission
            : photos.checkPermission,
        deviceId: () => SyncRepository().getDeviceId(),
        prefs: prefs,
      ).run();
    } on Object catch (e, stackTrace) {
      LoggerService.forClass(GalleryOriginBackfill).warning(
        'Could not run the gallery origin backfill',
        error: e,
        stackTrace: stackTrace,
      );
    }
  };
});
```

In `sync_providers.dart`, inside `performSync`'s `if (result.isSuccess) {` branch, directly after the `try { await _ref.read(gpsTrackMatchServiceProvider).sweep(); } catch ... { ... }` block and before the branch's closing `} else {`, add:

```dart
          // Gallery rows linked before links recorded an origin learn it
          // here (media sync program spec 6.1). After a sync, never at
          // launch: a stamp bumps the row clock, so this device's copies
          // should be as fresh as a pull makes them. Awaited, so it stays
          // inside this sync's single flight: a stamp republishes the row,
          // and a second sync merging or publishing mid-stamp would reopen
          // the stale-copy window it waits here to avoid. Once per device
          // (a flag read after that), and it contains its own failures.
          await _ref.read(galleryOriginBackfillProvider)();
          // The notifier can be disposed while the backfill runs, and the
          // settle below reads state.
          if (!mounted) return;
```

Add the import `import 'package:submersion/features/media/presentation/providers/gallery_origin_backfill_provider.dart';`. Awaited, not fire-and-forget: the stamps republish rows, so the backfill must stay inside the sync's single flight or a second sync could merge or publish mid-stamp.

- [ ] **Step 7: Run the affected suites**

Run: `flutter test test/features/media/data test/features/settings test/architecture`
Expected: all pass. `test/architecture/provider_change_tick_test.dart` requires the `// no-tick:` comment; if it flags the provider, the comment is not directly above the declaration.

- [ ] **Step 8: Mutation-check the backfill**

```bash
cp lib/features/media/data/services/gallery_origin_backfill.dart "$SCRATCH/gallery_origin_backfill.dart.bak"
```

(a) Replace `!= PhotoPermissionStatus.authorized` with `== PhotoPermissionStatus.denied`. Expected: `waits for full photo access, and retries after the next sync` FAILS. Restore.

(b) Stamp every candidate: replace `if (await _reader.exists(row.platformAssetId)) mine.add(row);` with `mine.add(row);`. Expected: `stamps the rows whose asset id loads here, and only those` FAILS. Restore and rerun: all pass.

- [ ] **Step 9: Commit**

```bash
git add lib/features/media/data/repositories/media_repository.dart lib/features/media/data/services/gallery_origin_backfill.dart lib/features/media/presentation/providers/gallery_origin_backfill_provider.dart lib/features/settings/presentation/providers/sync_providers.dart test/features/media/data/services/gallery_origin_backfill_test.dart
git commit -m "feat(media): stamp the origin of old gallery rows once, after a sync"
```

---

### Task 4: Scenario S5 goes green, and the backfill crosses devices

**Files:**
- Modify: `test/helpers/two_device_media_harness.dart` (the gallery resolver, two helpers)
- Modify: `test/features/media/two_device/resolution_scenarios_test.dart`

**Interfaces:**
- Consumes (Tasks 1 and 3): `PlatformGalleryResolver(localDeviceId:)`, `GalleryOriginBackfill`.
- Produces: `HarnessDevice.clearOrigin(String id)`, `HarnessDevice.backfillGalleryOrigins()`.

- [ ] **Step 1: Unskip S5 and add the backfill scenario**

In `resolution_scenarios_test.dart`, delete S5's `skip:` argument (two lines) and the three-line "Note for slice 7" comment inside it. Add this test after S5:

```dart
  test('an old gallery row learns its origin after a sync, and peers with '
      'it', () async {
    final dive = await h.a.createDive();
    final id = await h.a.linkGalleryPhoto(
      FakeGalleryAsset(id: 'A-1', bytes: photo, takenAt: taken),
      diveId: dive,
    );
    // Linked before gallery rows recorded an origin.
    await h.a.clearOrigin(id);
    await h.a.sync();
    await h.b.sync();
    expect((await h.b.media(id))!.originDeviceId, isNull);

    await h.a.backfillGalleryOrigins();
    await h.a.sync();
    await h.b.sync();

    expect(
      (await h.b.media(id))!.originDeviceId,
      h.a.deviceId,
      reason: 'the linking device stamped it and the stamp synced',
    );
    final tile = await h.b.tile(id);
    expect(
      (tile.data as UnavailableData).kind,
      UnavailableKind.fromOtherDevice,
    );
  });
```

- [ ] **Step 2: Run the scenarios to see them fail**

Run: `flutter test test/features/media/two_device/resolution_scenarios_test.dart`
Expected: compilation FAIL on `clearOrigin` and `backfillGalleryOrigins`.

- [ ] **Step 3: Wire the harness**

In `two_device_media_harness.dart`, give the gallery resolver the device id:

```dart
      MediaSourceType.platformGallery: PlatformGalleryResolver(
        resolutionService: AssetResolutionService(
          cacheRepository: d.assetCache,
          photoPickerService: d.gallery,
        ),
        assetReader: d.gallery,
        localDeviceId: () async => d.deviceId,
      ),
```

Add these two members to `HarnessDevice`, beside `stripStoreStamps`:

```dart
  /// Simulates a gallery row linked before links recorded an origin.
  Future<void> clearOrigin(String id) async {
    await activate();
    await db.customStatement(
      'UPDATE media SET origin_device_id = NULL WHERE id = ?',
      [id],
    );
  }

  /// Runs this device's one-time gallery origin backfill. The preference
  /// store is shared by both devices, so the flag is cleared first.
  Future<void> backfillGalleryOrigins() async {
    await activate();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(GalleryOriginBackfill.doneFlagKey);
    await GalleryOriginBackfill(
      mediaRepository: MediaRepository(),
      reader: gallery,
      photos: gallery,
      permissionStatus: () async => gallery.permission,
      deviceId: () async => deviceId,
      prefs: prefs,
    ).run();
  }
```

Add the imports for `GalleryOriginBackfill` and `SharedPreferences` if the harness lacks them.

- [ ] **Step 4: Run the two-device suite**

Run: `flutter test test/features/media/two_device`
Expected: all pass. S5 and the new scenario are green; the remaining skips belong to later slices (S4, S6, S7, S8, S10).

- [ ] **Step 5: Commit**

```bash
git add test/helpers/two_device_media_harness.dart test/features/media/two_device/resolution_scenarios_test.dart
git commit -m "test(media): S5 turns green, and an old row's origin crosses devices"
```

---

### Task 5: Record the decisions, verify the branch, open the PR

**Files:**
- Modify: `docs/superpowers/specs/2026-09-18-media-sync-program-design.md` (section 6.1)

- [ ] **Step 1: Record the owner decisions in spec 6.1**

Replace the paragraph's last sentence, "Until a row has an origin it keeps today's behaviour on the device with a cache hit for it and answers `fromOtherDevice` elsewhere.", with:

```markdown
Until a row has an origin it is never `notFound`, on any device (decided
2026-09-23). The spec first kept today's behaviour on a device with a
cache hit, but the first failed thumbnail fetch clears that mapping, so the
verdict would flip between renders. The backfill runs once per device after
a successful sync, never at launch: the origin has no fact group, so a stamp
bumps the row clock, and right after a pull is when it can least overwrite a
peer's unseen newer edit. It runs only with full photo access, since a
limited selection hides rows the device did link.
```

- [ ] **Step 2: Format, analyze, and run every affected suite**

Run: `dart format . && flutter analyze`
Expected: `No issues found!`

Run: `flutter test test/features/media test/features/media_store test/features/settings test/core/services/sync test/architecture > "$SCRATCH/s7_tests.log" 2>&1; echo "exit=$?"; tail -3 "$SCRATCH/s7_tests.log"`
Expected: `exit=0`, `All tests passed!`. Capture to a file; never pipe `flutter test` into `grep` or `tail`, which hides the exit status.

- [ ] **Step 3: Commit the spec, then push and open the PR (ask the owner first)**

```bash
git add docs/superpowers/specs/2026-09-18-media-sync-program-design.md
git commit -m "docs(spec): record slice 7's origin decisions in 6.1"
```

Push with `git push -u origin ericgriffin/media-sync-s7-origin-verdicts` and open against `main`. The body must carry:

```markdown
Closes #2113
Part of #2090
```
