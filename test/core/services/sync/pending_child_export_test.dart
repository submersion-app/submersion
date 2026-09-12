import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Children with no clock of their own (tanks, gear links, tags and the
/// rest) are exported through their parent's HLC. A change to only the
/// child used to reach peers only if the parent was re-stamped, which makes
/// a possibly stale whole parent row win under last-writer-wins. A pending
/// child now travels on its own, without its parent.
void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });
  tearDown(tearDownTestDatabase);

  /// A synced dive with two tanks and a gear link, returning the watermark
  /// a peer already holds (the dive's own HLC).
  Future<String> seedSyncedDive() async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('e1', 'Wing', 'bcd', 1, 1)",
    );
    await db.customStatement(
      'INSERT INTO dive_tanks (id, dive_id) '
      "VALUES ('t1', 'd1'), ('t2', 'd1')",
    );
    await db.customStatement(
      "INSERT INTO dive_equipment (dive_id, equipment_id) VALUES ('d1', 'e1')",
    );
    final dive = await serializer.fetchRecord('dives', 'd1');
    await SyncRepository().clearAllSyncRecords();
    return dive!['hlc'] as String;
  }

  Future<SyncData> changesetSince(String watermark) async {
    final payload = await serializer.exportChangeset(
      deviceId: 'me',
      hlcWatermark: watermark,
      deletions: const [],
    );
    return payload.data;
  }

  test('a pending tank travels without its dive', () async {
    final watermark = await seedSyncedDive();
    await SyncRepository().markRecordPending(
      entityType: 'diveTanks',
      recordId: 't1',
      localUpdatedAt: 1,
    );

    final data = await changesetSince(watermark);

    expect(data.dives, isEmpty, reason: 'the dive did not change');
    expect(data.diveTanks.map((t) => t['id']), ['t1']);
  });

  test('a pending composite-key gear link travels too', () async {
    final watermark = await seedSyncedDive();
    await SyncRepository().markRecordPending(
      entityType: 'diveEquipment',
      recordId: 'd1|e1',
      localUpdatedAt: 1,
    );

    final data = await changesetSince(watermark);

    expect(data.dives, isEmpty);
    expect(
      data.diveEquipment.map((r) => '${r['diveId']}|${r['equipmentId']}'),
      ['d1|e1'],
    );
  });

  test('nothing pending, nothing extra', () async {
    final watermark = await seedSyncedDive();

    final data = await changesetSince(watermark);

    expect(data.diveTanks, isEmpty);
    expect(data.diveEquipment, isEmpty);
  });

  test('a pending tank of a changed dive is sent once', () async {
    final watermark = await seedSyncedDive();
    await SyncRepository().markRecordPending(
      entityType: 'dives',
      recordId: 'd1',
      localUpdatedAt: 1,
    );
    await SyncRepository().markRecordPending(
      entityType: 'diveTanks',
      recordId: 't1',
      localUpdatedAt: 1,
    );

    final data = await changesetSince(watermark);

    expect(data.dives.map((d) => d['id']), ['d1']);
    expect(data.diveTanks.map((t) => t['id']).toList()..sort(), ['t1', 't2']);
  });

  test('a pending mark for a row since deleted is skipped', () async {
    final watermark = await seedSyncedDive();
    await SyncRepository().markRecordPending(
      entityType: 'diveTanks',
      recordId: 'gone',
      localUpdatedAt: 1,
    );

    final data = await changesetSince(watermark);

    expect(data.diveTanks, isEmpty);
  });

  test('every parent-gated child is clockless and keyed like the merge', () {
    for (final type in SyncDataSerializer.parentGatedChildEntities) {
      expect(
        SyncService.entityHasUpdatedAt[type],
        isFalse,
        reason: '$type rides its parent, so the merge applies it clockless',
      );
    }
    final samples = <String, Map<String, dynamic>>{
      'diveTanks': {'id': 't1', 'diveId': 'd1'},
      'diveEquipment': {'diveId': 'd1', 'equipmentId': 'e1'},
      'equipmentSetItems': {'setId': 's1', 'equipmentId': 'e1'},
      'divePlanEquipment': {'planId': 'p1', 'equipmentId': 'e1'},
      'diveSafetyReviews': {'diveId': 'd1'},
    };
    for (final MapEntry(key: type, value: row) in samples.entries) {
      expect(
        SyncDataSerializer.parentGatedRecordId(type, row),
        SyncService.recordIdForEntity(type, row),
        reason: type,
      );
    }
  });
}
