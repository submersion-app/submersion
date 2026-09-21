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
          // A solid accent badge carries an onAccent-colored icon (the
          // equipment summary's service-due avatar); icons need 3:1.
          //
          // This is its own slot rather than a reuse of container because
          // accent flips sides between modes: it is dark on a light page and
          // light on a dark one, so the color that reads on top of it is
          // white in one mode and near-black in the other.
          expect(
            _contrast(swatch.onAccent, swatch.accent),
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

    test('light containers are solid fills, not pastel washes', () {
      // The pastel light palette put the chip fill 1.05:1 against the page,
      // so a status chip read as a faint smudge next to dark mode's 1.55:1.
      // Solid fills with reversed labels are the fix; pinning them here
      // stops a later tweak from drifting back toward the wash.
      expect(StatusColors.light.alert.container, const Color(0xFFC62828));
      expect(StatusColors.light.alert.onContainer, const Color(0xFFFFFFFF));
      expect(StatusColors.light.warn.container, const Color(0xFFF0A81E));
      expect(StatusColors.light.ok.container, const Color(0xFF256D2B));
      expect(StatusColors.light.ok.onContainer, const Color(0xFFFFFFFF));
    });

    test('light warn keeps a dark label so the fill stays amber', () {
      // White on amber needs the fill dragged down to a brown before it
      // clears AA, which reads as a third red among the alert chips.
      expect(StatusColors.light.warn.onContainer, const Color(0xFF3A2200));
    });

    test('dark keeps the glyph color it rendered before onAccent existed', () {
      // onAccent was extracted from container, so dark must be unchanged.
      for (final MapEntry(key: tone, value: swatch) in _swatches(
        StatusColors.dark,
      ).entries) {
        expect(
          swatch.onAccent,
          swatch.container,
          reason: 'dark $tone avatar glyph moved',
        );
      }
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
      expect(mid.warn.onAccent, Color.lerp(light.onAccent, dark.onAccent, .5));
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
        onAccent: light.onAccent,
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
