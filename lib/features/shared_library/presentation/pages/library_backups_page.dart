import 'dart:io';

import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_archive.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_record.dart';
import 'package:submersion/core/services/shared_library/backup/library_restore_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_sync_notifier.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_backup_tile.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_error_text.dart';
import 'package:submersion/features/shared_library/presentation/widgets/picked_file_path.dart';
import 'package:submersion/features/shared_library/presentation/widgets/recovery_code_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// An owner's backups of a shared site library (issue #2567), listed like
/// the database backups: back up now with a note, import a backup file,
/// and pin, export, restore or delete each one.
class LibraryBackupsPage extends ConsumerStatefulWidget {
  const LibraryBackupsPage({super.key, required this.libraryId});

  final String libraryId;

  @override
  ConsumerState<LibraryBackupsPage> createState() => _LibraryBackupsPageState();
}

class _LibraryBackupsPageState extends ConsumerState<LibraryBackupsPage> {
  bool _busy = false;

  String get _libraryId => widget.libraryId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final role = ref.watch(libraryRoleProvider(_libraryId)).value;
    final owner = role == SharedLibraryRole.owner;
    final backups = owner
        ? ref.watch(libraryBackupsProvider(_libraryId))
        : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sharedLibrary_backups_title),
        actions: [
          if (owner)
            IconButton(
              icon: const Icon(Icons.file_open_outlined),
              tooltip: l10n.sharedLibrary_backups_import,
              onPressed: _busy ? null : _import,
            ),
        ],
      ),
      body: role == null
          ? const Center(child: CircularProgressIndicator())
          : !owner
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.sharedLibrary_backups_ownersOnly),
              ),
            )
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton.tonalIcon(
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.backup_outlined),
                      label: Text(l10n.sharedLibrary_backups_backUpNow),
                      onPressed: _busy ? null : _backUpNow,
                    ),
                  ),
                ),
                ...switch (backups) {
                  AsyncData(:final value) when value.isEmpty => [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(l10n.sharedLibrary_backups_empty),
                    ),
                  ],
                  AsyncData(:final value) => [
                    for (final r in value)
                      LibraryBackupTile(
                        record: r,
                        onPinToggle: () => _run(
                          (diverId) => ref
                              .read(libraryBackupServiceProvider)
                              .setPinned(
                                r.backupId,
                                libraryId: _libraryId,
                                diverId: diverId,
                                pinned: !r.pinned,
                              ),
                        ),
                        onExport: (tileContext) => _export(tileContext, r),
                        onRestore: () => _restore(r),
                        onDelete: () => _delete(r),
                      ),
                  ],
                  AsyncError(:final error) => [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(libraryErrorText(l10n, error)),
                    ),
                  ],
                  _ => [
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                },
              ],
            ),
    );
  }

  /// Runs [action] as the active profile, then re-reads the list. A failure
  /// shows as a snackbar; [onDone] names a success worth saying.
  Future<void> _run(
    Future<void> Function(String diverId) action, {
    String? onDone,
  }) async {
    final membership = await ref.read(
      currentMembershipProvider(_libraryId).future,
    );
    if (membership == null || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await action(membership.diverId);
      if (onDone != null) {
        messenger.showSnackBar(SnackBar(content: Text(onDone)));
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is BackupRefusedError
                ? l10n.sharedLibrary_backups_importRefused
                : libraryErrorText(l10n, e),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        ref.invalidate(libraryBackupsProvider(_libraryId));
      }
    }
  }

  Future<void> _backUpNow() async {
    final note = await _askForNote(context);
    if (note == null || !mounted) return;
    await _run(
      (diverId) => ref
          .read(libraryBackupServiceProvider)
          .backUp(libraryId: _libraryId, diverId: diverId, note: note),
      onDone: context.l10n.sharedLibrary_backups_done,
    );
  }

  Future<void> _import() async {
    final PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile(type: FileType.any);
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(libraryErrorText(context.l10n, e))),
        );
      }
      return;
    }
    final file = picked;
    if (file == null) return;
    await _run(
      (_) => withLocalPath(
        file,
        (path) => ref
            .read(libraryBackupServiceProvider)
            .import(libraryId: _libraryId, path: path),
      ),
    );
  }

  Future<void> _export(BuildContext tileContext, LibraryBackupRecord r) async {
    final anchor = shareAnchorFrom(tileContext);
    final title = context.l10n.sharedLibrary_backups_export;
    await _run((_) async {
      final path = await ref
          .read(libraryBackupServiceProvider)
          .localCopy(r.backupId, libraryId: _libraryId);
      // The share sheet, or a save dialog where it takes no files (Linux).
      if (canShareFiles) {
        await SharePlus.instance.share(
          ShareParams(files: [XFile(path)], sharePositionOrigin: anchor),
        );
      } else {
        await saveBytesToFile(
          await File(path).readAsBytes(),
          p.basename(path),
          dialogTitle: title,
          mimeType: 'application/zip',
        );
      }
    });
  }

  Future<void> _restore(LibraryBackupRecord r) async {
    final l10n = context.l10n;
    final date = UnitFormatter(
      ref.read(settingsProvider),
    ).formatDateTime(r.createdAt.toLocal(), l10n: l10n);
    if (!await _confirmRestore(context, date)) return;
    String? oldSecret;
    // The page is idle while a passphrase is asked for.
    while (mounted && await _restoreOnce(r, oldSecret)) {
      if (!mounted) return;
      final secret = await promptLibrarySecret(
        context,
        message: oldSecret == null
            ? l10n.sharedLibrary_backups_oldKey
            : l10n.sharedLibrary_encrypted_wrong,
      );
      // Cancelled: nothing was changed.
      if (secret == null) return;
      oldSecret = secret;
    }
  }

  /// One restore attempt; true when the backup needs its earlier key.
  Future<bool> _restoreOnce(LibraryBackupRecord r, String? oldSecret) async {
    final done = context.l10n.sharedLibrary_backups_restoreDone;
    final messenger = ScaffoldMessenger.of(context);
    // Read now: `ref` is unusable once the page closes, which a long
    // restore leaves time for.
    final sync = ref.read(sharedLibrarySyncProvider.notifier);
    var needsKey = false;
    await _run((diverId) async {
      try {
        await ref
            .read(libraryRestoreServiceProvider)
            .restore(
              libraryId: _libraryId,
              diverId: diverId,
              backupId: r.backupId,
              oldSecret: oldSecret,
            );
      } on BackupNeedsOldKeyError {
        needsKey = true;
        return;
      }
      // This device takes the restored library at once.
      await sync.syncOne(_libraryId);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    });
    return needsKey;
  }

  Future<void> _delete(LibraryBackupRecord r) async {
    final both = r.localPath != null && r.inStorage;
    final (fromDevice, fromStorage) = both
        ? await _askWhereToDelete(context) ?? (false, false)
        : await _confirmDelete(context)
        ? (r.localPath != null, r.inStorage)
        : (false, false);
    if (!fromDevice && !fromStorage) return;
    await _run(
      (diverId) => ref
          .read(libraryBackupServiceProvider)
          .delete(
            r.backupId,
            libraryId: _libraryId,
            diverId: diverId,
            fromDevice: fromDevice,
            fromStorage: fromStorage,
          ),
    );
  }
}

