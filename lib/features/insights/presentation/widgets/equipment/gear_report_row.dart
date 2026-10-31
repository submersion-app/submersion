import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// How many rows a gear report section shows before "Show all".
const gearReportRowLimit = 10;

/// The rows a section shows: all of them once [expanded], else the first
/// [gearReportRowLimit].
List<T> showAllSlice<T>(List<T> items, {required bool expanded}) =>
    expanded || items.length <= gearReportRowLimit
    ? items
    : items.sublist(0, gearReportRowLimit);

/// One line of a gear report: the item, a detail beneath it, and its figure
/// on the right.
class GearReportRow extends StatelessWidget {
  const GearReportRow({
    super.key,
    required this.title,
    required this.trailing,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String trailing;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              trailing,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Show all" and "Show less" control under a long section. Draws nothing
/// when every row already fits.
class GearReportShowAll extends StatelessWidget {
  const GearReportShowAll({
    super.key,
    required this.itemCount,
    required this.expanded,
    required this.onChanged,
  });

  final int itemCount;
  final bool expanded;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (itemCount <= gearReportRowLimit) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Center(
      child: TextButton(
        onPressed: () => onChanged(!expanded),
        child: Text(
          expanded
              ? l10n.insights_equipment_showLess
              : l10n.insights_equipment_showAll,
        ),
      ),
    );
  }
}
