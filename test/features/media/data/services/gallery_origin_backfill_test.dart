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
