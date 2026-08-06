import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_header.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

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

Future<void> pumpHeader(
  WidgetTester tester,
  TripStoryDay day, {
  double textScale = 1.0,
  MockSettingsNotifier? settingsNotifier,
}) async {
  // The header dates itself with DateFormat.MMMEd(), which resolves against
  // Intl.defaultLocale - a process global that app.dart sets from the app
  // locale - NOT the MaterialApp.locale set below. Pin it so the "Mar 8"
  // assertion states its real dependency instead of riding on intl's implicit
  // en_US fallback, and restore it so the global stays contained.
  final previousLocale = Intl.defaultLocale;
  Intl.defaultLocale = 'en';
  addTearDown(() => Intl.defaultLocale = previousLocale);

  final overrides = await getBaseOverrides(settingsNotifier: settingsNotifier);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          // Align to the top so the header keeps its intrinsic height rather
          // than being stretched by the body's constraints.
          body: Align(
            alignment: Alignment.topCenter,
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: TripStoryDayHeader(day: day),
              ),
            ),
          ),
        ),
      ),
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

  testWidgets('blank port name does not leave an empty subtitle segment', (
    tester,
  ) async {
    // The edit sheet normalizes "" to null, but sync/import payloads write the
    // nullable column directly, so a blank port can reach the entity. Joining
    // it verbatim would render "Dive Day -  - Blue Corner".
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
      itineraryDay: _itin(port: '   '),
      dives: [
        Dive(
          id: 'd1',
          dateTime: DateTime(2026, 3, 8, 9),
          site: const DiveSite(id: 'site-a', name: 'Blue Corner'),
        ),
      ],
    );
    await pumpHeader(tester, day);

    expect(find.text('Dive Day - Blue Corner'), findsOneWidget);
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

  testWidgets('short day still fills the minimum band height', (tester) async {
    // Title line only: shorter than the band, so the floor applies and every
    // day header reads as the same height at default text scale.
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
    );
    await pumpHeader(tester, day);

    expect(
      tester.getSize(find.byType(TripStoryDayHeader)).height,
      TripStoryDayHeader.minHeight,
    );
  });

  group('weather badge', () {
    TripStoryDay dayWith({
      double? airTemp,
      CloudCover? cloudCover,
      Precipitation? precipitation,
    }) => TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
      dives: [
        Dive(
          id: 'd1',
          dateTime: DateTime(2026, 3, 8, 9),
          airTemp: airTemp,
          cloudCover: cloudCover,
          precipitation: precipitation,
        ),
      ],
    );

    testWidgets('shows the conditions icon and air temperature', (
      tester,
    ) async {
      await pumpHeader(
        tester,
        dayWith(airTemp: 22, cloudCover: CloudCover.clear),
      );

      expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
      expect(find.text('22°C'), findsOneWidget);
    });

    testWidgets('air temperature respects the Fahrenheit setting', (
      tester,
    ) async {
      final settings = MockSettingsNotifier();
      await settings.setTemperatureUnit(TemperatureUnit.fahrenheit);
      await pumpHeader(
        tester,
        dayWith(airTemp: 22, cloudCover: CloudCover.clear),
        settingsNotifier: settings,
      );

      expect(find.text('72°F'), findsOneWidget);
    });

    testWidgets('precipitation outranks cloud cover for the icon', (
      tester,
    ) async {
      await pumpHeader(
        tester,
        dayWith(
          precipitation: Precipitation.rain,
          cloudCover: CloudCover.overcast,
        ),
      );

      expect(find.byIcon(Icons.water_drop), findsOneWidget);
      expect(find.byIcon(Icons.cloud), findsNothing);
    });

    testWidgets('precipitation "none" falls back to the cloud cover icon', (
      tester,
    ) async {
      await pumpHeader(
        tester,
        dayWith(
          precipitation: Precipitation.none,
          cloudCover: CloudCover.overcast,
        ),
      );

      expect(find.byIcon(Icons.cloud), findsOneWidget);
    });

    testWidgets('temperature-only day shows the value without an icon', (
      tester,
    ) async {
      await pumpHeader(tester, dayWith(airTemp: 22));

      expect(find.text('22°C'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('day without weather shows no badge', (tester) async {
      final day = TripStoryDay(
        date: DateTime(2026, 3, 8),
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
      );
      await pumpHeader(tester, day);

      expect(find.byType(Icon), findsNothing);
      expect(find.textContaining('°'), findsNothing);
    });
  });

  testWidgets('scaled text grows the header instead of clipping it', (
    tester,
  ) async {
    // Worst case: two text lines plus the Planned chip. A fixed-extent sliver
    // header would overflow here; the self-sizing header must just get taller.
    final day = TripStoryDay(
      date: DateTime(2027, 1, 10),
      dayNumber: 1,
      kind: TripStoryDayKind.future,
      itineraryDay: _itin(port: 'Kralendijk'),
    );
    await pumpHeader(tester, day, textScale: 2.0);

    // An overflowing RenderFlex reports a FlutterError the test framework
    // surfaces here; nothing thrown means nothing was clipped.
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(TripStoryDayHeader)).height,
      greaterThan(TripStoryDayHeader.minHeight),
    );
  });
}
