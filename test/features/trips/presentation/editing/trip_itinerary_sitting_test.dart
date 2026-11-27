import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_itinerary_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';
import '../pages/trip_detail_page_unlock_harness.dart';

/// A trip's itinerary days held in its sitting (issue #4527, phase 3).
void main() {
  ItineraryDay day(
    String id,
    DateTime date, {
    DayType type = DayType.diveDay,
  }) => ItineraryDay(
    id: id,
    tripId: 't1',
    dayNumber: 1,
    date: date,
    dayType: type,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  final june1 = day('i1', DateTime(2030, 6, 1));

  test('missing days follow the working dates and type', () {
    final working = redSea.copyWith(
      endDate: DateTime(2030, 6, 3),
      tripType: TripType.liveaboard,
    );

    final days = withDaysAdded([june1], missingItineraryDays([june1], working));

    expect(
      [for (final d in days) d.date],
      [DateTime(2030, 6, 1), DateTime(2030, 6, 2), DateTime(2030, 6, 3)],
    );
    expect(days.first, june1);
    // A liveaboard's last day is its disembark day.
    expect(days.last.dayType, DayType.disembark);
  });

  test('a day edited twice is one change of the itinerary card', () async {
    final list = tripItineraryDays(FakeItineraryDays([june1]));
    final session = EditSession<Trip>(redSea);
    await list.load(session);

    list.set(
      session,
      withDayEdited(list.current(session)!, june1.copyWith(notes: 'Wreck')),
    );
    list.set(
      session,
      withDayEdited(list.current(session)!, june1.copyWith(notes: 'Reef')),
    );

    expect(session.changedCardIds, {'itineraryDays'});
    expect(list.current(session)!.single.notes, 'Reef');
  });

  test('an edit keeps the sitting day number, not the page one', () {
    final edited = withDayEdited([june1], june1.copyWith(dayNumber: 4));
    expect(edited.single.dayNumber, 1);
  });

  test('new days keep the sitting ids at Save, and a changed day is written '
      'with updateDay, an unchanged one not at all', () async {
    final june2 = day('i2', DateTime(2030, 6, 2));
    final repository = FakeItineraryDays([june1, june2]);
    final list = tripItineraryDays(repository);
    final session = EditSession<Trip>(
      redSea.copyWith(endDate: DateTime(2030, 6, 3)),
    );
    await list.load(session);
    final edited = withDayEdited(
      list.current(session)!,
      june1.copyWith(notes: 'Wreck'),
    );
    final held = withDaysAdded(
      edited,
      missingItineraryDays(edited, session.working),
    );
    list.set(session, held);
    final added = held.last;

    expect(repository.saved, isEmpty);
    await session.runHeldWrites();

    expect(repository.saved.single.id, added.id);
    expect(repository.updated.single.id, 'i1');
    expect(repository.updated.single.notes, 'Wreck');
  });

  test(
    'a generated day for a date stored meanwhile is not written twice',
    () async {
      final repository = FakeItineraryDays([june1]);
      final list = tripItineraryDays(repository);
      final session = EditSession<Trip>(
        redSea.copyWith(endDate: DateTime(2030, 6, 3)),
      );
      await list.load(session);
      final held = list.current(session)!;
      list.set(
        session,
        withDaysAdded(held, missingItineraryDays(held, session.working)),
      );
      // Another device adds 2 June before the Save.
      repository.days.add(day('other', DateTime(2030, 6, 2)));

      await session.runHeldWrites();

      expect(
        [for (final d in repository.saved) d.date],
        [DateTime(2030, 6, 3)],
      );
    },
  );

  test('days added twice for the same dates are kept once a date', () {
    final working = redSea.copyWith(endDate: DateTime(2030, 6, 3));
    final first = missingItineraryDays([june1], working);
    final second = missingItineraryDays([june1], working);

    final days = withDaysAdded(withDaysAdded([june1], first), second);

    expect(
      [for (final d in days) d.date],
      [DateTime(2030, 6, 1), DateTime(2030, 6, 2), DateTime(2030, 6, 3)],
    );
    expect(withDaysAdded([june1], [...first, ...second]), hasLength(3));
  });

  group('withPlannedDives, as the board strip sets a day (plan 10)', () {
    var n = 0;
    String newId() => 'n${n++}';
    final now = DateTime(2026);

    test('every day of the date takes the plan', () {
      final twin = day('i2', DateTime(2030, 6, 1, 12));
      final days = withPlannedDives(
        [june1, twin],
        redSea,
        DateTime(2030, 6, 1, 18),
        3,
        newId: newId,
        now: now,
      );
      expect([for (final d in days) d.plannedDives], [3, 3]);
    });

    test('0 makes a dive day a rest day, and a plan makes it a dive day '
        'again; other types keep', () {
      final port = day('p', DateTime(2030, 6, 2), type: DayType.portDay);
      final rested = withPlannedDives(
        [june1, port],
        redSea,
        DateTime(2030, 6, 1),
        0,
        newId: newId,
        now: now,
      );
      expect(rested.first.dayType, DayType.rest);
      final again = withPlannedDives(
        rested,
        redSea,
        DateTime(2030, 6, 1),
        null,
        newId: newId,
        now: now,
      );
      expect(again.first.dayType, DayType.diveDay);
      expect(again.first.plannedDives, isNull);
      final portPlanned = withPlannedDives(
        rested,
        redSea,
        DateTime(2030, 6, 2),
        0,
        newId: newId,
        now: now,
      );
      expect(portPlanned.last.dayType, DayType.portDay);
    });

    test('a date with no day gets one numbered from the start; none for a '
        'null plan', () {
      n = 0;
      final added = withPlannedDives(
        [june1],
        redSea,
        DateTime(2030, 6, 3),
        2,
        newId: newId,
        now: now,
      );
      expect(added.last.id, 'n0');
      expect(added.last.dayNumber, 3);
      expect(added.last.dayType, DayType.diveDay);
      expect(added.last.plannedDives, 2);
      expect(
        withPlannedDives(
          [june1],
          redSea,
          DateTime(2030, 6, 3),
          null,
          newId: newId,
          now: now,
        ),
        [june1],
      );
      final rest = withPlannedDives(
        const [],
        redSea,
        DateTime(2030, 6, 2),
        0,
        newId: newId,
        now: now,
      );
      expect(rest.single.dayType, DayType.rest);
    });
  });

  group('withPlannedDives on a real database', () {
    setUp(() async {
      final db = await setUpTestDatabase();
      await db.customStatement('PRAGMA foreign_keys = OFF');
      await TripRepository(
        itineraryDays: ItineraryDayRepository(),
      ).createTrip(redSea);
    });
    tearDown(tearDownTestDatabase);

    test('matches setPlannedDives', () async {
      final repository = ItineraryDayRepository();
      await repository.saveAll([june1]);
      var n = 0;
      var held = await repository.getByTripId('t1');
      for (final (date, planned) in [
        (DateTime(2030, 6, 1), 0),
        (DateTime(2030, 6, 1), 2),
        (DateTime(2030, 6, 3), 0),
        (DateTime(2030, 6, 4), null),
      ]) {
        held = withPlannedDives(
          held,
          redSea,
          date,
          planned,
          newId: () => 'n${n++}',
          now: DateTime(2026),
        );
        await repository.setPlannedDives(
          tripId: 't1',
          date: date,
          plannedDives: planned,
        );
      }
      final stored = await repository.getByTripId('t1');
      String shape(ItineraryDay d) =>
          '${d.date} ${d.dayNumber} ${d.dayType.name} ${d.plannedDives}';
      expect(
        [for (final d in held) shape(d)],
        [for (final d in stored) shape(d)],
      );
    });
  });
}
