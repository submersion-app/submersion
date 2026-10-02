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
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import 'package:submersion/core/util/site_time_zone.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_times_table.dart';

const _location = GeoPoint(36.95, -122.02);

// The provider returns real instants. The section shows them in the site's
// wall clock: Santa Cruz is America/Los_Angeles, PDT (UTC-7) on both
// fixture dates. The chart window runs from the newest extreme before now
// (minus 30min) to the second extreme after now (plus 30min); far-past and
// far-future fixtures keep the result independent of the real clock and of
// the host's UTC offset. (#222)
final _extremes = [
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
  WidgetTester tester, {
  List<TidePrediction> predictions = const [],
}) async {
  final settings = MockSettingsNotifier();
  await settings.setTimeFormat(TimeFormat.twentyFourHour);
  final overrides = await getBaseOverrides(settingsNotifier: settings);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        hasTideDataProvider(_location).overrideWith((ref) async => true),
        currentTideStatusProvider(_location).overrideWith((ref) async => null),
        tidePredictionsProvider(
          _location,
        ).overrideWith((ref) async => predictions),
        tideExtremesProvider(_location).overrideWith((ref) async => _extremes),
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
  String? previousDefaultLocale;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  testWidgets('TideSection labels its chart window in wall-clock time (#222)', (
    tester,
  ) async {
    await _pumpSection(tester);

    // Low 06:15Z Mar 10 2020 is 23:15 PDT Mar 9, minus 30min = 22:45.
    // Low 14:30Z May 20 2030 is 07:30 PDT, plus 30min = 08:00.
    expect(find.text('Mon, Mar 9 | 22:45 - 08:00 (May 20)'), findsOneWidget);
  });

  testWidgets('the times table gets site-clock extremes and a site-clock now', (
    tester,
  ) async {
    await _pumpSection(tester);

    final table = tester.widget<TideTimesTable>(find.byType(TideTimesTable));
    expect(table.extremes.map((e) => e.time).toList(), [
      DateTime.utc(2020, 3, 9, 23, 15),
      DateTime.utc(2030, 5, 20, 1),
      DateTime.utc(2030, 5, 20, 7, 30),
    ]);

    // "Today" and "Tomorrow" must be judged on the site's calendar.
    final siteNow = SiteTimeZone.wallClockFromInstant(
      DateTime.now(),
      _location.latitude,
      _location.longitude,
    );
    expect(table.now, isNotNull);
    expect(
      table.now!.difference(siteNow).inMinutes.abs(),
      lessThanOrEqualTo(1),
    );
  });

  testWidgets('the chart plots instants and labels them in the site clock', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    await _pumpSection(
      tester,
      predictions: [
        for (var hours = -6; hours <= 24; hours++)
          TidePrediction(
            time: now.add(Duration(hours: hours)),
            heightMeters: hours / 10,
          ),
      ],
    );

    final chart = tester.widget<TideChart>(find.byType(TideChart));
    // Santa Cruz is America/Los_Angeles: PDT (UTC-7) in July.
    expect(chart.displayTime, isNotNull);
    expect(
      chart.displayTime!(DateTime.utc(2026, 7, 15, 12)),
      DateTime.utc(2026, 7, 15, 5),
    );
  });
}
