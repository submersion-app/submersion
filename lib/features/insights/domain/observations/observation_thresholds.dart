/// Every threshold in the observations spec (section 4), in one place.
abstract final class ObservationThresholds {
  static const trendMinDivesPerPeriod = 8;
  static const trendMinEffectSize = 0.5;
  static const rmvMinPercent = 8.0;
  static const maxDepthMinPercent = 15.0;
  static const diveTimeMinPercent = 15.0;
  static const weightMinKg = 1.0;
  static const frequencyMinPercent = 30.0;
  static const frequencyMinDives = 6;
  static const percentBandWidth = 10.0;
  static const weightBandKg = 1.0;
  static const recordMinLoggedDives = 10;
  static const diveGapDays = 90;
  static const favouriteSiteMinShare = 0.25;
  static const regularBuddyMinShare = 0.40;
  static const shareMinDives = 5;
  static const busiestMonthMinYears = 2;
  static const busiestMonthMinDivesPerYear = 4;
  static const ascentRateGuidanceLowMPerMin = 9.0;
  static const ascentRateGuidanceHighMPerMin = 10.0;
  static const ascentRateMinDives = 5;
  static const stripSize = 3;
  static const stripMaxPerKind = 2;
}
