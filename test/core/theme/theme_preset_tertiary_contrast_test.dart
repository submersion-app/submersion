import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';

import '../../helpers/contrast_ratio.dart';
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

  // Issue #2956: Console dark set no tertiary, so it fell back to secondary,
  // which is the same navy as its cards. Every label painted in tertiary on a
  // card vanished, leaving blank gaps in the dive computer download list.
  // The floor sits below WCAG's 3:1 on purpose: it guards against a label
  // vanishing (Console dark was 1:1), not against a faint brand colour.
  // Tropical light's coral is about 2.8:1 by design.
  const floor = 2.5;

  test('every preset paints tertiary legibly on its cards', () {
    for (final preset in AppThemeRegistry.presets) {
      for (final theme in [preset.lightTheme, preset.darkTheme]) {
        final scheme = theme.colorScheme;
        // A translucent card (Deep dark's is 70%) shows the surface through
        // it, so measure the colour actually on screen.
        final card = Color.alphaBlend(
          theme.cardTheme.color ?? scheme.surfaceContainerLow,
          scheme.surface,
        );
        final mode = theme.brightness.name;
        expect(
          contrastRatio(scheme.tertiary, card),
          greaterThanOrEqualTo(floor),
          reason: '${preset.id} $mode: tertiary on card is unreadable',
        );
        expect(
          contrastRatio(scheme.tertiary, scheme.surface),
          greaterThanOrEqualTo(floor),
          reason: '${preset.id} $mode: tertiary on surface is unreadable',
        );
        expect(
          contrastRatio(scheme.onTertiary, scheme.tertiary),
          greaterThanOrEqualTo(floor),
          reason: '${preset.id} $mode: onTertiary on tertiary is unreadable',
        );
      }
    }
  });

  // Console dark is the one preset that defines its tertiary pair itself, so
  // it is held to WCAG AA for small text: tertiary labels sit on cards, and
  // the scan step's known-computer badge puts onTertiary text on a tertiary
  // fill.
  test('Console dark tertiary pairs meet 4.5:1 for small text', () {
    final theme = AppThemeRegistry.findById('console').darkTheme;
    final scheme = theme.colorScheme;
    expect(
      contrastRatio(scheme.tertiary, theme.cardTheme.color!),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrastRatio(scheme.onTertiary, scheme.tertiary),
      greaterThanOrEqualTo(4.5),
    );
  });
}
