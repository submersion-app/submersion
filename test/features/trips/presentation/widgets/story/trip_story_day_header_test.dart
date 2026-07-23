import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_header.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

ItineraryDay _itin({String? port}) => ItineraryDay(
  id: 'itin-1',
  tripId: 'trip-1',
  dayNumber: 2,
  date: DateTime(2026, 3, 8),
  dayType: DayType.diveDay,
  portName: port,
  notes: '',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Future<void> pumpHeader(WidgetTester tester, TripStoryDay day) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: TripStoryDayHeader(day: day)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows the day number and date', (tester) async {
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
    );
    await pumpHeader(tester, day);

    expect(find.textContaining('Day 2'), findsOneWidget);
    // MMMEd for en locale: "Sun, Mar 8".
    expect(find.textContaining('Mar 8'), findsOneWidget);
  });

  testWidgets('subtitle joins day type, port, and site names', (tester) async {
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
      itineraryDay: _itin(port: 'Kralendijk'),
      dives: [
        Dive(
          id: 'd1',
          dateTime: DateTime(2026, 3, 8, 9),
          site: const DiveSite(id: 'site-a', name: 'Blue Corner'),
        ),
      ],
    );
    await pumpHeader(tester, day);

    final subtitle = find.textContaining('Kralendijk');
    expect(subtitle, findsOneWidget);
    expect(find.textContaining('Blue Corner'), findsOneWidget);
  });

  testWidgets('no subtitle line when there is nothing to say', (tester) async {
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
    );
    await pumpHeader(tester, day);

    // Only the title line renders.
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('future day shows the planned chip', (tester) async {
    final day = TripStoryDay(
      date: DateTime(2027, 1, 10),
      dayNumber: 1,
      kind: TripStoryDayKind.future,
    );
    await pumpHeader(tester, day);

    expect(find.text('Planned'), findsOneWidget);
  });

  testWidgets('header is exactly the delegate extent tall', (tester) async {
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
    );
    await pumpHeader(tester, day);

    expect(
      tester.getSize(find.byType(TripStoryDayHeader)).height,
      TripStoryDayHeaderDelegate.extent,
    );
  });

  test('delegate rebuilds only when the day value changes', () {
    TripStoryDay make({int dayNumber = 2}) => TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: dayNumber,
      kind: TripStoryDayKind.past,
    );

    final delegate = TripStoryDayHeaderDelegate(day: make());
    // TripStoryDay is Equatable: equal values => no rebuild.
    expect(
      delegate.shouldRebuild(TripStoryDayHeaderDelegate(day: make())),
      isFalse,
    );
    expect(
      delegate.shouldRebuild(
        TripStoryDayHeaderDelegate(day: make(dayNumber: 3)),
      ),
      isTrue,
    );
    expect(delegate.minExtent, delegate.maxExtent);
  });
}
