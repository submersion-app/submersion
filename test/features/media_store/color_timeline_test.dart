import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

const identity20 = <double>[
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  0, 0, 0, 1, 0, //
];

List<double> gains20(double r, double g, double b) => [
  r, 0, 0, 0, 0, //
  0, g, 0, 0, 0, //
  0, 0, b, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// Issue #3521: the colour timeline a corrected video share carries.
void main() {
  final a = ColorTimelineKey(timeMs: 0, matrix: identity20);
  final b = ColorTimelineKey(timeMs: 1000, matrix: gains20(2, 1, 1));

  test('matrixAt interpolates and holds at the ends', () {
    final t = ColorTimeline([b, a]);
    expect(t.matrixAt(-5)[0], 1);
    expect(t.matrixAt(500)[0], closeTo(1.5, 1e-9));
    expect(t.matrixAt(9999)[0], 2);
  });

  test('a one-key timeline is constant', () {
    final t = ColorTimeline([b]);
    expect(t.matrixAt(0), b.matrix);
    expect(t.matrixAt(5000), b.matrix);
  });

  test('toChannel is time-sorted plain data', () {
    final channel = ColorTimeline([b, a]).toChannel();
    expect(channel.first, {'t': 0, 'm': identity20});
    expect(channel.last, {'t': 1000, 'm': gains20(2, 1, 1)});
  });

  test('a key must hold 20 values', () {
    expect(
      () => ColorTimelineKey(timeMs: 0, matrix: const [1, 2]),
      throwsA(isA<AssertionError>()),
    );
  });
}
