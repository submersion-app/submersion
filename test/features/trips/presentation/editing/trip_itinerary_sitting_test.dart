import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_itinerary_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

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
}
