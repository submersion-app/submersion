import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';
import 'package:submersion/features/trips/domain/entities/trip_media_preview.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_itinerary_tab.dart';

import 'trip_itinerary_tab_harness.dart';

/// How the itinerary tab's day cards read: plans, a Rest day with a
/// dive, the richer card lines, and which day a dive is listed on.
void main() {
  testWidgets('a day ahead with a plan says how many dives', (tester) async {
    final planned = row('p', DateTime(2026, 3, 9), 4).copyWith(plannedDives: 3);
    await withClock(Clock.fixed(DateTime(2026, 3, 6, 10)), () async {
      await pumpTab(tester, trip: resortTrip(), days: [planned]);
    });
    expect(find.text('3 dives planned'), findsOneWidget);
  });

  testWidgets('a past day reports its plan as progress', (tester) async {
    final past = row('p', DateTime(2026, 3, 7), 2).copyWith(plannedDives: 3);
    final ahead = row('a', DateTime(2026, 3, 9), 4).copyWith(plannedDives: 2);
    await withClock(Clock.fixed(DateTime(2026, 3, 8, 10)), () async {
      await pumpTab(tester, trip: resortTrip(), days: [past, ahead]);
      // The trip is under way, so the tab opens at the next day; the past
      // day is above it.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
      await tester.pumpAndSettle();
    });
    expect(find.text('3 dives planned'), findsNothing);
    expect(find.text('0 of 3 planned dives'), findsOneWidget);
    expect(find.text('2 dives planned'), findsOneWidget);
  });

  // #2875: a dive logged on a day typed Rest makes it a dive day after all,
  // the way the trip story reads a day planned at none.
  group('a Rest day with a logged dive', () {
    final rest = row(
      'r',
      DateTime(2026, 3, 8),
      3,
    ).copyWith(dayType: DayType.rest, plannedDives: 0);

    testWidgets('reads as a Dive Day beside its dives', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 10, 10)), () async {
        await pumpTab(
          tester,
          trip: resortTrip(),
          days: [rest],
          dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
        );
      });
      expect(find.text('Dive Day'), findsOneWidget);
      expect(find.text('Rest'), findsNothing);
      expect(find.byIcon(Icons.scuba_diving), findsOneWidget);
      expect(find.text('1 dive'), findsOneWidget);
    });

    testWidgets('keeps its stored type in the edit sheet', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 10, 10)), () async {
        await pumpTab(
          tester,
          trip: resortTrip(),
          days: [rest],
          dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
          inSitting: true,
        );
      });
      await tester.tap(find.text('Day 3'));
      await tester.pumpAndSettle();
      final dropdown = tester.widget<DropdownButtonFormField<DayType>>(
        find.byType(DropdownButtonFormField<DayType>),
      );
      expect(dropdown.initialValue, DayType.rest);
    });

    testWidgets('without a dive still reads Rest', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 10, 10)), () async {
        await pumpTab(tester, trip: resortTrip(), days: [rest]);
      });
      expect(find.text('Rest'), findsOneWidget);
      expect(find.text('Dive Day'), findsNothing);
      expect(find.byIcon(Icons.beach_access), findsOneWidget);
    });
  });

  group('richer day cards', () {
    final day = row('r', DateTime(2026, 3, 8), 3);
    Dive dive(String id, int hour, {double? temp, int minutes = 50}) => Dive(
      id: id,
      diveNumber: hour,
      dateTime: DateTime(2026, 3, 8, hour),
      runtime: Duration(minutes: minutes),
      maxDepth: 18 + hour.toDouble(),
      waterTemp: temp,
      airTemp: 29,
    );
    MediaItem photo(String id) => MediaItem(
      id: id,
      mediaType: MediaType.photo,
      takenAt: DateTime(2026, 3, 8, 10),
      createdAt: DateTime(2026, 3, 8, 10),
      updatedAt: DateTime(2026, 3, 8, 10),
    );
    Sighting sighting(String id, String speciesId) => Sighting(
      id: id,
      diveId: 'a',
      speciesId: speciesId,
      speciesName: speciesId,
    );

    testWidgets('totals, conditions, weather and richer rows', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 9, 10)), () async {
        await pumpTab(
          tester,
          trip: resortTrip(),
          days: [day],
          dives: [dive('a', 9, temp: 26), dive('b', 14, temp: 28)],
        );
      });
      expect(find.textContaining('2 dives · 1h 40m · 32.0m'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('day-conditions-line'))).data,
        'Water 26°C to 28°C',
      );
      expect(find.text('29°C'), findsOneWidget);
      expect(find.text('09:00 · 50m · 27.0m · 26°C'), findsOneWidget);
      expect(find.text('14:00 · 50m · 32.0m · 28°C'), findsOneWidget);
    });

    testWidgets('stored weather fills in when no dive logged any', (
      tester,
    ) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 9, 10)), () async {
        await pumpTab(
          tester,
          trip: resortTrip(),
          days: [day],
          tripDayWeather: {
            tripDayMillis(day.date): TripDayWeather(
              id: 'w',
              tripId: 'trip-1',
              date: day.date,
              latitude: 12.1,
              longitude: -68.2,
              airTemp: 31,
              fetchedAt: DateTime(2026, 3, 8),
              createdAt: DateTime(2026, 3, 8),
              updatedAt: DateTime(2026, 3, 8),
            ),
          },
        );
      });
      expect(find.text('31°C'), findsOneWidget);
    });

    testWidgets('photos and species from the story', (tester) async {
      final trip = resortTrip();
      final diveA = dive('a', 9);
      final story = buildTripStory(
        trip: trip,
        dives: [diveA],
        itineraryDays: [day],
        mediaByDiveId: {
          'a': DiveMediaPreview(
            items: [photo('m1'), photo('m2')],
            mediaCount: 2,
            photoCount: 2,
          ),
        },
        sightingsByDiveId: {
          'a': [
            sighting('s1', 'sp-1'),
            sighting('s2', 'sp-1'),
            sighting('s3', 'sp-2'),
          ],
        },
        checklistItems: const [],
        today: DateTime(2026, 3, 9),
      );
      await withClock(Clock.fixed(DateTime(2026, 3, 9, 10)), () async {
        await pumpTab(
          tester,
          trip: trip,
          days: [day],
          dives: [diveA],
          story: story,
        );
      });
      expect(find.text('2 photos · 2 species'), findsOneWidget);
    });

    testWidgets('no photos or species means no media line', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 9, 10)), () async {
        await pumpTab(
          tester,
          trip: resortTrip(),
          days: [day],
          dives: [dive('a', 9)],
        );
      });
      expect(find.byIcon(Icons.photo_library_outlined), findsNothing);
    });

    testWidgets('today is tinted and says Today', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 8, 10)), () async {
        await pumpTab(tester, trip: resortTrip(), days: [day]);
      });
      expect(find.byKey(const Key('today-chip')), findsOneWidget);
      final card = tester.widget<Card>(find.byType(Card).first);
      final context = tester.element(find.byType(TripItineraryTab));
      final scheme = Theme.of(context).colorScheme;
      expect(
        (card.shape! as RoundedRectangleBorder).side.color,
        scheme.primary,
      );
      // An opaque fill, so it reads the same on any surface behind it.
      expect(card.color!.a, 1.0);
    });

    testWidgets('a past day compares logged with planned', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 9, 10)), () async {
        await pumpTab(
          tester,
          trip: resortTrip(),
          days: [day.copyWith(plannedDives: 3)],
          dives: [dive('a', 9)],
        );
      });
      expect(find.text('1 of 3 planned dives'), findsOneWidget);
    });
  });

  testWidgets('a dive is listed on the day it entered the water', (
    tester,
  ) async {
    // Logged at 23:50 on the 8th but entered the water after midnight: the
    // story puts it on the 9th, and so must the itinerary.
    final dive = Dive(
      id: 'late',
      dateTime: DateTime(2026, 3, 8, 23, 50),
      entryTime: DateTime(2026, 3, 9, 0, 10),
    );
    await withClock(Clock.fixed(DateTime(2026, 4, 1)), () async {
      await pumpTab(
        tester,
        trip: resortTrip(),
        days: [row('n', DateTime(2026, 3, 9), 4)],
        dives: [dive],
      );
    });
    expect(find.textContaining('1 dive'), findsOneWidget);
  });
}
