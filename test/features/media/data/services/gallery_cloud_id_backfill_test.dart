import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/gallery_cloud_id_backfill.dart';
import 'package:submersion/features/media/data/services/gallery_origin_backfill.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../../helpers/fake_photo_picker_service.dart';
import '../../../../helpers/test_database.dart';

/// Gallery rows linked before links recorded an iCloud identifier carry
/// none, so a peer sharing the library can only match them by metadata
/// (media sync program spec 6.2). The backfill stamps the cloud id on this
/// device's own rows, the only ones whose asset id names an asset here.
void main() {
  late AppDatabase db;
  late FakePhotoPickerService library;
  late SharedPreferences prefs;
  final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
  final taken = DateTime(2026, 7, 1);

  setUp(() async {
    db = await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({
      GalleryOriginBackfill.doneFlagKey: true,
    });
    prefs = await SharedPreferences.getInstance();
    library = FakePhotoPickerService();
  });
  tearDown(() async => tearDownTestDatabase());

  /// A gallery row this device linked (createMedia records it as origin),
  /// as it was before links recorded a cloud id.
  Future<String> link(String assetId) async =>
      (await MediaRepository().createMedia(
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

  Future<String?> cloudIdOf(String id) async =>
      (await MediaRepository().getMediaById(id))!.cloudAssetId;

  Future<bool> isPending(String id) async =>
      (await SyncRepository().getPendingRecords()).any(
        (r) => r.entityType == 'media' && r.recordId == id,
      );

  Future<void> clearPending() => db.customStatement(
    "DELETE FROM sync_records WHERE entity_type = 'media'",
  );

  GalleryCloudIdBackfill backfill({
    PhotoPermissionStatus permission = PhotoPermissionStatus.authorized,
    bool supportsGallery = true,
    FakePhotoPickerService? source,
  }) => GalleryCloudIdBackfill(
    mediaRepository: MediaRepository(),
    cloudIdentifiers: source ?? library,
    photos: FakePhotoPickerService(supportsGalleryBrowsing: supportsGallery),
    permissionStatus: () async => permission,
    deviceId: () => SyncRepository().getDeviceId(),
    prefs: prefs,
  );

  FakeGalleryAsset asset(String id, {String? cloudId}) =>
      FakeGalleryAsset(id: id, bytes: bytes, takenAt: taken, cloudId: cloudId);

  test('stamps this device\'s own rows whose asset has a cloud id, in one '
      'lookup', () async {
    library
      ..add(asset('a1', cloudId: 'C-1'))
      ..add(asset('a2'));
    final withCloud = await link('a1');
    final without = await link('a2');
    await clearPending();

    expect(await backfill().run(), (checked: 2, stamped: 1));

    expect(await cloudIdOf(withCloud), 'C-1');
    expect(await cloudIdOf(without), isNull, reason: 'no iCloud copy');
    expect(library.cloudIdCalls, 1);
    expect(GalleryCloudIdBackfill.isDone(prefs), isTrue);
    expect(await isPending(withCloud), isTrue, reason: 'peers must learn it');
    expect(await isPending(without), isFalse);
  });

  // Only the linking device's asset id names an asset in its library; a
  // peer's id could name a different photo here.
  test('never touches a peer\'s rows', () async {
    library.add(asset('a1', cloudId: 'C-1'));
    final id = await link('a1');
    await db.customStatement(
      "UPDATE media SET origin_device_id = 'peer' WHERE id = ?",
      [id],
    );

    expect(await backfill().run(), (checked: 0, stamped: 0));
    expect(await cloudIdOf(id), isNull);
  });

  test('restamps a row a relink left empty', () async {
    library.add(asset('a1', cloudId: 'C-1'));
    final id = await link('a1');
    await db.customStatement(
      "UPDATE media SET cloud_asset_id = '' WHERE id = ?",
      [id],
    );

    await backfill().run();

    expect(await cloudIdOf(id), 'C-1');
  });

  // Rows linked before origins were recorded become this device's own only
  // once the origin backfill stamps them; a pass before that would set the
  // flag over rows it could not yet claim.
  test('waits for the origin backfill', () async {
    await prefs.remove(GalleryOriginBackfill.doneFlagKey);
    library.add(asset('a1', cloudId: 'C-1'));
    await link('a1');

    expect(await backfill().run(), isNull);
    expect(GalleryCloudIdBackfill.isDone(prefs), isFalse);
    expect(library.cloudIdCalls, 0);
  });

  test('waits for full photo access', () async {
    library.add(asset('a1', cloudId: 'C-1'));
    final id = await link('a1');

    expect(
      await backfill(permission: PhotoPermissionStatus.limited).run(),
      isNull,
    );
    expect(GalleryCloudIdBackfill.isDone(prefs), isFalse);
    expect(await cloudIdOf(id), isNull);
  });

  test('a host with no photo library is done at once', () async {
    expect(await backfill(supportsGallery: false).run(), (
      checked: 0,
      stamped: 0,
    ));
    expect(GalleryCloudIdBackfill.isDone(prefs), isTrue);
    expect(library.cloudIdCalls, 0);
  });

  test('a failed lookup leaves the flag unset', () async {
    library
      ..add(asset('a1', cloudId: 'C-1'))
      ..cloudIdError = StateError('channel');
    final id = await link('a1');

    expect(await backfill().run(), isNull);
    expect(GalleryCloudIdBackfill.isDone(prefs), isFalse);
    expect(await cloudIdOf(id), isNull);
  });

  test('runs once', () async {
    library.add(asset('a1', cloudId: 'C-1'));
    await link('a1');

    await backfill().run();
    expect(await backfill().run(), isNull);
    expect(library.cloudIdCalls, 1);
  });

  // The lookup can take a while; a cloud id a sync delivered meanwhile is
  // the linking device's own answer and stays.
  test('a sync-delivered cloud id is kept', () async {
    final id = await link('a1');
    final racing = _SyncDuringLookup(db, id)..add(asset('a1', cloudId: 'C-1'));

    expect(await backfill(source: racing).run(), (checked: 1, stamped: 0));
    expect(await cloudIdOf(id), 'C-peer');
  });

  test('a row linked during the lookup keeps the flag open', () async {
    final linkedLater = _LinkDuringLookup(link)
      ..add(asset('a1', cloudId: 'C-1'));
    await link('a1');

    await backfill(source: linkedLater).run();

    expect(GalleryCloudIdBackfill.isDone(prefs), isFalse);
  });
}

/// A library whose lookup races a sync that writes the row's cloud id.
class _SyncDuringLookup extends FakePhotoPickerService {
  _SyncDuringLookup(this._db, this._id);

  final AppDatabase _db;
  final String _id;

  @override
  Future<Map<String, String>> cloudIdentifiers(List<String> localIds) async {
    await _db.customStatement(
      "UPDATE media SET cloud_asset_id = 'C-peer' WHERE id = ?",
      [_id],
    );
    return super.cloudIdentifiers(localIds);
  }
}

/// A library whose lookup races the user linking another photo.
class _LinkDuringLookup extends FakePhotoPickerService {
  _LinkDuringLookup(this._link);

  final Future<String> Function(String assetId) _link;

  @override
  Future<Map<String, String>> cloudIdentifiers(List<String> localIds) async {
    await _link('a-later');
    return super.cloudIdentifiers(localIds);
  }
}
