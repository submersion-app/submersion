import 'package:flutter/material.dart';

import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';

/// Signature for a function that maps a tissue loading percentage to a color.
typedef TissueColorFn = Color Function(double percentage);

/// Available color schemes for tissue loading visualization.
///
/// Each scheme maps a 0-120+ percentage (from [subsurfacePercentage]) to a
/// color gradient optimized for different use cases.
enum TissueColorScheme {
  classic('Default'),
  thermal('Thermal');

  final String displayName;

  const TissueColorScheme(this.displayName);

  /// Legend label for the low end of the color scale.
  String get leftLabel => 'On-gassing';

  /// Legend label for the high end of the color scale.
  String get rightLabel => 'Off-gassing';

  /// Parse a [TissueColorScheme] from its [name] string.
  ///
  /// Returns [TissueColorScheme.classic] if [name] is not recognized.
  static TissueColorScheme fromName(String name) {
    for (final scheme in values) {
      if (scheme.name == name) return scheme;
    }
    return TissueColorScheme.classic;
  }
}

/// Available visualization modes for tissue loading displays.
enum TissueVizMode {
  heatMap('Heat Map'),
  stackedArea('Stacked Area');

  final String displayName;

  const TissueVizMode(this.displayName);

  /// Parse a [TissueVizMode] from its [name] string.
  ///
  /// Returns [TissueVizMode.heatMap] if [name] is not recognized.
  static TissueVizMode fromName(String name) {
    for (final mode in values) {
      if (mode.name == name) return mode;
    }
    return TissueVizMode.heatMap;
  }
}

/// Returns the [TissueColorFn] for the given [scheme].
TissueColorFn colorFnForScheme(TissueColorScheme scheme) {
  switch (scheme) {
    case TissueColorScheme.thermal:
      return thermalColor;
    case TissueColorScheme.classic:
      // subsurfaceHeatColor's optional inertFraction parameter is not
      // accessible through TissueColorFn. Default 0.79 (air) is used.
      return subsurfaceHeatColor;
  }
}

/// 4-phase cool-to-warm gradient for tissue loading.
///
/// Color mapping:
/// - 0-50%:    Blue (#1565C0) -> Cyan (#00ACC1)
/// - 50-80%:   Green (#66BB6A) -> Yellow (#FFEE58)
/// - 80-100%:  Yellow (#FFEE58) -> Red (#EF5350)
/// - 100-120%: Red (#EF5350) -> White (#FFFFFF)
/// - 120+:     White
Color thermalColor(double percentage) {
  const blue = Color(0xFF1565C0);
  const cyan = Color(0xFF00ACC1);
  const green = Color(0xFF66BB6A);
  const yellow = Color(0xFFFFEE58);
  const red = Color(0xFFEF5350);
  const white = Color(0xFFFFFFFF);

  if (percentage <= 50.0) {
    final t = (percentage / 50.0).clamp(0.0, 1.0);
    return Color.lerp(blue, cyan, t)!;
  }

  if (percentage <= 80.0) {
    final t = ((percentage - 50.0) / 30.0).clamp(0.0, 1.0);
    return Color.lerp(green, yellow, t)!;
  }

  if (percentage <= 100.0) {
    final t = ((percentage - 80.0) / 20.0).clamp(0.0, 1.0);
    return Color.lerp(yellow, red, t)!;
  }

  if (percentage <= 120.0) {
    final t = ((percentage - 100.0) / 20.0).clamp(0.0, 1.0);
    return Color.lerp(red, white, t)!;
  }

  return white;
}

