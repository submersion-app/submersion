import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// One card an unlocked page is leaving out, offered in the [AddStrip].
@immutable
class AddStripEntry {
  const AddStripEntry({
    required this.cardId,
    required this.label,
    this.hidden = false,
  });

  final String cardId;

  /// The card's title.
  final String label;

  /// True when the diver has hidden the card, as opposed to it being left
  /// out for having nothing to show.
  final bool hidden;
}

/// The row of chips pinned under the top bar of an unlocked page, one per
/// card the page is leaving out because it is empty or hidden.
///
/// A locked page shows only what has a value, and the diver can hide cards.
/// This strip is how an unlocked page still reaches every one of them, and
/// it sits outside the scrolling content so nothing on the page moves.
class AddStrip extends StatelessWidget {
  const AddStrip({super.key, required this.entries, required this.onAdd});

  final List<AddStripEntry> entries;

  /// Called with the card id of a tapped chip.
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      // Full width, so the strip and its rule span the page and the chips
      // start at its left edge whatever the parent's alignment.
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Text(
                context.l10n.common_action_add,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              for (final entry in entries) ...[
                const SizedBox(width: 8),
                _AddChip(entry: entry, onAdd: onAdd),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip({required this.entry, required this.onAdd});

  static const double _radius = 8;

  final AddStripEntry entry;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chip = ActionChip(
      key: ValueKey('addStrip_${entry.cardId}'),
      label: Text(entry.label),
      onPressed: () => onAdd(entry.cardId),
      // Shrunk to the visible pill, so the dashed outline below traces the
      // chip and not its tap padding.
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius),
      ),
      side: entry.hidden ? BorderSide.none : null,
    );
    if (!entry.hidden) return chip;

    return Semantics(
      label: context.l10n.recordEdit_hiddenCard(entry.label),
      button: true,
      excludeSemantics: true,
      onTap: () => onAdd(entry.cardId),
      child: CustomPaint(
        foregroundPainter: _DashedOutlinePainter(
          color: scheme.outline,
          radius: _radius,
        ),
        child: chip,
      ),
    );
  }
}

/// A dashed rounded rectangle, marking a chip for a card the diver hid.
class _DashedOutlinePainter extends CustomPainter {
  const _DashedOutlinePainter({required this.color, required this.radius});

  static const double _dash = 4;
  static const double _gap = 3;

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.5),
          Radius.circular(radius),
        ),
      );
    for (final metric in outline.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += _dash + _gap) {
        canvas.drawPath(metric.extractPath(at, at + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutlinePainter oldDelegate) =>
      color != oldDelegate.color || radius != oldDelegate.radius;
}
