import 'package:flutter/material.dart';

import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// Whether a whole-record operation (delete, re-parse, mark as logged and
/// the like) may run now on a page that offers editing (issue #4527).
///
/// Such an operation acts on the record at once and is its own History
/// entry, so it needs the record unlocked and a sitting with nothing to
/// save: what it writes must not be mixed up with the diver's held changes.
enum RecordOperationBlock {
  /// Unlocked with nothing to save: it may run.
  none,

  /// The page is locked.
  locked,

  /// The sitting has unsaved changes, or is being saved, or another
  /// operation is running.
  unsaved,
}

/// The block for [controller], or null when the page offers no editing, so
/// its operations act as they always have.
RecordOperationBlock? recordOperationBlockOf(
  RecordEditController<Object?>? controller,
) {
  if (controller == null) return null;
  if (!controller.isUnlocked) return RecordOperationBlock.locked;
  if (controller.isDirty || controller.isBusy) {
    return RecordOperationBlock.unsaved;
  }
  return RecordOperationBlock.none;
}

/// Why an operation is unavailable, or null when it is available. [plural]
/// is the caption over a menu's group of operations; a single control
/// gives its reason in the singular.
String? recordOperationReason(
  AppLocalizations l10n,
  RecordOperationBlock? block, {
  bool plural = false,
}) => switch (block) {
  null || RecordOperationBlock.none => null,
  RecordOperationBlock.locked =>
    plural ? l10n.recordEdit_unlockToUseThese : l10n.recordEdit_unlockToUseThis,
  RecordOperationBlock.unsaved => l10n.recordEdit_saveOrCancelFirst,
};

/// The caption line over a menu's operations while they are unavailable.
/// It cannot be chosen.
PopupMenuItem<T> recordOperationCaption<T>(
  BuildContext context,
  String reason,
) => PopupMenuItem<T>(
  key: const ValueKey('recordOperationCaption'),
  enabled: false,
  child: Text(reason, style: Theme.of(context).textTheme.bodySmall),
);

/// A button for a whole-record operation, drawn disabled with [reason] as
/// its tooltip while the operation is unavailable. It keeps its place and
/// size either way, so a page does not move when it is unlocked.
class RecordOperationButton extends StatelessWidget {
  const RecordOperationButton({
    super.key,
    required this.reason,
    required this.builder,
    required this.onPressed,
  });

  /// Why the operation is unavailable, or null when it is available.
  final String? reason;

  /// Builds the button, handed null as its press while unavailable.
  final Widget Function(VoidCallback? onPressed) builder;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final reason = this.reason;
    if (reason == null) return builder(onPressed);
    return Tooltip(message: reason, child: builder(null));
  }
}
