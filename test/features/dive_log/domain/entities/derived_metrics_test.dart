import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';

void main() {
  DiveDerivedMetrics metrics({
    double? slope,
    double? mean,
    FinalStopKind kind = FinalStopKind.none,
    double? excursion,
    UnsupportedReason? reason,
    List<SacBucket> buckets = const [],
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
    sacBuckets: buckets,
  );

  test('a bucket is five minutes wide', () {
    expect(kSacBucketSeconds, 300);
  });

  test('the trend reads the slope against a flat band', () {
    expect(metrics(slope: 0.05).trend(), SacTrend.rising);
    expect(metrics(slope: -0.05).trend(), SacTrend.falling);
    expect(metrics(slope: 0.01).trend(), SacTrend.flat);
    expect(metrics(slope: -0.01).trend(), SacTrend.flat);
    // Exactly on the band edge is still flat: the band is inclusive, so a
    // dive cannot be called rising on a difference the engine cannot
    // distinguish from noise.
    expect(metrics(slope: 0.02).trend(), SacTrend.flat);
  });

  test('a dive with no slope has no trend', () {
    expect(metrics().trend(), isNull);
  });

  test('hasSac and hasFinalStop report what was computable', () {
    expect(
      metrics(
        mean: 0.6,
        buckets: const [SacBucket(index: 0, sacBarPerMin: 0.6)],
      ).hasSac,
      isTrue,
    );
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
