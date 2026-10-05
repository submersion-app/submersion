import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';

import '../../helpers/google_fonts_settle.dart';

/// WCAG 2.1 contrast ratio between two opaque colors.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// WCAG AA minimum for normal-size text.
const double _aaText = 4.5;

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
    void expectContainers(
      String description,
      Color Function(ColorScheme scheme, Color onContainer) foreground,
    ) {
      for (final preset in AppThemeRegistry.presets) {
        for (final brightness in Brightness.values) {
          final scheme = AppThemeRegistry.resolveTheme(
            preset,
            brightness,
          ).colorScheme;
          for (final MapEntry(key: role, value: (container, onContainer))
              in _containers(scheme).entries) {
            expect(
              _contrast(foreground(scheme, onContainer), container),
              greaterThanOrEqualTo(_aaText),
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
  });
}
