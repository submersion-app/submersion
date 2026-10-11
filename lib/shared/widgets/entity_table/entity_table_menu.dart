import 'package:flutter/material.dart';

/// One item in a table header or cell menu (#2984).
@immutable
class EntityTableMenuAction {
  const EntityTableMenuAction({
    required this.label,
    required this.onSelected,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onSelected;
  final bool enabled;
}

/// Items a list adds to a column's header menu, above "Hide column".
typedef EntityTableHeaderMenuBuilder<F> =
    List<EntityTableMenuAction> Function(BuildContext context, F field);

/// Items for the menu of one cell; an empty list shows no menu.
typedef EntityTableCellMenuBuilder<T, F> =
    List<EntityTableMenuAction> Function(
      BuildContext context,
      T entity,
      F field,
    );

/// Shows [sections] as one popup at [position] (global), a divider between
/// non-empty sections, and runs the chosen action after the menu closes.
Future<void> showEntityTableMenu(
  BuildContext context, {
  required Offset position,
  required List<List<EntityTableMenuAction>> sections,
}) async {
  final shown = sections.where((s) => s.isNotEmpty).toList();
  if (shown.isEmpty) return;
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final local = overlay.globalToLocal(position);
  final chosen = await showMenu<EntityTableMenuAction>(
    context: context,
    position: RelativeRect.fromRect(
      local & Size.zero,
      Offset.zero & overlay.size,
    ),
    items: [
      for (var i = 0; i < shown.length; i++) ...[
        if (i > 0) const PopupMenuDivider(),
        for (final action in shown[i])
          PopupMenuItem<EntityTableMenuAction>(
            value: action,
            enabled: action.enabled,
            child: Text(action.label),
          ),
      ],
    ],
  );
  // The table may have gone while its menu was open (a navigation, a sync
  // rebuild); its actions must not run against a disposed widget.
  if (chosen == null || !context.mounted) return;
  chosen.onSelected();
}
