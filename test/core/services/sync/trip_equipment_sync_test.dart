import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/trips/data/repositories/trip_equipment_repository.dart';

import '../../../helpers/test_database.dart';

/// Sync of gear packed for a trip (issue #2338): a parent-gated child of
/// `trips`, like equipment shares are of `equipment`.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 't1',
            name: 'Bonaire',
            startDate: t,
            endDate: t,
            createdAt: t,
            updatedAt: t,
          ),
        );
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'bcd',
            name: 'BCD',
            type: 'bcd',
            createdAt: t,
            updatedAt: t,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  Future<void> pack(String id) => db
      .into(db.tripEquipment)
      .insert(
        TripEquipmentCompanion.insert(
          id: id,
          tripId: 't1',
          equipmentId: 'bcd',
          createdAt: 1,
        ),
      );

  test('a packed row round-trips through fetch and upsert', () async {
    await pack('a');
    final fetched = await serializer.fetchRecord('tripEquipment', 'a');
    expect(fetched, isNotNull);
    await serializer.deleteRecord('tripEquipment', 'a');
    expect(await db.select(db.tripEquipment).get(), isEmpty);
    await serializer.upsertRecord('tripEquipment', fetched!);
    expect((await db.select(db.tripEquipment).get()).single.id, 'a');
  });

  test('a peer copy of a pair under another id converges on one row', () async {
    await pack('zzz-local');
    await serializer.upsertRecords('tripEquipment', [
      {
        'id': 'aaa-peer',
        'tripId': 't1',
        'equipmentId': 'bcd',
        'createdAt': 2,
        'hlc': null,
      },
    ]);
    final rows = await db.select(db.tripEquipment).get();
    expect(rows.map((r) => r.id), ['aaa-peer']);
  });

  test('a single peer copy under another id also converges', () async {
    await pack('zzz-local');
    await serializer.upsertRecord('tripEquipment', {
      'id': 'aaa-peer',
      'tripId': 't1',
      'equipmentId': 'bcd',
      'createdAt': 2,
      'hlc': null,
    });
    final rows = await db.select(db.tripEquipment).get();
    expect(rows.map((r) => r.id), ['aaa-peer']);
  });

  test('a trips tombstone drops its packed rows', () async {
    await pack('a');
    await serializer.deleteRecord('trips', 't1');
    expect(await db.select(db.tripEquipment).get(), isEmpty);
  });

  test('a pending row travels without its trip', () async {
    final trip = await serializer.fetchRecord('trips', 't1');
    await SyncRepository().clearAllSyncRecords();
    final watermark = (trip!['hlc'] as String?) ?? '0';
    await TripEquipmentRepository().pack('t1', ['bcd']);
    final payload = await serializer.exportChangeset(
      deviceId: 'me',
      hlcWatermark: watermark,
      deletions: const [],
    );
    expect(payload.data.tripEquipment, hasLength(1));
    expect(payload.data.tripEquipment.single['equipmentId'], 'bcd');
  });

  test('a full export carries every packed row', () async {
    await pack('a');
    final payload = await serializer.exportData(
      deviceId: 'me',
      deletions: const [],
    );
    expect(payload.data.tripEquipment.map((r) => r['id']), ['a']);
  });

  test('a trip whose clock moved carries its packed rows', () async {
    // Not pending itself: the row travels because its trip changed.
    await pack('a');
    const watermark = '000000000000000:000000:peer';
    await SyncRepository().markRecordPending(
      entityType: 'trips',
      recordId: 't1',
      localUpdatedAt: 1,
    );
    final payload = await serializer.exportChangeset(
      deviceId: 'me',
      hlcWatermark: watermark,
      deletions: const [],
    );
    expect(payload.data.tripEquipment.map((r) => r['id']), ['a']);
  });

  test('registration', () {
    expect(
      SyncDataSerializer.parentGatedChildEntities,
      contains('tripEquipment'),
    );
    expect(SyncRepository.hlcTargets['tripEquipment']!.table, 'trip_equipment');
    expect(SyncService.entityHasUpdatedAt['tripEquipment'], isFalse);
    final refs = SyncService.parentRefs['tripEquipment']!;
    expect(refs.map((r) => (r.field, r.parent, r.nullable)).toSet(), {
      ('tripId', 'trips', false),
      ('equipmentId', 'equipment', false),
    });
  });
}
