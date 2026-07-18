import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';

void main() {
  final lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
  );
  final darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
  );

  test('derives all colors from the scheme, differing by brightness', () {
    final light = PlanChartPalette.of(lightTheme);
    final dark = PlanChartPalette.of(darkTheme);
    expect(light.backdrop, isNot(dark.backdrop));
    expect(light.profileLine, isNot(dark.profileLine));
    // The profile line stays in the primary family.
    expect(
      light.profileLine.toARGB32() == lightTheme.colorScheme.primary.toARGB32(),
      isTrue,
    );
  });

  test('equal themes produce equal palettes (shouldRepaint contract)', () {
    expect(
      PlanChartPalette.of(darkTheme),
      equals(PlanChartPalette.of(darkTheme)),
    );
    expect(
      PlanChartPalette.of(darkTheme).hashCode,
      PlanChartPalette.of(darkTheme).hashCode,
    );
    expect(
      PlanChartPalette.of(darkTheme),
      isNot(equals(PlanChartPalette.of(lightTheme))),
    );
  });
}
