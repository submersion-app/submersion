import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_context_painter.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_geometry.dart';
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

/// Paints a bar per density bin over its slots on the track, in a narrow
/// column beside the context column, growing from the panel's start edge in
/// proportion to the busiest bin. Bars leave out the [clear] band.
class ListScrubberDensityPainter extends CustomPainter {
  const ListScrubberDensityPainter({
    required this.bins,
    required this.slotCount,
    required this.trackExtent,
    required this.offset,
    required this.color,
    required this.textDirection,
    this.clear,
  });

  /// The column's distance from the panel's start edge, past the context
  /// column.
  static const start =
      ListScrubberContextPainter.inset + ListScrubberContextPainter.width + 2;

  /// The longest bar, for the busiest bin.
  static const maxLength = 12.0;

  /// The shortest bar, so a quiet bin beside a busy one stays visible.
  static const minLength = 2.0;

  /// Where the column ends, from the panel's start edge.
  static const columnEnd = start + maxLength;

  final List<ScrubberDensityBin> bins;
  final int slotCount;
  final double trackExtent;

  /// Where slot 0 sits below the panel's top: half the thumb height.
  final double offset;
  final Color color;
  final TextDirection textDirection;

  /// A vertical band the bars leave out, such as the current value's.
  final ({double top, double bottom})? clear;

  double _y(int slot) =>
      offset +
      trackForSlot(slot: slot, trackExtent: trackExtent, slotCount: slotCount);

  /// The bars in the panel's coordinates, in bin order.
  List<Rect> bars(Size size) {
    var maxCount = 0;
    for (final bin in bins) {
      maxCount = math.max(maxCount, bin.count);
    }
    if (maxCount == 0) return const [];
    final rtl = textDirection == TextDirection.rtl;
    final clear = this.clear;
    final rects = <Rect>[];
    for (final bin in bins) {
      if (bin.count <= 0) continue;
      final length = math.max(minLength, maxLength * bin.count / maxCount);
      final left = rtl ? size.width - start - length : start;
      final top = _y(bin.firstSlot);
      final bottom = math.max(top + 1, _y(bin.lastSlot));
      if (clear == null || bottom <= clear.top || top >= clear.bottom) {
        rects.add(Rect.fromLTRB(left, top, left + length, bottom));
        continue;
      }
      if (top < clear.top) {
        rects.add(Rect.fromLTRB(left, top, left + length, clear.top));
      }
      if (bottom > clear.bottom) {
        rects.add(Rect.fromLTRB(left, clear.bottom, left + length, bottom));
      }
    }
    return rects;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (final bar in bars(size)) {
      path.addRect(bar);
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(ListScrubberDensityPainter oldDelegate) =>
      !identical(oldDelegate.bins, bins) ||
      oldDelegate.slotCount != slotCount ||
      oldDelegate.trackExtent != trackExtent ||
      oldDelegate.offset != offset ||
      oldDelegate.color != color ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.clear != clear;
}
