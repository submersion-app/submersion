/// Reads a UDDF waypoint `<gradientfactor>` as GF99, a whole percent.
///
/// Shearwater Cloud and Subsurface write whole percents ("0", "63"). Some
/// writers use a fraction of one instead ("0.63"); a value with a decimal
/// point in (0, 1] is read as such and scaled to percent. Nothing is
/// clamped, so a supersaturated 120 stays 120. Blank, non-numeric and
/// non-finite text read as null.
int? parseUddfGradientFactorPercent(String? text) {
  if (text == null) return null;
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  final asInt = int.tryParse(trimmed);
  if (asInt != null) return asInt;

  final asDouble = double.tryParse(trimmed);
  if (asDouble == null || !asDouble.isFinite) return null;

  final isFraction = trimmed.contains('.') && asDouble > 0 && asDouble <= 1.0;
  return isFraction ? (asDouble * 100).round() : asDouble.round();
}
