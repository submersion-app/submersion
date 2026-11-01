import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/derived_metrics_service.dart';
import 'package:submersion/features/dive_log/domain/services/gas_time_remaining.dart';
import 'package:submersion/features/dive_log/domain/services/range_gas_consumption.dart';

/// Issue #3958: every consumption rate read from a logged dive divides by the
/// ambient pressure of the selected site, the one its deco replay runs in.
void main() {
  final environment = DiveEnvironment.forConditions(
    altitudeMeters: 3000,
    waterType: WaterType.fresh,
  );
  const depth = 20.0;
  final ambient = environment.pressureAtDepth(depth);
  const standardAmbient = 3.0;

  // A flat 10 minutes at 20 m, 200 down to 100 bar: 10 bar/min at depth.
  final timestamps = [for (var t = 0; t <= 600; t += 10) t];
  final depths = [for (final _ in timestamps) depth];
  final pressures = [for (final t in timestamps) 200 - t / 6];

  group('ProfileAnalysisService', () {
    ProfileAnalysis analyze(DiveEnvironment environment) =>
        ProfileAnalysisService(environment: environment).analyze(
          diveId: 'sac',
          depths: depths,
          timestamps: timestamps,
          pressures: pressures,
        );

    test('the SAC curve reads the site pressure', () {
      expect(analyze(environment).sacCurve!.last, closeTo(10 / ambient, 1e-6));
    });

    test('the rolling SAC reads the site pressure', () {
      expect(
        analyze(environment).smoothedSacCurve![30],
        closeTo(10 / ambient, 1e-6),
      );
    });

    test('the SAC segments read the site pressure', () {
      expect(
        analyze(environment).sacSegments!.first.sacRate,
        closeTo(10 / ambient, 1e-6),
      );
    });

    test('gas time remaining reads the site pressure', () {
      final atSite = analyze(environment).gtrCurve!;
      final standard = analyze(DiveEnvironment.standard).gtrCurve!;

      expect(atSite.last, isNotNull);
      // The same drop at depth burns the same bar per minute at depth, but a
      // shallower ambient means a cheaper direct ascent, so more time is left.
      expect(atSite.last!, greaterThan(standard.last!));
    });
  });

  group('calculateGtrCurve', () {
    test('values the ascent at the site pressure', () {
      final gtr = calculateGtrCurve(
        depths: depths,
        timestamps: timestamps,
        pressures: pressures,
        reserveBar: 50,
        environment: environment,
      ).last!;

      // 10 bar/min at depth. The ascent is 20 m at 9 m/min, around the
      // pressure at 10 m.
      final sac = 10 / ambient;
      final ascentBar =
          sac *
          (depth / gtrAscentRateMetersPerMinute) *
          environment.pressureAtDepth(10);
      final seconds = ((100 - 50 - ascentBar) / 10 * 60).floor();
      expect(gtr, inInclusiveRange(seconds - 1, seconds + 1));
    });
  });

  group('rangeGasConsumption', () {
    const tank = DiveTank(id: 'bg', volume: 12, role: TankRole.backGas);
    final series = {
      'bg': [
        for (var t = 0; t <= 600; t += 60)
          TankPressurePoint(tankId: 'bg', timestamp: t, pressure: 200 - t / 6),
      ],
    };

    test('SAC and RMV read the site pressure', () {
      final result = rangeGasConsumption(
        tanks: const [tank],
        tankPressures: series,
        startTimestamp: 0,
        endTimestamp: 600,
        profile: const [
          DiveProfilePoint(timestamp: 0, depth: depth),
          DiveProfilePoint(timestamp: 600, depth: depth),
        ],
        model: GasModel.ideal,
        environment: environment,
      );

      expect(result.sac, closeTo(10 / ambient, 1e-9));
      expect(result.rmv, closeTo(120 / ambient, 1e-9));
    });
  });

  group('GasAnalysisService', () {
    const service = GasAnalysisService(gasModel: GasModel.ideal);
    const tank = DiveTank(
      id: 't1',
      volume: 12,
      startPressure: 200,
      endPressure: 100,
      role: TankRole.backGas,
    );
    const stage = DiveTank(
      id: 't2',
      volume: 12,
      startPressure: 200,
      endPressure: 100,
      role: TankRole.stage,
    );
    final profile = [
      for (var t = 0; t <= 600; t += 10)
        DiveProfilePoint(timestamp: t, depth: depth),
    ];
    final tankPressures = {
      't1': [
        for (var t = 0; t <= 600; t += 30)
          TankPressurePoint(tankId: 't1', timestamp: t, pressure: 200 - t / 6),
      ],
      't2': [
        for (var t = 0; t <= 600; t += 30)
          TankPressurePoint(tankId: 't2', timestamp: t, pressure: 200 - t / 6),
      ],
    };
    final gasSwitches = [
      GasSwitchWithTank(
        gasSwitch: GasSwitch(
          id: 's1',
          diveId: 'd1',
          timestamp: 300,
          tankId: 't2',
          createdAt: DateTime.utc(2026),
        ),
        tankName: 'Stage',
        gasMix: 'Air',
        o2Fraction: 0.21,
        heFraction: 0,
      ),
    ];

    void expectSegmentRead(SacSegment atSite, SacSegment standard) {
      expect(
        atSite.sacRate,
        closeTo(standard.sacRate * standardAmbient / ambient, 1e-6),
      );
      // The same gas left the cylinder, whatever the water.
      expect(atSite.gasConsumed, closeTo(standard.gasConsumed, 1e-6));
    }

    test('gas-switch segments read the site pressure', () {
      List<SacSegment>? segments(DiveEnvironment environment) =>
          service.calculateGasSwitchSegments(
            profile: profile,
            tanks: const [tank, stage],
            gasSwitches: gasSwitches,
            tankPressures: tankPressures,
            environment: environment,
          );

      expectSegmentRead(
        segments(environment)!.first,
        segments(DiveEnvironment.standard)!.first,
      );
    });

    test('phase segments read the site pressure', () {
      // Descent, bottom and ascent, so there are phases to read.
      final phased = [
        for (var t = 0; t <= 600; t += 10)
          DiveProfilePoint(
            timestamp: t,
            depth: t < 120
                ? depth * t / 120
                : t > 480
                ? depth * (600 - t) / 120
                : depth,
          ),
      ];
      List<SacSegment>? segments(DiveEnvironment environment) =>
          service.calculatePhaseSegments(
            profile: phased,
            tanks: const [tank],
            tankPressures: tankPressures,
            environment: environment,
          );

      final atSite = segments(environment)!;
      final standard = segments(DiveEnvironment.standard)!;
      expect(atSite, isNotEmpty);
      for (var i = 0; i < atSite.length; i++) {
        final segment = atSite[i];
        expect(
          segment.sacRate,
          closeTo(
            standard[i].sacRate *
                (1 + segment.avgDepth / 10) /
                environment.pressureAtDepth(segment.avgDepth),
            1e-6,
          ),
        );
      }
    });

    test('cylinder SAC reads the dive environment', () {
      Dive dive({double? altitude, WaterType? waterType}) => Dive(
        id: 'd1',
        dateTime: DateTime.utc(2026, 1, 1),
        runtime: const Duration(minutes: 10),
        avgDepth: depth,
        tanks: const [tank],
        altitude: altitude,
        waterType: waterType,
      );

      double sacOf(Dive dive, {bool series = true}) => service
          .calculateCylinderSac(
            dive: dive,
            profile: series ? profile : const [],
            tankPressures: series ? {'t1': tankPressures['t1']!} : null,
          )
          .single
          .sacRate!;

      final altitude = dive(altitude: 3000, waterType: WaterType.fresh);
      for (final series in [true, false]) {
        expect(
          sacOf(altitude, series: series),
          closeTo(
            sacOf(dive(), series: series) * standardAmbient / ambient,
            1e-6,
          ),
        );
      }
    });
  });

  group('DerivedMetricsService', () {
    test('the bucketed SAC reads the site pressure', () {
      final samples = [
        for (var t = 0; t <= 1200; t += 10)
          ProfileSample(timestamp: t, depth: depth),
      ];
      final tank = TankPressureSeries(
        tankId: 't1',
        volumeLiters: 12,
        points: [
          for (var t = 0; t <= 1200; t += 10) (timestamp: t, bar: 200 - t / 6),
        ],
      );

      final metrics = DerivedMetricsService.compute(
        diveId: 'd1',
        samples: samples,
        tanks: [tank],
        diveMode: DiveMode.oc,
        sourceUpdatedAt: 1,
        computedAtMs: 1,
        environment: environment,
      );

      expect(metrics.sacMeanBarPerMin, closeTo(10 / ambient, 1e-6));
    });
  });
}
