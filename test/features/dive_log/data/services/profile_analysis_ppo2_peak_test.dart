import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

/// Issue #3959: the oxygen summary reports the highest ppO2 the dive reached,
/// at the depth it was reached, not the highest interval average that CNS and
/// OTU integrate.
void main() {
  final service = ProfileAnalysisService(gfLow: 0.3, gfHigh: 0.7);
  const calculator = O2ToxicityCalculator();

  group('open circuit', () {
    const ean34 = ProfileGasSegment(startTimestamp: 0, fN2: 0.66);

    ProfileAnalysis analyzeOc({List<ProfileGasSegment>? gasSegments}) =>
        service.analyze(
          diveId: 'oc-peak',
          depths: const [30.0, 40.0, 30.0],
          timestamps: const [0, 120, 240],
          o2Fraction: 0.34,
          gasSegments: gasSegments,
        );

    test('a gas schedule keeps the peak the chart shows', () {
      final analysis = analyzeOc(gasSegments: const [ean34]);

      expect(analysis.ppO2Curve[1], closeTo(1.70, 1e-9));
      expect(analysis.o2Exposure.maxPpO2, closeTo(1.70, 1e-9));
      expect(analysis.o2Exposure.maxPpO2Depth, 40.0);
      expect(analysis.o2Exposure.ppO2Critical, isTrue);
      expect(analysis.hadPpO2Critical, isTrue);
    });

    test('a single gas with no schedule keeps the peak too', () {
      final analysis = analyzeOc();

      expect(analysis.o2Exposure.maxPpO2, closeTo(1.70, 1e-9));
      expect(analysis.o2Exposure.maxPpO2Depth, 40.0);
      expect(analysis.o2Exposure.ppO2Critical, isTrue);
    });

    test('CNS and OTU still integrate the interval average', () {
      final exposure = analyzeOc(gasSegments: const [ean34]).o2Exposure;

      // Both intervals average 35 m: 4.5 bar x 0.34 = 1.53 bar.
      expect(
        exposure.cnsEnd,
        closeTo(calculator.calculateCnsForSegment(1.53, 120) * 2, 1e-9),
      );
      expect(
        exposure.otu,
        closeTo(calculator.calculateOtuForSegment(1.53, 120) * 2, 1e-9),
      );
    });

    test('a gas switched between samples peaks at the switch', () {
      // Air from 20 m, EAN50 from 15 m at 100 s. Neither sample sees 1.25 bar.
      final analysis = service.analyze(
        diveId: 'oc-mid-interval-switch',
        depths: const [20.0, 10.0],
        timestamps: const [0, 200],
        o2Fraction: 0.21,
        gasSegments: const [
          ProfileGasSegment(startTimestamp: 0, fN2: 0.79),
          ProfileGasSegment(startTimestamp: 100, fN2: 0.5),
        ],
      );

      expect(analysis.o2Exposure.maxPpO2, closeTo(1.25, 1e-9));
      expect(analysis.o2Exposure.maxPpO2Depth, closeTo(15.0, 1e-9));
    });

    test('the richer gas counts up to the sample that leaves it', () {
      // EAN50 down to 30 m, trimix 18/45 from the moment 30 m is reached. The
      // chart reads the new gas at that sample; the diver arrived on EAN50.
      final analysis = service.analyze(
        diveId: 'oc-switch-on-sample',
        depths: const [20.0, 30.0, 30.0],
        timestamps: const [0, 60, 120],
        o2Fraction: 0.5,
        gasSegments: const [
          ProfileGasSegment(startTimestamp: 0, fN2: 0.5),
          ProfileGasSegment(startTimestamp: 60, fN2: 0.37, fHe: 0.45),
        ],
      );

      expect(analysis.ppO2Curve[1], closeTo(0.72, 1e-9));
      expect(analysis.o2Exposure.maxPpO2, closeTo(2.0, 1e-9));
      expect(analysis.o2Exposure.maxPpO2Depth, 30.0);
    });

    test('a switch on the last sample still counts the new gas', () {
      final analysis = service.analyze(
        diveId: 'oc-switch-on-last-sample',
        depths: const [20.0, 20.0],
        timestamps: const [0, 60],
        o2Fraction: 0.21,
        gasSegments: const [
          ProfileGasSegment(startTimestamp: 0, fN2: 0.79),
          ProfileGasSegment(startTimestamp: 60, fN2: 0.5),
        ],
      );

      expect(analysis.ppO2Curve.last, closeTo(1.5, 1e-9));
      expect(analysis.o2Exposure.maxPpO2, closeTo(1.5, 1e-9));
    });

    test('a peak on a repeated timestamp is not skipped', () {
      final analysis = service.analyze(
        diveId: 'oc-repeated-timestamp',
        depths: const [20.0, 20.0, 40.0, 20.0],
        timestamps: const [0, 60, 60, 120],
        o2Fraction: 0.34,
        gasSegments: const [ean34],
      );

      expect(analysis.o2Exposure.maxPpO2, closeTo(1.70, 1e-9));
      expect(analysis.o2Exposure.maxPpO2Depth, 40.0);
    });
  });

  group('rebreather', () {
    ProfileAnalysis analyzeLoop({
      required DiveMode diveMode,
      required List<double> depths,
      required List<int> timestamps,
      List<double>? ppO2,
    }) => service.analyze(
      diveId: 'loop-peak',
      depths: depths,
      timestamps: timestamps,
      o2Fraction: 0.21,
      diveMode: diveMode,
      rebreatherPpO2Curve: ppO2,
    );

    test('a measured CCR spike reaches the summary and the critical flag', () {
      final analysis = analyzeLoop(
        diveMode: DiveMode.ccr,
        depths: const [20.0, 20.0, 20.0],
        timestamps: const [0, 30, 60],
        ppO2: const [1.3, 1.8, 1.3],
      );

      expect(analysis.ppO2Curve, const [1.3, 1.8, 1.3]);
      expect(analysis.o2Exposure.maxPpO2, closeTo(1.8, 1e-9));
      expect(analysis.o2Exposure.ppO2Critical, isTrue);
    });

    test('the peak depth is a sampled depth, not a midpoint', () {
      final analysis = analyzeLoop(
        diveMode: DiveMode.ccr,
        depths: const [10.0, 25.0, 40.0],
        timestamps: const [0, 30, 60],
        ppO2: const [1.2, 1.8, 1.2],
      );

      expect(analysis.o2Exposure.maxPpO2Depth, 25.0);
    });

    test('a measured SCR spike reaches the summary and the critical flag', () {
      final analysis = analyzeLoop(
        diveMode: DiveMode.scr,
        depths: const [20.0, 24.0, 20.0],
        timestamps: const [0, 30, 60],
        ppO2: const [1.1, 1.7, 1.1],
      );

      expect(analysis.o2Exposure.maxPpO2, closeTo(1.7, 1e-9));
      expect(analysis.o2Exposure.maxPpO2Depth, 24.0);
      expect(analysis.o2Exposure.ppO2Critical, isTrue);
    });

    test('a constant setpoint reports the deepest depth it was held at', () {
      final analysis = analyzeLoop(
        diveMode: DiveMode.ccr,
        depths: const [0.0, 20.0, 30.0, 30.0, 0.0],
        timestamps: const [0, 60, 120, 600, 900],
        ppO2: List<double>.filled(5, 1.3),
      );

      expect(analysis.o2Exposure.maxPpO2, 1.3);
      expect(analysis.o2Exposure.maxPpO2Depth, 30.0);
    });

    test('an unknown loop ppO2 reports no peak and no depth', () {
      final analysis = analyzeLoop(
        diveMode: DiveMode.ccr,
        depths: const [0.0, 30.0, 0.0],
        timestamps: const [0, 300, 600],
      );

      expect(analysis.o2Exposure.maxPpO2, 0.0);
      expect(analysis.o2Exposure.maxPpO2Depth, 0.0);
    });
  });
}
