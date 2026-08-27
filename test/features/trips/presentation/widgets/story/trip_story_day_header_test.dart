import 'dart:async';

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
import 'package:submersion/features/trips/presentation/providers/surface_day_weather_provider.dart';
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
  SurfaceDayWeatherRequest? surfaceWeatherRequest,
  List<Override> extra = const [],
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
      overrides: [...overrides, ...extra],
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
                child: TripStoryDayHeader(
                  day: day,
                  surfaceWeatherRequest: surfaceWeatherRequest,
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

void main() {
  testWidgets('shows the day number badge and date', (tester) async {
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
    );
    await pumpHeader(tester, day);

    // The day number lives in the leading badge; the title is the date alone,
    // so the number is not announced or drawn twice.
    expect(
      find.descendant(
        of: find.byKey(const Key('day-number-badge')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Day 2'), findsNothing);
    // MMMEd for en locale: "Sun, Mar 8".
    expect(find.textContaining('Mar 8'), findsOneWidget);
  });

  testWidgets('day number badge keeps the "Day N" screen-reader label', (
    tester,
  ) async {
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
    );
    await pumpHeader(tester, day);

    // Visually the badge is a bare "2"; assistive tech still hears "Day 2".
    expect(find.bySemanticsLabel('Day 2'), findsOneWidget);
  });

  testWidgets('header band is tinted to anchor its chapter', (tester) async {
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
    );
    await pumpHeader(tester, day);

    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(TripStoryDayHeader),
            matching: find.byType(Material),
          )
          .first,
    );
    final context = tester.element(find.byType(TripStoryDayHeader));
    expect(material.color, Theme.of(context).colorScheme.surfaceContainer);
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
    // A dive with no site on a day with no itinerary: nothing to subtitle with,
    // but the dive keeps it off the surface-day path (which has its own label).
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
      dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
    );
    await pumpHeader(tester, day);

    // Only the badge number and the title line render.
    expect(find.byType(Text), findsNWidgets(2));
  });

  group('surface day', () {
    TripStoryDay surfaceDay() => TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
    );
    final request = SurfaceDayWeatherRequest(
      date: DateTime(2026, 3, 8),
      latitude: 12.1,
      longitude: -68.2,
    );

    testWidgets('gets the same badge and title line as any other day', (
      tester,
    ) async {
      await pumpHeader(tester, surfaceDay());

      expect(
        find.descendant(
          of: find.byKey(const Key('day-number-badge')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Mar 8'), findsOneWidget);
    });

    testWidgets('labels itself in the subtitle slot', (tester) async {
      await pumpHeader(tester, surfaceDay());

      expect(find.text('Surface day'), findsOneWidget);
    });

    testWidgets('title style matches a dive day title exactly', (tester) async {
      // The point of the shared header: a surface day must not read as a
      // lesser, smaller entry than the dive day above or below it.
      await pumpHeader(tester, surfaceDay());
      final surfaceStyle = tester
          .widget<Text>(find.textContaining('Mar 8'))
          .style;

      await pumpHeader(
        tester,
        TripStoryDay(
          date: DateTime(2026, 3, 8),
          dayNumber: 2,
          kind: TripStoryDayKind.past,
          dives: [
            Dive(
              id: 'd1',
              dateTime: DateTime(2026, 3, 8, 9),
              site: const DiveSite(id: 'site-a', name: 'Blue Corner'),
            ),
          ],
        ),
      );
      final diveStyle = tester.widget<Text>(find.textContaining('Mar 8')).style;

      expect(surfaceStyle, diveStyle);
      expect(surfaceStyle?.fontWeight, FontWeight.bold);
    });

    testWidgets('carries no leading icon', (tester) async {
      // The old slim row led with a waves icon; no other day header does, so
      // keeping it would reintroduce the asymmetry the shared header removes.
      await pumpHeader(tester, surfaceDay());

      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('shows fetched weather in the existing badge', (tester) async {
      await pumpHeader(
        tester,
        surfaceDay(),
        surfaceWeatherRequest: request,
        extra: [
          surfaceDayWeatherProvider(request).overrideWith(
            (ref) async => const TripStoryDayWeather(
              airTemp: 22,
              cloudCover: CloudCover.clear,
            ),
          ),
        ],
      );
      await tester.pump();

      expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
      expect(find.text('22°C'), findsOneWidget);
    });

    testWidgets('fetched temperature respects Fahrenheit', (tester) async {
      final settings = MockSettingsNotifier();
      await settings.setTemperatureUnit(TemperatureUnit.fahrenheit);
      await pumpHeader(
        tester,
        surfaceDay(),
        settingsNotifier: settings,
        surfaceWeatherRequest: request,
        extra: [
          surfaceDayWeatherProvider(
            request,
          ).overrideWith((ref) async => const TripStoryDayWeather(airTemp: 22)),
        ],
      );
      await tester.pump();

      expect(find.text('71.6°F'), findsOneWidget);
    });

    testWidgets('loading and failed weather stay badge-free', (tester) async {
      final pending = Completer<TripStoryDayWeather?>();
      await pumpHeader(
        tester,
        surfaceDay(),
        surfaceWeatherRequest: request,
        extra: [
          surfaceDayWeatherProvider(
            request,
          ).overrideWith((ref) => pending.future),
        ],
      );

      expect(find.textContaining('°'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      pending.completeError(Exception('weather unavailable'));
      await tester.pump();

      expect(find.textContaining('°'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('without a request stays badge-free', (tester) async {
      await pumpHeader(tester, surfaceDay());

      expect(find.textContaining('°'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
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
    // day header reads as the same height at default text scale. A siteless
    // dive keeps the subtitle empty without taking the surface-day path.
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
      dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
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

      // 22 C is 71.6 F: one decimal is kept, and only a zero decimal is
      // trimmed, so this no longer rounds to a whole degree (#912).
      expect(find.text('71.6°F'), findsOneWidget);
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
