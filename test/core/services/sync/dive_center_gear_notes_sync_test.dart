import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// diveCenterGearNotes is a parent-gated child of diveCenters (issue #2075):
/// own id, own hlc, exported with its center and on its own when pending,
/// applied after diveCenters and dives.
void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });
  tearDown(tearDownTestDatabase);

  Map<String, dynamic> noteJson(String id, {String? diveId}) => {
    'id': id,
    'diveCenterId': 'c1',
    'gearType': 'regulator',
    'label': '14',
    'size': null,
    'verdict': 'avoid',
    'leadAdjustmentKg': null,
    'volumeLiters': null,
    'note': 'wet',
    'diveId': diveId,
    'notedAt': 1000,
    'createdAt': 1000,
    'updatedAt': 1000,
    'hlc': null,
  };

  Future<void> insertCenter(String id) =>
      serializer.upsertRecord('diveCenters', {
        'id': id,
        'name': id,
        'affiliations': '',
        'notes': '',
        'createdAt': 1000,
        'updatedAt': 1000,
      });

  test('is registered everywhere a parent-gated child must be', () {
    expect(SyncRepository.hlcTargets['diveCenterGearNotes'], (
      table: 'dive_center_gear_notes',
      pk: 'id',
    ));
    expect(
      SyncDataSerializer.parentGatedChildEntities,
      contains('diveCenterGearNotes'),
    );
    expect(
      SyncDataSerializer.parentGatedTables['diveCenterGearNotes'],
      'dive_center_gear_notes',
    );
    expect(SyncService.entityHasUpdatedAt['diveCenterGearNotes'], isFalse);
    expect(SyncService.parentRefs['diveCenterGearNotes'], [
      (field: 'diveCenterId', parent: 'diveCenters', nullable: false),
      (field: 'diveId', parent: 'dives', nullable: true),
    ]);
  });

  test('SyncData carries the entity right after diveCenters', () {
    final keys = const SyncData().toJson().keys.toList();
    expect(
      keys.indexOf('diveCenterGearNotes'),
      keys.indexOf('diveCenters') + 1,
    );
    expect(
      SyncDataSerializer.debugBaseTableKeys,
      contains('diveCenterGearNotes'),
    );
    expect(
      SyncData.fromJson({
        'diveCenterGearNotes': [noteJson('n1')],
      }).diveCenterGearNotes,
      hasLength(1),
    );
  });

  test('round-trips through upsertRecord, fetchRecord, deleteRecord', () async {
    await insertCenter('c1');
    await serializer.upsertRecord('diveCenterGearNotes', noteJson('n1'));

    final row = await serializer.fetchRecord('diveCenterGearNotes', 'n1');
    expect(row, isNotNull);
    expect(row!['diveCenterId'], 'c1');
    expect(row['gearType'], 'regulator');
    expect(row['verdict'], 'avoid');
    expect(row['label'], '14');
    expect(row['note'], 'wet');

    await serializer.deleteRecord('diveCenterGearNotes', 'n1');
    expect(await serializer.fetchRecord('diveCenterGearNotes', 'n1'), isNull);
  });

  test('round-trips through the batch paths and recordIdsFor', () async {
    await insertCenter('c1');
    await serializer.upsertRecords('diveCenterGearNotes', [
      noteJson('n1'),
      noteJson('n2'),
    ]);
    final fetched = await serializer.fetchRecords('diveCenterGearNotes', [
      'n1',
      'n2',
    ]);
    expect(fetched.keys, containsAll(['n1', 'n2']));
    expect(
      await serializer.recordIdsFor('diveCenterGearNotes'),
      containsAll(['n1', 'n2']),
    );
  });

  test('a note whose center moved is exported by watermark', () async {
    await insertCenter('c1');
    await serializer.upsertRecord('diveCenterGearNotes', noteJson('n1'));
    // Stamp the center so its hlc is above the old watermark.
    await SyncRepository().markRecordPending(
      entityType: 'diveCenters',
      recordId: 'c1',
      localUpdatedAt: 2000,
    );
    final since = await serializer.exportChangeset(
      deviceId: 'dev',
      hlcWatermark: '000000000000000:000000:0',
      deletions: const [],
    );
    expect(since.data.diveCenterGearNotes.map((r) => r['id']), contains('n1'));
    final base = await serializer.exportChangeset(
      deviceId: 'dev',
      hlcWatermark: null,
      deletions: const [],
    );
    expect(base.data.diveCenterGearNotes.map((r) => r['id']), contains('n1'));
  });
}
