import 'package:flutter/material.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(TagSaveErrorLine);

/// Runs a tag dialog's [save], closing the dialog only once it lands.
///
/// [save] returns false when it chose not to write (the diver declined the
/// narrowing confirmation), which leaves the dialog open without an error.
/// A failure is logged and flagged through [setFailed], and the dialog
/// stays open with its edits so the diver can retry (#1907). [setSaving]
/// disables the dialog's buttons meanwhile, so a second tap cannot start a
/// second write. A new attempt clears the previous failure.
///
/// Every failure is caught here, so the Future a button drops cannot reach
/// the zone unattributed.
Future<void> saveFromTagDialog(
  BuildContext dialogContext, {
  required ValueChanged<bool> setSaving,
  required ValueChanged<bool> setFailed,
  required Future<bool> Function() save,
}) async {
  setFailed(false);
  setSaving(true);
  try {
    if (await save() && dialogContext.mounted) {
      Navigator.pop(dialogContext);
    }
  } catch (e, stackTrace) {
    _log.error('Failed to save a tag', error: e, stackTrace: stackTrace);
    if (dialogContext.mounted) setFailed(true);
  } finally {
    if (dialogContext.mounted) setSaving(false);
  }
}

/// The failed-save line, shown in a tag dialog itself: a page SnackBar would
/// render under the dialog's barrier, dimmed and out of reach (#1907). A
/// live region, so a screen reader announces it.
class TagSaveErrorLine extends StatelessWidget {
  const TagSaveErrorLine({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Semantics(
      liveRegion: true,
      child: Text(
        context.l10n.common_error_tryAgain,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  );
}
