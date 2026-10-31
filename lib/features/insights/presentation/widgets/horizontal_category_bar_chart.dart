import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Horizontal bars of counts, one row per category, in the order given
/// (issue #1765).
///
/// For distributions whose categories overlap, such as a dive counted under
/// every type of its site, where a pie's shares would misread. A plain widget
/// rather than a rotated fl_chart `BarChart`, whose axis labels rotate with
/// the bars.
class HorizontalCategoryBarChart extends StatelessWidget {
  const HorizontalCategoryBarChart({
    super.key,
    required this.data,
    this.barColor,
    this.formatCount,
    this.countWidth = 40,
    this.scaleTo,
    this.onOpenRow,
  });

  final List<({String label, int count})> data;
  final Color? barColor;

  /// The text beside each bar; the bare count when null. A longer text,
  /// such as a count with its share, needs a wider [countWidth].
  final String Function(int count)? formatCount;

  /// The width of the column the count text is drawn in, kept equal on
  /// every row so the bars share one right edge.
  final double countWidth;

  /// The count a full-width bar stands for; the largest count when null.
  /// Shares of a whole pass the whole, so each bar's length matches its
  /// share.
  final int? scaleTo;

  /// Set to open the dives behind a row in one tap (issue #3805). Each row
  /// already shows its number, so there is nothing to mark first.
  final Future<void> Function(int index)? onOpenRow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bar_chart,
                size: 48,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.insights_chart_noBarData,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final color = barColor ?? theme.colorScheme.primary;
    final maxCount =
        scaleTo ?? data.map((e) => e.count).reduce((a, b) => a > b ? a : b);

    return Semantics(
      label: context.l10n.insights_chart_barSemanticLabel(data.length),
      child: Column(
        children: [
          for (final (index, item) in data.indexed)
            _tappable(
              index,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        item.label,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: maxCount == 0
                            ? 0
                            : (item.count / maxCount).clamp(0.0, 1.0),
                        child: Container(
                          height: 16,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: countWidth,
                      // Shrinks a count too long for the column (a large text
                      // scale, a 4-digit count with its share) instead of
                      // wrapping it onto a second line.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text(
                          formatCount?.call(item.count) ?? '${item.count}',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.end,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    if (onOpenRow != null)
                      const Icon(Icons.chevron_right, size: 16),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tappable(int index, Widget row) {
    final open = onOpenRow;
    if (open == null) return row;
    return Semantics(
      button: true,
      child: InkWell(onTap: () => open(index), child: row),
    );
  }
}
