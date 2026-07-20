/// Every detector threshold, in one place. Detectors never inline numbers.
/// Units: meters, celsius, bar, seconds unless the name says otherwise.
abstract final class QualityThresholds {
  // clock_offset
  static const int futureGraceDays = 1;
  static const int minPlausibleYear = 1950;
  static const int hourOffsetMin = 1;
  static const int hourOffsetMax = 14;
  static const int hourOffsetRemainderToleranceMin = 5;

  // duplicate (DiveMatcher supplies its own 0.5/0.7 score thresholds)
  static const Duration duplicateWindow = Duration(minutes: 15);

  // split_pair
  static const Duration splitMaxGap = Duration(minutes: 10);
  static const Duration splitShallowGap = Duration(minutes: 3);
  static const double splitDeepEndMeters = 1.0;

  // sample_gap
  static const int gapMinSeconds = 30;
  static const double gapMedianFactor = 2.0;
  static const double gapWarnFractionOfRuntime = 0.10;
  static const int gapFillMaxSeconds = 300;

  // depth_spike
  static const double spikeRateMetersPerSecond = 3.0;
  static const double negativeDepthMeters = -0.5;
  static const double maxDepthMismatchFraction = 0.05;
  static const double maxDepthMismatchMinMeters = 0.5;
  static const int maxSpikeFindingsPerDive = 10;

  // impossible_rate
  static const double impossibleRateMetersPerMinute = 30.0;
  static const int impossibleRateMinSeconds = 30;

  // temp_anomaly
  static const double waterTempMinC = -2.0;
  static const double waterTempMaxC = 40.0;
  static const double tempJumpPerSampleC = 5.0;
  static const int tempJumpMaxSampleGapSeconds = 60;
  static const int maxTempJumpFindingsPerDive = 5;

  // pressure_anomaly
  static const double pressureRiseBar = 5.0;
  static const double pressureEndpointMismatchBar = 10.0;
  static const double pressureSwapMinDiffBar = 1.0;
  static const double sacSurfaceLpmMax = 100.0;
  static const int sacMinSeriesSeconds = 300;
  static const int switchProximitySeconds = 60;

  // gas_mod
  static const double ppO2WarnBar = 1.6;
  static const double ppO2CriticalBar = 1.8;
  static const int ppO2SustainSeconds = 60;
  static const double hypoxicFo2 = 0.16;
  static const double hypoxicMaxDepthMeters = 3.0;
  static const int hypoxicSustainSeconds = 120;
  static const double modToleranceMeters = 1.0;

  // tank_assignment
  static const double wrongTankInactiveDropFraction = 0.7;
  static const double wrongTankMinTotalDropBar = 20.0;
  static const double twinSeriesMeanDiffBar = 2.0;
  static const int twinSeriesMinSamples = 10;

  // source_conflict
  static const double sourceDepthDiffFraction = 0.05;
  static const double sourceDepthDiffMinMeters = 2.0;
  static const double sourceDurationDiffFraction = 0.10;
  static const double sourceTempDiffC = 3.0;
  static const double salinityRatioLow = 1.02;
  static const double salinityRatioHigh = 1.035;

  // neighbor lookup window for cross-dive detectors
  static const Duration neighborWindow = Duration(hours: 12);
}
