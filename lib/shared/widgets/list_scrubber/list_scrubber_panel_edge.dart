import 'package:flutter/rendering.dart';

/// The part of the current band that sticks out past the panel's start
/// edge, in the panel's coordinates.
typedef ListScrubberTab = ({double top, double bottom, double overhang});

/// Paints the scrubber panel's start hairline and, when the current band
/// sticks out, a [tab] in the panel's [fill] that the hairline runs around.
class ListScrubberPanelEdge extends CustomPainter {
  const ListScrubberPanelEdge({
    required this.fill,
    required this.edge,
    required this.textDirection,
    this.tab,
  });

  final Color fill;
  final Color edge;
  final TextDirection textDirection;
  final ListScrubberTab? tab;

  @override
  void paint(Canvas canvas, Size size) {
    final rtl = textDirection == TextDirection.rtl;
    final edgeX = rtl ? size.width - 0.5 : 0.5;
    final stroke = Paint()
      ..color = edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final tab = this.tab;
    if (tab == null) {
      canvas.drawLine(Offset(edgeX, 0), Offset(edgeX, size.height), stroke);
      return;
    }
    final outer = rtl ? size.width + tab.overhang : -tab.overhang;
    final rect = Rect.fromLTRB(
      rtl ? size.width : outer,
      tab.top,
      rtl ? outer : 0,
      tab.bottom,
    );
    canvas.drawRect(rect, Paint()..color = fill);
    final outerX = rtl ? outer - 0.5 : outer + 0.5;
    final path = Path()
      ..moveTo(edgeX, 0)
      ..lineTo(edgeX, tab.top + 0.5)
      ..lineTo(outerX, tab.top + 0.5)
      ..lineTo(outerX, tab.bottom - 0.5)
      ..lineTo(edgeX, tab.bottom - 0.5)
      ..lineTo(edgeX, size.height);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(ListScrubberPanelEdge oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.edge != edge ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.tab != tab;
}
