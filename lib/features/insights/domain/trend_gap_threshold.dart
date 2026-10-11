/// How long a stretch with no dives must last before a trend chart collapses
/// it into a break (issue #3251). Stored as [months] in
/// `diver_settings.trend_gap_collapse_months`.
enum TrendGapThreshold {
  off(0),
  months6(6),
  year1(12),
  years2(24);

  const TrendGapThreshold(this.months);

  /// Calendar months a gap must exceed; 0 for [off].
  final int months;

  static const defaultValue = TrendGapThreshold.year1;

  /// The choice stored as [months]. Anything else, from an older or newer
  /// peer or a hand-edited database, reads as [defaultValue].
  static TrendGapThreshold fromMonths(int? months) {
    for (final t in values) {
      if (t.months == months) return t;
    }
    return defaultValue;
  }
}
