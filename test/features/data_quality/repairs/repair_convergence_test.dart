import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/data/services/profile_repair_service.dart';
import 'package:submersion/features/data_quality/domain/detectors/depth_spike_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/impossible_rate_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/sample_gap_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/temp_anomaly_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/repairs/quality_repair_action.dart';
import 'package:submersion/features/data_quality/domain/repairs/repair_predicates.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../helpers/quality_test_helpers.dart';

/// The closed-loop contract behind issue #1001:
///
///   a one-tap profile repair, when offered, must CLEAR the finding it was
///   offered for.
///
/// `applyScanResults` reopens a `resolved` finding that the next scan still
/// produces, so a repair whose math cannot clear the flagged condition leaves
/// the user staring at an unchanged list while the UI reports success. The
/// escape hatch is to offer no automatic repair at all -- these tests accept
/// that, and separately pin the shapes that MUST stay repairable so the
/// contract cannot be satisfied by removing every button.
void main() {
  List<domain.DiveProfilePoint> toPoints(List<QualitySample> samples) => [
    for (final s in samples)
      domain.DiveProfilePoint(
        timestamp: s.t,
        depth: s.depth,
        temperature: s.temp,
      ),
  ];

  List<QualitySample> toSamples(List<domain.DiveProfilePoint> points) => [
    for (final p in points)
      QualitySample(t: p.timestamp, depth: p.depth, temp: p.temperature),
  ];

  /// The profile repair the mapping offers for [finding], or null when it
  /// only navigates.
  List<domain.DiveProfilePoint> Function(List<domain.DiveProfilePoint>)?
  offeredRepair(QualityFinding finding) {
    for (final action in repairOptionsFor(finding)) {
      switch (action) {
        case DespikeRepair():
          return ProfileRepairService.despike;
        case SmoothRatesRepair():
          return ProfileRepairService.smoothImpossibleRates;
        case ClampNegativeDepthsRepair():
          return ProfileRepairService.clampNegativeDepths;
        case FillGapsRepair():
          return ProfileRepairService.fillGaps;
        case SmoothTemperatureRepair():
          return ProfileRepairService.smoothTemperature;
        case ConvertTemperatureRepair(:final kelvinScale):
          return (points) => ProfileRepairService.convertTemperature(
            points,
            kelvinScale: kelvinScale,
          );
        default:
          continue;
      }
    }
    return null;
  }

  /// Detect over [samples], apply whatever repair is offered for the first
  /// matching finding, re-detect, and return the surviving findings. Returns
  /// null when no automatic repair is offered.
  List<QualityFinding>? repairAndRedetect({
    required List<QualitySample> samples,
    required List<QualityFinding> Function(DiveQualityContext) detect,
    bool Function(QualityFinding)? matching,
  }) {
    List<QualityFinding> run(List<QualitySample> s) {
      final all = detect(makeContext(dive: makeTestDive(), samples: s));
      return matching == null ? all : all.where(matching).toList();
    }

    final before = run(samples);
    expect(before, isNotEmpty, reason: 'test vector must trip the detector');
    final compute = offeredRepair(before.first);
    if (compute == null) return null;
    return run(toSamples(compute(toPoints(samples))));
  }

  group('impossible_rate', () {
    // Oscillating garbage: alternating 5 m / 20 m every 10 s for 2 minutes,
    // then a clean hold. Each step reads 90 m/min.
    List<QualitySample> oscillatingRun() => [
      for (var i = 0; i <= 12; i++)
        QualitySample(t: i * 10, depth: i.isEven ? 5.0 : 20.0),
      for (var t = 130; t <= 400; t += 10) QualitySample(t: t, depth: 20),
    ];

    test('the offered repair clears the finding', () {
      final after = repairAndRedetect(
        samples: oscillatingRun(),
        detect: const ImpossibleRateDetector().detect,
      );
      expect(
        after,
        isNotNull,
        reason: 'oscillating garbage must be repairable',
      );
      expect(after, isEmpty);
    });

    test('a sustained real descent is offered no automatic repair', () {
      // 40 m/min held for 60 s: past the threshold, but the endpoints are
      // genuinely that far apart, so redrawing the interior cannot help.
      final samples = [
        for (var t = 0; t <= 60; t += 10)
          QualitySample(t: t, depth: t * 40 / 60),
        for (var t = 70; t <= 400; t += 10) QualitySample(t: t, depth: 40),
      ];
      final findings = const ImpossibleRateDetector().detect(
        makeContext(dive: makeTestDive(), samples: samples),
      );
      expect(findings, isNotEmpty);
      expect(findings.single.params['interpolatable'], isFalse);
      expect(offeredRepair(findings.single), isNull);
    });
  });

  group('depth_spike', () {
    test('the negative-depth repair clears the finding', () {
      final after = repairAndRedetect(
        samples: [
          for (var t = 0; t <= 600; t += 10)
            QualitySample(t: t, depth: t >= 200 && t <= 260 ? -3.0 : 20.0),
        ],
        detect: const DepthSpikeDetector().detect,
        matching: (f) => f.params.containsKey('minDepth'),
      );
      expect(after, isNotNull, reason: 'negative depths must be repairable');
      expect(after, isEmpty);
    });

    test('the spike repair still clears an isolated spike', () {
      final after = repairAndRedetect(
        samples: [
          for (var t = 0; t <= 600; t += 10)
            QualitySample(t: t, depth: t == 300 ? 60.0 : 20.0),
        ],
        detect: const DepthSpikeDetector().detect,
        matching: (f) => f.params.containsKey('impliedRateMetersPerSecond'),
      );
      expect(after, isNotNull, reason: 'isolated spikes must be repairable');
      expect(after, isEmpty);
    });
  });

  group('temp_anomaly', () {
    test('the offered repair clears an isolated outlier', () {
      final after = repairAndRedetect(
        samples: [
          for (var t = 0; t <= 600; t += 10)
            QualitySample(t: t, depth: 20, temp: t == 300 ? 2.0 : 22.0),
        ],
        detect: const TempAnomalyDetector().detect,
        matching: (f) => f.params.containsKey('deltaC'),
      );
      expect(after, isNotNull, reason: 'isolated outliers must be repairable');
      expect(after, isEmpty);
    });

    test('a one-sided step is offered no automatic repair', () {
      // The reading drops 9 C and stays: which side is right is a judgment
      // call, and smoothing would leave the step in place anyway.
      final samples = [
        for (var t = 0; t <= 600; t += 10)
          QualitySample(t: t, depth: 20, temp: t < 300 ? 22.0 : 13.0),
      ];
      final findings = const TempAnomalyDetector()
          .detect(makeContext(dive: makeTestDive(), samples: samples))
          .where((f) => f.params.containsKey('deltaC'))
          .toList();
      expect(findings, isNotEmpty);
      expect(findings.first.params['spikeShaped'], isFalse);
      expect(offeredRepair(findings.first), isNull);
    });

    test('a whole Fahrenheit channel is still converted', () {
      final after = repairAndRedetect(
        samples: [
          for (var t = 0; t <= 600; t += 10)
            QualitySample(t: t, depth: 20, temp: 72.0),
        ],
        detect: const TempAnomalyDetector().detect,
        matching: (f) => f.params.containsKey('minTempC'),
      );
      expect(after, isNotNull, reason: 'a unit error must be repairable');
      expect(after, isEmpty);
    });

    test('one hot sample never triggers a whole-channel conversion', () {
      // 60 C in an otherwise plausible channel is a bad sample, not a unit
      // error: treating the series as Fahrenheit would turn 22 C into -5.6 C.
      final samples = [
        for (var t = 0; t <= 600; t += 10)
          QualitySample(t: t, depth: 20, temp: t == 300 ? 60.0 : 22.0),
      ];
      final findings = const TempAnomalyDetector()
          .detect(makeContext(dive: makeTestDive(), samples: samples))
          .where((f) => f.params.containsKey('minTempC'))
          .toList();
      expect(findings, isNotEmpty);
      expect(findings.single.params['fahrenheitSuspected'], isFalse);
      expect(findings.single.params['fahrenheitAsKelvinSuspected'], isFalse);
      expect(offeredRepair(findings.single), isNull);
    });

    /// The scalar repair rewrites `dives.water_temp` rather than the sample
    /// channel, so it converges through the dive instead of `repairAndRedetect`.
    List<QualityFinding>? repairScalarAndRedetect(double waterTemp) {
      List<QualityFinding> run(double t) => const TempAnomalyDetector()
          .detect(makeContext(dive: makeTestDive(waterTemp: t)))
          .where((f) => f.params.containsKey('waterTempC'))
          .toList();

      final before = run(waterTemp);
      expect(before, isNotEmpty, reason: 'test vector must trip the detector');
      final action = repairOptionsFor(
        before.single,
      ).whereType<ConvertWaterTempRepair>().firstOrNull;
      if (action == null) return null;
      return run(
        RepairPredicates.convertToCelsius(
          waterTemp,
          kelvinScale: action.kelvinScale,
        ),
      );
    }

    test('the offered repair clears a Fahrenheit water temperature', () {
      final after = repairScalarAndRedetect(78);
      expect(after, isNotNull, reason: 'a unit error must be repairable');
      expect(after, isEmpty);
    });

    test('the offered repair clears a Fahrenheit-as-Kelvin temperature', () {
      final after = repairScalarAndRedetect(297);
      expect(after, isNotNull, reason: 'a unit error must be repairable');
      expect(after, isEmpty);
    });

    test('an unexplainable water temperature is offered no repair', () {
      // No reinterpretation lands -50 in range, so nothing is offered.
      expect(repairScalarAndRedetect(-50), isNull);
    });
  });

  group('sample_gap', () {
    test('the offered repair clears a fillable hole', () {
      final after = repairAndRedetect(
        samples: [
          for (var t = 0; t <= 300; t += 10) QualitySample(t: t, depth: 20),
          for (var t = 420; t <= 900; t += 10) QualitySample(t: t, depth: 20),
        ],
        detect: const SampleGapDetector().detect,
      );
      expect(after, isNotNull, reason: 'a short hole must be repairable');
      expect(after, isEmpty);
    });

    test('no fill-gaps action is offered when no hole is fillable', () {
      // A 20-minute hole: past gapFillMaxSeconds, so fillGaps refuses it.
      final samples = [
        for (var t = 0; t <= 300; t += 10) QualitySample(t: t, depth: 20),
        for (var t = 1500; t <= 1800; t += 10) QualitySample(t: t, depth: 20),
      ];
      final findings = const SampleGapDetector().detect(
        makeContext(dive: makeTestDive(), samples: samples),
      );
      expect(findings, isNotEmpty);
      expect(findings.single.params['fillableGapCount'], 0);
      expect(
        repairOptionsFor(findings.single).whereType<FillGapsRepair>(),
        isEmpty,
      );
    });
  });
}
