/// The Insights key for a range that crosses a band edge on the diver's
/// current scale, so it belongs to no single band (issue #3226).
const visibilityRangeSpanningKey = 'range_spanning';

/// A visibility range in meters, logged when a diver picks a band instead of
/// measuring (issue #3226). [minM] is inclusive and [maxM] exclusive, matching
/// how `VisibilityScale.bandFor` draws band edges.
///
/// Either end may be null for an open range ("under 2 m", "12 m+"), never
/// both: a range with no ends says nothing, so callers model that as no range
/// at all ([fromColumns] returns null for it).
class VisibilityRange implements Comparable<VisibilityRange> {
  final double? minM;
  final double? maxM;

  const VisibilityRange({this.minM, this.maxM})
    : assert(minM != null || maxM != null, 'a range needs at least one end');

  /// The range the two `dives` columns hold, or null when both are null.
  static VisibilityRange? fromColumns(double? minM, double? maxM) =>
      minM == null && maxM == null
      ? null
      : VisibilityRange(minM: minM, maxM: maxM);

  /// As [fromColumns], for values read from an imported file: a negative or
  /// non-finite end, or a low end at or above the high end, is unreadable
  /// and yields null rather than a nonsense range.
  static VisibilityRange? tryParse(double? minM, double? maxM) {
    bool bad(double? v) => v != null && (!v.isFinite || v < 0);
    if (bad(minM) || bad(maxM)) return null;
    if (maxM != null && maxM <= 0) return null;
    if (minM != null && maxM != null && minM >= maxM) return null;
    return fromColumns(minM, maxM);
  }

  VisibilityRange copyWith({double? minM, double? maxM}) =>
      VisibilityRange(minM: minM ?? this.minM, maxM: maxM ?? this.maxM);

  /// Orders by low end, then high end. An open low end sorts first and an
  /// open high end last, so a table column reads poorest to clearest.
  @override
  int compareTo(VisibilityRange other) {
    final byMin = (minM ?? double.negativeInfinity).compareTo(
      other.minM ?? double.negativeInfinity,
    );
    if (byMin != 0) return byMin;
    return (maxM ?? double.infinity).compareTo(other.maxM ?? double.infinity);
  }

  @override
  bool operator ==(Object other) =>
      other is VisibilityRange && other.minM == minM && other.maxM == maxM;

  @override
  int get hashCode => Object.hash(minM, maxM);

  @override
  String toString() => 'VisibilityRange($minM m, $maxM m)';
}
