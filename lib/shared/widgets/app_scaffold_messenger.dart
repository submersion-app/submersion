import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The app's [ScaffoldMessenger], with a way out of a queue of messages
/// (#3834).
///
/// Snack bars show one at a time, each waiting for the one ahead of it to go.
/// A burst of them would otherwise have the user closing every message in
/// turn to reach what they cover, so while others are waiting the one on show
/// carries a Dismiss all button.
///
/// It also keeps a message with an action on screen for a screen reader user,
/// however short its duration, since `persist: false` has no such exception.
class AppScaffoldMessenger extends ScaffoldMessenger {
  const AppScaffoldMessenger({super.key, required super.child});

  @override
  ScaffoldMessengerState createState() => _AppScaffoldMessengerState();
}

class _AppScaffoldMessengerState extends ScaffoldMessengerState {
  /// Every message the user could still dismiss, in queue order. The queue
  /// itself is private to the framework.
  final _open = <ScaffoldFeatureController<SnackBar, SnackBarClosedReason>>[];

  final _othersWaiting = ValueNotifier(false);

  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    SnackBar snackBar, {
    AnimationStyle? snackBarAnimationStyle,
  }) {
    final controller = super.showSnackBar(
      _withDismissAll(snackBar),
      snackBarAnimationStyle: snackBarAnimationStyle,
    );
    _open.add(controller);
    _updateOthersWaiting();
    unawaited(
      controller.closed.then((_) {
        if (!mounted) return;
        _open.remove(controller);
        _updateOthersWaiting();
      }),
    );
    return controller;
  }

  @override
  void clearSnackBars() {
    super.clearSnackBars();
    // The framework forgets the waiting messages without closing them, so
    // their `closed` never tells us they went. The one on show is on its way
    // out too, and a message raised straight after this is not waiting for
    // anyone the user could dismiss.
    _open.clear();
    _updateOthersWaiting();
  }

  @override
  void dispose() {
    _othersWaiting.dispose();
    super.dispose();
  }

  void _updateOthersWaiting() => _othersWaiting.value = _open.length > 1;

  /// Removes each message in turn rather than calling [clearSnackBars], which
  /// leaves the waiting ones' `closed` incomplete: a caller may hold an undo
  /// snapshot until that completes.
  void _dismissAll() {
    for (var i = _open.length; i > 0; i--) {
      removeCurrentSnackBar(reason: SnackBarClosedReason.dismiss);
    }
  }

  /// Whether [snackBar] must wait for the user despite asking to time out.
  ///
  /// Someone on a screen reader has to move focus to an action to use it,
  /// which can take longer than the message lasts.
  bool _needsScreenReaderTime(SnackBar snackBar) =>
      snackBar.action != null && MediaQuery.accessibleNavigationOf(context);

  /// Copies [snackBar] field by field, as the framework's own
  /// [SnackBar.withAnimation] does, since it has no `copyWith`.
  SnackBar _withDismissAll(SnackBar snackBar) => SnackBar(
    key: snackBar.key,
    content: _DismissAllContent(
      othersWaiting: _othersWaiting,
      onDismissAll: _dismissAll,
      child: snackBar.content,
    ),
    backgroundColor: snackBar.backgroundColor,
    elevation: snackBar.elevation,
    margin: snackBar.margin,
    padding: snackBar.padding,
    width: snackBar.width,
    shape: snackBar.shape,
    hitTestBehavior: snackBar.hitTestBehavior,
    behavior: snackBar.behavior,
    action: snackBar.action,
    actionOverflowThreshold: snackBar.actionOverflowThreshold,
    showCloseIcon: snackBar.showCloseIcon,
    closeIconColor: snackBar.closeIconColor,
    duration: snackBar.duration,
    persist: snackBar.persist || _needsScreenReaderTime(snackBar),
    animation: snackBar.animation,
    onVisible: snackBar.onVisible,
    dismissDirection: snackBar.dismissDirection,
    clipBehavior: snackBar.clipBehavior,
  );
}

/// A message, with a Dismiss all button under it while others are waiting.
///
/// The button is a [SnackBarAction] so it takes the same colours as the
/// message's own action. It goes on a line of its own because the row beside
/// the message may already hold that action and the close icon, which leaves
/// no room on a phone.
class _DismissAllContent extends StatelessWidget {
  const _DismissAllContent({
    required this.othersWaiting,
    required this.onDismissAll,
    required this.child,
  });

  final ValueListenable<bool> othersWaiting;
  final VoidCallback onDismissAll;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: othersWaiting,
      child: child,
      builder: (context, waiting, child) => Column(
        mainAxisSize: MainAxisSize.min,
        // Stretch keeps the tight width the snack bar gives its content.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          child!,
          if (waiting)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: SnackBarAction(
                label: context.l10n.common_action_dismissAll,
                onPressed: onDismissAll,
              ),
            ),
        ],
      ),
    );
  }
}
