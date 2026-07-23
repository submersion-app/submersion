import 'package:flutter/material.dart';

/// Curated per-feature-area accent colors, exposed as a [ThemeExtension] so
/// lookups resolve against the active theme brightness and animate across
/// theme changes. Keys are the stable `NavDestination.id` strings plus
/// `settings-<sectionId>` entries for the settings root sections. A missing
/// key means "no accent" -- callers fall back to the ambient icon color.
class FeatureAccentColors extends ThemeExtension<FeatureAccentColors> {
  const FeatureAccentColors({required this.colors});

  final Map<String, Color> colors;

  Color? of(String featureId) => colors[featureId];

  static const FeatureAccentColors light = FeatureAccentColors(
    colors: {
      'dashboard': Color(0xFF0077B6),
      'dives': Color(0xFF1976D2),
      'sites': Color(0xFF388E3C),
      'trips': Color(0xFF7B1FA2),
      // Orange and amber are the two hues that go illegible first on a light
      // surface, so these are deepened past their Material 700 shades to keep
      // every light-mode accent at or above the 3:1 WCAG contrast ratio for
      // graphical objects.
      'equipment': Color(0xFFE65100),
      'buddies': Color(0xFFC2185B),
      'dive-centers': Color(0xFF6D4C41),
      'certifications': Color(0xFFB45309),
      'courses': Color(0xFF303F9F),
      'statistics': Color(0xFF00796B),
      'planning': Color(0xFF512DA8),
      'transfer': Color(0xFF0097A7),
      'gps-log': Color(0xFFD32F2F),
      'settings': Color(0xFF455A64),
      // Settings root sections: identical to the colors previously hardcoded
      // on settingsSections so the root page look does not change.
      'settings-about': Color(0xFF607D8B),
      'settings-appearance': Color(0xFFE91E63),
      'settings-data': Color(0xFF4CAF50),
      'settings-dataSources': Color(0xFFF44336),
      'settings-decompression': Color(0xFF673AB7),
      'settings-profile': Color(0xFF2196F3),
      'settings-safety': Color(0xFFFF5252),
      'settings-manage': Color(0xFF3F51B5),
      'settings-notifications': Color(0xFFFF9800),
      'settings-sharedData': Color(0xFF00BCD4),
      'settings-units': Color(0xFF009688),
      'settings-debug': Color(0xFF9E9E9E),
    },
  );

  static const FeatureAccentColors dark = FeatureAccentColors(
    colors: {
      'dashboard': Color(0xFF48CAE4),
      'dives': Color(0xFF64B5F6),
      'sites': Color(0xFF81C784),
      'trips': Color(0xFFBA68C8),
      'equipment': Color(0xFFFFB74D),
      'buddies': Color(0xFFF06292),
      'dive-centers': Color(0xFFBCAAA4),
      'certifications': Color(0xFFFFD54F),
      'courses': Color(0xFF7986CB),
      'statistics': Color(0xFF4DB6AC),
      'planning': Color(0xFF9575CD),
      'transfer': Color(0xFF4DD0E1),
      'gps-log': Color(0xFFE57373),
      'settings': Color(0xFF90A4AE),
      'settings-about': Color(0xFF90A4AE),
      'settings-appearance': Color(0xFFF06292),
      'settings-data': Color(0xFF81C784),
      'settings-dataSources': Color(0xFFE57373),
      'settings-decompression': Color(0xFF9575CD),
      'settings-profile': Color(0xFF64B5F6),
      'settings-safety': Color(0xFFFF8A80),
      'settings-manage': Color(0xFF7986CB),
      'settings-notifications': Color(0xFFFFB74D),
      'settings-sharedData': Color(0xFF4DD0E1),
      'settings-units': Color(0xFF4DB6AC),
      'settings-debug': Color(0xFFBDBDBD),
    },
  );

  @override
  FeatureAccentColors copyWith({Map<String, Color>? colors}) {
    return FeatureAccentColors(colors: colors ?? this.colors);
  }

  @override
  FeatureAccentColors lerp(
    ThemeExtension<FeatureAccentColors>? other,
    double t,
  ) {
    if (other is! FeatureAccentColors) return this;
    final keys = {...colors.keys, ...other.colors.keys};
    return FeatureAccentColors(
      colors: {
        for (final key in keys)
          key:
              Color.lerp(colors[key], other.colors[key], t) ??
              (other.colors[key] ?? colors[key]!),
      },
    );
  }
}
