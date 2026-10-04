import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DiversCompanion, DivesCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/presentation/providers/trip_fill_forecast_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late TripCylinderRepository cylinders;
  late String tripId;

  // 09:00 local on the trip's third day.
  final now = DateTime(2026, 3, 10, 9);

  setUp(() async {
    db = await setUpTestDatabase();
    container = ProviderContainer();
    addTearDown(container.dispose);
    cylinders = TripCylinderRepository();
    tripId = (await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Bonaire',
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 14),
        diversSharingCylinders: 2,
        divesPerDayTarget: 2,
        createdAt: now,
        updatedAt: now,
      ),
    )).id;
  });

  tearDown(tearDownTestDatabase);

  Future<void> fullSlots(int count, {String? centerId}) async {
    final at = DateTime.utc(2026, 3, 9, 18);
    for (var i = 0; i < count; i++) {
      final slot = await cylinders.createCylinder(
        TripCylinder(
          id: '',
          tripId: tripId,
          label: 'Truck ${i + 1}',
          workingPressure: 207,
          sortOrder: i,
          createdAt: at,
          updatedAt: at,
        ),
      );
      await cylinders.createEvent(
        TripCylinderEvent(
          id: '',
          tripCylinderId: slot.id,
          kind: TripCylinderEventKind.fill,
          occurredAt: at,
          pressure: 200,
          o2Percent: 32,
          diveCenterId: centerId,
          createdAt: at,
          updatedAt: at,
        ),
      );
    }
  }

  Future<void> diveAt(
    String id,
    DateTime wallClock, {
    String? diver,
    bool planned = false,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: wallClock.millisecondsSinceEpoch,
          tripId: Value(tripId),
          diverId: Value(diver),
          createdAt: 1,
          updatedAt: 1,
        ).copyWith(isPlanned: Value(planned)),
      );

  Future<T> at<T>(DateTime instant, Future<T> Function() body) =>
      withClock(Clock.fixed(instant), body);

  test(
    'gathers the trip, slots, today\'s dives and the fill station',
    () async {
      final center = await DiveCenterRepository().createDiveCenter(
        DiveCenter(
          id: '',
          name: 'Dive Friends',
          fillOpensAt: 480,
          fillClosesAt: 1020,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await fullSlots(3, centerId: center.id);
      await diveAt('today', DateTime.utc(2026, 3, 10, 8));
      await diveAt('yesterday', DateTime.utc(2026, 3, 9, 10));

      final f = (await at(
        now,
        () => container.read(tripFillForecastProvider(tripId).future),
      ))!;
      // Two a day (the trip's target), 2 divers. Today: 1 dive left is 2
      // cylinders; tomorrow 4. Three full leave 1 for tomorrow: 3 short.
      expect(f.fullCount, 3);
      expect(f.todayDemand, 2);
      expect(f.tomorrowDemand, 4);
      expect(f.tomorrowSupply, 1);
      expect(f.tomorrowShortfall, 3);
      expect(f.deadlineMinutes, 1020);
      expect(f.days, hasLength(5));
      // Today 2, then Mar 11 to 14 at 4 each.
      expect(f.remainingDemand, 18);
    },
  );

  test('a blank day needs nothing, however busy past trips were', () async {
    // Issue #2903: a past trip of three dives a day, and a trip with no
    // target whose only plan is one dive tomorrow. Today needs nothing.
    final past = (await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Cozumel',
        startDate: DateTime(2026, 1, 5),
        endDate: DateTime(2026, 1, 6),
        createdAt: now,
        updatedAt: now,
      ),
    )).id;
    for (final (i, hour) in [8, 11, 14].indexed) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'past$i',
              diveDateTime: DateTime.utc(
                2026,
                1,
                5,
                hour,
              ).millisecondsSinceEpoch,
              tripId: Value(past),
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    final trip = (await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Liveaboard',
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 14),
        createdAt: now,
        updatedAt: now,
      ),
    )).id;
    tripId = trip;
    await fullSlots(2);
    await ItineraryDayRepository().setPlannedDives(
      tripId: trip,
      date: DateTime(2026, 3, 11),
      plannedDives: 1,
    );

    final f = (await at(
      now,
      () => container.read(tripFillForecastProvider(trip).future),
    ))!;
    expect(f.todayDemand, 0);
    expect(f.tomorrowDemand, 1);
    expect([for (final d in f.days) d.plannedDives], [0, 1, 0, 0, 0]);
  });

  test('an ended trip has no forecast', () async {
    await fullSlots(2);
    expect(
      await at(
        DateTime(2026, 3, 15, 9),
        () => container.read(tripFillForecastProvider(tripId).future),
      ),
      isNull,
    );
  });

  test('a trip with no slots has no forecast', () async {
    expect(
      await at(
        now,
        () => container.read(tripFillForecastProvider(tripId).future),
      ),
      isNull,
    );
  });

  test('dives count by their wall-clock day', () async {
    await diveAt('late', DateTime.utc(2026, 3, 10, 23, 30));
    await diveAt('after-midnight', DateTime.utc(2026, 3, 11, 0, 10));
    await diveAt('early', DateTime.utc(2026, 3, 10, 0, 5));
    expect(
      await cylinders.countTripDiveRoundsOn(tripId, DateTime(2026, 3, 10)),
      2,
    );
    expect(
      await cylinders.countTripDiveRoundsOn(tripId, DateTime(2026, 3, 11)),
      1,
    );
  });

  test('a planned dive is not a dive already logged today', () async {
    // Issue #2660: a dive planned for this afternoon has used no gas yet,
    // so it must not lower today's remaining demand.
    await diveAt('morning', DateTime.utc(2026, 3, 10, 8));
    await diveAt('afternoon', DateTime.utc(2026, 3, 10, 14), planned: true);
    expect(
      await cylinders.countTripDiveRoundsOn(tripId, DateTime(2026, 3, 10)),
      1,
    );
  });

  test('two divers logging the same dives count one round each', () async {
    // A shared trip, two diver profiles: both log the morning dive, one
    // logs the midday dive too. Two rounds are done today, not three, so
    // the forecast does not free a bottle per profile.
    for (final id in ['a', 'b']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: 'Diver $id',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    await diveAt('a1', DateTime.utc(2026, 3, 10, 8), diver: 'a');
    await diveAt('b1', DateTime.utc(2026, 3, 10, 8, 5), diver: 'b');
    await diveAt('a2', DateTime.utc(2026, 3, 10, 11), diver: 'a');
    expect(
      await cylinders.countTripDiveRoundsOn(tripId, DateTime(2026, 3, 10)),
      2,
    );
  });

  test('the forecast rebuilds itself when its deadline arrives', () async {
    final center = await DiveCenterRepository().createDiveCenter(
      DiveCenter(
        id: '',
        name: 'Dive Friends',
        fillOpensAt: 480,
        fillClosesAt: 1020,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await fullSlots(1, centerId: center.id);
    // A tenth of a second before closing, so the tick is due at 17:00.
    final almost = DateTime(2026, 3, 10, 16, 59, 59, 900);
    await at(almost, () async {
      var settled = 0;
      final sub = container.listen(tripFillForecastProvider(tripId), (_, next) {
        if (next.hasValue && !next.isLoading) settled++;
      });
      addTearDown(sub.close);
      await container.read(tripFillForecastProvider(tripId).future);
      final before = settled;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(settled, greaterThan(before));
    });
  });
}
