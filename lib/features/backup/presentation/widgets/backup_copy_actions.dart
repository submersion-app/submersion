import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:submersion_saf/submersion_saf.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_copy_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Whether this platform has a system share sheet. Windows and Linux do not,
/// so there a backup can only be saved to a folder.
bool get platformHasShareSheet =>
    Platform.isIOS || Platform.isMacOS || Platform.isAndroid;

/// Save to a folder or Share for a backup from the history (issue #3650).
/// [context] is the history row's, so the iPad share popover anchors to it.
Future<void> showBackupCopySheet(
  BuildContext context,
  WidgetRef ref,
  BackupRecord record,
) async {
  // Captured now: the sheet is gone before Share runs.
  final anchor = shareAnchorFrom(context);
  final deviceLocked = await ref
      .read(backupServiceProvider)
      .isDeviceLockedSafetyCopy(record);
  if (!context.mounted) return;
  final notifier = ref.read(backupOperationProvider.notifier);
  final dialogTitle = context.l10n.settings_backups_saveFile;

  await BackupCopySheet.show(
    context,
    record: record,
    deviceLocked: deviceLocked,
    onSaveToFolder: () async {
      if (Platform.isAndroid) {
        // Scoped storage: a file_picker path is unwritable, so take a SAF
        // tree and stream into it, as saveBackupFile does.
        // coverage:ignore-start
        final folder = await SubmersionSaf.pickFolder();
        if (folder == null) return;
        await notifier.saveBackupCopyToSafTree(record, folder.uri);
        return;
        // coverage:ignore-end
      }
      // coverage:ignore-start
      final dir = await FilePicker.getDirectoryPath(dialogTitle: dialogTitle);
      if (dir == null) return;
      await notifier.saveBackupCopyToDirectory(record, dir);
      // coverage:ignore-end
    },
    onShare: platformHasShareSheet
        ? () async {
            // coverage:ignore-start
            final file = await notifier.prepareBackupForSharing(record);
            if (file == null) return;
            await SharePlus.instance.share(
              ShareParams(
                files: [XFile(file.path)],
                sharePositionOrigin: anchor,
              ),
            );
            // coverage:ignore-end
          }
        : null,
  );
}
