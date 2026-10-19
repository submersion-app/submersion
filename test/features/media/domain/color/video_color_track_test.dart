import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/color/auto_correction.dart';
import 'package:submersion/features/media/domain/color/video_color_track.dart';

const a = AutoCorrectionParams(
  redFromGreen: 0.1,
  gainR: 1.4,
  gainG: 1,
  gainB: 0.9,
);
const b = AutoCorrectionParams(
  redFromGreen: 0.3,
  gainR: 2.0,
  gainG: 0.9,
  gainB: 0.8,
);

void main() {
  const track = VideoColorTrack([
    VideoColorKey(seconds: 10, params: a),
    VideoColorKey(seconds: 30, params: b),
  ]);

  test('frameSampleTimes spreads samples through the clip', () {
    expect(frameSampleTimes(const Duration(seconds: 70)), [
      5,
      15,
      25,
      35,
      45,
      55,
      65,
    ]);
    expect(frameSampleTimes(const Duration(seconds: 10), count: 2), [2.5, 7.5]);
    expect(frameSampleTimes(Duration.zero), isEmpty);
  });

  test('paramsAt interpolates between neighbouring keys', () {
    expect(track.paramsAt(20), AutoCorrectionParams.lerp(a, b, 0.5));
  });

  test('paramsAt holds the end values outside the keys', () {
    expect(track.paramsAt(0), a);
    expect(track.paramsAt(99), b);
  });

  test('paramsAt applies the moment depth', () {
    expect(track.paramsAt(20, depthAt: (_) => 0.5), AutoCorrectionParams.none);
    expect(track.paramsAt(30, depthAt: (_) => 3), b.boundedFor(3));
    expect(track.paramsAt(30, depthAt: (_) => null), b);
  });

  test('keys are sorted by time', () {
    const unsorted = VideoColorTrack([
      VideoColorKey(seconds: 30, params: b),
      VideoColorKey(seconds: 10, params: a),
    ]);
    expect(unsorted.paramsAt(0), a);
  });

  test('average is the mean of the keys', () {
    expect(track.average, AutoCorrectionParams.lerp(a, b, 0.5));
  });

  test('an empty track is no correction', () {
    const empty = VideoColorTrack([]);
    expect(empty.paramsAt(5), AutoCorrectionParams.none);
    expect(empty.average, AutoCorrectionParams.none);
  });
}
