import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/shared/selection/selection_controller.dart';

/// Wraps a selectable list with its keyboard and back-navigation handling.
///
/// Escape leaves selection mode, Ctrl/Cmd-A checks everything, and Android
/// back leaves the mode rather than popping the route. Without this the only
/// way out is the bar's close button, which is what made selection mode feel
/// like a trap.
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
          canPop: !state.isActive,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) controller.exit();
          },
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () {
                if (controller.value.isActive) controller.exit();
              },
              const SingleActivator(
                LogicalKeyboardKey.keyA,
                control: true,
              ): () =>
                  controller.selectAll(selectableIds),
              const SingleActivator(LogicalKeyboardKey.keyA, meta: true): () =>
                  controller.selectAll(selectableIds),
            },
            child: Focus(autofocus: true, child: child),
          ),
        );
      },
    );
  }
}
