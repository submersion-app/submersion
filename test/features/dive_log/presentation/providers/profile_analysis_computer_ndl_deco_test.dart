import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';

/// Computers report a no-stop time only while they are out of deco; a deco or
/// deep stop sample carries the stop instead, so its NDL is stored as null.
/// With the NDL source set to the computer, such a sample must read as in
/// deco, not take the app's calculated NDL, which can still have no-stop time
/// left when the computer's model (VPM, RGBM, other gradient factors) does not
/// (issue #2551).
void main() {
  late List<DiveProfilePoint> profile;
  late ProfileAnalysis base;

  setUp(() {
    // Shallow and short enough that the calculated model never enters deco.
    profile = List.generate(
      61,
      (i) => DiveProfilePoint(timestamp: i * 10, depth: 12.0),
    );
    base = ProfileAnalysisService().analyze(
      diveId: 'computer-ndl-deco',
      depths: profile.map((p) => p.depth).toList(),
      timestamps: profile.map((p) => p.timestamp).toList(),
    );
    expect(base.ndlCurve.every((n) => n > 0), isTrue);
  });

  /// No-deco samples report an NDL; samples from 40 on carry [decoType]
  /// with no NDL, as the import mappers store a computer stop.
  List<DiveProfilePoint> withStopFrom40(int? decoType) => [
    for (var i = 0; i < profile.length; i++)
      if (i < 40)
        profile[i].copyWith(ndl: 600, decoType: 0)
      else
        profile[i].copyWith(decoType: decoType),
  ];

  test('a computer deco stop sample reads as in deco', () {
    final (result, info) = overlayComputerDecoData(
      base,
      withStopFrom40(2),
      ndlSource: MetricDataSource.computer,
    );

    expect(info.ndlActual, MetricDataSource.computer);
    expect(result.ndlCurve[10], 600);
    expect(result.ndlCurve[50], lessThan(0));
    expect(result.hadDecoObligation, isTrue);
  });

  test('a computer deep stop sample reads as in deco', () {
    final (result, _) = overlayComputerDecoData(
      base,
      withStopFrom40(3),
      ndlSource: MetricDataSource.computer,
    );

    expect(result.ndlCurve[50], lessThan(0));
  });

  test('a safety stop sample keeps the calculated fallback', () {
    final (result, _) = overlayComputerDecoData(
      base,
      withStopFrom40(1),
      ndlSource: MetricDataSource.computer,
    );

    expect(result.ndlCurve[50], base.ndlCurve[50]);
  });

  test('a sample with no deco state keeps the calculated fallback', () {
    final (result, _) = overlayComputerDecoData(
      base,
      withStopFrom40(null),
      ndlSource: MetricDataSource.computer,
    );

    expect(result.ndlCurve[50], base.ndlCurve[50]);
    expect(result.hadDecoObligation, isFalse);
  });

  test('the calculated source ignores the computer deco state', () {
    final (result, _) = overlayComputerDecoData(
      base,
      withStopFrom40(2),
      ndlSource: MetricDataSource.calculated,
    );

    expect(result.ndlCurve, same(base.ndlCurve));
  });
}
