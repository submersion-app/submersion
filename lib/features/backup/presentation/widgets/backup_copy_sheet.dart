import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Save to a folder and Share for a backup that already exists (issue
/// #3650). Laid out like [ExportBottomSheet] without its note field: the
/// backup already carries its note, and an encrypted one cannot be changed
/// without its password.
///
/// It reads [settingsProvider] so the date honours the diver's format, so a
/// `ProviderScope` must be in the tree above it.
class BackupCopySheet extends ConsumerWidget {
  final BackupRecord record;

  /// Adds the line saying this safety copy restores only on this device.
  final bool deviceLocked;

  final VoidCallback onSaveToFolder;

  /// Null hides Share, as on Windows and Linux, which have no share sheet.
  final VoidCallback? onShare;

  const BackupCopySheet({
    super.key,
    required this.record,
    required this.deviceLocked,
    required this.onSaveToFolder,
    this.onShare,
  });

  /// Shows the sheet. Each choice closes it before its callback runs.
  static Future<void> show(
    BuildContext context, {
    required BackupRecord record,
    required bool deviceLocked,
    required VoidCallback onSaveToFolder,
    VoidCallback? onShare,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => BackupCopySheet(
        record: record,
        deviceLocked: deviceLocked,
        onSaveToFolder: () {
          Navigator.of(sheetContext).pop();
          onSaveToFolder();
        },
        onShare: onShare == null
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                onShare();
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    // A sheet opened while idle stays open if a backup then starts, and the
    // notifier ignores a copy-out while busy: offer nothing it would ignore.
    final busy = ref.watch(isBackupInProgressProvider);
    final onShare = this.onShare;
    final when = units.formatDateTime(record.timestamp, l10n: context.l10n);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.l10n.backup_copySheet_title(when),
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (deviceLocked) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  context.l10n.backup_copySheet_deviceLocked,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: Text(context.l10n.settings_backups_saveToFolder),
              subtitle: Text(context.l10n.backup_export_saveToFile_subtitle),
              enabled: !busy,
              onTap: onSaveToFolder,
            ),
            if (onShare != null)
              ListTile(
                leading: const Icon(Icons.share),
                title: Text(context.l10n.backup_export_share),
                subtitle: Text(context.l10n.backup_export_share_subtitle),
                enabled: !busy,
                onTap: onShare,
              ),
          ],
        ),
      ),
    );
  }
}
