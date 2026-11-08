import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/role_consumption.dart';
import 'package:submersion/features/insights/domain/role_consumption_trend.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/providers/insights_gas_lane_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/insights/presentation/widgets/rate_average_tile.dart';
import 'package:submersion/features/insights/presentation/widgets/role_consumption_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/contrast_ratio.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The Gas page's consumption by cylinder role card (issue #771).
TrendDataPoint _point(int day, double value) => TrendDataPoint(
  date: DateTime.utc(2026, 1, day),
  value: value,
  diveId: 'dive-$day',
);

Future<void> _pump(
  WidgetTester tester,
  RoleConsumptionTrend trend, {
  GasConsumptionLane lane = GasConsumptionLane.rmv,
}) async {
  final overrides = await getBaseOverrides(
    settingsNotifier: MockSettingsNotifier(const AppSettings()),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        roleConsumptionTrendProvider.overrideWith((ref) async => trend),
        insightsGasLaneOverrideProvider.overrideWith((ref) => lane),
      ].cast(),
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: RoleConsumptionSection()),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

RoleConsumptionTrend _all() => RoleConsumptionTrend(
  rmv: {
    for (final group in ConsumptionRoleGroup.values)
      group: [_point(1, 10.0 + group.index)],
  },
);

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  testWidgets('a single-group diver sees one line and one tile', (
    tester,
  ) async {
    await _pump(
      tester,
      RoleConsumptionTrend(
        rmv: {
          ConsumptionRoleGroup.bottomGas: [_point(1, 14), _point(2, 16)],
        },
      ),
    );

    expect(find.text('Consumption by cylinder role'), findsOneWidget);
    expect(find.byType(RateAverageTile), findsOneWidget);
    expect(find.text('15.0 L/min'), findsOneWidget);
    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.points, hasLength(2));
    expect(chart.pointLabel, 'Bottom gas');
    expect(chart.secondarySeries, isEmpty);
  });

  testWidgets('a technical diver sees a line per group and the left-out note', (
    tester,
  ) async {
    await _pump(
      tester,
      RoleConsumptionTrend(
        rmv: {
          ConsumptionRoleGroup.bottomGas: [_point(1, 14)],
          ConsumptionRoleGroup.stage: [_point(1, 18)],
          ConsumptionRoleGroup.deco: [_point(1, 12)],
        },
        leftOutDives: 3,
      ),
    );

    expect(find.byType(RateAverageTile), findsNWidgets(3));
    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.secondarySeries.map((s) => s.label), ['Stage', 'Deco']);
    expect(
      find.text(
        '3 dives are left out: a stage, deco, pony or bailout cylinder lost '
        'gas with no gas switch onto it',
      ),
      findsOneWidget,
    );
  });

  testWidgets('every line has its own colour', (tester) async {
    await _pump(tester, _all());

    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    final colors = {
      chart.pointColor,
      for (final s in chart.secondarySeries) s.color,
    };
    expect(colors, hasLength(ConsumptionRoleGroup.values.length));
  });

  testWidgets('with no bottom gas the first group present is primary', (
    tester,
  ) async {
    await _pump(
      tester,
      RoleConsumptionTrend(
        rmv: {
          ConsumptionRoleGroup.deco: [_point(1, 12)],
          ConsumptionRoleGroup.bailout: [_point(1, 22)],
        },
      ),
    );

    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.pointLabel, 'Deco');
    expect(chart.secondarySeries.map((s) => s.label), ['Bailout']);
  });

  testWidgets('tapping a dot opens the dive', (tester) async {
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: SingleChildScrollView(child: RoleConsumptionSection()),
          ),
        ),
        GoRoute(
          path: '/dives/:id',
          builder: (_, state) => Text('opened ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          roleConsumptionTrendProvider.overrideWith(
            (ref) async => RoleConsumptionTrend(
              rmv: {
                ConsumptionRoleGroup.bottomGas: [_point(1, 14)],
              },
            ),
          ),
          insightsGasLaneOverrideProvider.overrideWith(
            (ref) => GasConsumptionLane.rmv,
          ),
        ].cast(),
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    tester.widget<DiveTrendChart>(find.byType(DiveTrendChart)).onDiveSelected!(
      'dive-1',
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('opened dive-1'), findsOneWidget);
  });

  testWidgets('the lane toggle switches the units', (tester) async {
    await _pump(
      tester,
      RoleConsumptionTrend(
        rmv: {
          ConsumptionRoleGroup.bottomGas: [_point(1, 14)],
        },
        sac: {
          ConsumptionRoleGroup.bottomGas: [_point(1, 1.2)],
        },
      ),
      lane: GasConsumptionLane.sac,
    );

    final sac = const UnitFormatter(AppSettings()).formatSac(1.2);
    expect(find.text(sac), findsOneWidget);
    expect(find.text('14.0 L/min'), findsNothing);
  });

  testWidgets('no data shows the empty state', (tester) async {
    await _pump(
      tester,
      RoleConsumptionTrend(
        sac: {
          ConsumptionRoleGroup.bottomGas: [_point(1, 1.2)],
        },
      ),
    );

    expect(find.text('No cylinder role rates yet'), findsOneWidget);
    expect(find.byType(DiveTrendChart), findsNothing);
  });

  testWidgets('the empty state still says why dives were left out', (
    tester,
  ) async {
    await _pump(tester, const RoleConsumptionTrend(leftOutDives: 4));

    expect(find.text('No cylinder role rates yet'), findsOneWidget);
    expect(
      find.text(
        '4 dives are left out: a stage, deco, pony or bailout cylinder lost '
        'gas with no gas switch onto it',
      ),
      findsOneWidget,
    );
  });

  testWidgets('every line stands out from a dark surface', (tester) async {
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(const AppSettings()),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          roleConsumptionTrendProvider.overrideWith((ref) async => _all()),
          insightsGasLaneOverrideProvider.overrideWith(
            (ref) => GasConsumptionLane.rmv,
          ),
        ].cast(),
        child: MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: RoleConsumptionSection()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final surface = Theme.of(
      tester.element(find.byType(RoleConsumptionSection)),
    ).colorScheme.surface;
    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    for (final color in [
      chart.pointColor!,
      for (final s in chart.secondarySeries) s.color,
    ]) {
      expect(
        contrastRatio(color, surface),
        greaterThanOrEqualTo(3),
        reason: '$color',
      );
    }
  });

  testWidgets('five tiles fit a 360 px wide screen', (tester) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pump(tester, _all());

    expect(tester.takeException(), isNull);
    expect(find.byType(RateAverageTile), findsNWidgets(5));
  });
}
