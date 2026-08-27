import 'package:flutter/material.dart';

import 'package:submersion/features/settings/presentation/widgets/enable_encryption_dialog.dart'
    show RecoveryCodeDisplay;
import 'package:submersion/l10n/l10n_extension.dart';

/// Displays a freshly regenerated backup recovery code behind a confirm-saved
/// gate. Regeneration invalidates the previous recovery slot before this
/// shows, so the new code is the ONLY way back in -- losing it is permanent.
/// [showBackupRecoveryCodeDialog] therefore presents it non-dismissibly (no
/// tap-outside, no Back) and keeps Done disabled until the user confirms they
/// saved it, matching the enable flow's recovery gate.
class BackupRecoveryCodeDialog extends StatefulWidget {
  final String code;

  const BackupRecoveryCodeDialog({super.key, required this.code});

  @override
  State<BackupRecoveryCodeDialog> createState() =>
      _BackupRecoveryCodeDialogState();
}

class _BackupRecoveryCodeDialogState extends State<BackupRecoveryCodeDialog> {
  var _saved = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(l10n.settings_backupEncryption_recoveryTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settings_backupEncryption_recoveryExplain),
            const SizedBox(height: 12),
            RecoveryCodeDisplay(code: widget.code),
            CheckboxListTile(
              value: _saved,
              onChanged: (v) => setState(() => _saved = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                l10n.settings_backupEncryption_recoverySavedConfirm,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: _saved ? () => Navigator.of(context).pop() : null,
            child: Text(l10n.settings_backupEncryption_done),
          ),
        ],
      ),
    );
  }
}

/// Show [BackupRecoveryCodeDialog] non-dismissibly so a stray tap or Back gesture
/// cannot discard a recovery code that can no longer be regenerated.
Future<void> showBackupRecoveryCodeDialog(
  BuildContext context, {
  required String code,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BackupRecoveryCodeDialog(code: code),
  );
}
