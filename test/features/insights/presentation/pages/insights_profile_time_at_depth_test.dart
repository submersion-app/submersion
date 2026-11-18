import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/series_profile_aggregates.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_distance_timeline.dart';
import 'package:submersion/features/insights/presentation/pages/insights_profile_page.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/providers/vertical_distance_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/category_bar_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier(DepthUnit unit) : super(AppSettings(depthUnit: unit));

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

/// Time at depth on the Profile page: hour scaling and adaptive bands
/// (issue #4600).
void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpPage(
    WidgetTester tester,
    List<DepthBucket> buckets, {
    DepthUnit unit = DepthUnit.meters,
  }) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          decoObligationStatsProvider.overrideWith(
            (ref) async => (decoCount: 0, noDecoCount: 0, unknownCount: 0),
          ),
          ascentDescentRatesProvider.overrideWith(
            (ref) async => (avgAscent: null, avgDescent: null),
          ),
          timeAtDepthRangesProvider.overrideWith((ref) async => buckets),
          verticalDistanceTimelineProvider.overrideWith(
            (ref) async => VerticalDistanceTimeline.empty,
          ),
          maxDepthTimelineProvider.overrideWith(
            (ref) async => VerticalDistanceTimeline.empty,
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => _MockSettingsNotifier(unit)),
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
  }

  CategoryBarChart chart(WidgetTester tester) =>
      tester.widget<CategoryBarChart>(find.byType(CategoryBarChart));

  testWidgets('a large log reads in hours with an open-ended last band', (
    tester,
  ) async {
    await pumpPage(tester, [
      for (var i = 0; i < 7; i++)
        (lowerDepth: i * 10, upperDepth: i * 10 + 10, minutes: 9000),
      (lowerDepth: 70, upperDepth: null, minutes: 66240),
    ]);

    final c = chart(tester);
    expect(c.data.last.label, '70+');
    expect(c.yAxisLabel, 'h');
    expect(c.yAxisScale, 60);
    expect(c.valueFormatter!(66240), '1,104 h');
  });

  testWidgets('a small log stays in minutes', (tester) async {
    await pumpPage(tester, [
      (lowerDepth: 0, upperDepth: 10, minutes: 120),
      (lowerDepth: 10, upperDepth: 20, minutes: 45),
    ]);

    final c = chart(tester);
    expect(c.yAxisLabel, 'min');
    expect(c.yAxisScale, 1);
    expect(c.valueFormatter!(120), '120 min');
  });

  testWidgets('feet bands are labelled as given, not converted again', (
    tester,
  ) async {
    await pumpPage(tester, unit: DepthUnit.feet, [
      (lowerDepth: 0, upperDepth: 30, minutes: 20),
      (lowerDepth: 30, upperDepth: 60, minutes: 10),
    ]);

    final c = chart(tester);
    expect(c.data.map((d) => d.label), ['0-30', '30-60']);
    expect(c.xAxisLabel, 'ft');
  });

  testWidgets('crowded bands shorten to the depth each one starts at', (
    tester,
  ) async {
    await pumpPage(tester, [
      (lowerDepth: 0, upperDepth: 30, minutes: 20),
      (lowerDepth: 30, upperDepth: null, minutes: 10),
    ]);

    final c = chart(tester);
    expect(c.compactXLabelsToFit, isTrue);
    expect(c.compactXLabelFormatter!('120-150'), '120');
    // The open-ended band keeps its plus: it is already short.
    expect(c.compactXLabelFormatter!('210+'), '210+');
  });
}
