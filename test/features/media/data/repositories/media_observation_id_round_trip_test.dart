import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

import '../../../../helpers/test_database.dart';

/// Gear photos (issue #3355): a media row carries the check-in it backs up,
/// and a gear item carries its chosen cover photo.
void main() {
  late MediaRepository media;
  late EquipmentRepository equipment;

  setUp(() async {
    await setUpTestDatabase();
    media = MediaRepository();
    equipment = EquipmentRepository();
  });

  tearDown(tearDownTestDatabase);

  Future<EquipmentItem> createItem() => equipment.createEquipment(
    const EquipmentItem(id: '', name: 'XTX50', type: EquipmentType.regulator),
  );

  MediaItem photo({
    required String equipmentId,
    String? observationId,
    MediaType type = MediaType.photo,
  }) => MediaItem(
    id: '',
    equipmentId: equipmentId,
    observationId: observationId,
    filePath: '/photos/reg.jpg',
    mediaType: type,
    takenAt: DateTime.utc(2026, 11, 3),
    createdAt: DateTime.utc(2026, 11, 3),
    updatedAt: DateTime.utc(2026, 11, 3),
  );

  test('createMedia keeps observationId', () async {
    final item = await createItem();
    final saved = await media.createMedia(
      photo(equipmentId: item.id, observationId: 'obs-1'),
    );

    final read = await media.getMediaById(saved.id);
    expect(read!.observationId, 'obs-1');
  });

  test('updateMedia does not clear observationId', () async {
    final item = await createItem();
    final saved = await media.createMedia(
      photo(equipmentId: item.id, observationId: 'obs-1'),
    );

    await media.updateMedia(
      saved.copyWith(caption: 'Nick', observationId: null),
    );

    final read = await media.getMediaById(saved.id);
    expect(read!.caption, 'Nick');
    expect(read.observationId, 'obs-1');
  });

  test('isGearPhoto and isCheckInPhoto read the links and the type', () {
    final id = photo(equipmentId: 'e1');
    final checkIn = photo(equipmentId: 'e1', observationId: 'o1');
    final doc = photo(equipmentId: 'e1', type: MediaType.document);
    final video = photo(equipmentId: 'e1', type: MediaType.video);

    expect(id.isGearPhoto, isTrue);
    expect(id.isCheckInPhoto, isFalse);
    expect(checkIn.isCheckInPhoto, isTrue);
    expect(doc.isGearPhoto, isFalse);
    expect(video.isGearPhoto, isTrue);
    expect(
      photo(equipmentId: 'e1').copyWith(equipmentId: null).isGearPhoto,
      isFalse,
    );
  });

  test('getEquipmentById maps cover_media_id', () async {
    final item = await createItem();
    final database = DatabaseService.instance.database;
    await (database.update(database.equipment)
          ..where((t) => t.id.equals(item.id)))
        .write(const db.EquipmentCompanion(coverMediaId: Value('m-cover')));

    final read = await equipment.getEquipmentById(item.id);
    expect(read!.coverMediaId, 'm-cover');
  });

  test('updateEquipment leaves cover_media_id untouched', () async {
    final item = await createItem();
    final database = DatabaseService.instance.database;
    await (database.update(database.equipment)
          ..where((t) => t.id.equals(item.id)))
        .write(const db.EquipmentCompanion(coverMediaId: Value('m-cover')));

    final read = await equipment.getEquipmentById(item.id);
    await equipment.updateEquipment(
      read!.copyWith(name: 'XTX50 renamed', clearCoverMediaId: true),
    );

    final after = await equipment.getEquipmentById(item.id);
    expect(after!.name, 'XTX50 renamed');
    expect(after.coverMediaId, 'm-cover');
  });
}
