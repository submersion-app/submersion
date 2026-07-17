import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

BuoyancyTwinResult _result(List<TwinSample> samples) => BuoyancyTwinResult(
  samples: samples,
  staticKg: 5,
  suitSurfaceKg: 3.9,
  drysuitGasLiters: 0,
  pressuresEstimated: false,
  input: TwinInput(
    profile: const [],
    tanks: const [],
    suit: const TwinSuitInput(
      kind: TwinSuitKind.none,
      anchorKg: 0,
      source: TermSource.typeDefault,
    ),
    staticTerms: const [],
    leadKg: 6,
    droppableLeadKg: 4,
    environment: DiveEnvironment.forConditions(),
  ),
);

TwinSample _s(int t, double depth, double net) =>
    TwinSample(timestamp: t, depthM: depth, suitKg: 3, tanksKg: 0, netKg: net);

void main() {
  const units = UnitFormatter(AppSettings());

  group('BuoyancyChart.spotsFor', () {
    test('one spot per sample, x in minutes', () {
      final spots = BuoyancyChart.spotsFor([
        _s(0, 0, 2),
        _s(60, 10, 1),
        _s(120, 5, 1.5),
      ], units);
      expect(spots.length, 3);
      expect(spots[1].x, closeTo(1.0, 1e-9)); // 60 s -> 1 min
    });

    test('drops non-finite net values (NaN-FlSpot crash guard)', () {
      final spots = BuoyancyChart.spotsFor([
        _s(0, 0, 2),
        _s(60, 10, double.nan),
        _s(120, 5, 1.5),
      ], units);
      expect(spots.length, 2);
      expect(spots.every((s) => s.y.isFinite), isTrue);
    });
  });

  testWidgets('renders a LineChart for a multi-sample result', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BuoyancyChart(
            result: _result([_s(0, 0, 2), _s(60, 10, 1), _s(120, 5, 1.5)]),
            units: units,
          ),
        ),
      ),
    );
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('renders nothing for fewer than two samples', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BuoyancyChart(result: _result([_s(0, 0, 2)]), units: units),
        ),
      ),
    );
    expect(find.byType(LineChart), findsNothing);
  });
}
