import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DivesCompanion, DiveTanksCompanion;
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TripCylinderRepository repository;
  late String tripId;
  late String otherTripId;

  final at = DateTime.utc(2026, 3, 9, 8, 0);

  Trip trip(String name) {
    final now = DateTime.now();
    return Trip(
      id: '',
      name: name,
      startDate: DateTime(2026, 3, 8),
      endDate: DateTime(2026, 3, 14),
      createdAt: now,
      updatedAt: now,
    );
  }

  TripCylinder slot({String label = 'Truck 1', int sortOrder = 0}) =>
      TripCylinder(
        id: '',
        tripId: tripId,
        label: label,
        volume: 11.1,
        workingPressure: 207,
        material: TankMaterial.aluminum,
        presetName: 'al80',
        sortOrder: sortOrder,
        createdAt: at,
        updatedAt: at,
      );

  TripCylinderEvent fill(String cylinderId, {DateTime? when, String? kind}) =>
      TripCylinderEvent(
        id: '',
        tripCylinderId: cylinderId,
        kind: TripCylinderEventKind.fill,
        occurredAt: when ?? at,
        bottleLabel: '14',
        pressure: 200,
        o2Percent: 32,
        analyzedO2: 31.6,
        cost: 12.5,
        currency: 'USD',
        createdAt: at,
        updatedAt: at,
      );

  Future<int> pendingCountFor(String entityType, String recordId) async {
    final row = await db
        .customSelect(
          "SELECT COUNT(*) AS n FROM sync_records WHERE entity_type = ? "
          "AND record_id = ? AND sync_status = 'pending'",
          variables: [Variable<String>(entityType), Variable<String>(recordId)],
        )
        .getSingle();
    return row.read<int>('n');
  }

  Future<int> tombstonesFor(String entityType, String recordId) async {
    final row = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM deletion_log '
          'WHERE entity_type = ? AND record_id = ?',
          variables: [Variable<String>(entityType), Variable<String>(recordId)],
        )
        .getSingle();
    return row.read<int>('n');
  }

  Future<void> insertDiveWithTank({
    required String diveId,
    required String tankId,
    required int entryMillis,
    required String cylinderId,
    double? start,
    double? end,
    double o2 = 32,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: diveId,
            diveDateTime: entryMillis,
            tripId: Value(tripId),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(id: tankId, diveId: diveId).copyWith(
            tripCylinderId: Value(cylinderId),
            startPressure: Value(start),
            endPressure: Value(end),
            o2Percent: Value(o2),
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    repository = TripCylinderRepository();
    final trips = TripRepository();
    tripId = (await trips.createTrip(trip('Bonaire'))).id;
    otherTripId = (await trips.createTrip(trip('Curacao'))).id;
  });

  tearDown(tearDownTestDatabase);

  group('slots', () {
    test(
      'create mints an id, stages the row and reads back in board order',
      () async {
        final second = await repository.createCylinder(
          slot(label: 'Truck 2', sortOrder: 1),
        );
        final first = await repository.createCylinder(slot(label: 'Truck 1'));

        expect(first.id, isNotEmpty);
        expect(await pendingCountFor('tripCylinders', first.id), 1);

        final listed = await repository.getCylindersForTrip(tripId);
        expect(listed.map((c) => c.label), ['Truck 1', 'Truck 2']);
        expect(listed.first.volume, 11.1);
        expect(listed.first.material, TankMaterial.aluminum);
        expect(listed.first.presetName, 'al80');
        expect(second.tripId, tripId);
        expect(await repository.getCylindersForTrip(otherTripId), isEmpty);
      },
    );

    test('update rewrites the editable columns', () async {
      final created = await repository.createCylinder(slot());
      await repository.updateCylinder(
        created.copyWith(label: 'Truck A', volume: 12.2, notes: 'DIN valve'),
      );
      final read = await repository.getCylinderById(created.id);
      expect(read!.label, 'Truck A');
      expect(read.volume, 12.2);
      expect(read.notes, 'DIN valve');
      expect(read.workingPressure, 207);
    });

    test('an unknown stored material reads as null, never a throw', () async {
      final created = await repository.createCylinder(slot());
      await db.customUpdate(
        "UPDATE trip_cylinders SET material = 'titanium' WHERE id = ?",
        variables: [Variable<String>(created.id)],
      );
      final read = await repository.getCylinderById(created.id);
      expect(read!.material, isNull);
    });

    test(
      'delete tombstones the slot and its ledger and clears tank links',
      () async {
        final created = await repository.createCylinder(slot());
        final event = await repository.createEvent(fill(created.id));
        await insertDiveWithTank(
          diveId: 'd1',
          tankId: 't1',
          entryMillis: at.millisecondsSinceEpoch + 3600000,
          cylinderId: created.id,
          start: 200,
          end: 60,
        );

        await repository.deleteCylinder(created.id);

        expect(await repository.getCylinderById(created.id), isNull);
        expect(await repository.getEventsForCylinder(created.id), isEmpty);
        expect(await tombstonesFor('tripCylinders', created.id), 1);
        expect(await tombstonesFor('tripCylinderEvents', event.id), 1);

        // The tank keeps everything but the link, and is staged so a peer
        // learns of the cleared link rather than relying on its own cascade.
        final tank = await db
            .customSelect(
              'SELECT trip_cylinder_id, end_pressure, o2_percent '
              "FROM dive_tanks WHERE id = 't1'",
            )
            .getSingle();
        expect(tank.readNullable<String>('trip_cylinder_id'), isNull);
        expect(tank.read<double>('end_pressure'), 60);
        expect(tank.read<double>('o2_percent'), 32);
        expect(await pendingCountFor('diveTanks', 't1'), 1);
      },
    );

    test('deleteByTripId removes only that trip slots', () async {
      await repository.createCylinder(slot());
      await repository.createCylinder(
        slot().copyWith(tripId: otherTripId, label: 'Other'),
      );

      await repository.deleteByTripId(tripId);

      expect(await repository.getCylindersForTrip(tripId), isEmpty);
      expect(await repository.getCylindersForTrip(otherTripId), hasLength(1));
    });
  });

  group('events', () {
    test(
      'create, read grouped by slot in time order, update, delete',
      () async {
        final a = await repository.createCylinder(slot(label: 'A'));
        final b = await repository.createCylinder(
          slot(label: 'B', sortOrder: 1),
        );
        final later = await repository.createEvent(
          fill(a.id, when: at.add(const Duration(hours: 5))),
        );
        final earlier = await repository.createEvent(fill(a.id));
        await repository.createEvent(fill(b.id));

        expect(await pendingCountFor('tripCylinderEvents', earlier.id), 1);

        final grouped = await repository.getEventsForTrip(tripId);
        expect(grouped.keys, containsAll([a.id, b.id]));
        expect(grouped[a.id]!.map((e) => e.id), [earlier.id, later.id]);
        expect(grouped[a.id]!.first.analyzedO2, 31.6);
        expect(grouped[a.id]!.first.cost, 12.5);
        expect(grouped[a.id]!.first.currency, 'USD');
        expect(grouped[a.id]!.first.occurredAt, at);
        expect(grouped[a.id]!.first.occurredAt.isUtc, isTrue);

        await repository.updateEvent(
          later.copyWith(analyzedO2: 31.9, note: 'reanalyzed'),
        );
        final forA = await repository.getEventsForCylinder(a.id);
        expect(forA.last.analyzedO2, 31.9);
        expect(forA.last.note, 'reanalyzed');

        await repository.deleteEvent(later.id);
        expect(await repository.getEventsForCylinder(a.id), hasLength(1));
        expect(await tombstonesFor('tripCylinderEvents', later.id), 1);
      },
    );

    test('an unknown stored kind reads as an adjustment', () async {
      final a = await repository.createCylinder(slot());
      final e = await repository.createEvent(fill(a.id));
      await db.customUpdate(
        "UPDATE trip_cylinder_events SET kind = 'swap' WHERE id = ?",
        variables: [Variable<String>(e.id)],
      );
      final read = await repository.getEventsForCylinder(a.id);
      expect(read.single.kind, TripCylinderEventKind.adjustment);
      expect(read.single.pressure, 200);
    });

    test('a slot from another trip is not in this trip ledger', () async {
      final other = await repository.createCylinder(
        slot().copyWith(tripId: otherTripId),
      );
      await repository.createEvent(fill(other.id));
      expect(await repository.getEventsForTrip(tripId), isEmpty);
    });
  });

  group('tank uses', () {
    test(
      'returns lean facts per slot in entry order, skipping other trips',
      () async {
        final a = await repository.createCylinder(slot(label: 'A'));
        final other = await repository.createCylinder(
          slot().copyWith(tripId: otherTripId),
        );
        final t0 = at.millisecondsSinceEpoch;
        await insertDiveWithTank(
          diveId: 'd2',
          tankId: 't2',
          entryMillis: t0 + 7200000,
          cylinderId: a.id,
          start: 200,
          end: 70,
          o2: 32,
        );
        await insertDiveWithTank(
          diveId: 'd1',
          tankId: 't1',
          entryMillis: t0 + 3600000,
          cylinderId: a.id,
          start: 200,
          o2: 21,
        );
        await insertDiveWithTank(
          diveId: 'd3',
          tankId: 't3',
          entryMillis: t0,
          cylinderId: other.id,
        );

        final uses = await repository.getTankUsesForTrip(tripId);
        expect(uses.keys, [a.id]);
        final forA = uses[a.id]!;
        expect(forA.map((u) => u.tankId), ['t1', 't2']);
        expect(forA.first.entryTime, DateTime.utc(2026, 3, 9, 9, 0));
        expect(forA.first.entryTime.isUtc, isTrue);
        expect(forA.first.endPressure, isNull);
        expect(forA.first.gasMix, const GasMix());
        expect(forA.last.endPressure, 70);
        expect(forA.last.gasMix.o2, 32);
        expect(forA.last.diveId, 'd2');

        expect(await repository.countLinkedDives(a.id), 2);
        // The other trip's slot has its own linked dive; the count is per slot,
        // not per trip.
        expect(await repository.countLinkedDives(other.id), 1);
      },
    );
  });

  test('the change tick fires on a slot write', () async {
    final fired = repository.watchTripCylinderChanges().first;
    await repository.createCylinder(slot());
    await expectLater(fired, completes);
  });
}
