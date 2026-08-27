import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/deco/ascent_rate_calculator.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';

ProfileAnalysis _analysis({
  required List<double> ceilingCurve,
  required List<double> decoStopCurve,
}) {
  return ProfileAnalysis(
    ascentRates: const [],
    ascentRateStats: const AscentRateStats(
      maxAscentRate: 0,
      maxDescentRate: 0,
      averageAscentRate: 0,
      averageDescentRate: 0,
      violationCount: 0,
      criticalViolationCount: 0,
      timeInViolation: 0,
    ),
    ascentRateViolations: const [],
    events: const [],
    ceilingCurve: ceilingCurve,
    ndlCurve: const [],
    decoStatuses: const [],
    o2Exposure: const O2Exposure(otu: 0),
    ppO2Curve: const [],
    decoStopCurve: decoStopCurve,
    maxDepth: 0,
    averageDepth: 0,
    maxDepthTimestamp: 0,
    durationSeconds: 0,
  );
}

DiveProfilePoint _point({required int timestamp, double? ceiling}) {
  return DiveProfilePoint(timestamp: timestamp, depth: 30, ceiling: ceiling);
}

void main() {
  group('deco stop source resolution', () {
    test('calculated source keeps the quantized curve', () {
      final profile = [
        _point(timestamp: 0, ceiling: 4.5),
        _point(timestamp: 10, ceiling: 4.5),
      ];
      final (result, sources) = overlayComputerDecoData(
        _analysis(ceilingCurve: [4.2, 4.2], decoStopCurve: [6.0, 6.0]),
        profile,
        decoStopSource: MetricDataSource.calculated,
      );

      expect(result.decoStopCurve, [6.0, 6.0]);
      expect(sources.decoStopActual, MetricDataSource.calculated);
    });

    test('calculated source is unaffected by a computer ceiling source', () {
      // Regression guard: selecting "computer" for the ceiling line must not
      // change the band when the band is set to calculated.
      final profile = [
        _point(timestamp: 0, ceiling: 4.5),
        _point(timestamp: 10, ceiling: 4.5),
      ];
      final (result, _) = overlayComputerDecoData(
        _analysis(ceilingCurve: [4.2, 4.2], decoStopCurve: [6.0, 6.0]),
        profile,
        ceilingSource: MetricDataSource.computer,
        decoStopSource: MetricDataSource.calculated,
      );

      expect(result.decoStopCurve, [6.0, 6.0]);
    });

    test('computer source uses raw DC stop depths without rounding', () {
      // 4.5 m is a legitimate non-3m stop on some computers and must survive.
      final profile = [
        _point(timestamp: 0, ceiling: 4.5),
        _point(timestamp: 10, ceiling: 3.0),
      ];
      final (result, sources) = overlayComputerDecoData(
        _analysis(ceilingCurve: [4.2, 2.1], decoStopCurve: [6.0, 3.0]),
        profile,
        decoStopSource: MetricDataSource.computer,
      );

      expect(result.decoStopCurve, [4.5, 3.0]);
      expect(sources.decoStopActual, MetricDataSource.computer);
    });

    test('computer source treats a missing DC ceiling as no obligation', () {
      final profile = [
        _point(timestamp: 0, ceiling: 6.0),
        _point(timestamp: 10, ceiling: null),
      ];
      final (result, _) = overlayComputerDecoData(
        _analysis(ceilingCurve: [4.2, 4.2], decoStopCurve: [6.0, 6.0]),
        profile,
        decoStopSource: MetricDataSource.computer,
      );

      expect(result.decoStopCurve, [6.0, 0.0]);
    });

    test('computer source falls back when the dive has no DC ceiling', () {
      final profile = [_point(timestamp: 0), _point(timestamp: 10)];
      final (result, sources) = overlayComputerDecoData(
        _analysis(ceilingCurve: [4.2, 4.2], decoStopCurve: [6.0, 6.0]),
        profile,
        decoStopSource: MetricDataSource.computer,
      );

      expect(result.decoStopCurve, [6.0, 6.0]);
      expect(sources.decoStopActual, MetricDataSource.calculated);
    });
  });
}
