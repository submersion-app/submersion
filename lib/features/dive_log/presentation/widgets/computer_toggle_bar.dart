import 'package:flutter/material.dart';

/// Color palette for multi-computer profiles.
const computerColors = [
  Color(0xFF00D4FF), // cyan (primary)
  Color(0xFFFF9500), // orange
  Color(0xFF2ECC71), // green
  Color(0xFFE91E8C), // magenta
];

/// Returns the color for a computer at the given index.
/// Cycles with reduced opacity for 5+ computers.
Color computerColorAt(int index) {
  final baseColor = computerColors[index % computerColors.length];
  if (index >= computerColors.length) {
    return baseColor.withValues(alpha: 0.6);
  }
  return baseColor;
}

/// Represents a single computer entry in the toggle bar.
class ComputerToggleItem {
  final String computerId;
  final String label;
  final bool isPrimary;
  final bool isEnabled;
  final Color color;

  const ComputerToggleItem({
    required this.computerId,
    required this.label,
    required this.isPrimary,
    required this.isEnabled,
    required this.color,
  });
}

/// A row of checkbox toggles below the profile chart that controls which
/// computers' data is visible. Returns [SizedBox.shrink] when there is only
/// one (or zero) computer.
class ComputerToggleBar extends StatelessWidget {
  final List<ComputerToggleItem> computers;
  final void Function(String computerId, bool enabled) onToggle;

  const ComputerToggleBar({
    super.key,
    required this.computers,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (computers.length <= 1) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'COMPUTERS',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              children: computers.map((item) {
                return _ComputerToggleChip(
                  item: item,
                  onToggle: (enabled) => onToggle(item.computerId, enabled),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComputerToggleChip extends StatelessWidget {
  final ComputerToggleItem item;
  final void Function(bool enabled) onToggle;

  const _ComputerToggleChip({required this.item, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final label = item.isPrimary ? '${item.label} (primary)' : item.label;

    return GestureDetector(
      onTap: () => onToggle(!item.isEnabled),
      child: Opacity(
        opacity: item.isEnabled ? 1.0 : 0.45,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Color swatch — solid for primary, dashed for secondary
            CustomPaint(
              size: const Size(20, 10),
              painter: _LineSwatch(color: item.color, dashed: !item.isPrimary),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: item.isEnabled
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 16,
              height: 16,
              child: Checkbox(
                value: item.isEnabled,
                onChanged: (v) => onToggle(v ?? false),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide(color: item.color, width: 1.5),
                activeColor: item.color,
                checkColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints a short horizontal line — solid for primary, dashed for secondary.
class _LineSwatch extends CustomPainter {
  final Color color;
  final bool dashed;

  const _LineSwatch({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final y = size.height / 2;

    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    } else {
      const dashWidth = 4.0;
      const gapWidth = 3.0;
      double x = 0;
      while (x < size.width) {
        final end = (x + dashWidth).clamp(0.0, size.width);
        canvas.drawLine(Offset(x, y), Offset(end, y), paint);
        x += dashWidth + gapWidth;
      }
    }
  }

  @override
  bool shouldRepaint(_LineSwatch old) =>
      old.color != color || old.dashed != dashed;
}
