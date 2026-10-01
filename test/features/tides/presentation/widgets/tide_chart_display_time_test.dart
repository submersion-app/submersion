import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/tide/tide.dart';
import 'package:submersion/core/util/site_time_zone.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  String? previousDefaultLocale;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() => Intl.defaultLocale = previousDefaultLocale);

  testWidgets('plots real instants and labels them in the site clock', (
    tester,
  ) async {
    // Monterey on the 2026-11-01 fall-back night: 09:30Z is the second
    // 01:30 of the site's clock (PST). The chart must keep the instants in
    // order and print the site time.
    final toSite = SiteTimeZone.wallClockConverterFor(36.62, -121.90);
    final predictions = [
      for (var minutes = 0; minutes <= 240; minutes += 10)
        TidePrediction(
          time: DateTime.utc(2026, 11, 1, 7).add(Duration(minutes: minutes)),
          heightMeters: minutes / 100,
        ),
    ];
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TideChart(
            predictions: predictions,
            extremes: [
              TideExtreme(
                type: TideExtremeType.high,
                time: DateTime.utc(2026, 11, 1, 9, 30),
                heightMeters: 1.5,
              ),
            ],
            now: DateTime.utc(2026, 11, 1, 9),
            displayTime: toSite,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('High tide at 01:30')), findsOneWidget);
    handle.dispose();
  });
}
