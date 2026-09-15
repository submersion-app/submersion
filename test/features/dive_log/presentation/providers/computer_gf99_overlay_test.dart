import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/computer_gf99_overlay.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';

DiveProfilePoint _point(int t, {int? gf99, int? n2Load}) =>
    DiveProfilePoint(timestamp: t, depth: 20, gf99: gf99, n2Load: n2Load);

void main() {
  group('hasComputerGf99', () {
    test('is false for an empty profile', () {
      expect(hasComputerGf99(const []), isFalse);
    });

    test('is false when no sample carries gf99', () {
      expect(hasComputerGf99([_point(0), _point(10)]), isFalse);
    });

    test('is true when any sample carries gf99, including zero', () {
      expect(hasComputerGf99([_point(0), _point(10, gf99: 0)]), isTrue);
    });
  });

  group('buildComputerGf99Curve', () {
    test('uses the computer value where reported', () {
      final curve = buildComputerGf99Curve(
        [_point(0, gf99: 12), _point(10, gf99: 45)],
        const [1.0, 2.0],
      );
      expect(curve, [12.0, 45.0]);
    });

    test('falls back to the calculated value where a sample has none', () {
      final curve = buildComputerGf99Curve(
        [_point(0, gf99: 12), _point(10), _point(20, gf99: 70)],
        const [1.0, 33.5, 3.0],
      );
      expect(curve, [12.0, 33.5, 70.0]);
    });

    test('falls back to zero when the calculated curve is short or null', () {
      expect(buildComputerGf99Curve([_point(0), _point(10, gf99: 5)], null), [
        0.0,
        5.0,
      ]);
      expect(
        buildComputerGf99Curve([_point(0, gf99: 5), _point(10)], const [9.0]),
        [5.0, 0.0],
      );
    });

    test('has one entry per profile sample', () {
      final profile = List.generate(
        7,
        (i) => _point(i, gf99: i.isEven ? i : null),
      );
      expect(buildComputerGf99Curve(profile, null).length, 7);
    });
  });

  group('buildComputerN2LoadCurve', () {
    test('is null when no sample carries n2Load', () {
      expect(buildComputerN2LoadCurve([_point(0), _point(10)]), isNull);
      expect(buildComputerN2LoadCurve(const []), isNull);
    });

    test('keeps the computer values verbatim with null gaps', () {
      final curve = buildComputerN2LoadCurve([
        _point(0, n2Load: 40),
        _point(10),
        _point(20, n2Load: 62),
      ]);
      expect(curve, [40, null, 62]);
    });
  });

  group('overlayComputerDecoData gf99Source', () {
    final analysis = ProfileAnalysis.empty().copyWith(
      gfCurve: const [10.0, 20.0, 30.0],
    );

    test('computer gf99 present: curve comes from the computer and the '
        'source info says computer', () {
      final profile = [_point(0, gf99: 15), _point(10), _point(20, gf99: 55)];
      final (overlaid, info) = overlayComputerDecoData(analysis, profile);
      expect(overlaid.gfCurve, [15.0, 20.0, 55.0]);
      expect(info.gf99Actual, MetricDataSource.computer);
    });

    test('computer gf99 absent: the calculated curve is retained and the '
        'source info says calculated', () {
      final profile = [_point(0), _point(10), _point(20)];
      final (overlaid, info) = overlayComputerDecoData(analysis, profile);
      expect(overlaid.gfCurve, [10.0, 20.0, 30.0]);
      expect(info.gf99Actual, MetricDataSource.calculated);
    });

    test('gf99Source calculated ignores computer gf99', () {
      final profile = [_point(0, gf99: 15), _point(10, gf99: 25)];
      final (overlaid, info) = overlayComputerDecoData(
        analysis,
        profile,
        gf99Source: MetricDataSource.calculated,
      );
      expect(overlaid.gfCurve, [10.0, 20.0, 30.0]);
      expect(info.gf99Actual, MetricDataSource.calculated);
    });

    test('n2LoadCurve is exposed whenever the computer reported it, even '
        'when nothing else is overlaid', () {
      final profile = [
        _point(0, n2Load: 41),
        _point(10),
        _point(20, n2Load: 63),
      ];
      final (overlaid, _) = overlayComputerDecoData(
        analysis,
        profile,
        gf99Source: MetricDataSource.calculated,
      );
      expect(overlaid.n2LoadCurve, [41, null, 63]);
    });

    test('n2LoadCurve stays null when the computer did not report it', () {
      final (overlaid, _) = overlayComputerDecoData(analysis, [
        _point(0),
        _point(10),
      ]);
      expect(overlaid.n2LoadCurve, isNull);
    });
  });
}
