import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Collapsible explanation at the foot of the tissue loading card: what load
/// and the surface level marker mean, why a compartment can take gas up after
/// a dive, and how helium and nitrogen move separately (issue #4228).
///
/// Collapsed by default so it costs one line in the dive detail view.
class TissueValuesInfo extends StatelessWidget {
  const TissueValuesInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Theme(
      // No divider lines above and below the tile inside the card.
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const PageStorageKey('tissue-values-info'),
        dense: true,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        expandedAlignment: Alignment.centerLeft,
        visualDensity: VisualDensity.compact,
        leading: Icon(
          Icons.info_outline,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        title: Text(
          l10n.diveLog_deco_info_title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          Text(
            l10n.diveLog_deco_info_body,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
