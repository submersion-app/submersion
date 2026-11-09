import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Explanation at the foot of the tissue loading card: what load and the
/// surface level marker mean, why a compartment can take gas up after a dive,
/// and how helium and nitrogen move separately (issue #4228).
///
/// Collapsed by default so it costs one line in the dive detail view. With
/// [inline] false it opens in a dialog instead of expanding in place: a card
/// stretched to a fixed height (the wide dive detail layout) has no room to
/// grow, and expanding there would overflow it.
class TissueValuesInfo extends StatelessWidget {
  final bool inline;

  const TissueValuesInfo({super.key, this.inline = true});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final leading = Icon(
      Icons.info_outline,
      size: 16,
      color: colorScheme.onSurfaceVariant,
    );
    final title = Text(
      l10n.diveLog_deco_info_title,
      style: theme.textTheme.labelMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    );
    final body = Text(
      l10n.diveLog_deco_info_body,
      style: theme.textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    );

    if (!inline) {
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        leading: leading,
        title: title,
        trailing: Icon(
          Icons.open_in_new,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        onTap: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.diveLog_deco_info_title),
            content: SingleChildScrollView(child: body),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  MaterialLocalizations.of(dialogContext).closeButtonLabel,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
        leading: leading,
        title: title,
        children: [body],
      ),
    );
  }
}
