import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/domain/conditions/conditions_row.dart';
import 'package:submersion/features/insights/presentation/providers/conditions_stats_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/site_access_condition_cards.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/surface_weather_group.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/water_movement_group.dart';
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
    await pump(tester, () async => [row('a', airTemp: 22)]);
    expect(find.text('Air Temperature Over Time'), findsOneWidget);
    expect(find.text('Dives by Air Temperature'), findsOneWidget);
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
}
