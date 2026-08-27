import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

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

    // When a non-finite sample is dropped, the surviving samples and the
    // plotted spots must stay index-aligned so a touched spot resolves to the
    // right sample in the tooltip (previously it indexed the unfiltered list).
    test('plottableSamples stays in lockstep with spotsFor', () {
      final samples = [
        _s(0, 0, 2),
        _s(60, 10, double.nan), // dropped
        _s(120, 5, 1.5),
      ];
      final plotted = BuoyancyChart.plottableSamples(samples, units);
      final spots = BuoyancyChart.spotsFor(samples, units);
      expect(plotted.length, spots.length);
      // Spot index 1 maps to the t=120 sample, not the dropped NaN sample.
      expect(plotted[1].timestamp, 120);
      expect(spots[1].x, closeTo(2.0, 1e-9)); // 120 s -> 2 min
    });
  });

  testWidgets('renders a LineChart with labelled axes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: _ChartHost()),
      ),
    );
    expect(find.byType(LineChart), findsOneWidget);
    // Axis name labels are present (X = time, Y = net in the weight unit).
    expect(find.text('Time (min)'), findsOneWidget);
    expect(find.textContaining('Net'), findsWidgets);
  });

  testWidgets('renders nothing for fewer than two samples', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BuoyancyChart(result: _result([_s(0, 0, 2)]), units: units),
        ),
      ),
    );
    expect(find.byType(LineChart), findsNothing);
  });
}

class _ChartHost extends StatelessWidget {
  const _ChartHost();
  @override
  Widget build(BuildContext context) => BuoyancyChart(
    result: _result([_s(0, 0, 2), _s(60, 10, 1), _s(120, 5, 1.5)]),
    units: const UnitFormatter(AppSettings()),
  );
}
