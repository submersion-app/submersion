import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/repair/media_repair_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

/// A repair relinks a row to a gallery asset or a file on THIS device, and
/// both are addresses only this device can resolve. The origin has to move
/// with them: only the origin device may call a failed search notFound
/// (media sync program spec 6.1), so a repaired row that kept a foreign or
/// missing origin could never be orphaned by the device that relinked it.
void main() {
  late AppDatabase db;
  late String me;
  final repo = MediaRepository();

  setUp(() async {
    db = await setUpTestDatabase();
    me = await SyncRepository().getDeviceId();
  });
  tearDown(() async => tearDownTestDatabase());

  /// A dead link another device made, or one made before links recorded an
  /// origin ([origin] null).
  Future<String> deadRow(String? origin) async {
    final id = (await repo.createMedia(
      MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.platformGallery,
        platformAssetId: 'gone',
        takenAt: DateTime(2026, 7, 1),
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      ),
    )).id;
    await db.customStatement(
      'UPDATE media SET origin_device_id = ?, is_orphaned = 1 WHERE id = ?',
      [origin, id],
    );
    return id;
  }

  Future<String?> originOf(String id) async =>
      (await repo.getMediaById(id))!.originDeviceId;

  test('a gallery relink records this device as the origin', () async {
    final foreign = await deadRow('peer');
    final unstamped = await deadRow(null);

    await repo.applyRepairWrites([
      RepairWrite(
        mediaId: foreign,
        newPlatformAssetId: 'A-1',
        newSourceType: MediaSourceType.platformGallery,
      ),
      RepairWrite(
        mediaId: unstamped,
        newPlatformAssetId: 'A-2',
        newSourceType: MediaSourceType.platformGallery,
      ),
    ]);

    expect(await originOf(foreign), me);
    expect(await originOf(unstamped), me);
  });

  test('a file relink records this device as the origin', () async {
    final id = await deadRow('peer');

    await repo.applyRepairWrites([
      RepairWrite(mediaId: id, newLocalPath: p.join('photos', 'reef.jpg')),
    ]);

    expect(await originOf(id), me);
  });

  // A source every device resolves the same way records no origin at link
  // time, and a repair to one must not keep the old device's: that origin
  // described an address the row no longer has.
  test('a relink to a shared source clears the old origin', () async {
    final id = await deadRow('peer');

    await repo.applyRepairWrites([
      RepairWrite(mediaId: id, newSourceType: MediaSourceType.networkUrl),
    ]);

    expect(await originOf(id), isNull);
  });
}
