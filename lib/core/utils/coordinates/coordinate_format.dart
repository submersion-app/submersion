/// How GPS coordinates are rendered and entered.
///
/// Presentational only. A coordinate is always stored as two decimal-degree
/// doubles, so changing this re-renders every site without altering a single
/// stored value -- the same contract VisibilityScalePreset has for measured
/// visibility.
///
/// Enum names are persisted verbatim in `diver_settings.coordinate_format`.
/// Renaming a value silently resets that diver to the default.
enum CoordinateFormat {
  /// 20.361944 degrees N, 87.029722 degrees W. The default, and what every
  /// map service and API speaks.
  decimalDegrees,

  /// 20 degrees 21.717 minutes N. What marine GPS units and chartplotters
  /// display, so this is the form most dive-boat coordinates arrive in.
  degreesDecimalMinutes,

  /// 20 degrees 21 minutes 43.0 seconds N. The cartographic convention.
  degreesMinutesSeconds,

  /// Universal Transverse Mercator: 16Q 496898E 2251535N.
  utm,

  /// Military Grid Reference System: 16Q DH 96898 51535.
  mgrs;

  /// Whether this format fuses both axes into a single grid reference.
  ///
  /// UTM shares a zone between the axes and MGRS encodes both in one token,
  /// so neither can be typed into independent latitude and longitude fields.
  /// The input widget uses this to choose its layout.
  bool get isGridFormat =>
      this == CoordinateFormat.utm || this == CoordinateFormat.mgrs;
}
