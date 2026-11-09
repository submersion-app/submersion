import 'dart:math' as math;

/// How full a cylinder's figure is drawn on the Cylinders card (issue
/// #3773): [end] is the top of the solid zone (gas left at the end of the
/// dive) and [start] the top of the tinted zone (gas used), each a fraction
/// of the figure's full height. Above [start] the figure is empty, which is
/// how a short fill shows.
///
/// Both are null when there is nothing honest to draw, and the figure is an
/// empty outline.
///
/// [now] is where the profile cursor's pressure sits (issue #4291), measured
/// against the same full height; null when the cursor is off the chart.
class TankFillLevels {
  const TankFillLevels._({this.end, this.start, this.now});

  /// The empty outline.
  static const none = TankFillLevels._();

  final double? end;
  final double? start;
  final double? now;

  bool get hasFill => end != null && start != null;

  /// Full height is the [rated] working pressure, so a short fill shows as
  /// a tank never quite full; without one, the [start] pressure is full.
  /// All pressures are in bar.
  ///
  /// - An end above the start is a sensor or entry error, and a fill drawn
  ///   from it would be a guess: outline.
  /// - A missing end fills solid to the start, a missing start solid to the
  ///   end; neither has a used zone.
  /// - An overfill (start above rated) is drawn full to the top.
  /// - A negative reading is a sensor or entry error and counts as missing.
  /// - The [now] pressure is placed whenever there is a full height, even on
  ///   an outline, since the cursor's reading stands on its own.
  factory TankFillLevels.resolve({
    double? start,
    double? end,
    double? rated,
    double? now,
  }) {
    if (start != null && start < 0) start = null;
    if (end != null && end < 0) end = null;
    final full = rated != null && rated > 0
        ? rated
        : (start != null && start > 0 ? start : null);
    if (full == null) return none;
    double level(double pressure) => (pressure / full).clamp(0.0, 1.0);
    final nowLevel = now != null && now >= 0 ? level(now) : null;

    if (start != null && end != null) {
      if (end > start) return TankFillLevels._(now: nowLevel);
      return TankFillLevels._(
        end: level(end),
        start: level(start),
        now: nowLevel,
      );
    }
    final only = start ?? end;
    if (only == null) return TankFillLevels._(now: nowLevel);
    return TankFillLevels._(
      end: level(only),
      start: level(only),
      now: nowLevel,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TankFillLevels &&
      other.end == end &&
      other.start == start &&
      other.now == now;

  @override
  int get hashCode => Object.hash(end, start, now);

  @override
  String toString() => 'TankFillLevels(end: $end, start: $start, now: $now)';
}

/// The top of each label beside a tank figure, given the [centres] they
/// want to sit at (top to bottom) and their [heights], so that no two come
/// closer than [gap] and all stay within [extent]. A label with room stays
/// centred on its level; crowded ones are pushed apart, down first, then
/// back up from the bottom edge.
///
/// The caller makes [extent] at least the labels' total height plus gaps.
List<double> spreadLabels({
  required List<double> centres,
  required List<double> heights,
  required double extent,
  double gap = 2,
}) {
  final tops = <double>[];
  for (var i = 0; i < centres.length; i++) {
    var top = math.max(centres[i] - heights[i] / 2, 0.0);
    if (i > 0) top = math.max(top, tops[i - 1] + heights[i - 1] + gap);
    tops.add(top);
  }
  var limit = extent;
  for (var i = tops.length - 1; i >= 0; i--) {
    final bottom = math.min(tops[i] + heights[i], limit);
    tops[i] = bottom - heights[i];
    limit = tops[i] - gap;
  }
  return tops;
}

/// The shortest and the tallest a cylinder's body is drawn.
const tankFigureMinHeight = 64.0;
const tankFigureMaxHeight = 104.0;

/// The volume the figure assumes for a cylinder with none on record: a
/// typical single tank (an AL80).
const _typicalVolumeLiters = 11.1;

/// The height of a cylinder's body on the card: scaled to its water volume
/// so a stage looks smaller than the back gas beside it, from 64 at 5 L to
/// 104 at 18 L, and clamped so a pony keeps room for its labels and doubles
/// do not dominate the card.
double tankFigureHeight(double? volumeLiters) {
  const minVolume = 5.0, maxVolume = 18.0;
  final volume = volumeLiters != null && volumeLiters > 0
      ? volumeLiters
      : _typicalVolumeLiters;
  final t = ((volume - minVolume) / (maxVolume - minVolume)).clamp(0.0, 1.0);
  return tankFigureMinHeight + t * (tankFigureMaxHeight - tankFigureMinHeight);
}
