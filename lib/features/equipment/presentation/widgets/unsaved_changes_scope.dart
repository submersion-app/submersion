import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Holds Back on a form while [hasChanges], and asks first whether to throw
/// them away, with the dialog the equipment form shows. Discard leaves the
/// page; Keep Editing stays on it.
class UnsavedChangesScope extends StatelessWidget {
  final bool hasChanges;
  final Widget child;

  const UnsavedChangesScope({
    super.key,
    required this.hasChanges,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await showDiscardChangesDialog(context);
        if (discard == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }
}

/// Asks whether to throw away a form's unsaved changes: true to discard.
Future<bool?> showDiscardChangesDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.equipment_edit_discardDialog_title),
      content: Text(context.l10n.equipment_edit_discardDialog_content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.equipment_edit_discardDialog_keepEditing),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.l10n.equipment_edit_discardDialog_discard),
        ),
      ],
    ),
  );
}
