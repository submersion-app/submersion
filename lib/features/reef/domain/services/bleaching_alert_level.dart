/// NOAA Coral Reef Watch bleaching alert levels.
///
/// The satellite product's own `CRW_BAA` field is documented as 0-7 but the
/// data caps at 4, so during the 2023 Florida Keys event it reported 4 where
/// the published scale said 5 or 6. The level is therefore always derived from
/// Degree Heating Weeks and HotSpot rather than read from the raw field.
enum BleachingAlertLevel {
  noStress(0),
  watch(1),
  warning(2),
  alertLevel1(3),
  alertLevel2(4),
  alertLevel3(5),
  alertLevel4(6),
  alertLevel5(7);

  final int code;
  const BleachingAlertLevel(this.code);

  /// Derives the alert level from the two driving variables.
  ///
  /// [dhw] is Degree Heating Weeks in Celsius-weeks. [hotspot] is the
  /// difference between sea surface temperature and the maximum monthly mean,
  /// in Celsius. Returns null when either is unavailable, which happens on
  /// land, ice, and missing pixels.
  ///
  /// The classification is instantaneous while the accumulated damage is not:
  /// a reef can read [watch] with a catastrophic [dhw] if HotSpot has briefly
  /// dipped below 1. Callers must display Degree Heating Weeks alongside the
  /// level, never the level alone.
  static BleachingAlertLevel? derive({
    required double? dhw,
    required double? hotspot,
  }) {
    if (dhw == null || hotspot == null) return null;
    if (hotspot <= 0) return noStress;
    if (hotspot < 1) return watch;
    if (dhw < 4) return warning;
    if (dhw < 8) return alertLevel1;
    if (dhw < 12) return alertLevel2;
    if (dhw < 16) return alertLevel3;
    if (dhw < 20) return alertLevel4;
    return alertLevel5;
  }
}
