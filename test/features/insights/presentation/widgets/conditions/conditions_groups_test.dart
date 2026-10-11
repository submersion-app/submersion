import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/domain/conditions/conditions_row.dart';
import 'package:submersion/features/insights/presentation/providers/conditions_stats_providers.dart';
import 'package:submersion/features/insights/presentation/providers/trend_chart_settings_provider.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/site_access_condition_cards.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/surface_weather_group.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/water_movement_group.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_chart_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

/// Issue #3118: the new Conditions groups show only what is recorded and
/// report a failed query once per group.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Future<List<ConditionsRow>> Function() rows,
  ) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          conditionsRowsProvider.overrideWith((ref) => rows()),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SurfaceWeatherGroup(),
                  WaterMovementGroup(),
                  AltitudeConditionsCard(),
                  ExitMethodConditionsCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ConditionsRow row(
    String id, {
    double? airTemp,
    CloudCover? cloudCover,
    CurrentStrength? currentStrength,
    double? altitude,
    EntryMethod? exitMethod,
  }) => ConditionsRow(
    diveId: id,
    dateTime: DateTime.utc(2026, 1, 1),
    airTemp: airTemp,
    cloudCover: cloudCover,
    currentStrength: currentStrength,
    altitude: altitude,
    exitMethod: exitMethod,
  );

  testWidgets('groups with nothing recorded are hidden entirely', (
    tester,
  ) async {
    await pump(tester, () async => [row('a'), row('b')]);
    expect(find.text('Surface & Weather'), findsNothing);
    expect(find.text('Water Movement'), findsNothing);
    expect(find.text('Altitude'), findsNothing);
    expect(find.text('Exit Method'), findsNothing);
  });

  testWidgets('shows only the cards that have data', (tester) async {
    await pump(
      tester,
      () async => [
        row('a', cloudCover: CloudCover.clear),
        row('b', currentStrength: CurrentStrength.light),
        row('c'),
      ],
    );
    expect(find.text('Surface & Weather'), findsOneWidget);
    expect(find.text('Cloud Cover'), findsOneWidget);
    expect(find.text('Precipitation'), findsNothing);
    expect(find.text('Air Temperature Over Time'), findsNothing);
    expect(find.text('Water Movement'), findsOneWidget);
    expect(find.text('Current Strength'), findsOneWidget);
    expect(find.text('Swell Height'), findsNothing);
    expect(find.text('Based on 1 of 3 dives'), findsNWidgets(2));
  });

  testWidgets('air temperature shows trend and bands', (tester) async {
    await pump(tester, () async => [row('a', airTemp: 22), row('b')]);
    expect(find.text('Air Temperature Over Time'), findsOneWidget);
    expect(find.text('Dives by Air Temperature'), findsOneWidget);
    // The trend says how many dives it covers, as every new chart does.
    final trend = find.byType(TrendChartSection);
    expect(
      find.descendant(of: trend, matching: find.text('Based on 1 of 2 dives')),
      findsOneWidget,
    );
  });

  testWidgets('altitude and exit method cards show their localized values', (
    tester,
  ) async {
    await pump(
      tester,
      () async => [row('a', altitude: 1200, exitMethod: EntryMethod.ladder)],
    );
    expect(find.text('Altitude'), findsOneWidget);
    expect(find.text('Altitude Group 2'), findsOneWidget);
    expect(find.text('Exit Method'), findsOneWidget);
    expect(find.text('Ladder'), findsOneWidget);
  });

  testWidgets('a failed query shows one error per weather group', (
    tester,
  ) async {
    await pump(tester, () async => throw StateError('boom'));
    expect(
      find.text('Failed to load weather and conditions data'),
      findsNWidgets(2),
    );
    expect(find.text('Surface & Weather'), findsOneWidget);
    expect(find.text('Water Movement'), findsOneWidget);
    expect(find.text('Altitude'), findsNothing);
  });

  testWidgets('a background refresh keeps the cards instead of a spinner', (
    tester,
  ) async {
    // A sync pull or dive download re-runs the query. The cards must stay
    // mounted while it does, or the page shrinks and the diver loses their
    // scroll position.
    var calls = 0;
    final pending = Completer<List<ConditionsRow>>();
    await pump(tester, () {
      calls++;
      return calls == 1
          ? Future.value([
              row('a', cloudCover: CloudCover.clear),
              row('b', currentStrength: CurrentStrength.light),
            ])
          : pending.future;
    });
    expect(find.text('Cloud Cover'), findsOneWidget);

    ProviderScope.containerOf(
      tester.element(find.byType(SurfaceWeatherGroup)),
    ).invalidate(conditionsRowsProvider);
    await tester.pump();

    expect(calls, 2);
    expect(find.text('Cloud Cover'), findsOneWidget);
    expect(find.text('Current Strength'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    pending.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('a failed refresh hides altitude and exit, matching the groups', (
    tester,
  ) async {
    var calls = 0;
    await pump(tester, () {
      calls++;
      return calls == 1
          ? Future.value([
              row('a', altitude: 1200, exitMethod: EntryMethod.ladder),
            ])
          : Future<List<ConditionsRow>>.error(StateError('boom'));
    });
    expect(find.text('Altitude'), findsOneWidget);

    ProviderScope.containerOf(
      tester.element(find.byType(AltitudeConditionsCard)),
    ).invalidate(conditionsRowsProvider);
    await tester.pumpAndSettle();

    expect(
      find.text('Failed to load weather and conditions data'),
      findsNWidgets(2),
    );
    expect(find.text('Altitude'), findsNothing);
    expect(find.text('Exit Method'), findsNothing);
  });

  testWidgets('air temperature rate in F is a difference, not a reading', (
    tester,
  ) async {
    final settings = MockSettingsNotifier();
    await settings.setTemperatureUnit(TemperatureUnit.fahrenheit);
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final base = await getBaseOverrides(settingsNotifier: settings);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          conditionsRowsProvider.overrideWith(
            (ref) async => [row('a', airTemp: 22)],
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: SurfaceWeatherGroup()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final section = tester.widget<TrendChartSection>(
      find.byType(TrendChartSection),
    );
    expect(section.chartId, TrendChartIds.airTemp);
    // 1 C per year is 1.8 F per year, never 33.8 F.
    expect(section.rateFormatter!(1), '1.8°F');
  });

  testWidgets('while loading each weather group shows one spinner', (
    tester,
  ) async {
    final pending = Completer<List<ConditionsRow>>();
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          conditionsRowsProvider.overrideWith((ref) => pending.future),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SurfaceWeatherGroup(),
                  WaterMovementGroup(),
                  AltitudeConditionsCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Surface & Weather'), findsOneWidget);
    expect(find.text('Water Movement'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    expect(find.text('Altitude'), findsNothing);

    pending.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('every cloud cover and current strength has its own colour', (
    tester,
  ) async {
    await pump(
      tester,
      () async => [
        for (var i = 0; i < 4; i++)
          row(
            'd$i',
            cloudCover: CloudCover.values[i],
            currentStrength: CurrentStrength.values[i],
          ),
      ],
    );
    final pies = tester.widgetList<PieChart>(find.byType(PieChart)).toList();
    expect(pies, hasLength(2));
    for (final pie in pies) {
      final colors = pie.data.sections.map((s) => s.color).toSet();
      expect(colors, hasLength(4));
    }
  });
}
