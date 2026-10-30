import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DivesCompanion, DiveTanksCompanion;
import 'package:submersion/features/dive_log/data/repositories/trip_cylinder_links.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';

import '../../../../helpers/test_database.dart';

/// A side trip's dives share the larger trip's cylinders, and the larger
/// trip's board counts that usage (issue #3658).
void main() {
  late AppDatabase db;
  late TripRepository trips;
  late TripCylinderRepository cylinders;
  late Trip parent;
  late Trip side;
  late String slotX;
  late String slotY;

  final at = DateTime.utc(2026, 3, 9, 8, 0);

  Trip trip(String name, {String? parentTripId}) {
    final now = DateTime.now();
    return Trip(
      id: '',
      name: name,
      startDate: DateTime(2026, 3, 2),
      endDate: DateTime(2026, 3, 16),
      parentTripId: parentTripId,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<String> slot(String tripId, String label) async =>
      (await cylinders.createCylinder(
        TripCylinder(
          id: '',
          tripId: tripId,
          label: label,
          createdAt: at,
          updatedAt: at,
        ),
      )).id;

  Future<void> diveWithTank(
    String diveId,
    String tankId, {
    required String tripId,
    required String cylinderId,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: diveId,
            diveDateTime: at.millisecondsSinceEpoch,
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
            startPressure: const Value(200.0),
            endPressure: const Value(60.0),
          ),
        );
  }

  Future<String?> linkOf(String tankId) async =>
      (await db
              .customSelect(
                'SELECT trip_cylinder_id FROM dive_tanks WHERE id = ?',
                variables: [Variable<String>(tankId)],
              )
              .getSingle())
          .readNullable<String>('trip_cylinder_id');

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

  setUp(() async {
    db = await setUpTestDatabase();
    trips = TripRepository();
    cylinders = TripCylinderRepository();
    parent = await trips.createTrip(trip('Indonesia'));
    side = await trips.createTrip(trip('Raja Ampat', parentTripId: parent.id));
    slotX = await slot(parent.id, 'X');
    slotY = await slot(side.id, 'Y');
  });
  tearDown(tearDownTestDatabase);

  test('moving a dive into a side trip keeps its larger trip link', () async {
    await diveWithTank('d1', 't1', tripId: parent.id, cylinderId: slotX);
    await trips.assignDivesToTrip(['d1'], side.id);
    expect(await linkOf('t1'), slotX);
  });

  test('a side trip may link its own and its parent slots', () async {
    expect(await tripCylinderIdsForTrip(db, side.id), {slotX, slotY});
    expect(await tripCylinderIdsForTrip(db, parent.id), {slotX});
    expect(await cylinders.linkableTripIds(side.id), [side.id, parent.id]);
    expect(await cylinders.linkableTripIds(parent.id), [parent.id]);
  });

  test('the larger trip board and record count side-trip usage', () async {
    await diveWithTank('d1', 't1', tripId: side.id, cylinderId: slotX);
    final uses = await cylinders.getTankUsesForTrip(parent.id);
    expect(uses[slotX]!.map((u) => u.tankId), ['t1']);
    final record = await cylinders.getGasRecordTanksForTrip(parent.id);
    expect(record.map((t) => t.tankId), ['t1']);
    expect(await cylinders.countTripDiveRoundsOn(parent.id, at), 1);
  });

  test('a tank on the parent slot is no gap on the side trip', () async {
    await diveWithTank('d1', 't1', tripId: side.id, cylinderId: slotX);
    expect(await cylinders.getUnlinkedTanksForTrip(side.id), isEmpty);
  });

  test('detaching the side trip drops its parent-slot links', () async {
    await diveWithTank('d1', 't1', tripId: side.id, cylinderId: slotX);
    await diveWithTank('d2', 't2', tripId: side.id, cylinderId: slotY);
    await trips.updateTrip(side.copyWith(parentTripId: null));
    expect(await linkOf('t1'), isNull);
    expect(await pendingCountFor('diveTanks', 't1'), 1);
    expect(await linkOf('t2'), slotY);
  });

  test("the larger trip's gaps take in side-trip tanks on no slot", () async {
    await diveWithTank('d1', 't1', tripId: side.id, cylinderId: slotY);
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd2',
            diveDateTime: at.millisecondsSinceEpoch,
            tripId: Value(side.id),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 't2', diveId: 'd2'));
    final gaps = await cylinders.getUnlinkedTanksForTrip(parent.id);
    // t1 breathes from the liveaboard's own slot: accounted for. t2 from
    // none: a gap the larger trip's record shows.
    expect(gaps.map((g) => g.tankId), ['t2']);
  });
}