/// The note for a new backup ('' for none), or null when cancelled.
Future<String?> _askForNote(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const _NoteDialog());

/// Owns its controller, so the field outlives the closing animation.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog();

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.sharedLibrary_backups_backUpNow),
      content: TextField(
        key: const Key('backup-note'),
        controller: _controller,
        autofocus: true,
        maxLength: 200,
        decoration: InputDecoration(labelText: l10n.sharedLibrary_backups_note),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(l10n.sharedLibrary_backups_backUpNow),
        ),
      ],
    );
  }
}

Future<bool> _confirmRestore(BuildContext context, String date) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.sharedLibrary_backups_restore),
        content: Text(context.l10n.sharedLibrary_backups_restoreConfirm(date)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.sharedLibrary_backups_restore),
          ),
        ],
      ),
    ) ??
    false;

Future<bool> _confirmDelete(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.sharedLibrary_backups_deleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.sharedLibrary_backups_delete),
          ),
        ],
      ),
    ) ??
    false;

/// (from this device, from storage), or null when cancelled.
Future<(bool, bool)?> _askWhereToDelete(BuildContext context) =>
    showDialog<(bool, bool)>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        return SimpleDialog(
          title: Text(l10n.sharedLibrary_backups_deleteWhere),
          children: [
            for (final (label, where) in [
              (l10n.sharedLibrary_backups_onDevice, (true, false)),
              (l10n.sharedLibrary_backups_inStorage, (false, true)),
              (l10n.sharedLibrary_backups_both, (true, true)),
            ])
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, where),
                child: Text(label),
              ),
          ],
        );
      },
    );
