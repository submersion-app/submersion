import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_weather_badge.dart';
import 'package:submersion/features/trips/presentation/widgets/day/today_chip.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_head.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

/// The head of a day's page: which day it is, what kind of day, and what it
/// added up to, in words. No band, no badge, no stat grid.
void main() {
  final date = DateTime(2026, 10, 29);

  Dive dive(String id, int hour, int minutes, double depth) => Dive(
    id: id,
    dateTime: DateTime(date.year, date.month, date.day, hour),
    runtime: Duration(minutes: minutes),
    maxDepth: depth,
    site: const DiveSite(id: 'bb', name: 'Big Brother'),
  );

  TripStoryDay diveDay({TripStoryDayKind kind = TripStoryDayKind.past}) =>
      TripStoryDay(
        date: date,
        dayNumber: 2,
        kind: kind,
        itineraryDay: ItineraryDay(
          id: 'itin-2',
          tripId: 'trip-1',
          dayNumber: 2,
          date: date,
          dayType: DayType.diveDay,
          notes: '',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        dives: [
          dive('a', 7, 52, 30.2),
          dive('b', 11, 49, 28.4),
          dive('c', 15, 50, 24.0),
        ],
      );

  final surfaceDay = TripStoryDay(
    date: DateTime(2026, 11, 2),
    dayNumber: 6,
    kind: TripStoryDayKind.past,
  );

  Future<void> pumpHead(
    WidgetTester tester, {
    required TripStoryDay day,
    int dayCount = 6,
    bool imperial = false,
    double textScale = 1,
    double width = 400,
    TripStoryDayWeather? storedWeather,
  }) async {
    // Dates are formatted against Intl.defaultLocale, a process global the
    // app sets from its own locale. Pin it and put it back.
    final previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
    addTearDown(() => Intl.defaultLocale = previousLocale);

    final overrides = await getBaseOverrides(
      settingsNotifier: imperial
          ? MockSettingsNotifier(
              const AppSettings(
                depthUnit: DepthUnit.feet,
                hasAcceptedPlanningDisclaimer: true,
              ),
            )
          : null,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: SizedBox(
                    width: width,
                    child: TripStoryDayHead(
                      day: day,
                      dayCount: dayCount,
                      storedWeather: storedWeather,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('says where the day sits and what it added up to', (
    tester,
  ) async {
    await pumpHead(tester, day: diveDay());

    expect(find.text('Thu, Oct 29'), findsOneWidget);
    expect(find.text('Day 2 of 6 · Dive Day · Big Brother'), findsOneWidget);
    expect(find.text('3 dives · 2h 31m · 30.2m max'), findsOneWidget);
  });

  testWidgets("max depth follows the diver's unit", (tester) async {
    await pumpHead(tester, day: diveDay(), imperial: true);

    expect(find.textContaining('ft max'), findsOneWidget);
    expect(find.textContaining('30.2m'), findsNothing);
  });

  testWidgets('a day with no dives has no totals line', (tester) async {
    await pumpHead(tester, day: surfaceDay);

    expect(find.text('Mon, Nov 2'), findsOneWidget);
    expect(find.text('Day 6 of 6 · Surface day'), findsOneWidget);
    expect(find.textContaining(' max'), findsNothing);
  });

  testWidgets('today carries the Today chip', (tester) async {
    await pumpHead(tester, day: diveDay(kind: TripStoryDayKind.today));

    expect(find.byType(TodayChip), findsOneWidget);
    expect(find.text('Planned'), findsNothing);
  });

  testWidgets('a day ahead carries the Planned chip', (tester) async {
    await pumpHead(tester, day: diveDay(kind: TripStoryDayKind.future));

    expect(find.text('Planned'), findsOneWidget);
    expect(find.byType(TodayChip), findsNothing);
  });

  testWidgets('a past day carries neither chip', (tester) async {
    await pumpHead(tester, day: diveDay());

    expect(find.byType(TodayChip), findsNothing);
    expect(find.text('Planned'), findsNothing);
  });

  testWidgets('weather shows when there is any', (tester) async {
    await pumpHead(
      tester,
      day: diveDay(),
      storedWeather: const TripStoryDayWeather(airTemp: 31),
    );

    expect(find.byType(DayWeatherBadge), findsOneWidget);
  });

  testWidgets('no weather, no badge', (tester) async {
    await pumpHead(tester, day: diveDay());

    expect(find.byType(DayWeatherBadge), findsNothing);
  });

  testWidgets('has no band behind it and no number badge', (tester) async {
    await pumpHead(tester, day: diveDay());

    expect(find.byKey(const Key('day-number-badge')), findsNothing);
    expect(
      find.descendant(
        of: find.byType(TripStoryDayHead),
        matching: find.byType(Material),
      ),
      findsNothing,
    );
  });

  testWidgets('at text scale 2.0 nothing overflows at 320 wide', (
    tester,
  ) async {
    await pumpHead(
      tester,
      day: diveDay(kind: TripStoryDayKind.today),
      textScale: 2,
      width: 320,
      storedWeather: const TripStoryDayWeather(airTemp: 31),
    );

    expect(tester.takeException(), isNull);
  });
}
