import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_factors_table.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<void> pump(
    WidgetTester tester,
    FocusFactorReport report, {
    AppSettings settings = const AppSettings(),
  }) async {
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(settings),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: FocusFactorsTable(report: report),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('too few dives shows the hint instead of a table', (
    tester,
  ) async {
    await pump(tester, const FocusFactorReport(factors: [], tooFewDives: true));
    expect(
      find.text('Choose at least 3 dives to compare common factors'),
      findsOneWidget,
    );
  });

  testWidgets('a standout numeric factor shows its chip and the summary', (
    tester,
  ) async {
    await pump(
      tester,
      const FocusFactorReport(
        tooFewDives: false,
        factors: [
          NumericFactor(
            id: FocusFactorId.maxDepth,
            groupCovered: 3,
            groupSize: 4,
            groupMean: 12,
            baselineMean: 19,
            standsOut: true,
          ),
        ],
      ),
    );
    expect(find.text('Dive shape'), findsOneWidget);
    expect(find.text('Stands out'), findsOneWidget);
    expect(find.text('Stands out: Max depth'), findsOneWidget);
    expect(find.text('3 of 4 dives'), findsOneWidget);
    expect(find.textContaining('12'), findsWidgets);
  });

  testWidgets('a categorical factor lists shares as percentages', (
    tester,
  ) async {
    await pump(
      tester,
      const FocusFactorReport(
        tooFewDives: false,
        factors: [
          CategoricalFactor(
            id: FocusFactorId.gas,
            groupCovered: 4,
            groupSize: 4,
            top: [
              CategoryShare(
                key: 'nitrox',
                groupShare: 0.75,
                baselineShare: 0.4,
                groupCount: 3,
                standsOut: true,
              ),
            ],
          ),
        ],
      ),
    );
    expect(find.text('Gas'), findsOneWidget);
    expect(find.textContaining('Nitrox'), findsOneWidget);
    expect(find.textContaining('75%'), findsOneWidget);
    expect(find.textContaining('40%'), findsOneWidget);
  });

  testWidgets('a factor nobody recorded reads Not recorded', (tester) async {
    await pump(
      tester,
      const FocusFactorReport(
        tooFewDives: false,
        factors: [
          NumericFactor(
            id: FocusFactorId.waterTemp,
            groupCovered: 0,
            groupSize: 3,
            groupMean: null,
            baselineMean: 24,
            standsOut: false,
          ),
        ],
      ),
    );
    expect(find.text('Not recorded'), findsOneWidget);
  });

  testWidgets('a Fahrenheit temperature difference is a delta, not a reading', (
    tester,
  ) async {
    await pump(
      tester,
      const FocusFactorReport(
        tooFewDives: false,
        factors: [
          NumericFactor(
            id: FocusFactorId.waterTemp,
            groupCovered: 3,
            groupSize: 3,
            groupMean: 26,
            baselineMean: 24,
            standsOut: false,
          ),
        ],
      ),
      settings: const AppSettings(temperatureUnit: TemperatureUnit.fahrenheit),
    );
    // 2 C warmer is 3.6 F warmer; converting the delta as a reading gives 35.6.
    expect(find.textContaining('+3.6'), findsOneWidget);
    expect(find.textContaining('35.6'), findsNothing);
  });
}
