import 'dart:io';

import 'package:flutter/material.dart';

import 'package:submersion/features/backup/data/services/backup_note_stamp.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_note_field.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Bottom sheet presenting export options (Save to File and Share) with an
/// optional note for the exported backup.
///
/// Share option is hidden on Windows and Linux (no share sheet support).
class ExportBottomSheet extends StatefulWidget {
  /// Each callback receives the normalized note, null when none was typed.
  final ValueChanged<String?> onSaveToFile;
  final ValueChanged<String?>? onShare;

  const ExportBottomSheet({
    super.key,
    required this.onSaveToFile,
    this.onShare,
  });

  /// Shows the bottom sheet. Actions are via callbacks; nothing is returned.
  static void show(
    BuildContext context, {
    required ValueChanged<String?> onSaveToFile,
    required ValueChanged<String?> onShare,
  }) {
    final showShare = Platform.isIOS || Platform.isMacOS || Platform.isAndroid;

    showModalBottomSheet<void>(
      context: context,
      // Lets the sheet rise above the keyboard while the note is typed.
      isScrollControlled: true,
      builder: (_) => ExportBottomSheet(
        onSaveToFile: (note) {
          Navigator.of(context).pop();
          onSaveToFile(note);
        },
        onShare: showShare
            ? (note) {
                Navigator.of(context).pop();
                onShare(note);
              }
            : null,
      ),
    );
  }

  @override
  State<ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends State<ExportBottomSheet> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String? get _normalizedNote => normalizeBackupNote(_note.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onShare = widget.onShare;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  context.l10n.backup_export_bottomSheet_title,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: BackupNoteField(controller: _note),
              ),
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: Text(context.l10n.backup_export_saveToFile),
                subtitle: Text(context.l10n.backup_export_saveToFile_subtitle),
                onTap: () => widget.onSaveToFile(_normalizedNote),
              ),
              if (onShare != null)
                ListTile(
                  leading: const Icon(Icons.share),
                  title: Text(context.l10n.backup_export_share),
                  subtitle: Text(context.l10n.backup_export_share_subtitle),
                  onTap: () => onShare(_normalizedNote),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
