import 'package:collection/collection.dart';

/// Finds the dives of a list that start near a given time (issue #3855).
///
/// [DiveMatcher] gates a pair on time, so a stored dive scored against an
/// incoming one is wasted work unless the two start within
/// `DiveMatcher.candidateWindow`. Sorting once and searching keeps a large
/// import against a large logbook from scoring every pair.
class DiveStartTimeIndex {
  DiveStartTimeIndex._(this._startMicros, this._positions);

  /// Indexes [starts] by position; a null start cannot be found.
  factory DiveStartTimeIndex(Iterable<DateTime?> starts) {
    final timed = <(int, int)>[
      for (final (position, start) in starts.indexed)
        if (start != null) (start.microsecondsSinceEpoch, position),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return DiveStartTimeIndex._(
      [for (final entry in timed) entry.$1],
      [for (final entry in timed) entry.$2],
    );
  }

  final List<int> _startMicros;
  final List<int> _positions;

  /// Positions of the dives starting at most [window] from [at], both edges
  /// included.
  ///
  /// Ascending by position, not by time: when several candidates tie on score
  /// the matching passes keep the first they meet, so they must meet them in
  /// the list's own order.
  List<int> positionsNear(DateTime at, Duration window) {
    final center = at.microsecondsSinceEpoch;
    final last = center + window.inMicroseconds;
    final found = <int>[];
    for (
      var i = lowerBound(_startMicros, center - window.inMicroseconds);
      i < _startMicros.length && _startMicros[i] <= last;
      i++
    ) {
      found.add(_positions[i]);
    }
    return found..sort();
  }
}
