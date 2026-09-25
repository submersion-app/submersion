import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_palette_theme.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_section_colors.dart';

/// The mannequin and the discs have to read on every theme the app ships.
/// Four of the five presets are hand-built and collapse their secondary
/// roles, so these tests pin outcomes (contrast floors), never roles.
void main() {
  for (final preset in AppThemeRegistry.presets) {
    for (final brightness in Brightness.values) {
      final scheme = AppThemeRegistry.resolveTheme(
        preset,
        brightness,
      ).colorScheme;
      final palette = figurePaletteFor(scheme);
      final name = '${preset.id} ${brightness.name}';

      test('$name: the body stands off the surfaces', () {
        for (final surface in [scheme.surface, scheme.surfaceContainer]) {
          expect(
            contrastRatio(Color(palette.body), surface),
            greaterThanOrEqualTo(1.6),
          );
        }
      });

      test('$name: the body shade differs from the body', () {
        expect(palette.bodyShade, isNot(palette.body));
      });

      test('$name: the disc digit reads on the disc', () {
        expect(
          contrastRatio(Color(palette.onDisc), Color(palette.disc)),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('$name: the fixed gear greys read on the body', () {
        expect(
          contrastRatio(Color(palette.gearDark), Color(palette.body)),
          greaterThanOrEqualTo(2.0),
        );
      });
    }
  }
}
