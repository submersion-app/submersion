import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_distance_timeline.dart';
import 'package:submersion/features/insights/presentation/pages/insights_profile_page.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/providers/vertical_distance_providers.dart';
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

/// The total ascent and descent card, then the max depths card, sit on the
/// Profile page under the average rates card (issue #4569).
void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('both cards sit between the rates and time at depth', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

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
          verticalDistanceTimelineProvider.overrideWith(
            (ref) async => VerticalDistanceTimeline([
              const DiveVerticalDistance(
                diveId: 'a',
                startMillis: 0,
                meters: 30,
                estimated: false,
              ),
            ]),
          ),
          maxDepthTimelineProvider.overrideWith(
            (ref) async => VerticalDistanceTimeline([
              const DiveVerticalDistance(
                diveId: 'a',
                startMillis: 0,
                meters: 20,
                estimated: false,
              ),
            ]),
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith(
            (ref) => _MockSettingsNotifier(const AppSettings()),
          ),
          currentDiverIdProvider.overrideWith(
            (ref) => _MockCurrentDiverIdNotifier(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: InsightsProfilePage(embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    double top(String title) => tester.getTopLeft(find.text(title)).dy;
    final card = top('Total Ascent & Descent');
    expect(card, greaterThan(top('Average Ascent & Descent Rates')));
    expect(card, lessThan(top('Time at Depth Ranges')));
    final maxDepths = top('Max Depths Added Up');
    // Beside it at this width, on the same line.
    expect(maxDepths, card);
    expect(maxDepths, lessThan(top('Time at Depth Ranges')));
  });
}
