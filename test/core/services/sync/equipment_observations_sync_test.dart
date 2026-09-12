import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';

import '../../../helpers/test_database.dart';

/// equipmentObservations is a synced aggregate root (condition phase 3a):
/// own id, own hlc, table-backed export descriptor, merged after its parents
/// (divers, equipment, dives).
void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });
  tearDown(tearDownTestDatabase);

  Map<String, dynamic> observationJson(String id, {String? diveId}) => {
    'id': id,
    'diverId': null,
    'equipmentId': 'reg',
    'diveId': diveId,
    'observedAt': 1000,
    'status': 'issue',
    'issueTags': '["freeFlow"]',
    'note': 'n',
    'createdAt': 1000,
    'updatedAt': 1000,
    'hlc': null,
  };

  Future<void> insertEquipment(String id) =>
      serializer.upsertRecord('equipment', {
        'id': id,
        'name': id,
        'type': 'regulator',
        'status': 'active',
        'purchaseCurrency': 'USD',
        'notes': '',
        'isActive': true,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

  test('SyncData carries the entity and the base table key', () {
    expect(
      SyncDataSerializer.debugBaseTableKeys,
      contains('equipmentObservations'),
    );
    expect(
      SyncData.fromJson({
        'equipmentObservations': [observationJson('o1')],
      }).equipmentObservations,
      hasLength(1),
    );
    expect(const SyncData().toJson().keys, contains('equipmentObservations'));
  });

  test('round-trips through upsertRecord, fetchRecord, deleteRecord', () async {
    await insertEquipment('reg');
    await serializer.upsertRecord(
      'equipmentObservations',
      observationJson('o1'),
    );

    final row = await serializer.fetchRecord('equipmentObservations', 'o1');
    expect(row, isNotNull);
    expect(row!['equipmentId'], 'reg');
    expect(row['status'], 'issue');
    expect(row['issueTags'], '["freeFlow"]');
    expect(row['note'], 'n');

    await serializer.deleteRecord('equipmentObservations', 'o1');
    expect(await serializer.fetchRecord('equipmentObservations', 'o1'), isNull);
  });

  test('round-trips through the batch paths and recordIdsFor', () async {
    await insertEquipment('reg');
    await serializer.upsertRecords('equipmentObservations', [
      observationJson('o1'),
      observationJson('o2'),
    ]);
    final fetched = await serializer.fetchRecords('equipmentObservations', [
      'o1',
      'o2',
    ]);
    expect(fetched.keys, containsAll(['o1', 'o2']));
    expect(
      await serializer.recordIdsFor('equipmentObservations'),
      containsAll(['o1', 'o2']),
    );
  });

  test('a local write is exported in the base and by watermark', () async {
    await insertEquipment('reg');
    final repo = EquipmentObservationRepository(
      syncRepository: SyncRepository(),
    );
    final created = await repo.create(
      equipmentId: 'reg',
      observedAt: DateTime.utc(2026),
      status: ObservationStatus.ok,
    );
    final base = await serializer.exportChangeset(
      deviceId: 'dev',
      hlcWatermark: null,
      deletions: const [],
    );
    expect(
      base.data.equipmentObservations.map((r) => r['id']),
      contains(created.id),
    );
    // A watermark newer than every clock exports nothing.
    final later = await serializer.exportChangeset(
      deviceId: 'dev',
      hlcWatermark: '9999-12-31T23:59:59.999Z-9999-zzzz',
      deletions: const [],
    );
    expect(later.data.equipmentObservations, isEmpty);
  });

  test('is registered as a clocked entity after its parents', () {
    expect(SyncService.entityHasUpdatedAt['equipmentObservations'], isTrue);
    final refs = SyncService.parentRefs['equipmentObservations']!;
    expect(
      refs.map((r) => '${r.field}:${r.parent}:${r.nullable}'),
      unorderedEquals([
        'diverId:divers:true',
        'equipmentId:equipment:false',
        'diveId:dives:true',
      ]),
    );
  });
}
