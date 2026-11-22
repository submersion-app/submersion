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

/// The pencil on an unlocked card is an electric lime disc rather than a
/// shade of the theme's own blue, so it stands out from everything else on
/// the page (issue #4527).
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

    test('the lime is the same in every preset', () {
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

    // A lime disc is bright but barely darker than a light card, so in
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

    test('no preset\'s primary is the lime, so the pencil is not its blue', () {
      for (final preset in AppThemeRegistry.presets) {
        for (final brightness in Brightness.values) {
          final scheme = AppThemeRegistry.resolveTheme(
            preset,
            brightness,
          ).colorScheme;
          final pencil = brightness == Brightness.light
              ? RecordPencilColors.light
              : RecordPencilColors.dark;
          expect(scheme.primary, isNot(pencil.fill));
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
      const RecordPencilColors(
        fill: Color(0xFF000000),
        onFill: Color(0xFF1B2600),
        outline: Color(0xFF4C6B00),
      ),
    );
  });
}
