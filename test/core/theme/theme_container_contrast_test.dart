import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';

import '../../helpers/contrast_ratio.dart';
import '../../helpers/google_fonts_settle.dart';

/// WCAG AA minimum for normal-size text.
const double _aaText = 4.5;

/// Minimum contrast between a container and the surface beneath it, so a
/// selection indicator or warning banner reads as a distinct fill. The seeded
/// Submersion light theme sits at 1.23.
const double _fillSeparation = 1.15;

/// Each container role with the foreground the scheme pairs it with.
Map<String, (Color, Color)> _containers(ColorScheme s) => {
  'primaryContainer': (s.primaryContainer, s.onPrimaryContainer),
  'secondaryContainer': (s.secondaryContainer, s.onSecondaryContainer),
  'tertiaryContainer': (s.tertiaryContainer, s.onTertiaryContainer),
  'errorContainer': (s.errorContainer, s.onErrorContainer),
};

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

  // A hand-built ColorScheme that omits a container role falls back to the
  // accent itself (primaryContainer -> primary), so plain body text drawn on
  // a "container" became white on bright teal in the Console theme (#2959).
  // Container roles are low-emphasis fills: both their paired foreground and
  // the scheme's ordinary onSurface text must read on them.
  //
  // The registry is read inside each test body, never while tests register:
  // touching it builds the GoogleFonts-backed theme finals, which must happen
  // inside setUpAll's guarded zone.
  group('theme container roles', () {
    /// Checks every container on every preset against the colour [against]
    /// picks, which must reach [minimum] contrast with it.
    void expectContainers(
      String description,
      Color Function(ColorScheme scheme, Color onContainer) against, {
      double minimum = _aaText,
    }) {
      for (final preset in AppThemeRegistry.presets) {
        for (final brightness in Brightness.values) {
          final scheme = AppThemeRegistry.resolveTheme(
            preset,
            brightness,
          ).colorScheme;
          for (final MapEntry(key: role, value: (container, onContainer))
              in _containers(scheme).entries) {
            expect(
              contrastRatio(against(scheme, onContainer), container),
              greaterThanOrEqualTo(minimum),
              reason: '${preset.id} ${brightness.name} $role: $description',
            );
          }
        }
      }
    }

    test('paired foreground meets WCAG AA on every preset', () {
      expectContainers('paired foreground', (_, onContainer) => onContainer);
    });

    test('onSurface text meets WCAG AA on every preset', () {
      expectContainers('onSurface text', (scheme, _) => scheme.onSurface);
    });

    // A container tinted from an accent that sits close to the surface (a
    // dark red error, Console dark's app-bar navy secondary) vanishes into it.
    test('every container stands apart from the surface', () {
      expectContainers(
        'separation from surface',
        (scheme, _) => scheme.surface,
        minimum: _fillSeparation,
      );
    });
  });

  // Console dark once used its app-bar navy as secondary: 1.10:1 on the
  // surface, so every secondary-coloured icon and label vanished.
  test('Console dark secondary and tertiary read on the surface', () {
    final scheme = AppThemeRegistry.resolveTheme(
      AppThemeRegistry.findById('console'),
      Brightness.dark,
    ).colorScheme;
    expect(
      contrastRatio(scheme.secondary, scheme.surface),
      greaterThanOrEqualTo(_aaText),
    );
    expect(
      contrastRatio(scheme.tertiary, scheme.surface),
      greaterThanOrEqualTo(_aaText),
    );
    expect(
      contrastRatio(scheme.onSecondary, scheme.secondary),
      greaterThanOrEqualTo(_aaText),
    );
  });

  group('theme error role', () {
    test('error reads on the surface and onError reads on error', () {
      for (final preset in AppThemeRegistry.presets) {
        for (final brightness in Brightness.values) {
          final scheme = AppThemeRegistry.resolveTheme(
            preset,
            brightness,
          ).colorScheme;
          final label = '${preset.id} ${brightness.name}';
          expect(
            contrastRatio(scheme.error, scheme.surface),
            greaterThanOrEqualTo(_aaText),
            reason: '$label: error on surface',
          );
          expect(
            contrastRatio(scheme.onError, scheme.error),
            greaterThanOrEqualTo(_aaText),
            reason: '$label: onError on error',
          );
        }
      }
    });
  });
}
