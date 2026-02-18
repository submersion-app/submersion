import 'dart:ui';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';

/// Which dive attribute to use for card background coloring.
enum CardColorAttribute {
  none,
  depth,
  duration,
  temperature,
  otu,
  maxPpO2;

  /// Parse from stored string, defaulting to none.
  static CardColorAttribute fromName(String name) {
    return CardColorAttribute.values.firstWhere(
      (e) => e.name == name,
      orElse: () => CardColorAttribute.none,
    );
  }
}

/// A named color gradient with start (low) and end (high) colors.
class CardColorGradient {
  final String name;
  final Color startColor;
  final Color endColor;

  const CardColorGradient({
    required this.name,
    required this.startColor,
    required this.endColor,
  });
}

/// Built-in gradient presets. Keyed by preset name.
const Map<String, CardColorGradient> cardColorPresets = {
  'ocean': CardColorGradient(
    name: 'Ocean',
    startColor: Color(0xFF4DD0E1),
    endColor: Color(0xFF0D1B2A),
  ),
  'thermal': CardColorGradient(
    name: 'Thermal',
    startColor: Color(0xFF2196F3),
    endColor: Color(0xFFF44336),
  ),
  'sunset': CardColorGradient(
    name: 'Sunset',
    startColor: Color(0xFFFFC107),
    endColor: Color(0xFF7B1FA2),
  ),
  'forest': CardColorGradient(
    name: 'Forest',
    startColor: Color(0xFF81C784),
    endColor: Color(0xFF1B5E20),
  ),
  'monochrome': CardColorGradient(
    name: 'Monochrome',
    startColor: Color(0xFFB0BEC5),
    endColor: Color(0xFF263238),
  ),
};

/// Extract the numeric value from a DiveSummary for a given attribute.
double? getCardColorValue(DiveSummary dive, CardColorAttribute attribute) {
  return switch (attribute) {
    CardColorAttribute.none => null,
    CardColorAttribute.depth => dive.maxDepth,
    CardColorAttribute.duration => dive.duration?.inMinutes.toDouble(),
    CardColorAttribute.temperature => dive.waterTemp,
    CardColorAttribute.otu => dive.otu,
    CardColorAttribute.maxPpO2 => dive.maxPpO2,
  };
}

/// Extract the numeric value from a full Dive entity for a given attribute.
/// OTU and maxPpO2 are not available on Dive (they are computed from profiles).
double? getCardColorValueFromDive(Dive dive, CardColorAttribute attribute) {
  return switch (attribute) {
    CardColorAttribute.none => null,
    CardColorAttribute.depth => dive.maxDepth,
    CardColorAttribute.duration => dive.duration?.inMinutes.toDouble(),
    CardColorAttribute.temperature => dive.waterTemp,
    CardColorAttribute.otu => null,
    CardColorAttribute.maxPpO2 => null,
  };
}

/// Normalize a value within [min, max] and lerp between two colors.
/// Returns null if value is null.
Color? normalizeAndLerp({
  required double? value,
  required double? min,
  required double? max,
  required Color startColor,
  required Color endColor,
}) {
  if (value == null || min == null || max == null) return null;

  final range = max - min;
  if (range <= 0) return startColor;

  final normalized = ((value - min) / range).clamp(0.0, 1.0);
  return Color.lerp(startColor, endColor, normalized);
}

/// Resolve the effective gradient colors from settings values.
({Color start, Color end}) resolveGradientColors({
  required String presetName,
  required int? customStart,
  required int? customEnd,
}) {
  if (customStart != null && customEnd != null) {
    return (start: Color(customStart), end: Color(customEnd));
  }
  final preset = cardColorPresets[presetName] ?? cardColorPresets['ocean']!;
  return (start: preset.startColor, end: preset.endColor);
}
