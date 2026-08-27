import 'package:clock/clock.dart';

/// Spaces Nominatim requests at least [minimumGap] apart, process-wide.
///
/// OpenStreetMap's usage policy allows one request per second. A single
/// interactive lookup makes two requests (address layer, then natural
/// layer) and the bulk backfill makes hundreds, so the spacing lives in one
/// place instead of at every call site. Waiters are released in call order.
///
/// Uses `clock.now()` rather than `Stopwatch` so fake_async tests can drive
/// it; a `Stopwatch` is invisible to the synthetic clock.
class NominatimThrottle {
  NominatimThrottle({this.minimumGap = const Duration(seconds: 1)});

  final Duration minimumGap;

  DateTime? _lastRelease;
  Future<void> _queue = Future<void>.value();

  /// Completes when the caller may send its request.
  Future<void> wait() {
    final turn = _queue.then((_) => _holdUntilGapElapsed());
    _queue = turn;
    return turn;
  }

  Future<void> _holdUntilGapElapsed() async {
    final last = _lastRelease;
    if (last != null) {
      final sinceLast = clock.now().difference(last);
      if (sinceLast < minimumGap) {
        await Future<void>.delayed(minimumGap - sinceLast);
      }
    }
    _lastRelease = clock.now();
  }
}
