import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/backdrop_color.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/header_map_backdrop.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_hero_card.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_stat_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

DateTime _daysFrom(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

Trip _trip({
  required DateTime start,
  required DateTime end,
  TripType tripType = TripType.resort,
}) => Trip(
  id: 'trip-1',
  name: 'Bonaire',
  startDate: start,
  endDate: end,
  tripType: tripType,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Dive _diveAt(String id, DateTime dt, {double lat = 12.1, double lng = -68.2}) =>
    Dive(
      id: id,
      dateTime: dt,
      maxDepth: 20,
      site: DiveSite(
        id: 'site-$id',
        name: 'Site $id',
        location: GeoPoint(lat, lng),
      ),
    );

TripStory _story(Trip trip, {List<Dive> dives = const [], DateTime? today}) =>
    buildTripStory(
      trip: trip,
      dives: dives,
      itineraryDays: [],
      mediaByDiveId: {},
      sightingsByDiveId: {},
      checklistItems: [],
      today: today ?? DateTime.now(),
    );

Future<void> pumpHeroCard(
  WidgetTester tester,
  TripStory story, {
  int diveCount = 2,
  int siteCount = 0,
  ThemeData? theme,
}) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        theme: theme,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TripHeroCard(
              story: story,
              stats: TripWithStats(trip: story.trip, diveCount: diveCount),
              siteCount: siteCount,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('a trip with located sites opens over a fading map', (
    tester,
  ) async {
    final story = _story(
      _trip(start: DateTime(2026, 3, 7), end: DateTime(2026, 3, 9)),
      dives: [
        _diveAt('d1', DateTime(2026, 3, 7, 9)),
        _diveAt('d2', DateTime(2026, 3, 8, 9), lng: -68.3),
      ],
      today: DateTime(2026, 6, 1),
    );
    await pumpHeroCard(tester, story, siteCount: 2);

    final card = find.byKey(const Key('trip-hero-card'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.byType(HeaderMapBackdrop)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.byType(FlutterMap)),
      findsOneWidget,
    );
    expect(find.byKey(const Key('trip-hero-gradient')), findsNothing);
    // Identity, dates and stats all live inside the one card.
    expect(find.descendant(of: card, matching: find.text('Bonaire')), findsOne);
    expect(
      find.descendant(of: card, matching: find.textContaining('3 days')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.byType(TripStatStrip)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Sites visited')),
      findsOneWidget,
    );
  });

  testWidgets('the map fades into the card colour', (tester) async {
    final story = _story(
      _trip(start: DateTime(2026, 3, 7), end: DateTime(2026, 3, 9)),
      dives: [_diveAt('d1', DateTime(2026, 3, 7, 9))],
      today: DateTime(2026, 6, 1),
    );
    final dark = ThemeData.dark();
    await pumpHeroCard(tester, story, theme: dark);
    final backdrop = tester.widget<HeaderMapBackdrop>(
      find.byType(HeaderMapBackdrop),
    );
    final context = tester.element(find.byType(HeaderMapBackdrop));
    // The card's own fill, as a theme preset paints it, not cardColor.
    expect(backdrop.fadeColor, backdropColorOf(context));
    expect(backdrop.fadeColor, isNot(Theme.of(context).cardColor));
  });

  testWidgets('a trip with no located sites gets the ocean gradient', (
    tester,
  ) async {
    final story = _story(
      _trip(start: DateTime(2026, 3, 7), end: DateTime(2026, 3, 9)),
      dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 7, 9))],
      today: DateTime(2026, 6, 1),
    );
    await pumpHeroCard(tester, story);

    expect(find.byType(FlutterMap), findsNothing);
    expect(find.byType(HeaderMapBackdrop), findsNothing);
    final box = tester.widget<DecoratedBox>(
      find.byKey(const Key('trip-hero-gradient')),
    );
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.gradient, TripHeroCard.heroGradient(Brightness.light));
    // White text over the gradient.
    final context = tester.element(find.byKey(const Key('trip-hero-card')));
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    expect(tester.widget<Text>(find.text('Bonaire')).style?.color, onPrimary);
    expect(tester.widget<Text>(find.text('2')).style?.color, onPrimary);
  });

  testWidgets('the dark theme gets the deeper gradient', (tester) async {
    final story = _story(
      _trip(start: DateTime(2026, 3, 7), end: DateTime(2026, 3, 9)),
      today: DateTime(2026, 6, 1),
    );
    await pumpHeroCard(tester, story, theme: ThemeData.dark());
    final box = tester.widget<DecoratedBox>(
      find.byKey(const Key('trip-hero-gradient')),
    );
    expect(
      (box.decoration as BoxDecoration).gradient,
      TripHeroCard.heroGradient(Brightness.dark),
    );
  });

  testWidgets('an upcoming trip counts down, a trip under way counts days', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await pumpHeroCard(
      tester,
      _story(_trip(start: _daysFrom(today, 12), end: _daysFrom(today, 19))),
    );
    expect(find.text('12 days until departure'), findsOneWidget);

    await pumpHeroCard(
      tester,
      _story(
        _trip(start: _daysFrom(today, -1), end: _daysFrom(today, 2)),
        today: now,
      ),
    );
    expect(find.text('Day 2 of 4'), findsOneWidget);
  });

  testWidgets('a liveaboard carries the sailing icon', (tester) async {
    await pumpHeroCard(
      tester,
      _story(
        _trip(
          start: DateTime(2026, 3, 7),
          end: DateTime(2026, 3, 9),
          tripType: TripType.liveaboard,
        ),
        today: DateTime(2026, 6, 1),
      ),
    );
    expect(find.byIcon(Icons.sailing), findsOneWidget);
    expect(find.byIcon(Icons.flight_takeoff), findsNothing);
  });
}
