import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/features/tides/presentation/widgets/current_tide_indicator.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The indicator's rate line comes from UnitFormatter.formatTideRate, the
/// same format the dive detail page and the sync conflict dialog use
/// (#3028): signed, two decimals, localized digits, depth unit per hour.
void main() {
  String? previousLocale;

  setUp(() => previousLocale = Intl.defaultLocale);
  tearDown(() => Intl.defaultLocale = previousLocale);

  Future<void> pump(WidgetTester tester, DepthUnit depthUnit) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CurrentTideIndicator(
              status: const TideStatus(
                state: TideState.falling,
                currentHeight: 1.2,
                rateOfChange: -0.3048,
              ),
              depthUnit: depthUnit,
            ),
          ),
        ),
      );

  testWidgets('shows the rate in the diver depth unit', (tester) async {
    Intl.defaultLocale = 'en';
    await pump(tester, DepthUnit.feet);

    expect(find.text('-1.00ft/hr'), findsOneWidget);
  });

  testWidgets('localizes the decimal separator', (tester) async {
    Intl.defaultLocale = 'de';
    await pump(tester, DepthUnit.meters);

    expect(find.text('-0,30m/hr'), findsOneWidget);
  });
}
