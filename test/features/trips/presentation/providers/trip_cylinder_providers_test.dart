import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DivesCompanion, DiveTanksCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late TripCylinderRepository repository;
  late String tripId;

  final at = DateTime.utc(2026, 3, 9, 8, 0);

  setUp(() async {
    db = await setUpTestDatabase();
    container = ProviderContainer();
    addTearDown(container.dispose);
    repository = TripCylinderRepository();
    final now = DateTime.now();
    tripId = (await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Bonaire',
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 14),
        createdAt: now,
        updatedAt: now,
      ),
    )).id;
  });

  tearDown(tearDownTestDatabase);

  Future<TripCylinder> slot(String label, {int sortOrder = 0}) =>
      repository.createCylinder(
        TripCylinder(
          id: '',
          tripId: tripId,
          label: label,
          workingPressure: 207,
          sortOrder: sortOrder,
          createdAt: at,
          updatedAt: at,
        ),
      );

  Future<void> fill(String cylinderId, {double o2 = 32}) =>
      repository.createEvent(
        TripCylinderEvent(
          id: '',
          tripCylinderId: cylinderId,
          kind: TripCylinderEventKind.fill,
          occurredAt: at,
          pressure: 200,
          o2Percent: o2,
          createdAt: at,
          updatedAt: at,
        ),
      );

  Future<void> diveOn(
    String cylinderId, {
    required int minutesAfter,
    double end = 60,
  }) async {
    final entry = at
        .add(Duration(minutes: minutesAfter))
        .millisecondsSinceEpoch;
    final diveId = 'd$minutesAfter';
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: diveId,
            diveDateTime: entry,
            tripId: Value(tripId),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 't$minutesAfter',
            diveId: diveId,
          ).copyWith(
            tripCylinderId: Value(cylinderId),
            endPressure: Value(end),
          ),
        );
  }

  test('a trip with no slots yields no states and no slots', () async {
    expect(await container.read(tripCylindersProvider(tripId).future), isEmpty);
    expect(
      await container.read(tripCylinderStatesProvider(tripId).future),
      isEmpty,
    );
  });

  test('states come back in board order with the fold applied', () async {
    final b = await slot('B', sortOrder: 1);
    final a = await slot('A');
    await fill(a.id);
    await fill(b.id);
    await diveOn(b.id, minutesAfter: 60);

    final states = await container.read(
      tripCylinderStatesProvider(tripId).future,
    );
    expect(states.map((s) => s.cylinder.label), ['A', 'B']);
    expect(states[0].status, TripCylinderStatus.full);
    expect(states[0].mix!.o2, 32);
    expect(states[1].status, TripCylinderStatus.partial);
    expect(states[1].pressure, 60);
    expect(states[1].linkedDiveCount, 1);
  });

  test('a fill written later refreshes the states', () async {
    final a = await slot('A');
    final before = await container.read(
      tripCylinderStatesProvider(tripId).future,
    );
    expect(before.single.status, TripCylinderStatus.unknown);

    // Keep the provider alive across the write, as a page would.
    final sub = container.listen(tripCylinderStatesProvider(tripId), (_, _) {});
    addTearDown(sub.close);
    await fill(a.id);
    // The tick is a stream; give the invalidation a turn to land.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final after = await container.read(
      tripCylinderStatesProvider(tripId).future,
    );
    expect(after.single.status, TripCylinderStatus.full);
  });

  test('a tank link written straight to dive_tanks refreshes too', () async {
    final a = await slot('A');
    await fill(a.id);
    final sub = container.listen(tripCylinderStatesProvider(tripId), (_, _) {});
    addTearDown(sub.close);
    expect(
      (await container.read(
        tripCylinderStatesProvider(tripId).future,
      )).single.status,
      TripCylinderStatus.full,
    );

    // A sync pull rewrites tank rows without touching the dives row.
    await diveOn(a.id, minutesAfter: 60);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      (await container.read(
        tripCylinderStatesProvider(tripId).future,
      )).single.status,
      TripCylinderStatus.partial,
    );
  });
}
