import 'package:flutter/material.dart';

import 'package:submersion/features/backup/data/services/backup_note_stamp.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The optional note field shared by the Backup Now dialog and the export
/// sheet, so both offer the same label, hint and length limit.
class BackupNoteField extends StatelessWidget {
  const BackupNoteField({
    super.key,
    required this.controller,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      maxLength: maxBackupNoteLength,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: context.l10n.backup_note_label,
        hintText: context.l10n.backup_note_hint,
      ),
    );
  }
}
