import 'package:flutter/material.dart';

import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/domain/services/checklist_session_engine.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One checklist row in the session runner: large tap target, state icon,
/// secondary menu for Skip/Flag/note. Dimmed and inert when the engine says
/// the item is not actionable (strict order, locked session, resolved).
class SessionItemTile extends StatelessWidget {
  final PreDiveSession session;
  final List<PreDiveSessionItem> sortedItems;
  final PreDiveSessionItem item;
  final VoidCallback onDone;
  final VoidCallback onSkip;
  final VoidCallback onFlag;
  final VoidCallback onEditValue;
  final VoidCallback onAddNote;
  final VoidCallback onReset;

  const SessionItemTile({
    super.key,
    required this.session,
    required this.sortedItems,
    required this.item,
    required this.onDone,
    required this.onSkip,
    required this.onFlag,
    required this.onEditValue,
    required this.onAddNote,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final actionable = ChecklistSessionEngine.isItemActionable(
      session,
      sortedItems,
      item,
    );
    // The overflow menu must respect strict-order gating too: a pending item
    // that is not yet actionable cannot be skipped/flagged/noted out of order.
    // Resolved items keep their menu so Reset/Note stay reachable.
    final showMenu = !session.isLocked && (actionable || item.isResolved);

    final (stateIcon, stateColor) = switch (item.state) {
      PreDiveItemState.pending => (
        Icons.radio_button_unchecked,
        theme.colorScheme.onSurfaceVariant,
      ),
      PreDiveItemState.done => (Icons.check_circle, theme.colorScheme.primary),
      PreDiveItemState.skipped => (
        Icons.remove_circle_outline,
        theme.colorScheme.onSurfaceVariant,
      ),
      PreDiveItemState.flagged => (Icons.flag, theme.colorScheme.error),
    };

    final valueLine = item.itemType == PreDiveItemType.value
        ? [
            if (item.valueLabel != null) item.valueLabel!,
            if (item.valueNumber != null)
              '${item.valueNumber}${item.valueUnit == null ? '' : ' ${item.valueUnit}'}',
          ].join(': ')
        : null;

    final subtitleChildren = <Widget>[
      if (valueLine != null && valueLine.isNotEmpty)
        Text(
          valueLine,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: item.valueOutOfRange
                ? Colors.amber.shade700
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: item.valueOutOfRange ? FontWeight.bold : null,
          ),
        ),
      if (item.note.isNotEmpty)
        Text(
          item.note,
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
      if (item.notes.isNotEmpty)
        Text(item.notes, style: theme.textTheme.bodySmall),
    ];

    final dimmed = !actionable && item.state == PreDiveItemState.pending;

    final tile = ListTile(
      minVerticalPadding: 12,
      leading: Icon(stateIcon, color: stateColor, size: 28),
      title: Text(item.title, style: theme.textTheme.bodyLarge),
      subtitle: subtitleChildren.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: subtitleChildren,
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.completedAt != null)
            Text(
              TimeOfDay.fromDateTime(item.completedAt!).format(context),
              style: theme.textTheme.bodySmall,
            ),
          if (showMenu)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'skip':
                    onSkip();
                  case 'flag':
                    onFlag();
                  case 'note':
                    onAddNote();
                  case 'reset':
                    onReset();
                }
              },
              itemBuilder: (context) => [
                if (!item.isRequired && !item.isResolved)
                  PopupMenuItem(
                    value: 'skip',
                    child: Text(l10n.preDive_runner_skip),
                  ),
                if (!item.isResolved)
                  PopupMenuItem(
                    value: 'flag',
                    child: Text(l10n.preDive_runner_flag),
                  ),
                PopupMenuItem(
                  value: 'note',
                  child: Text(l10n.preDive_runner_addNote),
                ),
                if (item.isResolved)
                  PopupMenuItem(
                    value: 'reset',
                    child: Text(l10n.preDive_runner_undo),
                  ),
              ],
            ),
        ],
      ),
      enabled: actionable,
      onTap: actionable
          ? (item.itemType == PreDiveItemType.value ? onEditValue : onDone)
          : null,
    );

    return dimmed ? Opacity(opacity: 0.4, child: tile) : tile;
  }
}
