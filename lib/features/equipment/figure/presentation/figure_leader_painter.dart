import 'package:flutter/rendering.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_labels.dart';

/// A thin line from each label to its gear, ending in a small dot.
class FigureLeaderPainter extends CustomPainter {
  FigureLeaderPainter({required this.slots, required this.color});

  final List<FigureLabelSlot> slots;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = color;
    for (final slot in slots) {
      final from = slot.onLeft ? slot.rect.centerRight : slot.rect.centerLeft;
      canvas.drawLine(from, slot.anchor, line);
      canvas.drawCircle(slot.anchor, 2.5, dot);
    }
  }

  @override
  bool shouldRepaint(FigureLeaderPainter oldDelegate) =>
      !identical(oldDelegate.slots, slots) || oldDelegate.color != color;
}
