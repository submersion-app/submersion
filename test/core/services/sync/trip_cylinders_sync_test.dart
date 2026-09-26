import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// The two trip cylinder entities (v229, issue #2325) through every sync
/// path a trip child takes: fetch, upsert, ids, delete, delta export,
/// registration, and the SQLite actions a peer's delete relies on.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 'trip-1',
            name: 'Bonaire',
            startDate: 0,
            endDate: 0,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.tripCylinders)
        .insert(
          TripCylindersCompanion.insert(
            id: 'slot-1',
            tripId: 'trip-1',
            label: const Value('Truck 1'),
            volume: const Value(11.1),
            workingPressure: const Value(207.0),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.tripCylinderEvents)
        .insert(
          TripCylinderEventsCompanion.insert(
            id: 'fill-1',
            tripCylinderId: 'slot-1',
            kind: 'fill',
            occurredAt: 1000,
            bottleLabel: const Value('14'),
            pressure: const Value(200.0),
            o2Percent: const Value(32.0),
            analyzedO2: const Value(31.6),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('tripCylinders export, fetch, upsert, and delete round-trip', () async {
    final record = await serializer.fetchRecord('tripCylinders', 'slot-1');
    expect(record, isNotNull);
    expect(record!['label'], 'Truck 1');
    expect(record['volume'], 11.1);

    await serializer.upsertRecord('tripCylinders', {
      ...record,
      'label': 'Truck A',
      'updatedAt': 2,
    });
    final merged = await serializer.fetchRecord('tripCylinders', 'slot-1');
    expect(merged!['label'], 'Truck A');

    expect(await serializer.recordIdsFor('tripCylinders'), contains('slot-1'));

    await serializer.deleteRecord('tripCylinders', 'slot-1');
    expect(await serializer.fetchRecord('tripCylinders', 'slot-1'), isNull);
  });

  test(
    'tripCylinderEvents export, fetch, upsert, and delete round-trip',
    () async {
      final record = await serializer.fetchRecord(
        'tripCylinderEvents',
        'fill-1',
      );
      expect(record, isNotNull);
      expect(record!['kind'], 'fill');
      expect(record['analyzedO2'], 31.6);
      expect(record['bottleLabel'], '14');

      await serializer.upsertRecord('tripCylinderEvents', {
        ...record,
        'analyzedO2': 31.8,
        'updatedAt': 2,
      });
      final merged = await serializer.fetchRecord(
        'tripCylinderEvents',
        'fill-1',
      );
      expect(merged!['analyzedO2'], 31.8);

      expect(
        await serializer.recordIdsFor('tripCylinderEvents'),
        contains('fill-1'),
      );

      await serializer.deleteRecord('tripCylinderEvents', 'fill-1');
      expect(
        await serializer.fetchRecord('tripCylinderEvents', 'fill-1'),
        isNull,
      );
    },
  );

  test(
    'a peer row with the columns this build knows applies without the rest',
    () async {
      // A 228 peer sends every column; the merge fills NOT NULL defaults for
      // any it leaves out (_withSchemaDefaults), so a minimal record applies.
      await serializer.upsertRecord('tripCylinders', {
        'id': 'slot-2',
        'tripId': 'trip-1',
        'createdAt': 3,
        'updatedAt': 3,
      });
      final row = await (db.select(
        db.tripCylinders,
      )..where((t) => t.id.equals('slot-2'))).getSingle();
      expect(row.label, '');
      expect(row.sortOrder, 0);
      expect(row.notes, '');
    },
  );

  test('the delta export filters on each row own hlc', () async {
    await (db.update(
      db.tripCylinders,
    )..where((t) => t.id.equals('slot-1'))).write(
      const TripCylindersCompanion(hlc: Value('2026-08-16T00:00:00.000-0000')),
    );
    await (db.update(
      db.tripCylinderEvents,
    )..where((t) => t.id.equals('fill-1'))).write(
      const TripCylinderEventsCompanion(
        hlc: Value('2026-08-16T00:00:00.000-0000'),
      ),
    );

    Future<(int, int)> counts(String? watermark) async {
      final payload = await serializer.exportChangeset(
        deviceId: 'device-1',
        hlcWatermark: watermark,
        deletions: const [],
      );
      return (
        payload.data.tripCylinders.length,
        payload.data.tripCylinderEvents.length,
      );
    }

    expect(await counts(null), (1, 1));
    expect(await counts('2026-08-17T00:00:00.000-0000'), (0, 0));
    expect(await counts('2026-08-15T00:00:00.000-0000'), (1, 1));
  });

  test(
    'deleting a slot record cascades its ledger and clears tank links',
    () async {
      // What a peer's tombstone does on arrival: SQLite's own actions.
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'd1',
              diveDateTime: 2000,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(
              id: 't1',
              diveId: 'd1',
            ).copyWith(tripCylinderId: const Value('slot-1')),
          );

      await serializer.deleteRecord('tripCylinders', 'slot-1');

      expect(
        await serializer.fetchRecord('tripCylinderEvents', 'fill-1'),
        isNull,
      );
      final tank = await db
          .customSelect(
            'SELECT trip_cylinder_id FROM dive_tanks WHERE id = ?',
            variables: [const Variable<String>('t1')],
          )
          .getSingle();
      expect(tank.readNullable<String>('trip_cylinder_id'), isNull);
    },
  );

  test('a peer trip tombstone that names no slots still applies', () async {
    // An older peer deletes the trip without knowing its slots exist, so no
    // slot or fill tombstone arrives. The remote apply runs in a deferred-FK
    // transaction and repairs the orphans, as it does for every trip child.
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: 2000,
            tripId: const Value('trip-1'),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 't1',
            diveId: 'd1',
          ).copyWith(tripCylinderId: const Value('slot-1')),
        );

    await serializer.applyInDeferredFkTransaction(() async {
      await serializer.deleteRecord('trips', 'trip-1');
      await serializer.repairDanglingForeignKeys();
    });

    expect(await serializer.fetchRecord('trips', 'trip-1'), isNull);
    expect(await serializer.fetchRecord('tripCylinders', 'slot-1'), isNull);
    expect(
      await serializer.fetchRecord('tripCylinderEvents', 'fill-1'),
      isNull,
    );
    final tank = await db
        .customSelect("SELECT trip_cylinder_id FROM dive_tanks WHERE id = 't1'")
        .getSingle();
    expect(tank.readNullable<String>('trip_cylinder_id'), isNull);
  });

  test('both entities are registered as hlc targets', () {
    // An omission here is silent: _stampHlc no-ops on an unknown entity
    // type, the column stays NULL, and the delta export excludes the row
    // from every changeset forever.
    expect(SyncRepository.hlcTargets['tripCylinders']!.table, 'trip_cylinders');
    expect(
      SyncRepository.hlcTargets['tripCylinderEvents']!.table,
      'trip_cylinder_events',
    );
  });

  test('both entities carry an updatedAt flag and their parent refs', () {
    expect(SyncService.entityHasUpdatedAt['tripCylinders'], isTrue);
    expect(SyncService.entityHasUpdatedAt['tripCylinderEvents'], isTrue);

    final slotRefs = SyncService.parentRefs['tripCylinders']!;
    expect(
      slotRefs,
      containsAll(const [
        (field: 'tripId', parent: 'trips', nullable: false),
        (field: 'equipmentId', parent: 'equipment', nullable: true),
      ]),
    );
    final eventRefs = SyncService.parentRefs['tripCylinderEvents']!;
    expect(
      eventRefs,
      containsAll(const [
        (field: 'tripCylinderId', parent: 'tripCylinders', nullable: false),
        (field: 'diveCenterId', parent: 'diveCenters', nullable: true),
      ]),
    );
  });
}
