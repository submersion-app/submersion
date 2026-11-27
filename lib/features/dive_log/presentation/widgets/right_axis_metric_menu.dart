import 'package:flutter/material.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_right_axis_metric_labels.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A metric the right axis can show, with the colour its line is drawn in.
typedef RightAxisChoice = ({ProfileRightAxisMetric metric, Color color});

/// The right-axis metric menu: "None", then each category's [choices], the
/// [current] one checked. Opened by tapping the axis and by the chart
/// options' Right axis row (issue #5069), so both offer the same list.
///
/// "None" reports through [onNone] rather than the menu's result, because
/// [showMenu] returns null both for it and for a dismissal.
Future<void> showRightAxisMetricMenu(
  BuildContext context, {
  required RelativeRect position,
  required List<RightAxisChoice> choices,
  required ProfileRightAxisMetric? current,
  required void Function(ProfileRightAxisMetric metric) onPick,
  required VoidCallback onNone,
}) async {
  final colorScheme = Theme.of(context).colorScheme;
  final l10n = context.l10n;
  final colors = {for (final c in choices) c.metric: c.color};

  final menuItems = <PopupMenuEntry<ProfileRightAxisMetric?>>[
    PopupMenuItem<ProfileRightAxisMetric?>(
      value: null,
      onTap: onNone,
      child: Row(
        children: [
          Icon(
            Icons.visibility_off,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(l10n.diveLog_profile_rightAxis_none),
        ],
      ),
    ),
    const PopupMenuDivider(),
  ];

  for (final category in ProfileMetricCategory.values) {
    final available = category.metrics.where(colors.containsKey).toList();
    if (available.isEmpty) continue;

    // Divider before each category but the first.
    if (menuItems.length > 2) menuItems.add(const PopupMenuDivider());
    menuItems.add(
      PopupMenuItem<ProfileRightAxisMetric?>(
        enabled: false,
        height: 32,
        child: Text(
          profileMetricCategoryName(l10n, category),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    for (final metric in available) {
      final isSelected = metric == current;
      final metricColor = colors[metric]!;
      menuItems.add(
        PopupMenuItem<ProfileRightAxisMetric?>(
          value: metric,
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check : Icons.show_chart,
                size: 16,
                color: isSelected ? metricColor : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Container(
                width: 12,
                height: 3,
                decoration: BoxDecoration(
                  color: metricColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                profileMetricName(l10n, metric),
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  final picked = await showMenu<ProfileRightAxisMetric?>(
    context: context,
    position: position,
    items: menuItems,
  );
  // "None" was handled by its onTap; null here is a dismissal or "None".
  if (picked != null) onPick(picked);
}
