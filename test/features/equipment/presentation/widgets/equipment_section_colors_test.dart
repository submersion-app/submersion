import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_section_colors.dart';

/// The Equipment / Sets title has to say which section is showing in every
/// theme the app ships, in both brightnesses.
///
/// Colour roles cannot be trusted to do it: in nine of the ten schemes
/// `onSurfaceVariant` equals `onSurface`, so a "dimmer role" is not dimmer at
/// all, and the default scheme's dark variant puts the two only 1.31:1 apart.
/// These tests pin the outcome, not the roles.
void main() {
  group('EquipmentSectionColors', () {
    for (final preset in AppThemeRegistry.presets) {
      for (final brightness in Brightness.values) {
        final scheme = AppThemeRegistry.resolveTheme(
          preset,
          brightness,
        ).colorScheme;
        final colors = EquipmentSectionColors.of(scheme);
        final name = '${preset.id} ${brightness.name}';

        test('$name: the unselected name is readable text', () {
          // On the header's surface, and on the tint the phone app bar takes
          // once the list scrolls under it.
          for (final surface in [scheme.surface, scheme.surfaceContainer]) {
            expect(
              contrastRatio(colors.unselected, surface),
              greaterThanOrEqualTo(4.5),
            );
          }
        });

        test('$name: the unselected name is clearly dimmer than text', () {
          // 1.31 is what dark mode rendered before; a dimmer name has to be
          // a visible step down, not a rounding error.
          expect(
            contrastRatio(scheme.onSurface, colors.unselected),
            greaterThanOrEqualTo(2.5),
          );
        });

        test('$name: the selected name is readable on its pill', () {
          expect(
            contrastRatio(colors.selected, colors.pill),
            greaterThanOrEqualTo(4.5),
          );
        });

        test('$name: every colour is opaque', () {
          // A tint is a recipe whose result depends on what it lands on; these
          // are resolved against the header's own surface.
          for (final c in [colors.pill, colors.selected, colors.unselected]) {
            expect(c.a, 1.0);
          }
        });
      }
    }

    test('the pill is the sidebar\'s selection colour', () {
      final scheme = AppThemeRegistry.resolveTheme(
        AppThemeRegistry.presets.first,
        Brightness.light,
      ).colorScheme;
      // NavigationRail's default indicator, so the two selections match.
      expect(EquipmentSectionColors.of(scheme).pill, scheme.secondaryContainer);
    });
  });

  group('contrastRatio', () {
    test('is 21 for black on white, either way round', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
      expect(contrastRatio(Colors.white, Colors.black), closeTo(21, 0.01));
    });

    test('is 1 for a colour against itself', () {
      expect(contrastRatio(Colors.teal, Colors.teal), closeTo(1, 0.0001));
    });
  });
}
