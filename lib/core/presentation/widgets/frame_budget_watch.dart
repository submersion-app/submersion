import 'dart:ui' show FramePhase, FrameTiming;

/// Watches how long frames take, and how often they come, to tell when a
/// decorative animation costs more than the device can give it.
///
/// A frame is slow when it takes longer than [slowFrame]. Once
/// [slowFramesToTrip] of the last [window] frames were slow, the watch trips
/// and stays tripped: an animation that starved the page once would do it
/// again. A few slow frames on their own (fonts and shaders loading at
/// startup) do not trip it.
///
/// It also trips when the frames come too seldom: the median gap between the
/// starts of the last [window] + 1 frames is longer than [slowFrame]. The
/// median, so that one long pause does not count, nor timer jitter that lands
/// one frame a display refresh early and the next a refresh late.
///
/// A browser without WebGL renders on the CPU, where a full-screen repaint
/// takes longer than the ocean background's frame interval. Its bubbles then
/// kept the main thread busy and Firefox never finished starting (#4177).
/// Chromium drawing WebGL in software does that drawing in its GPU process,
/// after a frame's timings end, so each frame looks quick while they arrive
/// about half as often as asked; the drawing took the CPU from drift's
/// workers and the splash waited a minute on the database (#4186).
class FrameBudgetWatch {
  FrameBudgetWatch({
    this.slowFrame = const Duration(milliseconds: 50),
    this.window = 12,
    this.slowFramesToTrip = 6,
  });

  final Duration slowFrame;
  final int window;
  final int slowFramesToTrip;

  /// Whether each of the most recent frames, at most [window], was slow.
  List<bool> _recent = const [];

  /// The most recent gaps between frame starts, in microseconds, at most
  /// [window].
  List<int> _gaps = const [];

  /// When the last recorded frame started, or null before the first one and
  /// after [restartCadence].
  int? _lastStart;

  bool _tripped = false;

  bool get tripped => _tripped;

  /// Adds each newly reported frame, oldest first, and returns whether the
  /// watch has tripped.
  bool record(Iterable<FrameTiming> timings) {
    if (_tripped) return true;
    for (final timing in timings) {
      final recent = [..._recent, timing.totalSpan > slowFrame];
      _recent = _lastOf(recent);
      _recordStart(timing.timestampInMicroseconds(FramePhase.vsyncStart));
      if (_recent.where((slow) => slow).length >= slowFramesToTrip ||
          _comesTooSeldom()) {
        _tripped = true;
        _recent = const [];
        _gaps = const [];
        return true;
      }
    }
    return false;
  }

  /// Forgets when the last frame started. The animation stopped asking for
  /// frames for a while (paused, covered), and the gap across that pause
  /// says nothing about the device.
  void restartCadence() {
    _lastStart = null;
    _gaps = const [];
  }

  void _recordStart(int start) {
    final last = _lastStart;
    _lastStart = start;
    if (last == null || start < last) return;
    _gaps = _lastOf([..._gaps, start - last]);
  }

  bool _comesTooSeldom() {
    if (_gaps.length < window) return false;
    final sorted = [..._gaps]..sort();
    final middle = sorted.length ~/ 2;
    final median = sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
    return median > slowFrame.inMicroseconds;
  }

  List<T> _lastOf<T>(List<T> values) =>
      values.length > window ? values.sublist(values.length - window) : values;
}
