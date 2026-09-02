import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/widgets/dive_type_badge.dart';

/// Single-line run of [DiveTypeBadge]s that collapses into a "+N" badge
/// (with a tooltip listing the hidden types) instead of wrapping when the
/// available width can't fit every label.
///
/// Sits below the OC/CCR mode badge in the dive detail header, where a
/// second line of type badges would push into the stat row underneath -- so
/// this measures labels against the incoming width and always renders
/// exactly one line.
class DiveTypeBadgeRow extends StatelessWidget {
  final List<String> labels;

  /// Renders every badge (including the "+N" overflow badge) in
  /// [DiveTypeBadge]'s dense size, matching [DiveModeBadge]'s own `dense`
  /// variant for list rows.
  final bool dense;

  const DiveTypeBadgeRow({super.key, required this.labels, this.dense = false});

  static const _spacing = 6.0;

  // DiveTypeBadge's horizontal padding each side (dense: 3, non-dense: 4)
  // plus its 1px border each side -- the width a badge adds on top of its
  // text.
  static double _badgeChrome(bool dense) => (dense ? 3.0 : 4.0) * 2 + 1.0 * 2;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();

    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontSize: DiveTypeBadge.fontSizeOf(context, dense: dense),
      fontWeight: FontWeight.bold,
    );
    final direction = Directionality.of(context);

    double badgeWidth(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        maxLines: 1,
      )..layout();
      return painter.width + _badgeChrome(dense);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        var used = 0.0;
        var visibleCount = 0;

        for (var i = 0; i < labels.length; i++) {
          final isLast = i == labels.length - 1;
          final ownWidth = badgeWidth(labels[i]);
          final overflowReserve = isLast
              ? 0.0
              : _spacing + badgeWidth('+${labels.length - i - 1}');
          final prefix = visibleCount == 0 ? 0.0 : _spacing;
          if (used + prefix + ownWidth + overflowReserve > maxWidth) break;
          used += prefix + ownWidth;
          visibleCount++;
        }

        final hidden = labels.sublist(visibleCount);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < visibleCount; i++) ...[
              if (i > 0) const SizedBox(width: _spacing),
              DiveTypeBadge(label: labels[i], dense: dense),
            ],
            if (hidden.isNotEmpty) ...[
              if (visibleCount > 0) const SizedBox(width: _spacing),
              Tooltip(
                message: hidden.join(', '),
                child: DiveTypeBadge(label: '+${hidden.length}', dense: dense),
              ),
            ],
          ],
        );
      },
    );
  }
}
