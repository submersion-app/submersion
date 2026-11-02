import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/ccr_gas_use_trend.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/ccr_gas_use_section.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The Rebreather gas use card: averages over one chart with both lines,
/// and nothing at all for a diver with no CCR dives (issue #4082).
TrendDataPoint _point(int day, double value) => TrendDataPoint(
  date: DateTime.utc(2026, 1, day),
  value: value,
  diveId: 'dive-$day',
);

Future<void> _pump(
  WidgetTester tester,
  Future<CcrGasUseTrend> Function() trend, {
  AppSettings settings = const AppSettings(),
}) async {
  final overrides = await getBaseOverrides(
    settingsNotifier: MockSettingsNotifier(settings),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        ccrGasUseTrendProvider.overrideWith((ref) => trend()),
      ].cast(),
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: CcrGasUseSection())),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  testWidgets('hidden when there are no CCR dives', (tester) async {
    await _pump(tester, () async => const CcrGasUseTrend(o2: [], diluent: []));
    expect(find.text('Rebreather gas use'), findsNothing);
    expect(find.byType(DiveTrendChart), findsNothing);
  });

  testWidgets('hidden while loading', (tester) async {
    await _pump(tester, () => Completer<CcrGasUseTrend>().future);
    expect(find.text('Rebreather gas use'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('hidden on an error', (tester) async {
    await _pump(tester, () async => throw StateError('no'));
    expect(find.text('Rebreather gas use'), findsNothing);
  });

  testWidgets('shows both averages and both series', (tester) async {
    await _pump(
      tester,
      () async => CcrGasUseTrend(
        o2: [_point(1, 1.2), _point(2, 1.6)],
        diluent: [_point(1, 3.0)],
      ),
    );

    expect(find.text('Rebreather gas use'), findsOneWidget);
    expect(find.text('1.4 L/min'), findsOneWidget);
    expect(find.text('O₂ average'), findsOneWidget);
    expect(find.text('3.0 L/min'), findsOneWidget);
    expect(find.text('Diluent average'), findsOneWidget);
    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.points, hasLength(2));
    expect(chart.secondarySeries.single.points, hasLength(1));
    expect(chart.secondarySeries.single.color, isNot(chart.pointColor));
  });

  testWidgets('a diver with diluent data only still gets the card', (
    tester,
  ) async {
    await _pump(
      tester,
      () async => CcrGasUseTrend(o2: const [], diluent: [_point(1, 3.0)]),
    );

    expect(find.text('O₂ average'), findsNothing);
    expect(find.text('Diluent average'), findsOneWidget);
    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.points, isEmpty);
    expect(chart.secondarySeries.single.points, hasLength(1));
  });

  testWidgets('a diver with O2 data only draws no second series', (
    tester,
  ) async {
    await _pump(
      tester,
      () async => CcrGasUseTrend(o2: [_point(1, 1.2)], diluent: const []),
    );

    expect(find.text('Diluent average'), findsNothing);
    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.secondarySeries, isEmpty);
  });

  testWidgets('selecting a point opens the dive', (tester) async {
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: SingleChildScrollView(child: CcrGasUseSection()),
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
          ccrGasUseTrendProvider.overrideWith(
            (ref) async =>
                CcrGasUseTrend(o2: [_point(1, 1.2)], diluent: [_point(1, 3.0)]),
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

  testWidgets('follows imperial units', (tester) async {
    const settings = AppSettings(volumeUnit: VolumeUnit.cubicFeet);
    await _pump(
      tester,
      () async => CcrGasUseTrend(o2: [_point(1, 1.8)], diluent: const []),
      settings: settings,
    );

    final expected = const UnitFormatter(settings).formatRmv(1.8);
    expect(expected, isNot(contains('L/min')));
    expect(find.text(expected), findsOneWidget);
  });
}
