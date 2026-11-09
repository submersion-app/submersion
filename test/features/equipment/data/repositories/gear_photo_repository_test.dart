import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_unlink_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

import '../../../../helpers/test_database.dart';

/// Gear photos (issue #3355): identification photos, check-in photos, the
/// Gear gallery and the cover photo.
void main() {
  late AppDatabase db;
  late GearPhotoRepository repository;
  late MediaRepository media;
  late EquipmentRepository equipment;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = GearPhotoRepository();
    media = MediaRepository();
    equipment = EquipmentRepository();
  });

  tearDown(tearDownTestDatabase);

  Future<EquipmentItem> createItem(String name) => equipment.createEquipment(
    EquipmentItem(id: '', name: name, type: EquipmentType.regulator),
  );

  Future<MediaItem> addMedia({
    required String equipmentId,
    String? observationId,
    String? diveId,
    MediaType type = MediaType.photo,
    DateTime? takenAt,
  }) {
    final at = takenAt ?? DateTime.utc(2026, 11, 3);
    return media.createMedia(
      MediaItem(
        id: '',
        equipmentId: equipmentId,
        observationId: observationId,
        diveId: diveId,
        filePath: '/photos/${DateTime.now().microsecondsSinceEpoch}.jpg',
        mediaType: type,
        takenAt: at,
        createdAt: at,
        updatedAt: at,
      ),
    );
  }

  test('identificationPhotos excludes check-in photos and documents', () async {
    final item = await createItem('Reg');
    final idPhoto = await addMedia(equipmentId: item.id);
    await addMedia(equipmentId: item.id, observationId: 'obs-1');
    await addMedia(equipmentId: item.id, type: MediaType.document);

    final photos = await repository.identificationPhotos(item.id);

    expect(photos.map((m) => m.id), [idPhoto.id]);
  });

  test('photosForObservation returns only that check-in\'s rows', () async {
    final item = await createItem('Reg');
    final a = await addMedia(equipmentId: item.id, observationId: 'obs-1');
    await addMedia(equipmentId: item.id, observationId: 'obs-2');
    await addMedia(equipmentId: item.id);

    final photos = await repository.photosForObservation('obs-1');

    expect(photos.map((m) => m.id), [a.id]);
  });

  test('photosByObservation keys every check-in photo of an item', () async {
    final item = await createItem('Reg');
    final a = await addMedia(equipmentId: item.id, observationId: 'obs-1');
    final b = await addMedia(equipmentId: item.id, observationId: 'obs-2');
    await addMedia(equipmentId: item.id);

    final map = await repository.photosByObservation(item.id);

    expect(map.keys, unorderedEquals(['obs-1', 'obs-2']));
    expect(map['obs-1']!.single.id, a.id);
    expect(map['obs-2']!.single.id, b.id);
  });

  test(
    'gearGallery groups by item and skips items outside the visible set',
    () async {
      final reg = await createItem('Reg');
      final suit = await createItem('Suit');
      final hidden = await createItem('Hidden');
      await addMedia(equipmentId: reg.id, takenAt: DateTime.utc(2026, 10, 1));
      await addMedia(
        equipmentId: suit.id,
        observationId: 'obs-9',
        takenAt: DateTime.utc(2026, 11, 1),
      );
      await addMedia(equipmentId: suit.id, type: MediaType.document);
      await addMedia(equipmentId: hidden.id);

      final groups = await repository.gearGallery({reg.id, suit.id});

      expect(groups.map((g) => g.name), ['Suit', 'Reg']);
      expect(groups.first.items, hasLength(1));
      expect(groups.first.items.single.isCheckInPhoto, isTrue);
    },
  );

  test('equipmentIdsWithPhotos lists items holding a gear photo', () async {
    final reg = await createItem('Reg');
    final suit = await createItem('Suit');
    final paper = await createItem('Paper');
    await addMedia(equipmentId: reg.id);
    await addMedia(equipmentId: suit.id, observationId: 'obs-1');
    await addMedia(equipmentId: paper.id, type: MediaType.document);

    expect(
      await repository.equipmentIdsWithPhotos(),
      unorderedEquals([reg.id, suit.id]),
    );
  });

  test('setCover stamps updatedAt and marks equipment pending', () async {
    final item = await createItem('Reg');
    final photo = await addMedia(equipmentId: item.id);
    await db.delete(db.syncRecords).go();

    await repository.setCover(item.id, photo.id);

    final row = await (db.select(
      db.equipment,
    )..where((t) => t.id.equals(item.id))).getSingle();
    expect(row.coverMediaId, photo.id);
    final pending = await db.select(db.syncRecords).get();
    expect(
      pending.where(
        (r) => r.entityType == 'equipment' && r.recordId == item.id,
      ),
      isNotEmpty,
    );

    await repository.setCover(item.id, null);
    final cleared = await (db.select(
      db.equipment,
    )..where((t) => t.id.equals(item.id))).getSingle();
    expect(cleared.coverMediaId, isNull);
  });

  test('unlinking the cover clears it', () async {
    final item = await createItem('Reg');
    final cover = await addMedia(equipmentId: item.id);
    final other = await addMedia(equipmentId: item.id);
    await repository.setCover(item.id, cover.id);
    final service = MediaUnlinkService(
      repository: media,
      deleteMedia: media.deleteMultipleMedia,
    );

    await service.unlinkFromEquipment([other.id]);
    expect((await equipment.getEquipmentById(item.id))!.coverMediaId, cover.id);

    await service.unlinkFromEquipment([cover.id]);
    expect((await equipment.getEquipmentById(item.id))!.coverMediaId, isNull);
  });

  test(
    'unlinkFromEquipment clears observation_id on rows a dive keeps',
    () async {
      final item = await createItem('Reg');
      final dive = await DiveRepository().createDive(
        Dive(id: '', diveNumber: 1, dateTime: DateTime.utc(2026, 11, 3)),
      );
      final kept = await addMedia(
        equipmentId: item.id,
        observationId: 'obs-1',
        diveId: dive.id,
      );
      final service = MediaUnlinkService(
        repository: media,
        deleteMedia: media.deleteMultipleMedia,
      );

      await service.unlinkFromEquipment([kept.id]);

      final read = await media.getMediaById(kept.id);
      expect(read!.equipmentId, isNull);
      expect(read.observationId, isNull);
      expect(read.diveId, dive.id);
    },
  );

  test('coverFor is null when the id dangles or names another item', () async {
    final reg = await createItem('Reg');
    final suit = await createItem('Suit');
    final suitPhoto = await addMedia(equipmentId: suit.id);
    final regPhoto = await addMedia(equipmentId: reg.id);

    await repository.setCover(reg.id, 'missing');
    expect(await repository.coverFor(reg.id), isNull);

    await repository.setCover(reg.id, suitPhoto.id);
    expect(await repository.coverFor(reg.id), isNull);

    await repository.setCover(reg.id, regPhoto.id);
    expect((await repository.coverFor(reg.id))!.id, regPhoto.id);
  });
}
