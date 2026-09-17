import 'package:flutter/material.dart';

/// Distance from the list's leading edge to the rail.
///
/// Dive cards carry a 16px horizontal margin, so a rail of [kTripRailWidth]
/// placed here sits entirely inside empty gutter: the cards keep their exact
/// width and left edge, grouped or loose (#1193). Widening either constant far
/// enough to reach a card would break that rule, which
/// `dive_list_trip_grouping_test.dart` guards.
const double kTripRailInset = 6;

/// Thickness of the rail.
const double kTripRailWidth = 3;

/// Marks a run of same-trip dives with one thin bar in the list's gutter.
///
/// Replaces the tinted band and its two accent borders: the group needs to be
/// legible, not loud, and everything the old decoration painted sat behind
/// near-white cards that covered most of it anyway.
///
/// A [Decoration] rather than a widget wrapping the rows, because that is what
/// [DecoratedSliver] takes, and painting behind the sliver is what keeps the
/// rows lazily built and their geometry untouched.
@immutable
class GutterRailDecoration extends Decoration {
  const GutterRailDecoration({
    required this.color,
    this.inset = kTripRailInset,
    this.width = kTripRailWidth,
  });

  final Color color;
  final double inset;
  final double width;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _GutterRailPainter(this);

  @override
  bool operator ==(Object other) =>
      other is GutterRailDecoration &&
      other.color == color &&
      other.inset == inset &&
      other.width == width;

  @override
  int get hashCode => Object.hash(color, inset, width);
}

class _GutterRailPainter extends BoxPainter {
  _GutterRailPainter(this._rail);

  final GutterRailDecoration _rail;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;

    // The gutter is on the leading side, so the rail follows the text
    // direction rather than always sitting on the left.
    final isRtl = configuration.textDirection == TextDirection.rtl;
    final left = isRtl
        ? offset.dx + size.width - _rail.inset - _rail.width
        : offset.dx + _rail.inset;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, offset.dy, _rail.width, size.height),
        Radius.circular(_rail.width / 2),
      ),
      Paint()..color = _rail.color,
    );
  }
}
