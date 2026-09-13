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
  });

  final List<({String label, int count})> data;
  final Color? barColor;

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
                context.l10n.statistics_chart_noBarData,
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
    final maxCount = data.map((e) => e.count).reduce((a, b) => a > b ? a : b);

    return Semantics(
      label: context.l10n.statistics_chart_barSemanticLabel(data.length),
      child: Column(
        children: [
          for (final item in data)
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
                      alignment: Alignment.centerLeft,
                      widthFactor: maxCount == 0 ? 0 : item.count / maxCount,
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
                    width: 40,
                    child: Text(
                      '${item.count}',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
