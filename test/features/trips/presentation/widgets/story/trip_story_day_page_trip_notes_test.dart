import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_page.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_plan.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_view.dart';

import '../../../../../helpers/mock_providers.dart';

final _date = DateTime(2026, 3, 8);

TripStoryDay _day({String itineraryNotes = ''}) => TripStoryDay(
  date: _date,
  dayNumber: 1,
  kind: TripStoryDayKind.past,
  itineraryDay: itineraryNotes.isEmpty
      ? null
      : ItineraryDay(
          id: 'itin-1',
          tripId: 'trip-1',
          dayNumber: 1,
          date: _date,
          dayType: DayType.diveDay,
          notes: itineraryNotes,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
);

Future<void> _pump(
  WidgetTester tester,
  TripStoryDay day, {
  String? tripNotes,
  VoidCallback? onOpenTripNotes,
  VoidCallback? onEditNote,
}) async {
  final previousLocale = Intl.defaultLocale;
  Intl.defaultLocale = 'en';
  addTearDown(() => Intl.defaultLocale = previousLocale);

  final story = TripStory(
    trip: Trip(
      id: 'trip-1',
      name: 'Bonaire',
      startDate: _date,
      endDate: _date,
      tripType: TripType.resort,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    days: [day],
    checklist: const TripStoryChecklistSummary(done: 0, total: 0, nextDue: []),
    mapGeometry: const TripStoryMapGeometry(points: []),
  );
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TripStoryDayPage(
            story: story,
            day: day,
            mapPoints: const [],
            tripNotes: tripNotes,
            onOpenTripNotes: onOpenTripNotes,
            onEditNote: onEditNote,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a day with only trip notes shows them, not "no dives"', (
    tester,
  ) async {
    await _pump(tester, _day(), tripNotes: 'Vis 30 m');

    expect(find.text('From trip notes'), findsOneWidget);
    expect(find.text('Vis 30 m'), findsOneWidget);
    expect(find.byKey(TripStoryDayPage.noDivesKey), findsNothing);
  });

  testWidgets('blank trip notes draw no caption', (tester) async {
    await _pump(tester, _day(), tripNotes: '  \n ');

    expect(find.byKey(TripStoryDayPlan.fromTripNotesKey), findsNothing);
    expect(find.byKey(TripStoryDayPage.noDivesKey), findsOneWidget);
  });

  testWidgets('a passage keeps the indentation of its first line', (
    tester,
  ) async {
    // Four spaces make an indented code block; trimming them would turn it
    // into a paragraph.
    await _pump(tester, _day(), tripNotes: '    nitrox 32 to 30 m\n');

    final view = tester.widget<MarkdownNotesView>(
      find.byKey(TripStoryDayPlan.tripNotesKey),
    );
    expect(view.source, '    nitrox 32 to 30 m');
  });

  testWidgets("the itinerary's own note comes before the trip notes", (
    tester,
  ) async {
    await _pump(
      tester,
      _day(itineraryNotes: 'Boat at 8'),
      tripNotes: 'Vis 30 m',
    );

    expect(
      tester.getTopLeft(find.text('Boat at 8')).dy,
      lessThan(tester.getTopLeft(find.text('Vis 30 m')).dy),
    );
  });

  testWidgets('tapping the caption opens the trip notes', (tester) async {
    var opened = 0;
    await _pump(
      tester,
      _day(),
      tripNotes: 'Vis 30 m',
      onOpenTripNotes: () => opened++,
    );

    await tester.tap(find.byKey(TripStoryDayPlan.fromTripNotesKey));
    expect(opened, 1);
  });

  testWidgets('the caption shows its chevron only when it can open', (
    tester,
  ) async {
    await _pump(tester, _day(), tripNotes: 'Vis 30 m');
    expect(
      find.descendant(
        of: find.byKey(TripStoryDayPlan.fromTripNotesKey),
        matching: find.byIcon(Icons.chevron_right),
      ),
      findsNothing,
    );

    await _pump(tester, _day(), tripNotes: 'Vis 30 m', onOpenTripNotes: () {});
    expect(
      find.descendant(
        of: find.byKey(TripStoryDayPlan.fromTripNotesKey),
        matching: find.byIcon(Icons.chevron_right),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a day with no passage offers Add note', (tester) async {
    var edits = 0;
    await _pump(tester, _day(), onEditNote: () => edits++);

    expect(find.text('Add note'), findsOneWidget);
    await tester.tap(find.byKey(TripStoryDayPage.editNoteKey));
    expect(edits, 1);
  });

  testWidgets('a day with a passage offers Edit note', (tester) async {
    await _pump(tester, _day(), tripNotes: 'Vis 30 m', onEditNote: () {});

    expect(find.text('Edit note'), findsOneWidget);
    expect(find.text('Add note'), findsNothing);
  });

  testWidgets('no edit action without a handler', (tester) async {
    await _pump(tester, _day(), tripNotes: 'Vis 30 m');

    expect(find.byKey(TripStoryDayPage.editNoteKey), findsNothing);
  });
}
