import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/app_bar_tab_metrics.dart';

import '../../helpers/contrast_ratio.dart';

void main() {
  group('AppBarTabColors.overlay', () {
    const selected = Color(0xFF123456);
    const colors = AppBarTabColors(
      selected: selected,
      unselected: Color(0xFF654321),
      barMatchesPage: true,
    );

    test('press and focus ink are the selected hue at 12%', () {
      for (final state in [WidgetState.pressed, WidgetState.focused]) {
        expect(
          colors.overlay.resolve({state}),
          selected.withValues(alpha: 0.12),
          reason: state.name,
        );
      }
    });

    test('hover ink is the selected hue at 8%', () {
      expect(
        colors.overlay.resolve({WidgetState.hovered}),
        selected.withValues(alpha: 0.08),
      );
    });

    test('press wins over hover', () {
      expect(
        colors.overlay.resolve({WidgetState.hovered, WidgetState.pressed}),
        selected.withValues(alpha: 0.12),
      );
    });

    test('no ink at rest', () {
      expect(colors.overlay.resolve(const {}), isNull);
    });
  });

  // A stock TextButton paints in primary, which Tropical light also fills its
  // app bar with, so an app-bar action vanished.
  group('AppBarTabColors.textButtonStyle', () {
    const selected = Color(0xFFFFFFFF);
    const colors = AppBarTabColors(
      selected: selected,
      unselected: Color(0xFFCCCCCC),
      barMatchesPage: false,
    );
    final style = colors.textButtonStyle;

    test('labels take the selected colour', () {
      expect(style.foregroundColor?.resolve(const {}), selected);
    });

    test('a disabled label is the selected colour dimmed', () {
      expect(
        style.foregroundColor?.resolve({WidgetState.disabled}),
        selected.withValues(alpha: 0.38),
      );
    });

    test('ink matches the tabs', () {
      expect(
        style.overlayColor?.resolve({WidgetState.pressed}),
        colors.overlay.resolve({WidgetState.pressed}),
      );
    });
  });

  group('AppBarTabColors.of unselected labels', () {
    ThemeData bar(Color fill, Color foreground) => ThemeData(
      colorScheme: ColorScheme.light(primary: fill),
      appBarTheme: AppBarTheme(
        backgroundColor: fill,
        foregroundColor: foreground,
      ),
    );

    // Tropical light's title reads at 5.04:1, too little headroom for the
    // usual 80% dimming (3.81:1), so the dimming stops where AA holds.
    test('stay at WCAG AA on a bar with little headroom', () {
      const fill = Color(0xFF007D6F);
      final colors = AppBarTabColors.of(bar(fill, const Color(0xFFFFFFFF)));
      expect(contrastRatio(colors.unselected, fill), greaterThanOrEqualTo(4.5));
    });

    test('keep the usual 80% dimming where it already reads', () {
      const fill = Color(0xFF0A1628);
      const foreground = Color(0xFFFFFFFF);
      final colors = AppBarTabColors.of(bar(fill, foreground));
      expect(
        colors.unselected,
        Color.alphaBlend(foreground.withValues(alpha: 0.8), fill),
      );
    });
  });
}
