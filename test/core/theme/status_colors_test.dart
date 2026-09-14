import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/core/theme/status_colors.dart';

/// WCAG 2.1 contrast ratio between two opaque colors.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// WCAG AA minimum for normal-size text; chip labels and the equipment
/// list's due labels are 11-12sp, well under the large-text threshold.
const double _aaText = 4.5;

Map<String, StatusSwatch> _swatches(StatusColors c) => {
  'alert': c.alert,
  'warn': c.warn,
  'ok': c.ok,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

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
          try {
            await GoogleFonts.pendingFonts();
          } catch (_) {
            // Expected: fonts are not bundled in test assets.
          }
        },
        (error, stack) {
          // Silently absorb google_fonts errors in the test environment.
        },
      );
    } finally {
      debugPrint = originalDebugPrint;
    }
  });

  group('StatusColors palette', () {
    for (final (mode, palette) in [
      ('light', StatusColors.light),
      ('dark', StatusColors.dark),
    ]) {
      for (final MapEntry(key: tone, value: swatch) in _swatches(
        palette,
      ).entries) {
        test('$mode $tone label is AA legible on its container', () {
          expect(
            _contrast(swatch.onContainer, swatch.container),
            greaterThanOrEqualTo(_aaText),
          );
        });

        test('$mode $tone badge glyph is legible on its accent', () {
          // A solid accent badge carries a container-colored icon (the
          // equipment summary's service-due avatar); icons need 3:1.
          expect(
            _contrast(swatch.container, swatch.accent),
            greaterThanOrEqualTo(3.0),
          );
        });

        test('$mode $tone outline is distinct from its container', () {
          expect(swatch.outline, isNot(swatch.container));
        });
      }
    }

    test('the three tones use three different hues in each mode', () {
      for (final palette in [StatusColors.light, StatusColors.dark]) {
        final containers = _swatches(palette).values.map((s) => s.container);
        expect(containers.toSet(), hasLength(3));
      }
    });

    test('dark alert keeps the established overdue chip colors', () {
      expect(StatusColors.dark.alert.container, const Color(0xFF93000A));
      expect(StatusColors.dark.alert.onContainer, const Color(0xFFFFDAD6));
    });
  });

  group('StatusColors against every theme preset', () {
    test('every preset registers the palette in both modes', () {
      for (final preset in AppThemeRegistry.presets) {
        expect(
          preset.lightTheme.extension<StatusColors>(),
          same(StatusColors.light),
          reason: '${preset.id} light theme missing status colors',
        );
        expect(
          preset.darkTheme.extension<StatusColors>(),
          same(StatusColors.dark),
          reason: '${preset.id} dark theme missing status colors',
        );
      }
    });

    test('accents are AA legible on every preset surface', () {
      for (final preset in AppThemeRegistry.presets) {
        for (final theme in [preset.lightTheme, preset.darkTheme]) {
          final scheme = theme.colorScheme;
          final palette = theme.extension<StatusColors>()!;
          // Accents are drawn straight onto the page (Service clocks dots,
          // the list's due labels) and onto cards, which M3 paints with
          // surfaceContainerLow.
          for (final surface in [scheme.surface, scheme.surfaceContainerLow]) {
            for (final MapEntry(key: tone, value: swatch) in _swatches(
              palette,
            ).entries) {
              expect(
                _contrast(swatch.accent, surface),
                greaterThanOrEqualTo(_aaText),
                reason:
                    '${preset.id} ${theme.brightness.name} $tone accent '
                    'on $surface',
              );
            }
          }
        }
      }
    });
  });

  group('StatusColors.of', () {
    Future<StatusColors> resolve(WidgetTester tester, ThemeData theme) async {
      late StatusColors resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              resolved = StatusColors.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return resolved;
    }

    testWidgets('reads the registered extension', (tester) async {
      final custom = StatusColors.light.copyWith(warn: StatusColors.dark.warn);
      final resolved = await resolve(tester, ThemeData(extensions: [custom]));
      expect(resolved, same(custom));
    });

    testWidgets('falls back to the light palette on a bare light theme', (
      tester,
    ) async {
      final resolved = await resolve(tester, ThemeData());
      expect(resolved, same(StatusColors.light));
    });

    testWidgets('falls back to the dark palette on a bare dark theme', (
      tester,
    ) async {
      final resolved = await resolve(
        tester,
        ThemeData(brightness: Brightness.dark),
      );
      expect(resolved, same(StatusColors.dark));
    });
  });

  group('ThemeExtension contract', () {
    test('lerp interpolates every slot of every tone', () {
      final mid = StatusColors.light.lerp(StatusColors.dark, 0.5);
      final light = StatusColors.light.warn;
      final dark = StatusColors.dark.warn;
      expect(
        mid.warn.container,
        Color.lerp(light.container, dark.container, .5),
      );
      expect(
        mid.warn.onContainer,
        Color.lerp(light.onContainer, dark.onContainer, .5),
      );
      expect(mid.warn.outline, Color.lerp(light.outline, dark.outline, .5));
      expect(mid.warn.accent, Color.lerp(light.accent, dark.accent, .5));
    });

    test('lerp against a foreign extension returns itself', () {
      expect(StatusColors.light.lerp(null, 0.5), same(StatusColors.light));
    });

    test('swatches compare by value and hash alike', () {
      final light = StatusColors.light.alert;
      final copy = StatusSwatch(
        container: light.container,
        onContainer: light.onContainer,
        outline: light.outline,
        accent: light.accent,
      );
      expect(copy, light);
      expect(copy.hashCode, light.hashCode);
      expect({copy, light}, hasLength(1));
      expect(StatusColors.dark.alert, isNot(light));
    });

    test('copyWith replaces only the named tone', () {
      final replaced = StatusColors.light.copyWith(ok: StatusColors.dark.ok);
      expect(replaced.ok, StatusColors.dark.ok);
      expect(replaced.alert, StatusColors.light.alert);
      expect(replaced.warn, StatusColors.light.warn);
    });
  });
}
