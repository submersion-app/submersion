import 'package:flutter/material.dart';

/// Available metrics for the right Y-axis on dive profile charts.
///
/// Each metric includes display metadata and rendering configuration.
/// The chart uses these to dynamically render the appropriate axis labels
/// and scale the data correctly.
enum ProfileRightAxisMetric {
  temperature(
    displayName: 'Temperature',
    shortName: 'Temp',
    color: null, // Uses colorScheme.tertiary
    unitSuffix: null, // Uses unit formatter
    category: ProfileMetricCategory.primary,
  ),
  pressure(
    displayName: 'Pressure',
    shortName: 'Press',
    color: Colors.orange,
    unitSuffix: null, // Uses unit formatter
    category: ProfileMetricCategory.primary,
  ),
  heartRate(
    displayName: 'Heart Rate',
    shortName: 'HR',
    color: Colors.red,
    unitSuffix: 'bpm',
    category: ProfileMetricCategory.primary,
  ),
  sac(
    displayName: 'SAC Rate',
    shortName: 'SAC',
    color: Colors.teal,
    unitSuffix: null, // Uses unit formatter (bar/min or L/min)
    category: ProfileMetricCategory.primary,
  ),
  ndl(
    displayName: 'NDL',
    shortName: 'NDL',
    color: Color(0xFF689F38), // Colors.lightGreen.shade700
    unitSuffix: 'min',
    category: ProfileMetricCategory.decompression,
  ),
  ppO2(
    displayName: 'ppO2',
    shortName: 'ppO2',
    color: Color(0xFF00ACC1), // Cyan 600 - distinct from depth blue
    unitSuffix: 'bar',
    category: ProfileMetricCategory.gasAnalysis,
  ),
  ppN2(
    displayName: 'ppN2',
    shortName: 'ppN2',
    color: Colors.indigo,
    unitSuffix: 'bar',
    category: ProfileMetricCategory.gasAnalysis,
  ),
  ppHe(
    displayName: 'ppHe',
    shortName: 'ppHe',
    color: Color(0xFFF48FB1), // Colors.pink.shade300
    unitSuffix: 'bar',
    category: ProfileMetricCategory.gasAnalysis,
  ),
  gasDensity(
    displayName: 'Gas Density',
    shortName: 'Density',
    color: Colors.brown,
    unitSuffix: 'g/L',
    category: ProfileMetricCategory.gasAnalysis,
  ),
  gf(
    displayName: 'GF%',
    shortName: 'GF%',
    color: Colors.deepPurple,
    unitSuffix: '%',
    category: ProfileMetricCategory.gradientFactor,
  ),
  surfaceGf(
    displayName: 'Surface GF',
    shortName: 'SrfGF',
    color: Color(0xFFBA68C8), // Colors.purple.shade300
    unitSuffix: '%',
    category: ProfileMetricCategory.gradientFactor,
  ),
  meanDepth(
    displayName: 'Mean Depth',
    shortName: 'Mean',
    color: Colors.blueGrey,
    unitSuffix: null, // Uses unit formatter
    category: ProfileMetricCategory.other,
  ),
  tts(
    displayName: 'TTS',
    shortName: 'TTS',
    color: Color(0xFFAD1457), // Pink 800 - distinct from pressure orange
    unitSuffix: 'min',
    category: ProfileMetricCategory.decompression,
  );

  final String displayName;
  final String shortName;
  final Color? color;
  final String? unitSuffix;
  final ProfileMetricCategory category;

  const ProfileRightAxisMetric({
    required this.displayName,
    required this.shortName,
    required this.color,
    required this.unitSuffix,
    required this.category,
  });

  /// Fallback priority chain for when selected metric has no data.
  /// Returns metrics in order of preference for automatic fallback.
  static const List<ProfileRightAxisMetric> fallbackPriority = [
    temperature,
    pressure,
    heartRate,
    sac,
    ndl,
    ppO2,
  ];

  /// Get the effective color, using theme color for temperature
  Color getColor(ColorScheme colorScheme) {
    return color ?? colorScheme.tertiary;
  }
}

/// Categories for grouping metrics in the UI
enum ProfileMetricCategory {
  primary('Primary Metrics'),
  decompression('Decompression'),
  gasAnalysis('Gas Analysis'),
  gradientFactor('Gradient Factors'),
  other('Other');

  final String displayName;
  const ProfileMetricCategory(this.displayName);
}

/// Extension to get metrics by category
extension ProfileMetricCategoryExtension on ProfileMetricCategory {
  List<ProfileRightAxisMetric> get metrics {
    return ProfileRightAxisMetric.values
        .where((m) => m.category == this)
        .toList();
  }
}
