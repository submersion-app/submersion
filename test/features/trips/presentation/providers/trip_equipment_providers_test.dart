import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Trip;
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_equipment_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';

import '../../../../helpers/test_database.dart';

/// A trip's gear and an item's trips (issue #2338).
void main() {
  group('rankPackedTrips', () {
    final now = DateTime(2026, 10, 1);
    PackedTrip at(String id, DateTime start, DateTime end) => PackedTrip(
      trip: Trip(
        id: id,
        name: id,
        startDate: start,
        endDate: end,
        createdAt: now,
        updatedAt: now,
      ),
      packed: true,
      slot: false,
    );

    test('in progress, then upcoming by start, then past by recent end', () {
      final ranked = rankPackedTrips([
        at('old', DateTime(2026, 1, 1), DateTime(2026, 1, 5)),
        at('later', DateTime(2026, 12, 1), DateTime(2026, 12, 5)),
        at('recent', DateTime(2026, 8, 1), DateTime(2026, 8, 5)),
        at('now', DateTime(2026, 9, 29), DateTime(2026, 10, 3)),
        at('soon', DateTime(2026, 10, 10), DateTime(2026, 10, 12)),
      ], now);
      expect(ranked.map((p) => p.trip.id), [
        'now',
        'soon',
        'later',
        'recent',
        'old',
      ]);
    });
  });

  group('providers', () {
    late AppDatabase db;
    late ProviderContainer container;
    final t = DateTime(2026, 10, 1).millisecondsSinceEpoch;

    Future<void> trip(String id, String diverId) => db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: id,
            name: id,
            startDate: t,
            endDate: t,
            createdAt: t,
            updatedAt: t,
            diverId: Value(diverId),
          ),
        );

    Future<void> item(String id, String diverId) => db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: 'tank',
            createdAt: t,
            updatedAt: t,
            diverId: Value(diverId),
          ),
        );

    setUp(() async {
      db = await setUpTestDatabase();
      for (final d in ['me', 'other']) {
        await db
            .into(db.divers)
            .insert(
              DiversCompanion.insert(
                id: d,
                name: d,
                createdAt: t,
                updatedAt: t,
              ),
            );
      }
      await trip('t1', 'me');
      await trip('t2', 'me');
      await trip('theirs', 'other');
      await item('Zeagle', 'me');
      await item('Apeks', 'me');
      await item('reg', 'other');
      container = ProviderContainer(
        overrides: [
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
        ],
      );
      addTearDown(container.dispose);
    });

    tearDown(tearDownTestDatabase);

    Future<T> read<T>(FutureProvider<T> provider) async {
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      return container.read(provider.future);
    }

    test("tripGearProvider lists the trip's visible gear by name", () async {
      await TripEquipmentRepository().pack('t1', ['Zeagle', 'Apeks']);
      final gear = await read(tripGearProvider('t1'));
      expect(gear.map((e) => e.name), ['Apeks', 'Zeagle']);
    });

    test('gear the diver cannot see is left off', () async {
      await TripEquipmentRepository().pack('t1', ['Apeks', 'reg']);
      final gear = await read(tripGearProvider('t1'));
      expect(gear.map((e) => e.id), ['Apeks']);
    });

    test('a revoked share takes the item off the trip', () async {
      await db
          .into(db.equipmentShares)
          .insert(
            EquipmentSharesCompanion.insert(
              id: 'share',
              equipmentId: 'reg',
              diverId: 'me',
              createdAt: t,
            ),
          );
      await TripEquipmentRepository().pack('t1', ['reg']);
      expect((await read(tripGearProvider('t1'))).map((e) => e.id), ['reg']);
      // The owner revokes the share: only equipment_shares changes.
      await (db.delete(
        db.equipmentShares,
      )..where((s) => s.id.equals('share'))).go();
      await Future<void>.delayed(Duration.zero);
      expect(await container.read(tripGearProvider('t1').future), isEmpty);
    });

    test('equipmentTripsProvider unions packed links and slots', () async {
      await TripEquipmentRepository().pack('t1', ['Apeks']);
      await db
          .into(db.tripCylinders)
          .insert(
            TripCylindersCompanion.insert(
              id: 'slot',
              tripId: 't2',
              createdAt: t,
              updatedAt: t,
            ).copyWith(equipmentId: const Value('Apeks')),
          );
      final trips = await read(equipmentTripsProvider('Apeks'));
      final byId = {for (final p in trips) p.trip.id: p};
      expect(byId.keys.toSet(), {'t1', 't2'});
      expect((byId['t1']!.packed, byId['t1']!.slot), (true, false));
      expect((byId['t2']!.packed, byId['t2']!.slot), (false, true));
    });

    test('a trip the diver cannot see is left off', () async {
      await db
          .into(db.tripCylinders)
          .insert(
            TripCylindersCompanion.insert(
              id: 'slot',
              tripId: 'theirs',
              createdAt: t,
              updatedAt: t,
            ).copyWith(equipmentId: const Value('Apeks')),
          );
      expect(await read(equipmentTripsProvider('Apeks')), isEmpty);
    });
  });
}
