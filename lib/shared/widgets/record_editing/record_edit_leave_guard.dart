import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/forms/discard_dialog.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/tab_visibility.dart';

/// Ends a sitting without saving, asking first when it has unsaved changes.
///
/// True means the record is now locked. False means the diver chose to keep
/// editing and nothing changed, or a save is running: a sitting that is
/// being written cannot be discarded, and locks by itself when the write
/// ends.
Future<bool> cancelSitting<T>(
  BuildContext context,
  RecordEditController<T> controller,
) async {
  if (controller.isBusy) return false;
  if (controller.isDirty && !await showDiscardDialog(context)) return false;
  controller.lock();
  return true;
}

/// Guards a record page's sitting: it is not left with unsaved changes
/// unasked, and nothing happens to it while it is being saved.
///
/// With changes pending, going back asks whether to discard them. With none,
/// the page simply closes, and an unlocked record is locked on the way out.
///
/// While a save is running the page takes no input, from a pointer or the
/// keyboard, and going back does nothing. Otherwise a keystroke could reach
/// a sitting that has already been handed to the database, and a discard
/// could lock the page while the write carries on. The save ends shortly
/// and either locks the page or gives it back.
class RecordEditLeaveGuard<T> extends StatelessWidget {
  const RecordEditLeaveGuard({
    super.key,
    required this.controller,
    required this.child,
    this.backsOutFirst,
  });

  final RecordEditController<T> controller;
  final Widget child;

  /// Whether the page has a step of its own that Back closes first (the
  /// photo viewer's fullscreen): while it does, Back leaves the sitting as
  /// it is and asks nothing. Read as Back arrives, before that step's own
  /// handler runs.
  final bool Function()? backsOutFirst;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      child: child,
      builder: (context, child) {
        // A kept-alive tab that is hidden (Training, Media and Documents)
        // lets Back through and asks nothing: the tab on screen answers
        // it, and the page leaves with this one's sitting, as the old forms
        // did (#3437).
        final shown = TabVisibility.isVisible(context);
        return PopScope(
          canPop: !controller.isBusy && (!controller.isDirty || !shown),
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) {
              controller.lock();
              return;
            }
            // A route tells every scope of a Back another refused: hidden,
            // this one has nothing to ask.
            if (!shown || controller.isBusy) return;
            // Back closes the page's own step first; the sitting stays.
            if (backsOutFirst?.call() ?? false) return;
            // With nothing to save this guard let the pop through: a scope
            // inside the page refused it for a step of its own (the photo
            // viewer leaving fullscreen first), and the page stays.
            if (!controller.isDirty) return;
            final navigator = Navigator.of(context);
            if (!await cancelSitting(context, controller)) return;
            // The page went while the question was open (an editor closed
            // by a change of diver, the question being in the root
            // navigator): popping now would take the page under it.
            if (!context.mounted) return;
            if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
            // A page with nothing under it (the list pane's, its tab's first
            // page) locks and stays: there is nowhere to go back to.
            if (navigator.canPop()) navigator.pop();
          },
          // Both stay in the tree, so a save starting or ending never
          // rebuilds the page beneath them. Excluding focus also takes it
          // from a field that has it, which closes the keyboard.
          child: AbsorbPointer(
            absorbing: controller.isBusy,
            child: ExcludeFocus(excluding: controller.isBusy, child: child!),
          ),
        );
      },
    );
  }
}
