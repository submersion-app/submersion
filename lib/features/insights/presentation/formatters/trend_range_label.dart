import 'package:submersion/features/insights/domain/trend_range.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// On-screen name for a Range menu entry. [menuItem] names the custom entry
/// as an action ("Custom range...") rather than a state ("Custom").
String trendRangeLabel(
  TrendRangePreset preset,
  AppLocalizations l10n, {
  bool menuItem = false,
}) => switch (preset) {
  TrendRangePreset.all => l10n.insights_trend_range_all,
  TrendRangePreset.years5 => l10n.insights_trend_range_years5,
  TrendRangePreset.years2 => l10n.insights_trend_range_years2,
  TrendRangePreset.year1 => l10n.insights_trend_range_year1,
  TrendRangePreset.months6 => l10n.insights_trend_range_months6,
  TrendRangePreset.months3 => l10n.insights_trend_range_months3,
  TrendRangePreset.custom =>
    menuItem
        ? l10n.insights_trend_range_customPick
        : l10n.insights_trend_range_custom,
};
