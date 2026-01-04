import 'package:flutter/material.dart';

import '../../domain/entities/dive.dart';
import '../providers/gas_switch_providers.dart';

/// Color scheme for different gas types on dive profile charts.
///
/// Colors are chosen to be easily distinguishable and match common
/// diving conventions:
/// - Air: Blue (standard, most common)
/// - Nitrox: Green (enriched air = "greener" for your body)
/// - Trimix: Purple (technical diving = more exotic)
class GasColors {
  GasColors._(); // Prevent instantiation

  /// Color for Air (21% O2, no He) - uses theme primary or default blue
  static const Color air = Color(0xFF2196F3); // Blue

  /// Color for Nitrox (>21% O2, no He)
  static const Color nitrox = Color(0xFF4CAF50); // Green

  /// Color for Trimix (contains He)
  static const Color trimix = Color(0xFF9C27B0); // Purple

  /// Get color for a gas type enum
  static Color forGasType(GasType type) {
    switch (type) {
      case GasType.air:
        return air;
      case GasType.nitrox:
        return nitrox;
      case GasType.trimix:
        return trimix;
    }
  }

  /// Get color for a GasMix object
  static Color forGasMix(GasMix gasMix) {
    if (gasMix.isTrimix) return trimix;
    if (gasMix.isNitrox) return nitrox;
    return air;
  }

  /// Get color for O2 and He percentages (0-100 scale)
  static Color forMixPercent(double o2Percent, double hePercent) {
    if (hePercent > 0) return trimix;
    if (o2Percent > 22) return nitrox;
    return air;
  }

  /// Get color for O2 and He fractions (0-1 scale)
  static Color forMixFraction(double o2Fraction, double heFraction) {
    if (heFraction > 0) return trimix;
    if (o2Fraction > 0.22) return nitrox;
    return air;
  }

  /// Get a lighter fill color for use in chart area fills
  static Color fillColor(Color gasColor, {double opacity = 0.2}) {
    return gasColor.withValues(alpha: opacity);
  }

  /// Get gradient colors for a gas type (for chart fills)
  static List<Color> gradientColors(Color gasColor) {
    return [gasColor.withValues(alpha: 0.05), gasColor.withValues(alpha: 0.3)];
  }
}
