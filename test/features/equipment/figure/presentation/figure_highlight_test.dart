import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_palette_theme.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_section_colors.dart';

/// A tapped disc flashes its legend row. Four of the five presets are
/// hand-built and leave `primaryContainer` unset, so Flutter falls back to
/// `primary`, and a row filled with it hid its own title (1.00:1 on console
/// light). The flash is derived by contrast instead, and pinned here as an
/// outcome across every preset and brightness.
void main() {
  for (final preset in AppThemeRegistry.presets) {
    for (final brightness in Brightness.values) {
      final scheme = AppThemeRegistry.resolveTheme(
        preset,
        brightness,
      ).colorScheme;
      final highlight = figureHighlightFor(scheme);
      final name = '${preset.id} ${brightness.name}';

      test('$name: the row text reads on the flash', () {
        expect(
          contrastRatio(highlight.onFill, highlight.fill),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('$name: a name pill stands off the card and reads', () {
        final pill = figurePillFor(scheme);
        expect(
          contrastRatio(pill.fill, scheme.surfaceContainerLow),
          greaterThanOrEqualTo(1.15),
        );
        expect(
          contrastRatio(pill.onFill, pill.fill),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('$name: the flash stands off the card it fills', () {
        for (final card in [scheme.surfaceContainerLow, scheme.surface]) {
          expect(
            contrastRatio(highlight.fill, card),
            greaterThanOrEqualTo(1.2),
          );
        }
      });
    }
  }
}
