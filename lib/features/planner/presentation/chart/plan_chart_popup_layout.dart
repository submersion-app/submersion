import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Puts a marker's card beside its [footprint]: to the right when it fits,
/// else to the left, vertically centred on it. When the card fits on neither
/// side it goes below the marker, else above, so it never covers the marker.
/// It always stays inside the chart. Shared by the warning markers and the
/// worst-case bailout marker, so both cards follow the same rules.
class PlanChartPopupLayout extends SingleChildLayoutDelegate {
  const PlanChartPopupLayout(this.footprint);

  final Rect footprint;

  static const _margin = 4.0;
  static const _gap = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.min(260, constraints.maxWidth - 2 * _margin),
        maxHeight: constraints.maxHeight - 2 * _margin,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final right = footprint.right + _gap;
    final left = footprint.left - _gap - childSize.width;
    final below = footprint.bottom + _gap;
    final above = footprint.top - _gap - childSize.height;
    final besideY = footprint.center.dy - childSize.height / 2;
    final centredX = footprint.center.dx - childSize.width / 2;
    final Offset position;
    if (right + childSize.width <= size.width - _margin) {
      position = Offset(right, besideY);
    } else if (left >= _margin) {
      position = Offset(left, besideY);
    } else if (below + childSize.height <= size.height - _margin) {
      position = Offset(centredX, below);
    } else if (above >= _margin) {
      position = Offset(centredX, above);
    } else {
      position = Offset(left, besideY);
    }
    return Offset(
      position.dx.clamp(
        _margin,
        math.max(_margin, size.width - childSize.width - _margin),
      ),
      position.dy.clamp(
        _margin,
        math.max(_margin, size.height - childSize.height - _margin),
      ),
    );
  }

  @override
  bool shouldRelayout(PlanChartPopupLayout oldDelegate) =>
      footprint != oldDelegate.footprint;
}
