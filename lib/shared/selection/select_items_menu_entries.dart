import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The overflow-menu value of the "Select items" entry.
///
/// The entry acts through its own `onTap`, so an `onSelected` handler only
/// needs to leave this value alone.
const selectItemsMenuValue = 'select_items';

/// Finds the "Select items" entry once its menu is open.
const selectItemsMenuKey = ValueKey('enter_selection');

/// "Select items" and the divider under it, first in a list's overflow menu.
///
/// The way into bulk actions on every entity list except Media, whose grid
/// keeps a visible control. It replaced a checklist icon in each list header
/// (issue #2775). Long-press no longer enters selection mode, so on touch this
/// entry is the only route in. One definition, so every menu shows the same
/// entry.
List<PopupMenuEntry<String>> selectItemsMenuEntries(
  BuildContext context, {
  required VoidCallback onSelect,
}) => [
  PopupMenuItem<String>(
    key: selectItemsMenuKey,
    value: selectItemsMenuValue,
    onTap: onSelect,
    child: Row(
      children: [
        const Icon(Icons.checklist, size: 20),
        const SizedBox(width: 12),
        // Wraps rather than overflows: some translations are long.
        Flexible(child: Text(context.l10n.common_selection_enterTooltip)),
      ],
    ),
  ),
  const PopupMenuDivider(),
];
