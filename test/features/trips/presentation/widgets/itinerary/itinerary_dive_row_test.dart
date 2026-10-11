import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/itinerary/itinerary_dive_row.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _imperial = UnitFormatter(
  AppSettings(
    temperatureUnit: TemperatureUnit.fahrenheit,
    depthUnit: DepthUnit.feet,
  ),
);

final _dive = Dive(
  id: 'd',
  diveNumber: 1234,
  dateTime: DateTime(2026, 3, 8, 9),
  runtime: const Duration(minutes: 62),
  maxDepth: 31.4,
  waterTemp: 27.5,
  site: const DiveSite(id: 's', name: 'Alice in Wonderland'),
);

Future<void> _pumpRow(WidgetTester tester, {double textScale = 1.0}) =>
    tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            // What a 360px phone leaves a dive row: list and card insets
            // plus the card's 48px indent.
            child: const Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 256, child: _RowHost()),
            ),
          ),
        ),
      ),
    );

class _RowHost extends StatelessWidget {
  const _RowHost();

  @override
  Widget build(BuildContext context) =>
      ItineraryDiveRow(dive: _dive, units: _imperial);
}

void main() {
  for (final scale in [1.0, 1.3]) {
    testWidgets('fits a phone row at text scale $scale with the site legible', (
      tester,
    ) async {
      await _pumpRow(tester, textScale: scale);
      expect(tester.takeException(), isNull);
      final site = find.text('Alice in Wonderland');
      expect(site, findsOneWidget);
      expect(tester.getSize(site).width, greaterThan(120));
      expect(find.textContaining('°F'), findsOneWidget);
      expect(find.textContaining('ft'), findsOneWidget);
    });
  }

  testWidgets('shows the entry time the itinerary groups the dive by', (
    tester,
  ) async {
    final lateDive = Dive(
      id: 'late',
      dateTime: DateTime(2026, 3, 8, 23, 50),
      entryTime: DateTime(2026, 3, 9, 0, 10),
      site: const DiveSite(id: 's', name: 'Salt Pier'),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ItineraryDiveRow(dive: lateDive, units: _imperial),
        ),
      ),
    );
    expect(find.textContaining('00:10'), findsOneWidget);
    expect(find.textContaining('23:50'), findsNothing);
  });
}
