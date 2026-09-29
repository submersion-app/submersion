import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';

void main() {
  DiveDerivedMetrics metrics({
    double? slope,
    double? mean,
    FinalStopKind kind = FinalStopKind.none,
    double? excursion,
    UnsupportedReason? reason,
  }) => DiveDerivedMetrics(
    diveId: 'd1',
    engineVersion: 1,
    sourceUpdatedAt: 100,
    computedAt: 200,
    finalStopKind: kind,
    finalStopMaxExcursionMeters: excursion,
    sacMeanBarPerMin: mean,
    sacSlopeBarPerMinPerMin: slope,
    unsupportedReason: reason,
  );

  test('a bucket is five minutes wide', () {
    expect(kSacBucketSeconds, 300);
  });

  test('the trend reads the slope against a steady band', () {
    expect(metrics(slope: 0.05).sacTrend, SacTrend.rising);
    expect(metrics(slope: -0.05).sacTrend, SacTrend.falling);
    expect(metrics(slope: 0.01).sacTrend, SacTrend.steady);
    expect(metrics(slope: -0.01).sacTrend, SacTrend.steady);
    // On the band edge is still steady: the band is inclusive, so a dive is
    // never called rising on a difference the engine treats as noise.
    expect(metrics(slope: kSacSteadyBand).sacTrend, SacTrend.steady);
  });

  test('a dive with no slope has no trend', () {
    expect(metrics().sacTrend, isNull);
  });

  test('the stop state reads the excursion against one metre', () {
    expect(
      metrics(kind: FinalStopKind.safety, excursion: 0.4).finalStopState,
      FinalStopState.stable,
    );
    expect(
      metrics(kind: FinalStopKind.safety, excursion: 1.0).finalStopState,
      FinalStopState.stable,
    );
    expect(
      metrics(kind: FinalStopKind.deco, excursion: 1.4).finalStopState,
      FinalStopState.unstable,
    );
    expect(metrics().finalStopState, FinalStopState.noStop);
  });

  test('a stop is judged without pressure data, not without a profile', () {
    expect(
      metrics(
        kind: FinalStopKind.safety,
        excursion: 0.2,
        reason: UnsupportedReason.noPressureSeries,
      ).finalStopState,
      FinalStopState.stable,
    );
    for (final reason in [
      UnsupportedReason.noProfile,
      UnsupportedReason.tooShort,
      UnsupportedReason.gaugeMode,
    ]) {
      expect(metrics(reason: reason).finalStopState, isNull, reason: '$reason');
    }
  });

  test('hasSac and hasFinalStop report what was computable', () {
    expect(metrics(mean: 0.6).hasSac, isTrue);
    expect(metrics(reason: UnsupportedReason.noPressureSeries).hasSac, isFalse);
    expect(metrics(kind: FinalStopKind.safety).hasFinalStop, isTrue);
    expect(metrics(kind: FinalStopKind.none).hasFinalStop, isFalse);
  });

  test('buckets compare by value', () {
    expect(
      const SacBucket(index: 1, sacBarPerMin: 0.5),
      const SacBucket(index: 1, sacBarPerMin: 0.5),
    );
    expect(
      const SacBucket(index: 1, sacBarPerMin: 0.5),
      isNot(const SacBucket(index: 2, sacBarPerMin: 0.5)),
    );
  });
}
