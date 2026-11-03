/// Watches how long frames take, to tell when a decorative animation costs
/// more than the device can give it.
///
/// A frame is slow when it takes longer than [slowFrame]. Once
/// [slowFramesToTrip] of the last [window] frames were slow, the watch trips
/// and stays tripped: an animation that starved the page once would do it
/// again. A few slow frames on their own (fonts and shaders loading at
/// startup) do not trip it.
///
/// A browser without WebGL renders on the CPU, where a full-screen repaint
/// takes longer than the ocean background's frame interval. Its bubbles then
/// kept the main thread busy and Firefox never finished starting (#4177).
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
  bool _tripped = false;

  bool get tripped => _tripped;

  /// Adds the total time of each newly reported frame, oldest first, and
  /// returns whether the watch has tripped.
  bool record(Iterable<Duration> spans) {
    if (_tripped) return true;
    for (final span in spans) {
      final recent = [..._recent, span > slowFrame];
      _recent = recent.length > window
          ? recent.sublist(recent.length - window)
          : recent;
      if (_recent.where((slow) => slow).length >= slowFramesToTrip) {
        _tripped = true;
        _recent = const [];
        return true;
      }
    }
    return false;
  }
}
