import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';

/// A computer that never measures a metric can still leave a zero in every
/// sample, and a zero is not a reading. TTS has been treated that way for a
/// while; NDL and the ceiling need the same rule.
///
/// The Cressi Leonardo is the case that forces it (PR #342): it logs a deco
/// obligation as a single bit and no numbers at all, so its stop depth is zero
/// throughout a deco stop and its no-stop time is zero for the rest of the
/// dive. Read literally that says "the ceiling is at the surface" and "you
/// have no no-stop time left", drawn over the app's own calculated curves.
void main() {
  late ProfileAnalysisService service;
  late List<DiveProfilePoint> profile;
  late ProfileAnalysis base;

  setUp(() {
    service = ProfileAnalysisService(gfLow: 0.30, gfHigh: 0.70);
    profile = List.generate(
      361,
      (i) => DiveProfilePoint(timestamp: i * 10, depth: 20.0),
    );
    base = service.analyze(
      diveId: 'zero-sentinel',
      depths: profile.map((p) => p.depth).toList(),
      timestamps: profile.map((p) => p.timestamp).toList(),
    );
  });

  group('overlayComputerDecoData NDL', () {
    test('treats an all-zero NDL series as unreported', () {
      final zeroed = [for (final p in profile) p.copyWith(ndl: 0)];

      final (result, info) = overlayComputerDecoData(
        base,
        zeroed,
        ndlSource: MetricDataSource.computer,
      );

      expect(result.ndlCurve, same(base.ndlCurve));
      expect(info.ndlActual, MetricDataSource.calculated);
    });

    test('uses the computer NDL when any sample reports one', () {
      final reported = [
        for (var i = 0; i < profile.length; i++)
          if (i < 100)
            profile[i].copyWith(ndl: 12)
          else
            profile[i].copyWith(ndl: 0),
      ];

      final (result, info) = overlayComputerDecoData(
        base,
        reported,
        ndlSource: MetricDataSource.computer,
      );

      expect(info.ndlActual, MetricDataSource.computer);
      expect(result.ndlCurve[50], 12);
      expect(result.ndlCurve[200], 0);
    });
  });

  group('overlayComputerDecoData ceiling', () {
    test('treats an all-zero ceiling series as unreported', () {
      final zeroed = [for (final p in profile) p.copyWith(ceiling: 0.0)];

      final (result, info) = overlayComputerDecoData(
        base,
        zeroed,
        ceilingSource: MetricDataSource.computer,
      );

      expect(result.ceilingCurve, same(base.ceilingCurve));
      expect(info.ceilingActual, MetricDataSource.calculated);
    });

    test('uses the computer ceiling when any sample reports one', () {
      final reported = [
        for (var i = 0; i < profile.length; i++)
          if (i >= 100 && i < 300)
            profile[i].copyWith(ceiling: 6.0)
          else
            profile[i].copyWith(ceiling: 0.0),
      ];

      final (result, info) = overlayComputerDecoData(
        base,
        reported,
        ceilingSource: MetricDataSource.computer,
      );

      expect(info.ceilingActual, MetricDataSource.computer);
      expect(result.ceilingCurve[200], 6.0);
      expect(result.ceilingCurve[50], 0.0);
    });
  });
}
