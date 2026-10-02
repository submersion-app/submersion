import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/app_bar_tab_metrics.dart';

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
}
