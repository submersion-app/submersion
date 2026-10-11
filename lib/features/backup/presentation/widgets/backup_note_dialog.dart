import 'package:flutter/material.dart';

import 'package:submersion/features/backup/data/services/backup_note_stamp.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_note_field.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the Backup Now dialog decided. [BackupNoteDialog.show] returns null
/// when the diver cancels; a result whose [note] is null means "back up
/// without a note".
class BackupNoteResult {
  const BackupNoteResult(this.note);

  final String? note;
}

/// Asks for an optional note before a manual backup.
class BackupNoteDialog extends StatefulWidget {
  const BackupNoteDialog({super.key});

  static Future<BackupNoteResult?> show(BuildContext context) =>
      showDialog<BackupNoteResult>(
        context: context,
        builder: (_) => const BackupNoteDialog(),
      );

  @override
  State<BackupNoteDialog> createState() => _BackupNoteDialogState();
}

class _BackupNoteDialogState extends State<BackupNoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(
    context,
  ).pop(BackupNoteResult(normalizeBackupNote(_controller.text)));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.backup_note_dialog_title),
      content: BackupNoteField(
        controller: _controller,
        autofocus: true,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.backup_note_dialog_confirm),
        ),
      ],
    );
  }
}
