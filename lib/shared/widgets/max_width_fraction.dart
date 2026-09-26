import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The share of a list row that a `ListTile.trailing` status column may
/// take (issue #1981). A third keeps the title the wider of the two even on
/// a phone, where the leading avatar takes its own share.
const double kListTileTrailingMaxWidthFraction = 1 / 3;

/// Caps [child] at [fraction] of the width its parent offers, while still
/// letting a narrower child keep its own width.
///
/// Built for `ListTile.trailing`: the tile lays trailing out against the
/// whole row's width and gives the title only what is left, so a long status
/// label once squeezed an equipment name to one letter per line (issue
/// #1981). A `FractionallySizedBox` would reserve the space even for a short
/// label, and a `LayoutBuilder` cannot answer the dry layout the tile asks
/// for, hence a render object.
class MaxWidthFraction extends SingleChildRenderObjectWidget {
  const MaxWidthFraction({super.key, required this.fraction, super.child})
    : assert(fraction > 0 && fraction <= 1);

  /// The share of the offered width the child may take, in (0, 1].
  final double fraction;

  @override
  RenderMaxWidthFraction createRenderObject(BuildContext context) =>
      RenderMaxWidthFraction(fraction: fraction);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMaxWidthFraction renderObject,
  ) {
    renderObject.fraction = fraction;
  }
}

/// The render object behind [MaxWidthFraction].
class RenderMaxWidthFraction extends RenderProxyBox {
  RenderMaxWidthFraction({required double fraction, RenderBox? child})
    : _fraction = fraction,
      super(child);

  double get fraction => _fraction;
  double _fraction;
  set fraction(double value) {
    if (value == _fraction) return;
    _fraction = value;
    markNeedsLayout();
  }

  BoxConstraints _capped(BoxConstraints constraints) {
    // An unbounded width has no fraction to take; pass it through.
    if (!constraints.hasBoundedWidth) return constraints;
    final cap = constraints.maxWidth * _fraction;
    return constraints.copyWith(
      minWidth: math.min(constraints.minWidth, cap),
      maxWidth: cap,
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final c = child;
    if (c == null) return constraints.smallest;
    return constraints.constrain(c.getDryLayout(_capped(constraints)));
  }

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(_capped(constraints), parentUsesSize: true);
    size = constraints.constrain(c.size);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('fraction', _fraction));
  }
}
