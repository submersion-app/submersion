import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:submersion_saf/submersion_saf.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/backup_bookmark_service.dart';
import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/features/backup/data/services/backup_note_stamp.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_encrypted_exception.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_note_dialog.dart';
import 'package:submersion/features/backup/presentation/widgets/export_bottom_sheet.dart';
import 'package:submersion/features/backup/presentation/widgets/restore_confirmation_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/encryption_passphrase_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "Back up now": asks for an optional note first; cancelling backs nothing
/// up.
class BackupNowTile extends ConsumerWidget {
  const BackupNowTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy =
        ref.watch(backupOperationProvider).status ==
        BackupOperationStatus.inProgress;
    return ListTile(
      leading: const Icon(Icons.backup),
      title: Text(context.l10n.settings_backups_backUpNow),
      enabled: !busy,
      onTap: () async {
        final result = await BackupNoteDialog.show(context);
        if (result == null) return;
        await ref
            .read(backupOperationProvider.notifier)
            .performBackup(note: result.note);
      },
    );
  }
}

/// "Restore from a file", with today's confirmation and unlock dialogs.
class RestoreFromFileTile extends ConsumerWidget {
  const RestoreFromFileTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy =
        ref.watch(backupOperationProvider).status ==
        BackupOperationStatus.inProgress;
    return ListTile(
      leading: const Icon(Icons.restore),
      title: Text(context.l10n.settings_backups_restoreFile),
      enabled: !busy,
      onTap: () => restoreFromFile(context, ref),
    );
  }
}

Future<void> restoreFromFile(BuildContext context, WidgetRef ref) async {
  final PlatformFile? picked;
  try {
    picked = await FilePicker.pickFile(type: FileType.any);
  } on Exception catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open file picker: $e')));
    }
    return;
  }

  final filePath = picked?.path;
  if (picked == null || filePath == null || !context.mounted) return;

  // Show confirmation dialog with file info
  final file = File(filePath);
  final sizeBytes = await file.length();
  // A plaintext backup carries its note inside; an encrypted one cannot
  // be read before decryption and shows none.
  final note = await readBackupNote(filePath);
  final record = BackupRecord(
    id: 'temp',
    filename: picked.name,
    timestamp: await file.lastModified(),
    sizeBytes: sizeBytes,
    location: BackupLocation.local,
    diveCount: 0,
    siteCount: 0,
    note: note,
  );

  if (!context.mounted) return;

  final mode = await RestoreConfirmationDialog.show(
    context,
    record,
    currentSchemaVersion: AppDatabase.currentSchemaVersion,
    offerReplace: ref.read(cloudStorageProviderProvider) != null,
  );
  if (mode == null) return;
  try {
    await ref
        .read(backupOperationProvider.notifier)
        .restoreFromFilePath(filePath, mode: mode);
  } on BackupEncryptedException {
    if (!context.mounted) return;
    await showEncryptionPassphraseDialog(
      context,
      title: context.l10n.settings_backupEncryption_restoreUnlockTitle,
      hint: context.l10n.settings_backupEncryption_restoreUnlockHint,
      onSubmit: (secret) => ref
          .read(backupOperationProvider.notifier)
          .restoreFromFilePath(filePath, mode: mode, encryptionSecret: secret),
    );
  }
}

/// Lets the diver pick a backup folder in the form each platform can keep
/// writing to across launches.
Future<void> pickBackupFolder(BuildContext context, WidgetRef ref) async {
  final BackupFolderPick? picked;
  if (Platform.isIOS) {
    // iOS: capture a security-scoped bookmark directly. A bare file_picker
    // path would lose its scope on the next launch.
    picked = await BackupBookmarkService.pickFolder();
  } else if (Platform.isAndroid) {
    // Android: pick a SAF tree (content:// URI). A file_picker path is
    // unwritable under scoped storage, so persist the URI + its display
    // name and skip the bookmark flow entirely. Native + platform-gated,
    // so the branch body is excluded from coverage; setSafBackupLocation
    // itself is unit-tested separately.
    // coverage:ignore-start
    final folder = await SubmersionSaf.pickFolder();
    if (folder != null) {
      await ref
          .read(backupSettingsProvider.notifier)
          .setSafBackupLocation(folder.uri, folder.displayName);
    }
    return;
    // coverage:ignore-end
  } else {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: context.l10n.settings_backups_folder,
    );
    picked = path == null
        ? null
        : BackupFolderPick(
            path: path,
            bookmark: BackupBookmarkService.isSupported
                ? await BackupBookmarkService.createBookmark(path)
                : null,
          );
  }
  if (picked != null) {
    await ref
        .read(backupSettingsProvider.notifier)
        .setBackupLocationWithBookmark(picked.path, picked.bookmark);
  }
}

/// "Save a backup file": today's export sheet, with a note, Save to a
/// folder and Share. [context] is the tile's, so the iPad share popover
/// anchors to it.
void saveBackupFile(BuildContext context, WidgetRef ref) {
  final encrypted = ref.read(backupSettingsProvider).backupEncryptionEnabled;
  // Captured now: the export sheet is dismissed before onShare runs, so the
  // anchor has to come from the tile that opened it.
  final anchor = shareAnchorFrom(context);
  ExportBottomSheet.show(
    context,
    onSaveToFile: (note) async {
      // Deliberately a folder pick rather than a Save As sheet.
      // file_picker 12's saveFile requires the entire artifact up front as
      // `bytes`, and a dive library can be far too large to hold in memory,
      // so every branch below streams instead. Mirrors the backup folder
      // picker above, including its Android reasoning.
      final fileName = _defaultFileName(encrypted);
      final notifier = ref.read(backupOperationProvider.notifier);

      if (Platform.isAndroid) {
        // Scoped storage: a file_picker path is unwritable, so take a SAF
        // tree and stream into it.
        // coverage:ignore-start
        final folder = await SubmersionSaf.pickFolder();
        if (folder == null) return;
        await notifier.exportToSafTree(
          treeUri: folder.uri,
          fileName: fileName,
          note: note,
        );
        return;
        // coverage:ignore-end
      }

      final dir = await FilePicker.getDirectoryPath(
        dialogTitle: context.l10n.settings_backups_saveFile,
      );
      if (dir == null) return;
      await notifier.exportToPath(p.join(dir, fileName), note: note);
    },
    onShare: (note) async {
      final file = await ref
          .read(backupOperationProvider.notifier)
          .exportForSharing(note: note);
      if (file != null && context.mounted) {
        await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], sharePositionOrigin: anchor),
        );
      }
    },
  );
}

String _defaultFileName(bool encrypted) {
  final now = DateTime.now();
  final formatted =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  return 'submersion_backup_$formatted.${encrypted ? 'sbe' : 'db'}';
}
