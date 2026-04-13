import 'package:flutter/material.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shows a confirmation dialog when the user tries to navigate away
/// during an active dive computer download.
///
/// Returns `true` if the user confirmed they want to leave (and cancel
/// the download), `false` if they chose to stay or dismissed the dialog.
Future<bool> showDownloadExitConfirmation(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.l10n.diveComputer_downloadExit_title),
      content: Text(dialogContext.l10n.diveComputer_downloadExit_content),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(dialogContext.l10n.diveComputer_downloadExit_stay),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(dialogContext.l10n.diveComputer_downloadExit_leave),
        ),
      ],
    ),
  );
  return result ?? false;
}
