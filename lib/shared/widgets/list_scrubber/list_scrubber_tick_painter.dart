import 'package:flutter/rendering.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_geometry.dart';

/// Paints a short horizontal tick per slot in [ticks], in a column right
/// beside the thumb track at the panel's end edge.
class ListScrubberTickPainter extends CustomPainter {
  const ListScrubberTickPainter({
    required this.ticks,
    required this.slotCount,
    required this.trackExtent,
    required this.offset,
    required this.endInset,
    required this.color,
    required this.textDirection,
  });

  static const length = 6.0;
  static const thickness = 2.0;

  final List<int> ticks;
  final int slotCount;
  final double trackExtent;

  /// Where slot 0 sits below the panel's top: half the thumb height.
  final double offset;

  /// The thumb track's width from the panel's end edge.
  final double endInset;
  final Color color;
  final TextDirection textDirection;

  /// The ticks in the panel's coordinates, in slot order.
  List<Rect> rects(Size size) {
    final left = textDirection == TextDirection.rtl
        ? endInset
        : size.width - endInset - length;
    return [
      for (final slot in ticks)
        Rect.fromLTWH(
          left,
          offset +
              trackForSlot(
                slot: slot,
                trackExtent: trackExtent,
                slotCount: slotCount,
              ) -
              thickness / 2,
          length,
          thickness,
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (final tick in rects(size)) {
      path.addRect(tick);
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(ListScrubberTickPainter oldDelegate) =>
      !identical(oldDelegate.ticks, ticks) ||
      oldDelegate.slotCount != slotCount ||
      oldDelegate.trackExtent != trackExtent ||
      oldDelegate.offset != offset ||
      oldDelegate.endInset != endInset ||
      oldDelegate.color != color ||
      oldDelegate.textDirection != textDirection;
}
