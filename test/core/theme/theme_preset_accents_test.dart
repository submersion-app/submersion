import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';

import '../../helpers/google_fonts_settle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Force-initialize the theme finals inside a guarded zone so the expected
  // google_fonts load errors (fonts are not bundled in test assets) do not
  // escape as unhandled async exceptions. Mirrors app_theme_registry_test.
  setUpAll(() async {
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
    try {
      await runZonedGuarded(
        () async {
          // ignore: unnecessary_statements
          AppThemeRegistry.presets;
          // Bounded: a font load another file left pending never finishes.
          await settleGoogleFonts();
        },
        (error, stack) {
          // Silently absorb google_fonts errors in the test environment.
        },
      );
    } finally {
      debugPrint = originalDebugPrint;
    }
  });

  test('every theme preset registers FeatureAccentColors in both modes', () {
    for (final preset in AppThemeRegistry.presets) {
      expect(
        preset.lightTheme.extension<FeatureAccentColors>(),
        same(FeatureAccentColors.light),
        reason: '${preset.id} light theme missing accents',
      );
      expect(
        preset.darkTheme.extension<FeatureAccentColors>(),
        same(FeatureAccentColors.dark),
        reason: '${preset.id} dark theme missing accents',
      );
    }
  });

  test('buddies accent text reads at 4.5:1 on every preset card', () {
    // The buddies accent colours the dive count, last-dive date and initials
    // on each buddy card, so it is held to the WCAG AA bar for small text on
    // the surface it actually sits on, not the 3:1 icon bar (#3584).
    for (final preset in AppThemeRegistry.presets) {
      for (final theme in [preset.lightTheme, preset.darkTheme]) {
        // Material 3 cards default to surfaceContainerLow.
        final card =
            theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow;
        final accent = theme.extension<FeatureAccentColors>()!.of('buddies')!;
        expect(
          _contrast(accent, card),
          greaterThanOrEqualTo(4.5),
          reason: '${preset.id} ${theme.brightness.name} card',
        );
      }
    }
  });
}

// WCAG 2.1 contrast ratio.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
