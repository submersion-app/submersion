import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';

import '../../helpers/google_fonts_settle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Runtime fetching is off for this file's tests only. Set in setUpAll, not
  // here, because a CI bundle declares every file before any test runs.
  late bool originalFetching;

  // Force-initialize the theme finals inside a guarded zone so the expected
  // google_fonts load errors (fonts are not bundled in test assets) do not
  // escape as unhandled async exceptions. Mirrors app_theme_registry_test.
  setUpAll(() async {
    originalFetching = GoogleFonts.config.allowRuntimeFetching;
    GoogleFonts.config.allowRuntimeFetching = false;
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
  tearDownAll(() => GoogleFonts.config.allowRuntimeFetching = originalFetching);

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
}
