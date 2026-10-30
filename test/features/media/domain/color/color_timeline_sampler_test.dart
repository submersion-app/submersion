import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/domain/color/auto_correction.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/color/color_correction_policy.dart';
import 'package:submersion/features/media/domain/color/color_matrix.dart';
import 'package:submersion/features/media/domain/color/color_timeline_sampler.dart';
import 'package:submersion/features/media/domain/color/video_color_track.dart';
import 'package:submersion/features/media/presentation/providers/video_color_track_provider.dart';

/// Issue #3521: the colour a shared video carries is the viewer's, sampled.
void main() {
  // A clip that starts 4 minutes in, during a descent to 25 m.
  const profile = [
    DiveProfilePoint(timestamp: 0, depth: 0),
    DiveProfilePoint(timestamp: 240, depth: 3),
    DiveProfilePoint(timestamp: 300, depth: 25),
    DiveProfilePoint(timestamp: 1200, depth: 25),
  ];
  final depthAt = videoDepthLookup(profile, 240);
  const track = VideoColorTrack([
    VideoColorKey(
      seconds: 4,
      params: AutoCorrectionParams(
        redFromGreen: 0.4,
        gainR: 2.2,
        gainG: 1,
        gainB: 0.8,
      ),
    ),
    VideoColorKey(
      seconds: 12,
      params: AutoCorrectionParams(
        redFromGreen: 0.5,
        gainR: 2.5,
        gainG: 0.95,
        gainB: 0.75,
      ),
    ),
    VideoColorKey(
      seconds: 20,
      params: AutoCorrectionParams(
        redFromGreen: 0.3,
        gainR: 1.8,
        gainG: 1,
        gainB: 0.85,
      ),
    ),
    VideoColorKey(
      seconds: 28,
      params: AutoCorrectionParams(
        redFromGreen: 0.45,
        gainR: 2.4,
        gainG: 1,
        gainB: 0.8,
      ),
    ),
    VideoColorKey(
      seconds: 36,
      params: AutoCorrectionParams(
        redFromGreen: 0.5,
        gainR: 2.5,
        gainG: 1,
        gainB: 0.7,
      ),
    ),
    VideoColorKey(
      seconds: 44,
      params: AutoCorrectionParams(
        redFromGreen: 0.35,
        gainR: 2.0,
        gainG: 1.05,
        gainB: 0.8,
      ),
    ),
    VideoColorKey(
      seconds: 52,
      params: AutoCorrectionParams(
        redFromGreen: 0.4,
        gainR: 2.2,
        gainG: 1,
        gainB: 0.8,
      ),
    ),
  ]);
  const adjustment = ColorAdjustment(warmth: 0.3, contrast: 0.1);
  ColorMatrix viewerMatrixAt(double s) => composeCorrection(
    adjustment: adjustment,
    auto: track.paramsAt(s, depthAt: depthAt),
  );

  test('identity everywhere gives null', () {
    expect(
      sampleColorTimeline(
        durationSeconds: 30,
        matrixAt: (_) => ColorMatrix.identity,
      ),
      isNull,
    );
  });

  test('constant matrix gives one key', () {
    final m = ColorMatrix.warmth(0.4);
    final t = sampleColorTimeline(durationSeconds: 30, matrixAt: (_) => m)!;
    expect(t.keys, hasLength(1));
    expect(t.keys.single.timeMs, 0);
    expect(t.keys.single.matrix, m.values);
  });

  test('null duration gives one key from matrixAt(0)', () {
    final t = sampleColorTimeline(
      durationSeconds: null,
      matrixAt: viewerMatrixAt,
    )!;
    expect(t.keys, hasLength(1));
    expect(t.keys.single.matrix, viewerMatrixAt(0).values);
  });

  test('0.2 s clip gives one key', () {
    final t = sampleColorTimeline(
      durationSeconds: 0.2,
      matrixAt: viewerMatrixAt,
    )!;
    expect(t.keys, hasLength(1));
  });

  test('keys equal matrixAt at their times and reach the end', () {
    final t = sampleColorTimeline(
      durationSeconds: 56,
      matrixAt: viewerMatrixAt,
    )!;
    expect(t.keys.first.timeMs, 0);
    expect(t.keys.last.timeMs, 56000);
    for (final k in t.keys) {
      expect(k.matrix, viewerMatrixAt(k.timeMs / 1000).values);
    }
  });

  test('interpolation stays within one level', () {
    final t = sampleColorTimeline(
      durationSeconds: 56,
      matrixAt: viewerMatrixAt,
    )!;
    const pixels = [(20, 100, 160), (128, 128, 128), (240, 200, 60)];
    for (var ms = 0; ms <= 56000; ms += 50) {
      final want = viewerMatrixAt(ms / 1000);
      final got = ColorMatrix(t.matrixAt(ms));
      for (final (r, g, b) in pixels) {
        final (wr, wg, wb) = want.applyToPixel(r, g, b);
        final (gr, gg, gb) = got.applyToPixel(r, g, b);
        expect(
          [(wr - gr).abs(), (wg - gg).abs(), (wb - gb).abs()],
          everyElement(lessThanOrEqualTo(1)),
          reason: 'at $ms ms, pixel ($r, $g, $b)',
        );
      }
    }
  });
}
