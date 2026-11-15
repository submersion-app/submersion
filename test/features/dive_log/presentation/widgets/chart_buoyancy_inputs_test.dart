import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/chart_buoyancy_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/chart_buoyancy_inputs.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Issue #4593: what every profile surface (dive page, dashboard preview,
/// planner, list pane, full screen) hands the chart. The simulation runs only
/// while the line is on: the dashboard preview renders on the app's first
/// frame and must not pay for a line that is off.
void main() {
  const diveId = 'dive-1';
  final drawn = [
    for (final t in [0, 10, 20]) DiveProfilePoint(timestamp: t, depth: 10),
  ];

  BuoyancyTwinResult result() => runBuoyancyTwin(
    TwinInput(
      profile: [
        for (final p in drawn)
          TwinProfileSample(timestamp: p.timestamp, depthM: p.depth),
      ],
      tanks: const [],
      suit: const TwinSuitInput(
        kind: TwinSuitKind.none,
        anchorKg: 0,
        source: TermSource.physics,
      ),
      staticTerms: const [],
      leadKg: 2,
      droppableLeadKg: 0,
      environment: DiveEnvironment.standard,
      totalMassKg: 80,
    ),
  );

  Future<({int runs, ChartBuoyancyInputs inputs})> pump(
    WidgetTester tester, {
    required bool lineOn,
    required bool modelable,
    ProfileRightAxisMetric defaultRightAxis =
        ProfileRightAxisMetric.temperature,
  }) async {
    var runs = 0;
    late ChartBuoyancyInputs inputs;
    final model = result();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _TestSettingsNotifier(
              AppSettings(
                defaultShowBuoyancy: lineOn,
                defaultRightAxisMetric: defaultRightAxis,
              ),
            ),
          ),
          buoyancyModelableProvider(
            diveId,
          ).overrideWith((ref) async => modelable),
          chartBuoyancyTwinProvider(diveId).overrideWith((ref) async {
            runs++;
            return model;
          }),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            inputs = watchChartBuoyancy(ref, diveId, drawn);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (runs: runs, inputs: inputs);
  }

  testWidgets('dashboard does not run the model while off', (tester) async {
    final got = await pump(tester, lineOn: false, modelable: true);
    expect(got.runs, 0);
    expect(got.inputs.available, isTrue);
    expect(got.inputs.curve, isNull);
  });

  testWidgets('runs the model once the line is on', (tester) async {
    final got = await pump(tester, lineOn: true, modelable: true);
    expect(got.runs, 1);
    expect(got.inputs.curve, hasLength(3));
    expect(got.inputs.curve!.every((v) => v != null), isTrue);
  });

  testWidgets('runs the model for a buoyancy right axis with the line off', (
    tester,
  ) async {
    // Every other right-axis metric reads without its line shown; without
    // the curve this axis would silently fall back to another metric.
    final got = await pump(
      tester,
      lineOn: false,
      modelable: true,
      defaultRightAxis: ProfileRightAxisMetric.buoyancy,
    );
    expect(got.runs, 1);
    expect(got.inputs.curve, hasLength(3));
  });

  testWidgets('an unmodelable dive offers nothing and runs nothing', (
    tester,
  ) async {
    final got = await pump(tester, lineOn: true, modelable: false);
    expect(got.runs, 0);
    expect(got.inputs.available, isFalse);
    expect(got.inputs.curve, isNull);
  });

  testWidgets('the curve keeps its identity across rebuilds', (tester) async {
    // The chart keys its cached bars on the curve's identity, so a new list
    // on every build would redraw the whole analysis layer each frame.
    final model = result();
    final seen = <List<double?>?>[];
    final rebuild = ValueNotifier(0);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _TestSettingsNotifier(
              const AppSettings(defaultShowBuoyancy: true),
            ),
          ),
          buoyancyModelableProvider(diveId).overrideWith((ref) async => true),
          chartBuoyancyTwinProvider(diveId).overrideWith((ref) async => model),
        ],
        child: ValueListenableBuilder<int>(
          valueListenable: rebuild,
          builder: (context, _, _) => Consumer(
            builder: (context, ref, _) {
              seen.add(watchChartBuoyancy(ref, diveId, drawn).curve);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    rebuild.value++;
    await tester.pump();
    final curves = seen.whereType<List<double?>>().toList();
    expect(curves.length, greaterThanOrEqualTo(2));
    expect(identical(curves[curves.length - 2], curves.last), isTrue);
  });

  testWidgets('a rebuilt drawn series with the same samples keeps the curve', (
    tester,
  ) async {
    // Surfaces rebuild the drawn list each build (heart rate merged in), so
    // the cache must not hang on the list's identity.
    final model = result();
    final seen = <List<double?>?>[];
    final rebuild = ValueNotifier(0);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _TestSettingsNotifier(
              const AppSettings(defaultShowBuoyancy: true),
            ),
          ),
          buoyancyModelableProvider(diveId).overrideWith((ref) async => true),
          chartBuoyancyTwinProvider(diveId).overrideWith((ref) async => model),
        ],
        child: ValueListenableBuilder<int>(
          valueListenable: rebuild,
          builder: (context, _, _) => Consumer(
            builder: (context, ref, _) {
              seen.add(watchChartBuoyancy(ref, diveId, [...drawn]).curve);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    rebuild.value++;
    await tester.pump();
    final curves = seen.whereType<List<double?>>().toList();
    expect(curves.length, greaterThanOrEqualTo(2));
    expect(identical(curves[curves.length - 2], curves.last), isTrue);
  });
}
