import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/theme/app_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/mini_chart_line_color.dart';

void main() {
  const depth = AppColors.chartDepth;
  final cyan = Colors.cyan.shade200;
  final teal = Colors.teal.shade800;

  group('miniChartLineColor', () {
    test('keeps the depth colour on a light card', () {
      expect(
        miniChartLineColor(
          depthColor: depth,
          fallback: teal,
          background: const Color(0xFFE6E8EC),
        ),
        depth,
      );
    });

    test('keeps the depth colour on a dark card it clears 2:1 on', () {
      // About 2.5:1: under WCAG's 3:1 for graphics, but plainly readable,
      // and the plain dark card every dark-mode diver sees.
      expect(
        miniChartLineColor(
          depthColor: depth,
          fallback: cyan,
          background: const Color(0xFF2A2D33),
        ),
        depth,
      );
    });

    test('falls back on a mid-tint card the depth colour disappears into', () {
      // The Ocean gradient halfway: about 1.1:1 against the depth blue.
      final midOcean = Color.lerp(
        const Color(0xFF4DD0E1),
        const Color(0xFF0D1B2A),
        0.5,
      )!;
      expect(
        miniChartLineColor(
          depthColor: depth,
          fallback: cyan,
          background: midOcean,
        ),
        cyan,
      );
    });

    test('keeps the depth colour when the fallback reads no better', () {
      // The Ocean gradient a fifth of the way: the blue is about 1.8:1 and
      // the light cyan about 1.7:1, so swapping would make it worse.
      final shallowOcean = Color.lerp(
        const Color(0xFF4DD0E1),
        const Color(0xFF0D1B2A),
        0.2,
      )!;
      expect(
        miniChartLineColor(
          depthColor: depth,
          fallback: cyan,
          background: shallowOcean,
        ),
        depth,
      );
    });
  });
}
