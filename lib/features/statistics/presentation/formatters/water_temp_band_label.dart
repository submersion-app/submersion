/// Label for one water-temperature band: "<10", "10-18" or "24+", in whole
/// degrees of the unit the bands were defined in. The unit symbol is left to
/// the caller: the band chart puts it on the axis, the band table after the
/// label.
String waterTempBandLabel({required int? lower, required int? upper}) {
  if (lower == null) return '<$upper';
  if (upper == null) return '$lower+';
  return '$lower-$upper';
}
