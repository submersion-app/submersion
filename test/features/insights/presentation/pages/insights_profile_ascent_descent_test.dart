import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/presentation/pages/insights_profile_page.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockCurrentDiverIdNotifier extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  _MockCurrentDiverIdNotifier() : super(null);

  @override
  Future<void> setCurrentDiver(String id) async => state = id;

  @override
  Future<void> clearCurrentDiver() async => state = null;
}

/// The average ascent and descent tiles show their rate in the diver's depth
/// unit per minute, taken from UnitFormatter.depthRateSymbol (issue #1932).
void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpPage(WidgetTester tester, AppSettings settings) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          decoObligationStatsProvider.overrideWith(
            (ref) async => (decoCount: 0, noDecoCount: 0, unknownCount: 0),
          ),
          ascentDescentRatesProvider.overrideWith(
            (ref) async => (avgAscent: 9.0, avgDescent: 18.0),
          ),
          timeAtDepthRangesProvider.overrideWith((ref) async => []),
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith(
            (ref) => _MockSettingsNotifier(settings),
          ),
          currentDiverIdProvider.overrideWith(
            (ref) => _MockCurrentDiverIdNotifier(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InsightsProfilePage(embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('metric rates read in m/min', (tester) async {
    await pumpPage(tester, const AppSettings());

    expect(find.text('9.0 m/min'), findsOneWidget);
    expect(find.text('18.0 m/min'), findsOneWidget);
  });

  testWidgets('imperial rates convert to ft/min', (tester) async {
    await pumpPage(tester, const AppSettings(depthUnit: DepthUnit.feet));

    // 9 m/min is 29.5 ft/min; 18 m/min is 59.1 ft/min.
    expect(find.text('29.5 ft/min'), findsOneWidget);
    expect(find.text('59.1 ft/min'), findsOneWidget);
  });
}
