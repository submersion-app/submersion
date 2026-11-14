import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/forms/discard_dialog.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// Ends a sitting without saving, asking first when it has unsaved changes.
///
/// True means the record is now locked. False means the diver chose to keep
/// editing and nothing changed.
Future<bool> cancelSitting<T>(
  BuildContext context,
  RecordEditController<T> controller,
) async {
  if (controller.isDirty && !await showDiscardDialog(context)) return false;
  controller.lock();
  return true;
}

/// Stops a record page being left with unsaved changes unasked.
///
/// With changes pending, going back asks whether to discard them. With none,
/// the page simply closes, and an unlocked record is locked on the way out.
class RecordEditLeaveGuard<T> extends StatelessWidget {
  const RecordEditLeaveGuard({
    super.key,
    required this.controller,
    required this.child,
  });

  final RecordEditController<T> controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      child: child,
      builder: (context, child) => PopScope(
        canPop: !controller.isDirty,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) {
            controller.lock();
            return;
          }
          final navigator = Navigator.of(context);
          if (await cancelSitting(context, controller)) navigator.pop();
        },
        child: child!,
      ),
    );
  }
}
