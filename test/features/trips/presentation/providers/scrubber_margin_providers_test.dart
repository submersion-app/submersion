import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    hide Trip, ServiceRecord;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/scrubber_margin.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/scrubber_margin_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// One margin per active rebreather, computed as of the trip start from
/// the repack record, the loop dives since it, and the diver's history.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = await setUpTestDatabase();
    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
  });
  tearDown(tearDownTestDatabase);

  Future<void> ccrDive(
    String id,
    DateTime at,
    String equipmentId, {
    int runtime = 3600,
    int? bottomTime,
    double? scrubber,
    int summaryStamp = 1,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            // Stored as the app stores dives: the wall clock, in UTC.
            diveDateTime: DateTime.utc(
              at.year,
              at.month,
              at.day,
              at.hour,
              at.minute,
            ).millisecondsSinceEpoch,
            createdAt: 1,
            updatedAt: 1,
          ).copyWith(
            diveMode: const Value('ccr'),
            runtime: Value(runtime),
            bottomTime: Value(bottomTime),
          ),
        );
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: id, equipmentId: equipmentId),
        );
    if (scrubber != null) {
      await db
          .into(db.diveSensorSummaries)
          .insert(
            DiveSensorSummariesCompanion.insert(
              diveId: id,
              engineVersion: 1,
              sourceUpdatedAt: summaryStamp,
              computedAt: 1,
            ).copyWith(scrubberConsumedMinutes: Value(scrubber)),
          );
    }
  }

  Future<Trip> trip(String name, DateTime start, DateTime end) =>
      TripRepository().createTrip(
        Trip(
          id: '',
          name: name,
          startDate: start,
          endDate: end,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );

  test(
    'reads rating, repack, loop dives and history as of the start',
    () async {
      final ccr = await EquipmentRepository().createEquipment(
        const EquipmentItem(
          id: '',
          name: 'CCR',
          type: EquipmentType.rebreather,
          attributes: [
            EquipmentAttribute(
              id: '',
              equipmentId: '',
              key: 'scrubber_duration_h',
              valueNum: 5,
            ),
          ],
        ),
      );
      await ServiceRecordRepository().createRecord(
        ServiceRecord(
          id: '',
          equipmentId: ccr.id,
          serviceCategory: ServiceCategory.values.first,
          serviceKindId: 'scrubber-repack',
          serviceDate: DateTime(2026, 2, 1),
          currency: 'USD',
          notes: '',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      await ccrDive('before', DateTime(2026, 1, 15), ccr.id, scrubber: 30);
      await ccrDive('m1', DateTime(2026, 3, 10), ccr.id, scrubber: 40);
      await ccrDive('m2', DateTime(2026, 3, 20), ccr.id, runtime: 3000);
      final june = await trip(
        'June',
        DateTime(2026, 6, 1),
        DateTime(2026, 6, 5),
      );
      final march = await trip(
        'March',
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 2),
      );

      final margins = await container.read(
        tripScrubberMarginsProvider(june.id).future,
      );
      final m = margins.single;
      expect(m.item.id, ccr.id);
      expect(m.ratedMinutes, 300);
      // 40 from the summary plus 50 minutes of runtime; the January dive
      // predates the repack.
      expect(m.consumedMinutes, 90);
      expect(m.remainingBefore, 210);
      // No earlier trips: 5 calendar days at the default 2 per day.
      expect(m.expectedDives, 10);
      expect(m.expectedDivesN, 0);
      // Summary figures of every rebreather dive before June: 40 and 30.
      expect(m.minutesPerDive, 35);
      expect(m.minutesPerDiveN, 2);
      expect(m.caution, isTrue);

      final past = await container.read(
        tripScrubberMarginsProvider(march.id).future,
      );
      // As of 1 March: nothing consumed since the repack, one history dive.
      expect(past.single.consumedMinutes, 0);
      expect(past.single.minutesPerDive, 30);
      expect(past.single.minutesPerDiveN, 1);
    },
  );

  test('a stale summary gives way to the runtime in the consumed '
      'minutes', () async {
    // A loop dive edited after its summary was built: the stored scrubber
    // minutes describe the dive before the edit, so its runtime counts
    // until the rebuild lands, as the exposure inputs already read it.
    final ccr = await EquipmentRepository().createEquipment(
      const EquipmentItem(
        id: '',
        name: 'CCR',
        type: EquipmentType.rebreather,
        attributes: [
          EquipmentAttribute(
            id: '',
            equipmentId: '',
            key: 'scrubber_duration_h',
            valueNum: 5,
          ),
        ],
      ),
    );
    await ccrDive(
      'edited',
      DateTime(2026, 3, 10),
      ccr.id,
      scrubber: 40,
      summaryStamp: 0,
    );
    final june = await trip('June', DateTime(2026, 6, 1), DateTime(2026, 6, 5));

    final margins = await container.read(
      tripScrubberMarginsProvider(june.id).future,
    );
    expect(margins.single.consumedMinutes, 60);
  });

  test('a repack on the trip start date is the anchor', () async {
    // Service dates come from a date picker, so a repack logged on the
    // day the trip starts is a real case. Excluding it would charge the
    // trip for every loop dive before a scrubber that was just packed.
    final ccr = await EquipmentRepository().createEquipment(
      const EquipmentItem(
        id: '',
        name: 'CCR',
        type: EquipmentType.rebreather,
        attributes: [
          EquipmentAttribute(
            id: '',
            equipmentId: '',
            key: 'scrubber_duration_h',
            valueNum: 5,
          ),
        ],
      ),
    );
    await ServiceRecordRepository().createRecord(
      ServiceRecord(
        id: '',
        equipmentId: ccr.id,
        serviceCategory: ServiceCategory.values.first,
        serviceKindId: 'scrubber-repack',
        serviceDate: DateTime(2026, 2, 1),
        currency: 'USD',
        notes: '',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await ccrDive('older', DateTime(2026, 1, 15), ccr.id, scrubber: 30);
    final sameDay = await trip(
      'SameDay',
      DateTime(2026, 2, 1),
      DateTime(2026, 2, 5),
    );

    final margins = await container.read(
      tripScrubberMarginsProvider(sameDay.id).future,
    );
    // The January dive predates the repack, so nothing is consumed.
    expect(margins.single.consumedMinutes, 0);
    expect(margins.single.remainingBefore, 300);
  });

  Future<EquipmentItem> rebreather() => EquipmentRepository().createEquipment(
    const EquipmentItem(
      id: '',
      name: 'CCR',
      type: EquipmentType.rebreather,
      attributes: [
        EquipmentAttribute(
          id: '',
          equipmentId: '',
          key: 'scrubber_duration_h',
          valueNum: 5,
        ),
      ],
    ),
  );

  test('a repack saved with a time of day on the start date is the '
      'anchor', () async {
    // A new service record starts at DateTime.now() and saves unchanged
    // unless the picker is opened, so a repack logged that morning carries
    // a time after the trip's local midnight. It is still that day's
    // repack.
    final ccr = await rebreather();
    await ServiceRecordRepository().createRecord(
      ServiceRecord(
        id: '',
        equipmentId: ccr.id,
        serviceCategory: ServiceCategory.values.first,
        serviceKindId: 'scrubber-repack',
        serviceDate: DateTime(2026, 2, 1, 10, 37),
        currency: 'USD',
        notes: '',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await ccrDive('older', DateTime(2026, 1, 15), ccr.id, scrubber: 30);
    final t = await trip('Feb', DateTime(2026, 2, 1), DateTime(2026, 2, 5));
    final m = (await container.read(
      tripScrubberMarginsProvider(t.id).future,
    )).single;
    expect(m.consumedMinutes, 0);
    expect(m.consumedSince, DateTime(2026, 2, 1, 10, 37));
  });

  test('a paused repack clock anchors nothing', () async {
    // A paused clock is off for the clocks engine. Its anchor must not
    // exclude the loop dives before it and inflate the margin.
    final ccr = await rebreather();
    Future<ScrubberMargin> margin(bool enabled) async {
      await db.delete(db.serviceSchedules).go();
      await ServiceScheduleRepository().createSchedule(
        ServiceSchedule(
          id: '',
          equipmentId: ccr.id,
          serviceKindId: 'scrubber-repack',
          anchorDate: DateTime(2026, 3, 1, 9),
          enabled: enabled,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      final t = await trip(
        'T$enabled',
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 5),
      );
      return (await container.read(
        tripScrubberMarginsProvider(t.id).future,
      )).single;
    }

    await ccrDive('jan', DateTime(2026, 1, 10), ccr.id);
    await ccrDive('feb', DateTime(2026, 2, 10), ccr.id, runtime: 3000);
    // An active clock anchored that morning excludes both dives.
    final active = await margin(true);
    expect(active.consumedMinutes, 0);
    expect(active.consumedSince, DateTime(2026, 3, 1, 9));
    final paused = await margin(false);
    expect(paused.consumedMinutes, 110);
    expect(paused.consumedSince, isNull);
  });

  test('an itinerary with no dive days expects no dives', () async {
    // A crossing or a port stay is a real itinerary. Only an EMPTY one
    // falls back to the calendar days; this one says no dives.
    await rebreather();
    final t = await trip(
      'Crossing',
      DateTime(2026, 6, 1),
      DateTime(2026, 6, 3),
    );
    await ItineraryDayRepository().saveAll([
      for (var i = 0; i < 3; i++)
        ItineraryDay(
          id: '',
          tripId: t.id,
          dayNumber: i + 1,
          date: DateTime(2026, 6, 1 + i),
          dayType: DayType.seaDay,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
    ]);
    final m = (await container.read(
      tripScrubberMarginsProvider(t.id).future,
    )).single;
    expect(m.expectedDives, 0);
  });

  test('a rating edit reaches an open trip', () async {
    // The rated duration is an attribute; its write reaches
    // equipment_attributes alone.
    final ccr = await rebreather();
    final t = await trip('T', DateTime(2026, 6, 1), DateTime(2026, 6, 5));
    final sub = container.listen(tripScrubberMarginsProvider(t.id), (_, _) {});
    addTearDown(sub.close);
    Future<double?> rated() async => (await container.read(
      tripScrubberMarginsProvider(t.id).future,
    )).single.ratedMinutes;
    expect(await rated(), 300);
    await EquipmentRepository().saveAttributes(ccr.id, [
      EquipmentAttribute(
        id: '',
        equipmentId: ccr.id,
        key: 'scrubber_duration_h',
        valueNum: 6,
      ),
    ]);
    var now = await rated();
    for (var i = 0; i < 50 && now != 360; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      now = await rated();
    }
    expect(now, 360);
  });

  test('a hand-logged zero runtime counts its bottom time', () async {
    // With no summary, a loop dive's runtime stands in for its scrubber
    // minutes; a zero runtime beside a real bottom time is no figure.
    final ccr = await rebreather();
    await ccrDive(
      'manual',
      DateTime(2026, 3, 10),
      ccr.id,
      runtime: 0,
      bottomTime: 2400,
    );
    final t = await trip('June', DateTime(2026, 6, 1), DateTime(2026, 6, 5));
    final m = (await container.read(
      tripScrubberMarginsProvider(t.id).future,
    )).single;
    expect(m.consumedMinutes, 40);
  });

  test('a loop dive counts by the trip calendar day, in any zone', () async {
    // Dives are stored as their wall clock in UTC; the trip start is a
    // local midnight. Compared as instants, a dive the evening before
    // drops out east of UTC and an early one on the first day counts
    // as pre-trip west of it. CI runs in UTC, where both agree; run this
    // under another TZ to see it discriminate.
    final ccr = await rebreather();
    await ccrDive('eve', DateTime.utc(2026, 5, 31, 22), ccr.id);
    await ccrDive('dawn', DateTime.utc(2026, 6, 1, 1), ccr.id);
    final t = await trip('June', DateTime(2026, 6, 1), DateTime(2026, 6, 5));
    final m = (await container.read(
      tripScrubberMarginsProvider(t.id).future,
    )).single;
    expect(m.consumedMinutes, 60);
  });

  test('the repack clock\'s anchor stands in for a missing record', () async {
    // The clocks engine anchors a clock on its newest record, else the
    // schedule's anchor date. With no repack logged, the margin must count
    // from that anchor too, not charge every loop dive the unit ever made.
    final ccr = await EquipmentRepository().createEquipment(
      const EquipmentItem(
        id: '',
        name: 'CCR',
        type: EquipmentType.rebreather,
        attributes: [
          EquipmentAttribute(
            id: '',
            equipmentId: '',
            key: 'scrubber_duration_h',
            valueNum: 5,
          ),
        ],
      ),
    );
    await db.delete(db.serviceSchedules).go();
    await ServiceScheduleRepository().createSchedule(
      ServiceSchedule(
        id: '',
        equipmentId: ccr.id,
        serviceKindId: 'scrubber-repack',
        anchorDate: DateTime(2026, 3, 1),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await ccrDive('feb', DateTime(2026, 2, 10), ccr.id);
    await ccrDive('mar', DateTime(2026, 3, 10), ccr.id, runtime: 3000);

    final june = await trip('June', DateTime(2026, 6, 1), DateTime(2026, 6, 5));
    final m = (await container.read(
      tripScrubberMarginsProvider(june.id).future,
    )).single;
    expect(m.consumedMinutes, 50);
    expect(m.consumedSince, DateTime(2026, 3, 1));

    // An anchor after the trip start is not a baseline as of that start.
    final feb = await trip('Feb', DateTime(2026, 2, 20), DateTime(2026, 2, 22));
    final early = (await container.read(
      tripScrubberMarginsProvider(feb.id).future,
    )).single;
    expect(early.consumedMinutes, 60);
    expect(early.consumedSince, isNull);
  });

  test('with no repack or anchor the purchase date is the baseline', () async {
    // The clocks engine anchors an unrecorded clock on the purchase date
    // (then the creation date); the margin must count from the same
    // point, not charge every loop dive before the unit was bought. No
    // repack is known, so the card still says so.
    final ccr = await EquipmentRepository().createEquipment(
      EquipmentItem(
        id: '',
        name: 'CCR',
        type: EquipmentType.rebreather,
        purchaseDate: DateTime(2026, 3, 1),
        attributes: const [
          EquipmentAttribute(
            id: '',
            equipmentId: '',
            key: 'scrubber_duration_h',
            valueNum: 5,
          ),
        ],
      ),
    );
    await db.delete(db.serviceSchedules).go();
    await ccrDive('feb', DateTime(2026, 2, 10), ccr.id);
    await ccrDive('mar', DateTime(2026, 3, 10), ccr.id, runtime: 3000);

    final june = await trip('June', DateTime(2026, 6, 1), DateTime(2026, 6, 5));
    final m = (await container.read(
      tripScrubberMarginsProvider(june.id).future,
    )).single;
    expect(m.consumedMinutes, 50);
    expect(m.consumedSince, isNull);
  });

  test('a paused repack clock supplies no rating', () async {
    // With no rated duration on the unit, the rating falls back to its
    // scrubber-repack clock. A paused clock is off for the clocks engine,
    // so it must not rate the scrubber either.
    final ccr = await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'CCR', type: EquipmentType.rebreather),
    );
    await db.delete(db.serviceSchedules).go();
    Future<double?> rated(bool enabled) async {
      await db.delete(db.serviceSchedules).go();
      await ServiceScheduleRepository().createSchedule(
        ServiceSchedule(
          id: '',
          equipmentId: ccr.id,
          serviceKindId: 'scrubber-repack',
          intervalHours: 4,
          enabled: enabled,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      final t = await trip(
        'T$enabled',
        DateTime(2026, 6, 1),
        DateTime(2026, 6, 5),
      );
      return (await container.read(
        tripScrubberMarginsProvider(t.id).future,
      )).single.ratedMinutes;
    }

    expect(await rated(true), 240);
    expect(await rated(false), isNull);
  });

  test('a diver with no active rebreather gets an empty list', () async {
    await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    );
    final t = await trip('T', DateTime(2026, 6, 1), DateTime(2026, 6, 5));
    expect(
      await container.read(tripScrubberMarginsProvider(t.id).future),
      isEmpty,
    );
  });

  test('an unknown trip gets an empty list', () async {
    expect(
      await container.read(tripScrubberMarginsProvider('nope').future),
      isEmpty,
    );
  });
}
