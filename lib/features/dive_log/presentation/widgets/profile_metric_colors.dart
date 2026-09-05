import 'package:flutter/material.dart';

import 'package:submersion/core/theme/app_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/deco_stop_band.dart';

/// Base colour of every profile-chart metric, shared by the primary trace,
/// its tooltip bullet, the chart-options swatch, and the per-computer overlay
/// tints derived through [overlayTint]. Temperature is deliberately absent:
/// it follows the theme's `colorScheme.tertiary`.
abstract final class ProfileMetricColors {
  static const Color depth = AppColors.chartDepth;
  static const Color pressure = Colors.orange;
  static const Color heartRate = Color(0xFFF44336); // Red 500
  static const Color sac = Color(0xFF009688); // Teal 500
  static const Color ascentRateLine = Color(0xFFCDDC39); // Lime 500

  /// Legend colour for the velocity-band tinting of the depth line, which has
  /// no single line colour of its own.
  static const Color ascentRateColors = Color(0xFF43A047); // Green 600

  // Markers and event glyphs.
  static const Color events = Color(0xFF00838F); // Cyan 800
  static const Color maxDepth = Color(0xFF880E4F); // Pink 900
  static const Color pressureMarkers = Color(0xFFBF360C); // Deep Orange 900
  static const Color decoStops = decoStopBandColor;
  static const Color ceiling = Color(0xFF7B1FA2); // Purple 700
  static const Color ndl = Color(0xFFFBC02D); // Yellow 700
  static const Color tts = Color(0xFFAD1457); // Pink 800
  static const Color gtr = Color(0xFF2E7D32); // Green 800
  static const Color cns = Color(0xFFE65100); // Orange 900
  static const Color otu = Color(0xFF6D4C41); // Brown 600
  static const Color ppO2 = Color(0xFF00ACC1); // Cyan 600
  static const Color ppN2 = Color(0xFF3F51B5); // Indigo 500
  static const Color ppHe = Color(0xFFF48FB1); // Pink 300
  static const Color mod = Color(0xFFFFB300); // Amber 600
  static const Color density = Color(0xFF827717); // Lime 900
  static const Color gf = Color(0xFF673AB7); // Deep Purple 500
  static const Color surfaceGf = Color(0xFFBA68C8); // Purple 300
  static const Color meanDepth = Color(0xFF607D8B); // Blue Grey 500
}

/// Lightness added per overlaid computer, so the second computer's trace is
/// a clearly lighter tint of the same hue and a third one lighter still.
const double _overlayTintStep = 0.2;

/// Ceiling on lightness so heavily tinted traces never wash out to white.
const double _overlayTintMaxLightness = 0.86;

/// Colour for an overlaid computer's trace of a metric whose primary trace is
/// [base]: the same hue, lightened by [overlayIndex] + 1 steps. Keeps the
/// metric recognisable across computers (depth blue vs light blue, TTS
/// magenta vs light magenta) instead of collapsing every metric of the second
/// computer onto one shared source colour.
Color overlayTint(Color base, int overlayIndex) {
  final hsl = HSLColor.fromColor(base);
  final lightness = (hsl.lightness + (overlayIndex + 1) * _overlayTintStep)
      .clamp(0.0, _overlayTintMaxLightness);
  return hsl.withLightness(lightness).toColor();
}
