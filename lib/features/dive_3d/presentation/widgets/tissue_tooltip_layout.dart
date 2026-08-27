import 'package:flutter/widgets.dart';

/// Positions the tissue hover tooltip just below-right of the picked point but
/// fully inside the viewport, clamping against the tooltip's REAL measured size
/// (via [getPositionForChild]'s childSize) rather than a fixed height guess -- so
/// a taller tooltip from localization or large text scaling can't spill off the
/// bottom/right edge. Width is capped at [maxWidth] (narrowed to the viewport on
/// tiny panes); height is intrinsic.
class TissueTooltipLayoutDelegate extends SingleChildLayoutDelegate {
  /// Anchor point in viewport-local coordinates (the pick's screen position).
  final Offset anchor;

  /// Preferred maximum tooltip width; clamped down to the viewport width on
  /// panes narrower than this so the tooltip never overflows horizontally.
  final double maxWidth;

  /// Gap between the anchor and the tooltip's top-left corner.
  static const double gap = 14;

  const TissueTooltipLayoutDelegate(this.anchor, {this.maxWidth = 220});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final w = maxWidth < constraints.maxWidth ? maxWidth : constraints.maxWidth;
    return BoxConstraints(
      minWidth: w,
      maxWidth: w,
      maxHeight: constraints.maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxLeft = (size.width - childSize.width).clamp(0.0, double.infinity);
    final maxTop = (size.height - childSize.height).clamp(0.0, double.infinity);
    return Offset(
      (anchor.dx + gap).clamp(0.0, maxLeft),
      (anchor.dy + gap).clamp(0.0, maxTop),
    );
  }

  @override
  bool shouldRelayout(TissueTooltipLayoutDelegate old) =>
      old.anchor != anchor || old.maxWidth != maxWidth;
}
