import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/shared/selection/selection_controller.dart';

/// Which container the selection bar is rendered into.
enum SelectionBarShell {
  /// The surface owns the window chrome, so the bar is a real [AppBar].
  appBar,

  /// The surface is a pane or an embedded section, so the bar is a plain
  /// container placed above the list.
  pane,
}

/// The contextual bar shown while a surface is in selection mode.
///
/// One content builder, two shells. The baseline controls -- select all,
/// deselect all, delete -- are injected here rather than declared per surface,
/// so no list can ship without them. Surfaces contribute only their extras.
///
/// Delete is deliberately the one baseline control that never renders inline.
/// It sits at the bottom of the overflow menu, below a divider, so destroying a
/// whole selection takes a deliberate open-then-choose rather than a single tap
/// next to the controls a user reaches for constantly. That is a safety
/// property of the shared bar, not a per-surface choice: every surface inherits
/// it.
///
/// The action set and its ordering are computed once in [_buildControls] and
/// are identical in both shells; only the split between inline icons and the
/// overflow menu depends on [maxInlineActions]. That is what stops the pane
/// variant from quietly offering fewer actions than the full-width one.
///
/// Leaving selection mode after an action is the third property injected
/// here rather than left to each surface. Every control -- inline icon,
/// overflow entry and the baseline delete -- routes through
/// [_runAndMaybeExit], which ends the mode on [BulkActionOutcome.completed]
/// and leaves it alone otherwise, so a finished action always returns the
/// diver to the normal list (#1262) while a cancelled or failed one keeps the
/// selection they built.
class SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Menu value for the baseline delete entry.
  ///
  /// Fenced so it cannot collide with a surface-supplied [BulkAction.id],
  /// which lets [_buildControls] keep a single dispatch point for the menu.
  static const String _deleteMenuValue = '__selection_delete__';

  final SelectionController controller;

  /// Ids the surface will accept actions on, already filtered to exclude
  /// non-selectable rows. Select-all uses exactly this list.
  final List<String> selectableIds;

  /// Surface-specific extras: merge, export, bulk edit, and so on.
  final List<BulkAction> actions;

  final SelectionBarShell shell;

  /// Invoked by the baseline delete entry in the overflow menu, reporting
  /// whether the diver went through with it.
  ///
  /// Null only for surfaces that have no true delete -- the dive media section
  /// unlinks media from a dive without destroying files, so a trash entry
  /// there would misdescribe what it does. When null the delete entry is
  /// omitted entirely rather than rendered disabled, so the menu never shows a
  /// dead row. Every surface that can delete must pass this.
  final FutureOr<BulkActionOutcome> Function()? onDelete;

  /// How many extras render as inline icons before the rest overflow.
  ///
  /// Counts extras only. Delete is never inline, so it never consumes a slot
  /// and lowering this can never push delete back into the bar.
  final int maxInlineActions;

  const SelectionAppBar({
    super.key,
    required this.controller,
    required this.selectableIds,
    required this.actions,
    required this.shell,
    required this.onDelete,
    this.maxInlineActions = 3,
  });

  /// Whether this surface offers a delete at all.
  bool get _hasDelete => onDelete != null;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, state, _) {
        final count = state.count;
        final title = Text(context.l10n.common_selection_countSelected(count));
        final leading = IconButton(
          key: const ValueKey('selection_exit'),
          icon: const Icon(Icons.close),
          tooltip: context.l10n.common_selection_exitTooltip,
          onPressed: controller.exit,
        );
        final trailing = _buildControls(context, count, state.checkedIds);

        switch (shell) {
          case SelectionBarShell.appBar:
            return AppBar(leading: leading, title: title, actions: trailing);
          case SelectionBarShell.pane:
            return Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: SizedBox(
                height: kToolbarHeight,
                child: Row(
                  children: [
                    leading,
                    const SizedBox(width: 8),
                    Expanded(child: title),
                    ...trailing,
                  ],
                ),
              ),
            );
        }
      },
    );
  }

  /// Run [handler] and end selection mode if it reports it finished.
  ///
  /// The single place the mode ends after an action, for inline icons,
  /// overflow entries and the baseline delete alike. A handler is free to
  /// call `exit()` earlier for its own reasons -- the delete paths do, so the
  /// bar disappears the instant the diver confirms rather than lingering
  /// through a slow bulk delete -- and this stays a no-op when it does:
  /// [SelectionState] defines `==`, so re-assigning the inactive state
  /// notifies nobody.
  Future<void> _runAndMaybeExit(
    FutureOr<BulkActionOutcome> Function() handler, {
    bool exitsOnComplete = true,
  }) async {
    final outcome = await handler();
    if (outcome == BulkActionOutcome.completed && exitsOnComplete) {
      controller.exit();
    }
  }

  Future<void> _invoke(BulkAction action) => _runAndMaybeExit(
    action.onInvoke,
    exitsOnComplete: action.exitsSelectionOnComplete,
  );

  /// Start a dispatch from a synchronous widget callback.
  ///
  /// Fire-and-forget by necessity -- onPressed and onSelected cannot await --
  /// but not unlistened. A handler that throws instead of reporting
  /// [BulkActionOutcome.failed] would otherwise send its error to the zone,
  /// where the running app logs it as a bare uncaught error and a test blames
  /// whichever case happens to be running when it surfaces. [logFailure]
  /// attaches the listener and names the action in the log.
  ///
  /// The contract still holds on that path: the throw aborts
  /// [_runAndMaybeExit] before it can exit, so a failed action leaves the
  /// selection standing exactly as a reported failure would.
  void _start(Future<void> dispatch, String actionId) =>
      logFailure(dispatch, SelectionAppBar, 'run the $actionId bulk action');

  /// Baseline controls plus extras, in a fixed order, identical in both
  /// shells.
  List<Widget> _buildControls(
    BuildContext context,
    int count,
    Set<String> checkedIds,
  ) {
    // A surface that picked the sentinel as an action id would have its menu
    // entry silently invoke onDelete instead of its own handler -- the wrong
    // handler, and a destructive one. BulkAction.id is free-form, so make the
    // collision fail loudly in debug rather than shipping that.
    assert(
      actions.every((action) => action.id != _deleteMenuValue),
      'BulkAction.id "$_deleteMenuValue" is reserved for the baseline delete '
      'entry; rename the action.',
    );

    final allChecked =
        count >= selectableIds.length && selectableIds.isNotEmpty;
    final inline = actions.take(maxInlineActions).toList();
    final overflow = actions.skip(maxInlineActions).toList();

    return [
      IconButton(
        key: const ValueKey('selection_select_all'),
        icon: const Icon(Icons.select_all),
        tooltip: context.l10n.common_selection_selectAllTooltip,
        onPressed: allChecked
            ? null
            : () => controller.selectAll(selectableIds),
      ),
      IconButton(
        key: const ValueKey('selection_deselect_all'),
        icon: const Icon(Icons.deselect),
        tooltip: context.l10n.common_selection_deselectAllTooltip,
        onPressed: count == 0 ? null : controller.deselectAll,
      ),
      for (final action in inline)
        IconButton(
          key: ValueKey('selection_action_${action.id}'),
          icon: Icon(action.icon),
          tooltip: action.label,
          color: action.isDestructive
              ? Theme.of(context).colorScheme.error
              : null,
          onPressed: action.isEnabledForSelection(count, checkedIds)
              ? () => _start(_invoke(action), action.id)
              : null,
        ),
      if (overflow.isNotEmpty || _hasDelete)
        PopupMenuButton<String>(
          key: const ValueKey('selection_overflow'),
          itemBuilder: (context) => [
            for (final action in overflow)
              PopupMenuItem<String>(
                key: ValueKey('selection_menu_${action.id}'),
                value: action.id,
                enabled: action.isEnabledForSelection(count, checkedIds),
                child: ListTile(
                  leading: Icon(action.icon),
                  title: Text(action.label),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            if (_hasDelete) ...[
              // Delete sorts last, behind a divider, so it is never adjacent
              // to a benign entry the user is aiming for.
              if (overflow.isNotEmpty) const PopupMenuDivider(),
              _buildDeleteItem(context, count),
            ],
          ],
          // onSelected is synchronous, so the dispatch is deliberately
          // fire-and-forget: the menu closes now and the bar reacts when the
          // action reports back.
          onSelected: (id) {
            if (id == _deleteMenuValue) {
              _start(_invokeDelete(), 'delete');
              return;
            }
            for (final action in overflow) {
              if (action.id == id) {
                _start(_invoke(action), action.id);
                return;
              }
            }
          },
        ),
    ];
  }

  /// Run the baseline delete under the same exit rule as any other action.
  ///
  /// Destroying the checked rows always ends the mode, so there is no opt-out
  /// to carry here; the decision itself still lives in [_runAndMaybeExit].
  Future<void> _invokeDelete() async {
    final handler = onDelete;
    if (handler == null) return;
    await _runAndMaybeExit(handler);
  }

  /// The baseline delete entry.
  ///
  /// The colour is resolved here rather than left to the menu because the
  /// [ListTile] child resolves its own icon colour: an unconditional error
  /// colour would keep the row looking live while [PopupMenuItem.enabled] had
  /// already made it inert.
  PopupMenuItem<String> _buildDeleteItem(BuildContext context, int count) {
    final theme = Theme.of(context);
    final enabled = count > 0;
    final color = enabled ? theme.colorScheme.error : theme.disabledColor;

    return PopupMenuItem<String>(
      key: const ValueKey('selection_delete'),
      value: _deleteMenuValue,
      enabled: enabled,
      child: ListTile(
        leading: Icon(Icons.delete_outline, color: color),
        title: Text(
          MaterialLocalizations.of(context).deleteButtonTooltip,
          style: TextStyle(color: color),
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
