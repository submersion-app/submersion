import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/color/auto_correction.dart';
import 'package:submersion/features/media/domain/color/channel_stats.dart';
import 'package:submersion/features/media/domain/color/color_matrix.dart';

const deepBlue = ChannelStats(meanR: 0.08, meanG: 0.40, meanB: 0.55);

void main() {
  test('warms a deep blue shot', () {
    final p = computeAutoCorrection(deepBlue, depthMeters: 25);
    expect(p.redFromGreen, greaterThan(0));
    expect(p.gainR, greaterThan(1));
    expect(p.gainB, lessThanOrEqualTo(1.1));
  });

  test('never goes purple', () {
    for (final stats in [
      deepBlue,
      const ChannelStats(meanR: 0.02, meanG: 0.10, meanB: 0.60),
      const ChannelStats(meanR: 0.05, meanG: 0.50, meanB: 0.30),
    ]) {
      for (final depth in [null, 2.0, 10.0, 40.0]) {
        final p = computeAutoCorrection(stats, depthMeters: depth);
        final g = p.gainG * stats.meanG;
        final r = p.gainR * (stats.meanR + p.redFromGreen * stats.meanG);
        expect(r, lessThanOrEqualTo(1.05 * g + 1e-9), reason: '$stats $depth');
        expect(
          p.gainB * stats.meanB,
          lessThanOrEqualTo(1.05 * g + 1e-9),
          reason: '$stats $depth',
        );
      }
    }
  });

  test('a 5 m shot is corrected less than a 25 m shot', () {
    final shallow = computeAutoCorrection(deepBlue, depthMeters: 5);
    final deep = computeAutoCorrection(deepBlue, depthMeters: 25);
    expect(shallow.gainR, lessThan(deep.gainR));
    expect(shallow.redFromGreen, lessThan(deep.redFromGreen));
  });

  test('a balanced strobe-lit shot is left almost alone', () {
    final p = computeAutoCorrection(
      const ChannelStats(meanR: 0.45, meanG: 0.47, meanB: 0.50),
      depthMeters: 20,
    );
    expect(p.gainR, closeTo(1, 0.1));
    expect(p.gainG, closeTo(1, 0.1));
    expect(p.gainB, closeTo(1, 0.1));
    expect(p.redFromGreen, lessThan(0.05));
  });

  test('a red-dominant strobe shot is left alone (no red cut, no green '
      'cast)', () {
    expect(
      computeAutoCorrection(
        const ChannelStats(meanR: 0.55, meanG: 0.35, meanB: 0.30),
        depthMeters: 20,
      ),
      AutoCorrectionParams.none,
    );
  });

  test('the purple cap never cuts red below its own level', () {
    final p = computeAutoCorrection(
      const ChannelStats(meanR: 0.39, meanG: 0.5, meanB: 0.2),
      depthMeters: 20,
    );
    expect(p.gainR, greaterThanOrEqualTo(1.0));
  });

  test('shallower than 1 m is no correction', () {
    expect(
      computeAutoCorrection(deepBlue, depthMeters: 0.6),
      AutoCorrectionParams.none,
    );
  });

  test('depthFactor bounds', () {
    expect(depthFactor(null), 1.0);
    expect(depthFactor(0.5), 0.0);
    expect(depthFactor(1.0), 0.2);
    expect(depthFactor(7.5), 0.5);
    expect(depthFactor(15), 1.0);
    expect(depthFactor(60), 1.0);
  });

  test('gain clamps follow the depth factor', () {
    final p = computeAutoCorrection(deepBlue, depthMeters: 3);
    final f = depthFactor(3);
    expect(p.gainR, lessThanOrEqualTo(1 + 1.5 * f + 1e-9));
    expect(p.redFromGreen, lessThanOrEqualTo(0.5 * f + 1e-9));
  });

  test('boundedFor re-clamps params to a moment depth', () {
    final deep = computeAutoCorrection(deepBlue, depthMeters: 25);
    expect(
      deep.boundedFor(3).gainR,
      lessThanOrEqualTo(1 + 1.5 * depthFactor(3)),
    );
    expect(
      deep.boundedFor(3).redFromGreen,
      lessThanOrEqualTo(0.5 * depthFactor(3)),
    );
    expect(deep.boundedFor(0.5), AutoCorrectionParams.none);
    expect(deep.boundedFor(null), deep);
  });

  test('toMatrix rebuilds red then applies gains', () {
    const p = AutoCorrectionParams(
      redFromGreen: 0.5,
      gainR: 2,
      gainG: 1,
      gainB: 0.5,
    );
    expect(
      p.toMatrix(),
      ColorMatrix.redFromGreen(0.5).then(ColorMatrix.gains(2, 1, 0.5)),
    );
    expect(AutoCorrectionParams.none.toMatrix().isIdentity, isTrue);
  });

  test('lerp interpolates every parameter', () {
    const b = AutoCorrectionParams(
      redFromGreen: 0.4,
      gainR: 2,
      gainG: 0.8,
      gainB: 0.6,
    );
    expect(
      AutoCorrectionParams.lerp(AutoCorrectionParams.none, b, 0.5),
      const AutoCorrectionParams(
        redFromGreen: 0.2,
        gainR: 1.5,
        gainG: 0.9,
        gainB: 0.8,
      ),
    );
  });
}
