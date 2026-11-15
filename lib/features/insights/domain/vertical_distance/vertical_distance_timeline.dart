import 'dart:typed_data';

/// One dive's contribution to the running vertical distance (issue #4569).
class DiveVerticalDistance {
  const DiveVerticalDistance({
    required this.diveId,
    required this.startMillis,
    required this.meters,
    required this.estimated,
  });

  final String diveId;

  /// When the dive started, as stored on the dive: a wall clock flagged UTC,
  /// in epoch milliseconds. Decode with `wallClockUtcFromMillis`.
  final int startMillis;

  /// Metres travelled down, which equals metres travelled up.
  final double meters;

  /// True when [meters] came from the dive's max depth because it has no
  /// usable profile.
  final bool estimated;
}

/// The diver's dives in dive order with their running vertical distance,
/// and the lookup that turns a level on the scale into the dive that reached
/// it.
class VerticalDistanceTimeline {
  /// [dives] in dive order. Dives with nothing to add (`meters <= 0`) are
  /// left out of the counts and are never a crossing.
  factory VerticalDistanceTimeline(List<DiveVerticalDistance> dives) {
    final counted = [
      for (final d in dives)
        if (d.meters > 0) d,
    ];
    final sums = Float64List(counted.length);
    var running = 0.0;
    for (var i = 0; i < counted.length; i++) {
      running += counted[i].meters;
      sums[i] = running;
    }
    return VerticalDistanceTimeline._(
      counted,
      sums,
      counted.where((d) => d.estimated).length,
    );
  }

  VerticalDistanceTimeline._(this._dives, this._sums, this.estimatedDives);

  static final VerticalDistanceTimeline empty = VerticalDistanceTimeline._(
    const [],
    Float64List(0),
    0,
  );

  final List<DiveVerticalDistance> _dives;

  /// Running total after each of [_dives], ascending.
  final Float64List _sums;

  /// Of the dives counted, how many were estimated from max depth.
  final int estimatedDives;

  /// Total metres down, which equals total metres up.
  double get totalMeters => _sums.isEmpty ? 0 : _sums.last;

  /// Dives that added anything to the total.
  int get countedDives => _dives.length;

  bool get isEmpty => totalMeters <= 0;

  /// The dive whose running total first reached [meters], or null when
  /// [meters] is not above zero or is beyond the total.
  DiveVerticalDistance? crossingAt(double meters) {
    if (meters <= 0 || _sums.isEmpty || meters > _sums.last) return null;
    // Lower bound: the first running total at or above [meters].
    var lo = 0;
    var hi = _sums.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_sums[mid] >= meters) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return _dives[lo];
  }
}
