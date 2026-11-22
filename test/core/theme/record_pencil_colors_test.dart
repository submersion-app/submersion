import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/core/theme/record_pencil_colors.dart';

import '../../helpers/contrast_ratio.dart';
import '../../helpers/google_fonts_settle.dart';

/// WCAG 1.4.11: a graphical object a diver needs to see, such as the
/// pencil that opens a card, needs 3:1 against what it sits on.
const double _graphic = 3.0;

/// The colour a card is painted with under [theme].
Color _card(ThemeData theme) =>
    theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow;

/// The pencil on an unlocked card is an amber yellow disc rather than a
/// shade of the theme's own blue, so it stands out from everything else on
/// the page, and the dot that marks unsaved changes wears it too
/// (issue #4527).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Force-initialize the theme finals inside a guarded zone so the expected
  // google_fonts load errors (fonts are not bundled in test assets) do not
  // escape as unhandled async exceptions. Mirrors status_colors_test.
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

  group('RecordPencilColors palette', () {
    test('the glyph reads on its disc in both modes', () {
      for (final palette in [
        RecordPencilColors.light,
        RecordPencilColors.dark,
      ]) {
        expect(
          contrastRatio(palette.onFill, palette.fill),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('the pencil is the same in every preset', () {
      for (final preset in AppThemeRegistry.presets) {
        for (final brightness in Brightness.values) {
          final theme = AppThemeRegistry.resolveTheme(preset, brightness);
          expect(
            theme.extension<RecordPencilColors>(),
            brightness == Brightness.light
                ? RecordPencilColors.light
                : RecordPencilColors.dark,
            reason: '${preset.id} ${brightness.name}',
          );
        }
      }
    });

    // A yellow disc is bright but barely darker than a light card, so in
    // light mode its ring is the edge a diver sees.
    test('in light mode the ring stands off every preset\'s card', () {
      for (final preset in AppThemeRegistry.presets) {
        final theme = AppThemeRegistry.resolveTheme(preset, Brightness.light);
        for (final surface in [_card(theme), theme.scaffoldBackgroundColor]) {
          expect(
            contrastRatio(RecordPencilColors.light.outline, surface),
            greaterThanOrEqualTo(_graphic),
            reason: preset.id,
          );
        }
      }
    });

    test('in dark mode the disc stands off every preset\'s card', () {
      for (final preset in AppThemeRegistry.presets) {
        final theme = AppThemeRegistry.resolveTheme(preset, Brightness.dark);
        for (final surface in [_card(theme), theme.scaffoldBackgroundColor]) {
          expect(
            contrastRatio(RecordPencilColors.dark.fill, surface),
            greaterThanOrEqualTo(_graphic),
            reason: preset.id,
          );
        }
      }
    });

    // Eric chose an amber yellow (issue #4527): a warm hue no preset's
    // primary comes near, so the pencil cannot read as the page's accent.
    test('the pencil is an amber yellow, far from every preset\'s primary', () {
      double hue(Color c) => HSVColor.fromColor(c).hue;
      for (final pencil in [
        RecordPencilColors.light,
        RecordPencilColors.dark,
      ]) {
        expect(hue(pencil.fill), inInclusiveRange(40, 50));
      }
      for (final preset in AppThemeRegistry.presets) {
        for (final brightness in Brightness.values) {
          final primary = AppThemeRegistry.resolveTheme(
            preset,
            brightness,
          ).colorScheme.primary;
          final pencil = brightness == Brightness.light
              ? RecordPencilColors.light
              : RecordPencilColors.dark;
          // Measured round the colour wheel: hue 355 is 50 from hue 45.
          final gap = (hue(primary) - hue(pencil.fill)).abs();
          final apart = gap > 180 ? 360 - gap : gap;
          expect(
            // A grey primary has no hue to compare.
            HSVColor.fromColor(primary).saturation < .2 || apart >= 60,
            isTrue,
            reason: '${preset.id} ${brightness.name}',
          );
        }
      }
    });
  });

  group('RecordPencilColors.of', () {
    testWidgets('reads the theme\'s extension', (tester) async {
      const custom = RecordPencilColors(
        fill: Color(0xFF112233),
        onFill: Color(0xFFFFFFFF),
        outline: Color(0xFF445566),
      );
      late RecordPencilColors read;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [custom]),
          home: Builder(
            builder: (context) {
              read = RecordPencilColors.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(read, custom);
    });

    for (final brightness in Brightness.values) {
      testWidgets('falls back by brightness with none (${brightness.name})', (
        tester,
      ) async {
        late RecordPencilColors read;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Builder(
              builder: (context) {
                read = RecordPencilColors.of(context);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(
          read,
          brightness == Brightness.light
              ? RecordPencilColors.light
              : RecordPencilColors.dark,
        );
      });
    }
  });

  test('lerp blends each colour, and copyWith keeps what it is not given', () {
    final mid = RecordPencilColors.light.lerp(RecordPencilColors.dark, 0.5);
    expect(
      mid.fill,
      Color.lerp(
        RecordPencilColors.light.fill,
        RecordPencilColors.dark.fill,
        .5,
      ),
    );
    expect(
      RecordPencilColors.light.copyWith(fill: const Color(0xFF000000)),
      RecordPencilColors(
        fill: const Color(0xFF000000),
        onFill: RecordPencilColors.light.onFill,
        outline: RecordPencilColors.light.outline,
      ),
    );
  });
}
