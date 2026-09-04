import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

import '../../../helpers/test_database.dart';

void main() {
  late LocalCacheDatabase cacheDb;
  late MediaTransferQueueRepository queue;
  late MediaRepository mediaRepository;
  late EquipmentRepository equipmentRepository;

  setUp(() async {
    await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    queue = MediaTransferQueueRepository(database: cacheDb);
    mediaRepository = MediaRepository();
    equipmentRepository = EquipmentRepository(
      mediaRepository: mediaRepository,
      mediaDeletionCoordinator: MediaDeletionCoordinator(
        mediaRepository: mediaRepository,
        queue: () => queue,
      ),
    );
  });

  tearDown(() async {
    await cacheDb.close();
    await tearDownTestDatabase();
  });

  Future<EquipmentItem> makeEquipment() => equipmentRepository.createEquipment(
    const EquipmentItem(
      id: '',
      name: 'MK25 EVO',
      type: EquipmentType.regulator,
    ),
  );

  Future<String> insertDive() async {
    final db = DatabaseService.instance.database;
    final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-1'),
            diveDateTime: Value(epoch),
            createdAt: Value(epoch),
            updatedAt: Value(epoch),
          ),
        );
    return 'dive-1';
  }

  MediaItem doc(String name, {String? equipmentId, String? diveId}) =>
      MediaItem(
        id: '',
        mediaType: MediaType.document,
        sourceType: MediaSourceType.localFile,
        filePath: '/tmp/$name',
        localPath: '/tmp/$name',
        originalFilename: name,
        equipmentId: equipmentId,
        diveId: diveId,
        takenAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  test('deleting equipment removes its only-attachment documents', () async {
    final item = await makeEquipment();
    final invoice = await mediaRepository.createMedia(
      doc('invoice.pdf', equipmentId: item.id),
    );

    await equipmentRepository.deleteEquipment(item.id);

    expect(await mediaRepository.getMediaById(invoice.id), isNull);
  });

  test('a document a dive still needs survives the deletion', () async {
    final item = await makeEquipment();
    final diveId = await insertDive();
    final shared = await mediaRepository.createMedia(
      doc('manual.pdf', equipmentId: item.id, diveId: diveId),
    );

    await equipmentRepository.deleteEquipment(item.id);

    final reloaded = await mediaRepository.getMediaById(shared.id);
    expect(reloaded, isNotNull);
    expect(reloaded!.equipmentId, isNull);
    expect(reloaded.diveId, diveId);
  });

  test('deleting equipment with no attachments still succeeds', () async {
    final item = await makeEquipment();
    await equipmentRepository.deleteEquipment(item.id);
    expect(await equipmentRepository.getEquipmentById(item.id), isNull);
  });
}
