import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Places its child so that the point [childAnchor] on the child lands on
/// [anchor], kept inside the width it is given.
///
/// It sets the labels over the time chart: a bar's value just past its end,
/// and the average's name on the average line.
class SacPinLayout extends SingleChildLayoutDelegate {
  final Offset anchor;
  final Alignment childAnchor;

  const SacPinLayout({required this.anchor, required this.childAnchor});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final along = (childAnchor.x + 1) / 2;
    final down = (childAnchor.y + 1) / 2;
    final left = anchor.dx - childSize.width * along;
    return Offset(
      left.clamp(0.0, math.max(0.0, size.width - childSize.width)),
      anchor.dy - childSize.height * down,
    );
  }

  @override
  bool shouldRelayout(SacPinLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.childAnchor != childAnchor;
}

/// Places a tooltip beside the bar from [barLeft] to [barRight], on whichever
/// side has room, centered on [centerY]. On a narrow plot it narrows to the
/// roomier side, down to [minBesideWidth], wrapping its text onto more lines.
///
/// Where even that side is narrower, it centers on
/// the bar across the average line at [baselineY] from it, below a bar that
/// [rises] and above one that hangs, so it clears the bar it describes.
///
/// It stays inside the width it is given and between [top] and [bottom],
/// the plot's own edges, so nothing drawn after the plot, such as the time
/// axis, paints over it. Only a tooltip taller than the plot, at very large
/// text, runs past [bottom].
class SacTooltipLayout extends SingleChildLayoutDelegate {
  static const double gap = 6;

  /// The narrowest a tooltip squeezes to sit beside its bar.
  static const double minBesideWidth = 120;

  final double barLeft;
  final double barRight;
  final double centerY;
  final double baselineY;
  final bool rises;
  final double top;
  final double bottom;
  final double maxWidth;

  const SacTooltipLayout({
    required this.barLeft,
    required this.barRight,
    required this.centerY,
    required this.baselineY,
    required this.rises,
    required this.top,
    required this.bottom,
    required this.maxWidth,
  });

  /// Allows for rounding where the tooltip was narrowed to the room exactly.
  static const double _slack = 0.01;

  double _fit(double y, double height) =>
      math.max(top, math.min(y, bottom - height));

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final room = math.max(constraints.maxWidth - barRight, barLeft) - gap;
    final width = room >= minBesideWidth ? room : constraints.maxWidth;
    return BoxConstraints(maxWidth: math.min(maxWidth, width));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final width = childSize.width;
    final beside = _fit(centerY - childSize.height / 2, childSize.height);
    if (barRight + gap + width <= size.width + _slack) {
      return Offset(barRight + gap, beside);
    }
    if (barLeft - gap - width >= -_slack) {
      return Offset(barLeft - gap - width, beside);
    }
    final double left = ((barLeft + barRight - width) / 2).clamp(
      0.0,
      math.max(0.0, size.width - width),
    );
    return Offset(
      left,
      _fit(
        rises ? baselineY + gap : baselineY - gap - childSize.height,
        childSize.height,
      ),
    );
  }

  @override
  bool shouldRelayout(SacTooltipLayout oldDelegate) =>
      oldDelegate.barLeft != barLeft ||
      oldDelegate.barRight != barRight ||
      oldDelegate.centerY != centerY ||
      oldDelegate.baselineY != baselineY ||
      oldDelegate.rises != rises ||
      oldDelegate.top != top ||
      oldDelegate.bottom != bottom ||
      oldDelegate.maxWidth != maxWidth;
}

/// The figures of the stretch the diver picked, floating beside its bar in
/// the colors of a Material tooltip.
class SacChartTooltip extends StatelessWidget {
  final String text;

  /// The locale's own direction; the chart around it runs left to right.
  final TextDirection? textDirection;

  const SacChartTooltip({super.key, required this.text, this.textDirection});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          text,
          textDirection: textDirection,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onInverseSurface),
        ),
      ),
    );
  }
}
