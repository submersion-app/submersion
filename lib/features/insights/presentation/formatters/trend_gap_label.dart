import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The threshold's name in the Range menu and the Settings picker.
String trendGapThresholdLabel(TrendGapThreshold t, AppLocalizations l10n) =>
    switch (t) {
      TrendGapThreshold.off => l10n.insights_trend_gaps_off,
      TrendGapThreshold.months6 => l10n.insights_trend_gaps_months6,
      TrendGapThreshold.year1 => l10n.insights_trend_gaps_year1,
      TrendGapThreshold.years2 => l10n.insights_trend_gaps_years2,
    };

/// Whole calendar months from [start] to [end], ignoring time of day.
int calendarMonthsBetween(DateTime start, DateTime end) {
  var months = (end.year - start.year) * 12 + end.month - start.month;
  if (end.day < start.day) months--;
  return months < 0 ? 0 : months;
}

/// A collapsed break's length for the label under its band: "6y 9m", or
/// "3y" or "7m" when one part is zero.
String trendGapLengthLabel(
  DateTime start,
  DateTime end,
  AppLocalizations l10n,
) {
  final total = calendarMonthsBetween(start, end);
  final years = total ~/ 12;
  final months = total % 12;
  if (years == 0) return l10n.insights_trend_gap_months(months);
  if (months == 0) return l10n.insights_trend_gap_years(years);
  return l10n.insights_trend_gap_yearsMonths(years, months);
}
