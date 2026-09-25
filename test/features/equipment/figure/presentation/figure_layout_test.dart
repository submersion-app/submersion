import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_layout.dart';

void main() {
  test('a phone width shares the box between two 1:2 figures', () {
    final layout = FigureLayout.forSize(const Size(360, 348));
    expect(layout.front.width, closeTo(174, 0.01));
    expect(layout.front.height, closeTo(348, 0.01));
    expect(layout.back.left, closeTo(174 + FigureLayout.gutter, 0.01));
    expect(layout.scale, closeTo(174 / 200, 0.0001));
  });

  test('a wide box caps the figures by height and centres them', () {
    final layout = FigureLayout.forSize(const Size(1000, 360));
    expect(layout.front.height, closeTo(360, 0.01));
    expect(layout.front.width, closeTo(180, 0.01));
    final total = layout.back.right - layout.front.left;
    expect(layout.front.left, closeTo((1000 - total) / 2, 0.01));
  });

  test('preferredHeight is the pair height for a width, capped', () {
    expect(FigureLayout.preferredHeight(360), closeTo(348, 0.01));
    expect(FigureLayout.preferredHeight(1000), FigureLayout.maxHeight);
  });

  test('toBox maps figure space through the scale and offset', () {
    final layout = FigureLayout.forSize(const Size(412, 400));
    final p = layout.toBox(FigureView.back, 100, 0);
    expect(p.dx, closeTo(layout.back.left + 100 * layout.scale, 0.001));
    expect(p.dy, closeTo(layout.back.top, 0.001));
  });

  test('a degenerate box stays finite and positive', () {
    for (final size in const [Size(0, 0), Size(5, 300), Size(300, 0)]) {
      final layout = FigureLayout.forSize(size);
      expect(layout.front.width, greaterThan(0));
      expect(layout.front.height, greaterThan(0));
      expect(layout.scale.isFinite, isTrue);
      final p = layout.toBox(FigureView.front, 100, 200);
      expect(p.dx.isFinite && p.dy.isFinite, isTrue);
    }
  });

  test('forSingle centres one figure at 36 percent of the width', () {
    final layout = FigureLayout.forSingle(const Size(360, 420));
    expect(layout.front.width, closeTo(129.6, 0.01));
    expect(layout.front.left, closeTo(115.2, 0.01));
    expect(layout.front.top, 0);
    expect(layout.back, layout.front);
    expect(layout.scale, closeTo(129.6 / 200, 0.0001));
  });

  test('forSize takes a gutter, so wide pills have room between figures', () {
    final layout = FigureLayout.forSize(const Size(900, 360), gutter: 180);
    expect(layout.front.width, closeTo(180, 0.01));
    expect(layout.back.left - layout.front.right, closeTo(180, 0.01));
    expect(layout.front.left, closeTo(900 - layout.back.right, 0.01));
  });

  test('forSingle is capped by the box height and stays positive', () {
    expect(FigureLayout.forSingle(const Size(1000, 300)).front.height, 300);
    expect(FigureLayout.forSingle(Size.zero).front.width, greaterThan(0));
  });
}
