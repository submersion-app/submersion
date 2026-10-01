/// Reads a UDDF waypoint `<gradientfactor>` as GF99, a whole percent.
///
/// Shearwater Cloud and Subsurface write whole percents ("0", "63"). A
/// decimal is read as a percent too and rounded: no known writer emits a
/// fraction of one, and reading "1.0" as one would turn a 1% GF99 into
/// 100%. Nothing is clamped, so a supersaturated 120 stays 120. Blank,
/// non-numeric and non-finite text read as null.
int? parseUddfGradientFactorPercent(String? text) {
  if (text == null) return null;
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  final asInt = int.tryParse(trimmed);
  if (asInt != null) return asInt;

  final asDouble = double.tryParse(trimmed);
  if (asDouble == null || !asDouble.isFinite) return null;
  return asDouble.round();
}