/// Subsurface's HSV-based color scale for tissue loading heat map.
///
/// This is a direct port of Subsurface's `colorScale()` function from
/// `profile-widget/divepercentageitem.cpp`. Uses full-saturation HSV colors.
///
/// Color mapping (for air, inert fraction = air N2 fraction):
/// - 0 to ~31.6:    Cyan -> Blue -> Purple  (tissue far below ambient)
/// - ~31.6 to ~39.5: Magenta -> Black        (tissue near inspired gas pressure)
/// - ~39.5 to 50:    Black -> Green           (tissue between inspired and ambient)
/// - 50 to 65:       Green -> Yellow-green    (offgassing, 0-30% GF to M-value)
/// - 65 to 85:       Yellow-green -> Orange   (offgassing, 30-70% GF)
/// - 85 to 100:      Orange -> Red            (offgassing, 70-100% GF)
/// - 100 to 120:     Red -> White             (M-value exceeded)
/// - 120+:           White
Color subsurfaceHeatColor(
  double percentage, {
  double inertFraction = airN2Fraction,
}) {
  // scaledValue represents tissue tension as a fraction of inspired inert gas
  // pressure. At 1.0, tissue tension equals inspired N2 at that depth.
  final scaledValue = percentage / (50.0 * inertFraction);

  if (scaledValue < 0.8) {
    // Cyan (180) -> Blue (225) -> Purple (270): far below ambient
    final h = (0.5 + 0.25 * scaledValue / 0.8) * 360.0;
    return HSVColor.fromAHSV(1.0, h.clamp(0.0, 360.0), 1.0, 1.0).toColor();
  }

  if (scaledValue < 1.0) {
    // Magenta (270) fading to black: near inspired gas pressure
    final v = ((1.0 - scaledValue) / 0.2).clamp(0.0, 1.0);
    return HSVColor.fromAHSV(1.0, 270.0, 1.0, v).toColor();
  }

  if (percentage < 50.0) {
    // Black -> Bright green (120): between inspired and ambient
    final threshold = 50.0 * inertFraction;
    final range = 50.0 - threshold;
    final v = range > 0
        ? ((percentage - threshold) / range).clamp(0.0, 1.0)
        : 0.0;
    return HSVColor.fromAHSV(1.0, 120.0, 1.0, v).toColor();
  }

  if (percentage < 65.0) {
    // Green (120) -> Yellow-green (72): 0-30% of GF toward M-value
    final h = (0.333 - 0.133 * (percentage - 50.0) / 15.0) * 360.0;
    return HSVColor.fromAHSV(1.0, h.clamp(0.0, 360.0), 1.0, 1.0).toColor();
  }

  if (percentage < 85.0) {
    // Yellow-green (72) -> Orange (36): 30-70% of GF toward M-value
    final h = (0.2 - 0.1 * (percentage - 65.0) / 20.0) * 360.0;
    return HSVColor.fromAHSV(1.0, h.clamp(0.0, 360.0), 1.0, 1.0).toColor();
  }

  if (percentage < 100.0) {
    // Orange (36) -> Red (0): 70-100% of GF toward M-value
    final h = (0.1 * (100.0 - percentage) / 15.0) * 360.0;
    return HSVColor.fromAHSV(1.0, h.clamp(0.0, 360.0), 1.0, 1.0).toColor();
  }

  if (percentage < 120.0) {
    // Red -> White: M-value exceeded
    final s = (1.0 - (percentage - 100.0) / 20.0).clamp(0.0, 1.0);
    return HSVColor.fromAHSV(1.0, 0.0, s, 1.0).toColor();
  }

  // White: well beyond M-value
  return const Color(0xFFFFFFFF);
}

/// Subsurface-style tissue percentage: two-phase normalization relative to
/// ambient pressure.
///
/// Returns a value where:
/// - 0-50: tissue is undersaturated (tension below ambient pressure)
///   Specifically: `(tension / ambient) * 50`
/// - 50: tissue is at equilibrium with ambient pressure
/// - 50-100: tissue is supersaturated (above ambient, up to M-value)
///   Specifically: `50 + gradientFactor * 50`
/// - >100: tissue tension exceeds M-value
double subsurfacePercentage(TissueCompartment comp, double ambientPressure) {
  final tension = comp.totalInertGas;

  if (ambientPressure <= 0) return 50.0;

  if (tension < ambientPressure) {
    // Undersaturated: 0-50 range
    return (tension / ambientPressure) * 50.0;
  } else {
    // Supersaturated: 50-100+ range based on gradient factor to M-value
    final mValue = comp.blendedA + ambientPressure / comp.blendedB;
    if (mValue <= ambientPressure) return 50.0;
    final gf = (tension - ambientPressure) / (mValue - ambientPressure);
    return 50.0 + gf * 50.0;
  }
}
