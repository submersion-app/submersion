/// One moment of a colour timeline: the 4x5 colour matrix (rows R, G, B, A;
/// columns r, g, b, a, offset; offsets on the 0-255 scale, row-major) in
/// effect [timeMs] into the clip.
class ColorTimelineKey {
  ColorTimelineKey({required this.timeMs, required this.matrix})
    : assert(matrix.length == 20, 'a colour matrix has 20 values');

  final int timeMs;
  final List<double> matrix;
}

/// The colour correction a video carries through the clip (issue #3521):
/// keys the app samples, which an encoder interpolates between for each
/// frame. Before the first key the first applies, after the last the last.
class ColorTimeline {
  ColorTimeline(List<ColorTimelineKey> keys)
    : assert(keys.isNotEmpty, 'a timeline has at least one key'),
      keys = List.unmodifiable(
        List.of(keys)..sort((a, b) => a.timeMs.compareTo(b.timeMs)),
      );

  /// Sorted by time.
  final List<ColorTimelineKey> keys;

  /// The matrix at [timeMs]: the elementwise blend of the keys around it.
  List<double> matrixAt(int timeMs) {
    if (timeMs <= keys.first.timeMs) return keys.first.matrix;
    if (timeMs >= keys.last.timeMs) return keys.last.matrix;
    var i = 1;
    while (keys[i].timeMs < timeMs) {
      i++;
    }
    final lo = keys[i - 1], hi = keys[i];
    final t = (timeMs - lo.timeMs) / (hi.timeMs - lo.timeMs);
    return [
      for (var k = 0; k < 20; k++)
        lo.matrix[k] + (hi.matrix[k] - lo.matrix[k]) * t,
    ];
  }

  /// The timeline as the native encoders receive it.
  List<Object> toChannel() => [
    for (final k in keys) {'t': k.timeMs, 'm': k.matrix},
  ];
}
