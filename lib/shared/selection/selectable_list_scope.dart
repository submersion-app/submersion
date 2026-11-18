import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:submersion/shared/widgets/tab_visibility.dart';

import 'package:submersion/shared/selection/selection_controller.dart';

/// Wraps a selectable list with its keyboard and back-navigation handling.
///
/// Escape leaves selection mode (and only then is it taken: outside the
/// mode it goes on to what is around the list), Ctrl/Cmd-A checks
/// everything, and Android back leaves the mode rather than popping the
/// route. Without this the only way out is the bar's close button, which is
/// what made selection mode feel like a trap.
class SelectableListScope extends StatelessWidget {
  final SelectionController controller;

  /// Ids Ctrl/Cmd-A should check, already filtered to selectable rows.
  final List<String> selectableIds;

  final Widget child;

  const SelectableListScope({
    super.key,
    required this.controller,
    required this.selectableIds,
    required this.child,
  });

  /// True when the platform's multi-select modifier is held: Cmd on macOS,
  /// Control elsewhere.
  static bool isModifierPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return keys.contains(LogicalKeyboardKey.metaLeft) ||
          keys.contains(LogicalKeyboardKey.metaRight);
    }
    return keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight);
  }

  /// True when either shift key is held, for range extension.
  static bool isShiftPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, state, _) {
        return PopScope(
          // A hidden tab's selection lets Back through: ending a selection
          // nobody can see would be all Back did (#3437).
          canPop: !state.isActive || !TabVisibility.isVisible(context),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) controller.exit();
          },
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(
                LogicalKeyboardKey.keyA,
                control: true,
              ): () =>
                  controller.selectAll(selectableIds),
              const SingleActivator(LogicalKeyboardKey.keyA, meta: true): () =>
                  controller.selectAll(selectableIds),
            },
            // Escape answers only while selection mode is on. A binding
            // above would claim every Escape, and outside the mode it must
            // go on to what is around the list: the list pane's editing
            // sitting, which it cancels (issue #4527). The mode entered from
            // Select with no row checked yet counts: its bar is showing, and
            // one press closes the bar without also discarding the pane's
            // changes. A held Escape's repeats are kept here: they are the
            // press that left selection mode, not a new one asking to
            // cancel.
            child: Focus(
              autofocus: true,
              onKeyEvent: (_, event) {
                if (event.logicalKey != LogicalKeyboardKey.escape) {
                  return KeyEventResult.ignored;
                }
                if (event is KeyRepeatEvent) return KeyEventResult.handled;
                if (event is! KeyDownEvent || !controller.value.isActive) {
                  return KeyEventResult.ignored;
                }
                controller.exit();
                return KeyEventResult.handled;
              },
              child: child,
            ),
          ),
        );
      },
    );
  }
}
