import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/tide/entities/tide_prediction.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_chart.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_section.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_times_table.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

// A diver on DD/MM/YYYY must read "Mon, 10 Aug", not "Mon, Aug 10" (#964).
// Every fixture below is wall-clock-as-UTC, matching how tide instants are
// stored, so the rendered digits depend only on the fixture. (#222)

const _location = GeoPoint(36.95, -122.02);

final _reference = DateTime.utc(2026, 1, 15, 22);

final _chartExtremes = [
  TideExtreme(
    type: TideExtremeType.high,
    time: DateTime.utc(2026, 1, 16, 1),
    heightMeters: 2.4,
  ),
  TideExtreme(
    type: TideExtremeType.low,
    time: DateTime.utc(2026, 1, 16, 7),
    heightMeters: 0.4,
  ),
];

/// Half-hourly predictions spanning the chart's visible window, which runs
/// from `reference - 6h` (16:00 Jan 15) through the second future extreme
/// plus 30min. The first visible prediction lands exactly on 16:00, which is
/// what the tooltip assertions below read.
List<TidePrediction> _buildPredictions() {
  final start = DateTime.utc(2026, 1, 15, 12);
  return [
    for (var i = 0; i <= 48; i++)
      TidePrediction(
        time: start.add(Duration(minutes: 30 * i)),
        heightMeters: 1.4 + math.sin(i * math.pi / 12),
      ),
  ];
}

/// The date line of the chart's touch tooltip for the first visible point.
String _firstTooltipDate(WidgetTester tester) {
  final data = tester.widget<LineChart>(find.byType(LineChart)).data;
  final curve = data.lineBarsData.first;
  final items = data.lineTouchData.touchTooltipData.getTooltipItems([
    LineBarSpot(curve, 0, curve.spots.first),
  ]);
  return items.first!.children!.map((span) => span.toPlainText()).join();
}

Future<void> _pumpChart(
  WidgetTester tester,
  DateFormatPreference dateFormat,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 800,
            child: TideChart(
              predictions: _buildPredictions(),
              extremes: _chartExtremes,
              now: _reference,
              dateFormat: dateFormat,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpTimesTable(
  WidgetTester tester,
  DateFormatPreference dateFormat,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TideTimesTable(
          extremes: [
            TideExtreme(
              type: TideExtremeType.high,
              time: DateTime.utc(2026, 1, 20, 10, 30),
              heightMeters: 1.2,
            ),
          ],
          now: DateTime.utc(2026, 1, 15, 9),
          showPast: true,
          dateFormat: dateFormat,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// The section's window label replicates TideChart's maths against the real
// clock, so anchor the bounds on far-past and far-future extremes to keep the
// rendered window fully determined by the fixtures.
final _sectionExtremes = [
  TideExtreme(
    type: TideExtremeType.low,
    time: DateTime.utc(2020, 3, 10, 6, 15),
    heightMeters: 0.4,
  ),
  TideExtreme(
    type: TideExtremeType.high,
    time: DateTime.utc(2030, 5, 20, 8),
    heightMeters: 2.4,
  ),
  TideExtreme(
    type: TideExtremeType.low,
    time: DateTime.utc(2030, 5, 20, 14, 30),
    heightMeters: 0.6,
  ),
];

Future<void> _pumpSection(
  WidgetTester tester,
  DateFormatPreference dateFormat,
) async {
  final settings = MockSettingsNotifier();
  await settings.setTimeFormat(TimeFormat.twentyFourHour);
  await settings.setDateFormat(dateFormat);
  final overrides = await getBaseOverrides(settingsNotifier: settings);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        hasTideDataProvider(_location).overrideWith((ref) async => true),
        currentTideStatusProvider(_location).overrideWith((ref) async => null),
        tidePredictionsProvider(
          _location,
        ).overrideWith((ref) async => <TidePrediction>[]),
        tideExtremesProvider(
          _location,
        ).overrideWith((ref) async => _sectionExtremes),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: TideSection(location: _location)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // These widgets format via DateFormat(pattern) with no explicit locale, so
  // they resolve against intl's process-global default. Pin it so the expected
  // month names do not depend on the locale the test host happens to run under.
  String? previousDefaultLocale;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  group('TideChart date order (#964)', () {
    testWidgets('the touch tooltip is month-first by default', (tester) async {
      await _pumpChart(tester, DateFormatPreference.mmddyyyy);

      expect(_firstTooltipDate(tester), contains('Thu, Jan 15'));
    });

    testWidgets('the touch tooltip follows a day-first preference', (
      tester,
    ) async {
      await _pumpChart(tester, DateFormatPreference.ddmmyyyy);

      expect(_firstTooltipDate(tester), contains('Thu, 15 Jan'));
    });

    testWidgets('the top axis keeps its bare weekday label in both orders', (
      tester,
    ) async {
      // A weekday alone carries no day/month order, so the day-first
      // preference must not disturb it.
      await _pumpChart(tester, DateFormatPreference.ddmmyyyy);

      expect(find.text('Fri'), findsOneWidget);
    });
  });

  group('TideTimesTable date order (#964)', () {
    testWidgets('row dates are month-first by default', (tester) async {
      await _pumpTimesTable(tester, DateFormatPreference.mmddyyyy);

      expect(find.text('Tue, Jan 20'), findsOneWidget);
    });

    testWidgets('row dates follow a day-first preference', (tester) async {
      await _pumpTimesTable(tester, DateFormatPreference.ddmmyyyy);

      expect(find.text('Tue, 20 Jan'), findsOneWidget);
    });
  });

  group('TideSection chart window date order (#964)', () {
    testWidgets('the window label is month-first by default', (tester) async {
      await _pumpSection(tester, DateFormatPreference.mmddyyyy);

      expect(find.text('Tue, Mar 10 | 05:45 - 15:00 (May 20)'), findsOneWidget);
    });

    testWidgets('the window label follows a day-first preference', (
      tester,
    ) async {
      // Both halves flip: the start date and the parenthesised end date.
      await _pumpSection(tester, DateFormatPreference.ddmmyyyy);

      expect(find.text('Tue, 10 Mar | 05:45 - 15:00 (20 May)'), findsOneWidget);
    });
  });
}
