import 'package:flutter/material.dart';

/// One line's chip. A null [onToggle] keeps the line on, as As dived always
/// is: the chip stays enabled, since a disabled chip reads as a line that is
/// off, and ignores taps instead.
class CompareChipData {
  const CompareChipData({
    required this.id,
    required this.label,
    required this.color,
    required this.selected,
    this.dashed = true,
    this.onToggle,
  });

  final String id;
  final String label;
  final Color color;
  final bool selected;

  /// Whether the swatch is dashed, as the chart draws this line.
  final bool dashed;
  final ValueChanged<bool>? onToggle;
}

/// Compare's chips: one per line, then whatever can add a line.
class CompareChips extends StatelessWidget {
  const CompareChips({super.key, required this.chips, this.actions = const []});

  final List<CompareChipData> chips;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final chip in chips)
          IgnorePointer(
            ignoring: chip.onToggle == null,
            child: FilterChip(
              key: ValueKey('compareChip_${chip.id}'),
              avatar: _LineSwatch(color: chip.color, dashed: chip.dashed),
              label: Text(chip.label),
              selected: chip.selected,
              showCheckmark: false,
              onSelected: chip.onToggle ?? (_) {},
            ),
          ),
        ...actions,
      ],
    );
  }
}

/// A short length of the chip's line, so a chip reads against the chart.
class _LineSwatch extends StatelessWidget {
  const _LineSwatch({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(18, 12),
    painter: _LineSwatchPainter(color: color, dashed: dashed),
  );
}

class _LineSwatchPainter extends CustomPainter {
  const _LineSwatchPainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    for (var x = 0.0; x < size.width; x += 7) {
      final end = x + 4 > size.width ? size.width : x + 4;
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
    }
  }

  @override
  bool shouldRepaint(_LineSwatchPainter oldDelegate) =>
      color != oldDelegate.color || dashed != oldDelegate.dashed;
}
