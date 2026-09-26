import 'dart:math' as math;
import 'dart:ui';

import 'package:submersion/features/equipment/figure/domain/figure_space.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';

/// Where the front and back figures sit inside a box, and the scale from
/// figure space to that box. Both figures share one scale so they are the
/// same size.
class FigureLayout {
  const FigureLayout({
    required this.front,
    required this.back,
    required this.scale,
  });

  static const double gutter = 12;
  static const double maxHeight = 360;

  final Rect front;
  final Rect back;
  final double scale;

  /// The pair side by side, each at the figure's 1:2 aspect, as large as the
  /// box allows, centred. A degenerate box still yields a positive layout.
  static FigureLayout forSize(
    Size size, {
    double gutter = FigureLayout.gutter,
  }) {
    final byWidth = (size.width - gutter) / 2;
    final byHeight = size.height / 2;
    final figureWidth = math.max(1.0, math.min(byWidth, byHeight));
    final figureHeight = figureWidth * 2;
    final totalWidth = figureWidth * 2 + gutter;
    final left = (size.width - totalWidth) / 2;
    final top = (size.height - figureHeight) / 2;
    return FigureLayout(
      front: Rect.fromLTWH(left, top, figureWidth, figureHeight),
      back: Rect.fromLTWH(
        left + figureWidth + gutter,
        top,
        figureWidth,
        figureHeight,
      ),
      scale: figureWidth / kFigureWidth,
    );
  }

  /// One figure centred in [size] at [fraction] of its width (and the
  /// matching 1:2 height, capped by the box height), top-aligned so label
  /// columns can run below it. Both [front] and [back] are that rectangle,
  /// since the phone layout shows one view at a time.
  static FigureLayout forSingle(Size size, {double fraction = 0.36}) {
    final figureWidth = math.max(
      1.0,
      math.min(size.width * fraction, size.height / 2),
    );
    final rect = Rect.fromLTWH(
      (size.width - figureWidth) / 2,
      0,
      figureWidth,
      figureWidth * 2,
    );
    return FigureLayout(
      front: rect,
      back: rect,
      scale: figureWidth / kFigureWidth,
    );
  }

  /// The height a full-width pair wants for [width], capped at [maxHeight].
  static double preferredHeight(double width) =>
      math.min(maxHeight, math.max(2.0, width - gutter));

  Rect rectFor(FigureView view) => view == FigureView.front ? front : back;

  /// A figure-space point of [view] in box coordinates.
  Offset toBox(FigureView view, double x, double y) {
    final rect = rectFor(view);
    return Offset(rect.left + x * scale, rect.top + y * scale);
  }
}
