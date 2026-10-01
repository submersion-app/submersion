import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';

/// Computers report a no-stop time only while they are out of deco; a deco
/// stop sample carries the stop instead, so its NDL is stored as null.
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

  test('a deep stop sample keeps the calculated fallback', () {
    // Deep stops are recommended stops that also occur on no-deco dives; the
    // statistics deco scan does not count them as an obligation either.
    final (result, _) = overlayComputerDecoData(
      base,
      withStopFrom40(3),
      ndlSource: MetricDataSource.computer,
    );

    expect(result.ndlCurve[50], base.ndlCurve[50]);
    expect(result.hadDecoObligation, isFalse);
  });

  test('a deco stop sample with a zero NDL reads as in deco', () {
    // Subsurface and Diving Log imports carry an NDL of zero through a stop
    // next to the in-deco flag, rather than leaving it null.
    final zeroNdl = [
      for (final p in withStopFrom40(2))
        p.decoType == 2 ? p.copyWith(ndl: 0) : p,
    ];

    final (result, _) = overlayComputerDecoData(
      base,
      zeroNdl,
      ndlSource: MetricDataSource.computer,
    );

    expect(result.ndlCurve[50], lessThan(0));
    expect(result.hadDecoObligation, isTrue);
  });

  test('a deco flag alone counts as computer NDL data', () {
    // DAN DL7 and Diving Log imports can record the in-deco flag with no NDL
    // readings at all, so no sample has a positive NDL.
    final flagOnly = [
      for (var i = 0; i < profile.length; i++)
        i < 40 ? profile[i] : profile[i].copyWith(decoType: 2),
    ];

    final (result, info) = overlayComputerDecoData(
      base,
      flagOnly,
      ndlSource: MetricDataSource.computer,
    );

    expect(info.ndlActual, MetricDataSource.computer);
    expect(result.ndlCurve[10], base.ndlCurve[10]);
    expect(result.ndlCurve[50], lessThan(0));
  });

  test('a deco flag does not make an all-zero NDL series a reading', () {
    // The Cressi Leonardo logs a zero NDL for the whole dive next to its deco
    // bit; outside the stop those zeros still are not readings.
    final leonardo = [
      for (var i = 0; i < profile.length; i++)
        i < 40
            ? profile[i].copyWith(ndl: 0, decoType: 0)
            : profile[i].copyWith(ndl: 0, decoType: 2),
    ];

    final (result, _) = overlayComputerDecoData(
      base,
      leonardo,
      ndlSource: MetricDataSource.computer,
    );

    expect(result.ndlCurve[10], base.ndlCurve[10]);
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
