import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The opacity every surface greys a permanently closed dive center to
/// (#3379): list tiles, table rows, map markers and picker rows.
const double kClosedDiveCenterOpacity = 0.6;

/// A small outlined "Closed" label beside a permanently closed dive center's
/// name (#3379). Deliberately not a [Chip], so it sizes to its text and is
/// safe beside a title in a row.
class DiveCenterClosedTag extends StatelessWidget {
  const DiveCenterClosedTag({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        context.l10n.diveCenters_tag_closed,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
        maxLines: 1,
      ),
    );
  }
}
