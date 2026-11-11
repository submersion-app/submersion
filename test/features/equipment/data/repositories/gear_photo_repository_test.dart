import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
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

  Future<String> checkIn(String equipmentId, String id) async =>
      (await EquipmentObservationRepository().create(
        id: id,
        equipmentId: equipmentId,
        observedAt: DateTime.utc(2026, 11, 3),
        status: ObservationStatus.ok,
      )).id;

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

  // A check-in deleted here or by a sync moves its photos to the item's
  // identification photos without touching a media row, so the photo
  // readers must tick on the check-ins table too.
  for (final (name, watch) in [
    ('watchGearPhotoChanges', () => repository.watchGearPhotoChanges()),
    ('watchGearItemPhotoChanges', () => repository.watchGearItemPhotoChanges()),
  ]) {
    test('$name ticks when a check-in is deleted', () async {
      final reg = await createItem('Reg');
      final obs = await checkIn(reg.id, 'obs-tick');
      var ticks = 0;
      final sub = watch().listen((_) => ticks++);
      addTearDown(sub.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final before = ticks;

      await EquipmentObservationRepository().delete(obs);
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(ticks, greaterThan(before));
    });
  }

  test('identificationPhotos excludes check-in photos and documents', () async {
    final item = await createItem('Reg');
    final idPhoto = await addMedia(equipmentId: item.id);
    await addMedia(
      equipmentId: item.id,
      observationId: await checkIn(item.id, 'obs-1'),
    );
    await addMedia(equipmentId: item.id, type: MediaType.document);

    final photos = await repository.identificationPhotos(item.id);

    expect(photos.map((m) => m.id), [idPhoto.id]);
  });

  test(
    'a photo naming a check-in that does not exist is an identification photo',
    () async {
      // A draft's photos outliving an app kill, or a check-in deleted on a
      // peer, must not vanish from the gear page (issue #3355).
      final item = await createItem('Reg');
      final checkIn = await EquipmentObservationRepository().create(
        equipmentId: item.id,
        observedAt: DateTime.utc(2026, 11, 3),
        status: ObservationStatus.ok,
      );
      final orphan = await addMedia(
        equipmentId: item.id,
        observationId: 'gone',
      );
      final backed = await addMedia(
        equipmentId: item.id,
        observationId: checkIn.id,
      );

      final ids = (await repository.identificationPhotos(
        item.id,
      )).map((m) => m.id);
      expect(ids, contains(orphan.id));
      expect(ids, isNot(contains(backed.id)));

      await repository.setCover(item.id, orphan.id);
      expect((await repository.coverFor(item.id, orphan.id))?.id, orphan.id);
    },
  );

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
    final a = await addMedia(
      equipmentId: item.id,
      observationId: await checkIn(item.id, 'obs-1'),
    );
    final b = await addMedia(
      equipmentId: item.id,
      observationId: await checkIn(item.id, 'obs-2'),
    );
    await addMedia(equipmentId: item.id);

    final map = await repository.photosByObservation(item.id);

    expect(map.keys, unorderedEquals(['obs-1', 'obs-2']));
    expect(map['obs-1']!.single.id, a.id);
    expect(map['obs-2']!.single.id, b.id);
  });

  test(
    'gearGallery groups by item and shows only gear the diver may see',
    () async {
      for (final id in ['me', 'other']) {
        await db
            .into(db.divers)
            .insert(
              DiversCompanion.insert(
                id: id,
                name: id,
                createdAt: 0,
                updatedAt: 0,
              ),
            );
      }
      Future<EquipmentItem> owned(String name, String diverId) =>
          equipment.createEquipment(
            EquipmentItem(
              id: '',
              diverId: diverId,
              name: name,
              type: EquipmentType.regulator,
            ),
          );
      final reg = await owned('Reg', 'me');
      final suit = await owned('Suit', 'me');
      final hidden = await owned('Hidden', 'other');
      await addMedia(equipmentId: reg.id, takenAt: DateTime.utc(2026, 10, 1));
      await addMedia(
        equipmentId: suit.id,
        observationId: await checkIn(suit.id, 'obs-9'),
        takenAt: DateTime.utc(2026, 11, 1),
      );
      await addMedia(equipmentId: suit.id, type: MediaType.document);
      await addMedia(equipmentId: hidden.id);

      final groups = await repository.gearGallery(diverId: 'me');

      expect(groups.map((g) => g.name), ['Suit', 'Reg']);
      expect(groups.first.items, hasLength(1));
      expect(groups.first.items.single.isCheckInPhoto, isTrue);

      // A check-in id with no check-in is no check-in in the gallery either.
      await addMedia(equipmentId: reg.id, observationId: 'gone');
      final again = await repository.gearGallery(diverId: 'me');
      expect(
        again
            .firstWhere((g) => g.equipmentId == reg.id)
            .items
            .every((m) => !m.isCheckInPhoto),
        isTrue,
      );
      // With no diver, every item's photos show.
      expect(
        (await repository.gearGallery()).map((g) => g.equipmentId),
        contains(hidden.id),
      );
    },
  );

  test('linkedLocalPathsFor returns the item\'s local file paths', () async {
    final item = await createItem('Reg');
    final at = DateTime.utc(2026, 11, 3);
    await media.createMedia(
      MediaItem(
        id: '',
        equipmentId: item.id,
        localPath: '/Users/me/Pictures/label.jpg',
        mediaType: MediaType.photo,
        takenAt: at,
        createdAt: at,
        updatedAt: at,
      ),
    );

    expect(await repository.linkedLocalPathsFor(item.id), {
      '/Users/me/Pictures/label.jpg',
    });
  });

  test('gearGallery drops a group whose item no longer exists', () async {
    final reg = await createItem('Reg');
    await addMedia(equipmentId: reg.id);
    // A peer's delete can leave a row naming an item this device lacks.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement(
      "UPDATE media SET equipment_id = 'missing-item' WHERE equipment_id = ?",
      [reg.id],
    );
    await db.customStatement('PRAGMA foreign_keys = ON');

    expect(await repository.gearGallery(), isEmpty);
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

  test('a deleted item\'s photo a dive keeps loses its check-in too', () async {
    final item = await createItem('Reg');
    final dive = await DiveRepository().createDive(
      Dive(id: '', diveNumber: 1, dateTime: DateTime.utc(2026, 11, 3)),
    );
    final kept = await addMedia(
      equipmentId: item.id,
      observationId: await checkIn(item.id, 'obs-1'),
      diveId: dive.id,
    );

    await media.unlinkMediaFromDeletedEquipment([kept.id]);

    final read = await media.getMediaById(kept.id);
    expect(read!.equipmentId, isNull);
    expect(read.observationId, isNull);
  });

  test('coverFor is null when the id dangles or names another item', () async {
    final reg = await createItem('Reg');
    final suit = await createItem('Suit');
    final suitPhoto = await addMedia(equipmentId: suit.id);
    final regPhoto = await addMedia(equipmentId: reg.id);

    expect(await repository.coverFor(reg.id, 'missing'), isNull);
    expect(await repository.coverFor(reg.id, suitPhoto.id), isNull);
    expect((await repository.coverFor(reg.id, regPhoto.id))!.id, regPhoto.id);
  });

  test(
    'setCover takes only one of the item\'s own identification photos',
    () async {
      final reg = await createItem('Reg');
      final suit = await createItem('Suit');
      final suitPhoto = await addMedia(equipmentId: suit.id);
      final finding = await addMedia(
        equipmentId: reg.id,
        observationId: await checkIn(reg.id, 'obs-cover'),
      );
      final own = await addMedia(equipmentId: reg.id);

      for (final bad in [suitPhoto.id, finding.id, 'no-such-photo']) {
        await expectLater(
          repository.setCover(reg.id, bad),
          throwsArgumentError,
          reason: bad,
        );
      }
      Future<String?> coverOf(String id) async => (await (db.select(
        db.equipment,
      )..where((t) => t.id.equals(id))).getSingle()).coverMediaId;
      expect(await coverOf(reg.id), isNull);

      await repository.setCover(reg.id, own.id);
      expect(await coverOf(reg.id), own.id);
    },
  );

  test('a video is never a cover', () async {
    final reg = await createItem('Reg');
    final video = await addMedia(equipmentId: reg.id, type: MediaType.video);

    expect(await repository.coverFor(reg.id, video.id), isNull);
    await expectLater(
      repository.setCover(reg.id, video.id),
      throwsArgumentError,
    );
    final row = await (db.select(
      db.equipment,
    )..where((t) => t.id.equals(reg.id))).getSingle();
    expect(row.coverMediaId, isNull);
  });

  test('setCover on an item that is gone throws and marks nothing', () async {
    await db.delete(db.syncRecords).go();

    await expectLater(repository.setCover('gone-item', null), throwsStateError);
    final pending = await db.select(db.syncRecords).get();
    expect(pending.where((r) => r.recordId == 'gone-item'), isEmpty);
  });

  test('a check-in id list longer than one chunk is read in full', () async {
    final item = await createItem('Reg');
    final living = await addMedia(
      equipmentId: item.id,
      observationId: await checkIn(item.id, 'obs-real'),
    );
    // More dangling check-in ids than one bound-variable chunk holds.
    const count = kSeriesIdChunkSize + 50;
    final values = [
      for (var i = 0; i < count; i++)
        "('m$i', 'p$i', 'photo', $i, 1, 1, '${item.id}', 'gone-$i')",
    ].join(', ');
    await db.customStatement(
      'INSERT INTO media (id, file_path, file_type, taken_at, created_at, '
      'updated_at, equipment_id, observation_id) VALUES $values',
    );

    final ids = (await repository.identificationPhotos(
      item.id,
    )).map((m) => m.id);
    expect(ids, hasLength(count));
    expect(ids, isNot(contains(living.id)));
    expect((await repository.photosByObservation(item.id)).keys, ['obs-real']);
  });
}
