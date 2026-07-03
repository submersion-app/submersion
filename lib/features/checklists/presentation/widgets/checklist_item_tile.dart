import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A single checklist row: checkbox, title, optional due chip, edit/delete.
class ChecklistItemTile extends StatelessWidget {
  final TripChecklistItem item;

  /// Whether overdue styling applies (false for past trips - they never nag).
  final bool showOverdue;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ChecklistItemTile({
    super.key,
    required this.item,
    required this.showOverdue,
    required this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = showOverdue && item.isOverdue(DateTime.now());
    final due = item.dueDate;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 4, right: 0),
      leading: Checkbox(
        value: item.isDone,
        onChanged: (value) => onToggle(value ?? false),
      ),
      title: Text(
        item.title,
        style: item.isDone
            ? theme.textTheme.bodyMedium?.copyWith(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.onSurfaceVariant,
              )
            : theme.textTheme.bodyMedium,
      ),
      subtitle: item.notes.isEmpty
          ? null
          : Text(item.notes, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (due != null)
            Chip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              label: Text(
                isOverdue
                    ? context.l10n.checklists_item_overdue
                    : DateFormat.MMMd().format(due),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isOverdue
                      ? theme.colorScheme.onErrorContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              backgroundColor: isOverdue
                  ? theme.colorScheme.errorContainer
                  : theme.colorScheme.surfaceContainerHighest,
              side: BorderSide.none,
            ),
          PopupMenuButton<String>(
            iconSize: 20,
            onSelected: (value) {
              if (value == 'edit') onEdit?.call();
              if (value == 'delete') onDelete?.call();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Text(context.l10n.checklists_item_edit),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(context.l10n.checklists_item_delete),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
