import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:submersion/core/accessibility/app_shortcuts.dart';
import 'package:submersion/core/accessibility/not_while_typing_activator.dart';
import 'package:submersion/core/accessibility/shortcut_registry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// Unlock the record page in view (Cmd/Ctrl+L).
class UnlockRecordIntent extends Intent {
  const UnlockRecordIntent();
}

/// Save its sitting (Cmd/Ctrl+S).
class SaveSittingIntent extends Intent {
  const SaveSittingIntent();
}

/// Cancel its sitting (Escape).
class CancelSittingIntent extends Intent {
  const CancelSittingIntent();
}

/// A record page the editing keys act on (issue #4527): its lock state and
/// what each key does there.
class RecordEditShortcutTarget {
  RecordEditShortcutTarget({
    required this.controller,
    required this.unlock,
    required this.save,
    required this.cancel,
    required this.isCurrent,
  });

  final RecordEditController<Object?> controller;
  final VoidCallback unlock;
  final VoidCallback save;
  final VoidCallback cancel;

  /// Whether the page is the one in view: false while a page, a sheet or a
  /// menu is open over it, or once it has gone.
  final bool Function() isCurrent;
}

/// The record pages that take the editing keys, latest last.
class RecordEditShortcutTargets {
  final _targets = <RecordEditShortcutTarget>[];

  void add(RecordEditShortcutTarget target) => _targets.add(target);

  void remove(RecordEditShortcutTarget target) => _targets.remove(target);

  /// The page the keys act on: the latest one that is in view.
  RecordEditShortcutTarget? get current {
    for (final target in _targets.reversed) {
      if (target.isCurrent()) return target;
    }
    return null;
  }
}

final recordEditShortcutTargetsProvider = Provider<RecordEditShortcutTargets>(
  (ref) => RecordEditShortcutTargets(),
);

/// Unlock, Save and Cancel from the keyboard, for the record page in view
/// (issue #4527). Mounted once above the app's pages.
///
/// Each key acts only when it has something to do there: unlock on a locked
/// page, save with changes to save, cancel during a sitting with nothing
/// nearer to dismiss. Otherwise the key is left to whatever else listens, so
/// Escape still closes suggestions, a menu or a sheet over the page. Save
/// and Cancel work while a field is being typed in; unlock, a plain chord,
/// not then.
class RecordEditShortcuts extends ConsumerStatefulWidget {
  const RecordEditShortcuts({super.key, required this.child});

  /// The app, below the editing keys. While mounted, Unlock and Save are
  /// listed in the keyboard shortcuts help; Escape is listed already, as
  /// "Close / Cancel".
  final Widget child;

  @override
  ConsumerState<RecordEditShortcuts> createState() =>
      _RecordEditShortcutsState();
}

/// The help's labels: English identifiers, translated as it draws them.
const _unlockLabel = 'Unlock to edit';
const _saveLabel = 'Save changes';

class _RecordEditShortcutsState extends ConsumerState<RecordEditShortcuts> {
  @override
  void initState() {
    super.initState();
    ShortcutCatalog.instance.registerAll([
      ShortcutEntry(
        label: _unlockLabel,
        category: 'Editing',
        activator: platformShortcut(LogicalKeyboardKey.keyL),
      ),
      ShortcutEntry(
        label: _saveLabel,
        category: 'Editing',
        activator: platformShortcut(LogicalKeyboardKey.keyS),
      ),
    ]);
  }

  @override
  void dispose() {
    ShortcutCatalog.instance
      ..unregisterLabel(_unlockLabel)
      ..unregisterLabel(_saveLabel);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targets = ref.watch(recordEditShortcutTargetsProvider);
    return Shortcuts(
      shortcuts: {
        NotWhileTypingActivator(platformShortcut(LogicalKeyboardKey.keyL)):
            const UnlockRecordIntent(),
        platformShortcut(LogicalKeyboardKey.keyS): const SaveSittingIntent(),
        const SingleActivator(LogicalKeyboardKey.escape):
            const CancelSittingIntent(),
      },
      child: Actions(
        actions: {
          UnlockRecordIntent: _TargetAction<UnlockRecordIntent>(
            targets,
            when: (c) => !c.isUnlocked,
            run: (t) => t.unlock(),
          ),
          SaveSittingIntent: _TargetAction<SaveSittingIntent>(
            targets,
            when: (c) => c.isUnlocked && c.isDirty && !c.isBusy,
            run: (t) => t.save(),
          ),
          CancelSittingIntent: _TargetAction<CancelSittingIntent>(
            targets,
            // Escape is the app's dismiss key too: whatever nearer the
            // focus would dismiss something of its own (an autocomplete's
            // suggestions, a menu, a sheet) closes that first.
            when: (c) => c.isUnlocked && !c.isBusy && !_nearerDismissal(),
            run: (t) => t.cancel(),
          ),
        },
        child: widget.child,
      ),
    );
  }
}

/// Whether Escape has something nearer the focus to dismiss: an enabled
/// [DismissIntent] action between the focused widget and the app, such as
/// an autocomplete's while its suggestions show. A disabled one (a
/// Scaffold's, with no drawer open) and a text field's own do not count.
bool _nearerDismissal() {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  // A text field answers the dismiss key itself, always (it hides its own
  // toolbar): that is no reason to keep the sitting, so the search starts
  // above the field. An autocomplete's, around the field, still counts.
  Element? field;
  focused.visitAncestorElements((element) {
    if (element.widget is! EditableText) return true;
    field = element;
    return false;
  });
  final context = field ?? focused;
  final action = Actions.maybeFind<DismissIntent>(context);
  if (action == null) return false;
  return action is ContextAction<DismissIntent>
      ? action.isEnabled(const DismissIntent(), context)
      : action.isEnabled(const DismissIntent());
}

/// An editing key's action on the current target, enabled only when [when]
/// holds for its controller: a disabled action leaves the key unhandled.
class _TargetAction<I extends Intent> extends Action<I> {
  _TargetAction(this.targets, {required this.when, required this.run});

  final RecordEditShortcutTargets targets;
  final bool Function(RecordEditController<Object?> controller) when;
  final void Function(RecordEditShortcutTarget target) run;

  RecordEditShortcutTarget? get _target {
    final target = targets.current;
    return target != null && when(target.controller) ? target : null;
  }

  @override
  bool isEnabled(I intent) => _target != null;

  @override
  Object? invoke(I intent) {
    final target = _target;
    if (target != null) run(target);
    return null;
  }
}
