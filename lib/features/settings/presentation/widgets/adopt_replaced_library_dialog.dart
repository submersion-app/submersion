import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/sync_maintenance_progress_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Confirm and run adoption of a replaced cloud library. Shared by the Cloud
/// Sync page and the app-root surfacing so the destructive adopt has exactly
/// one implementation. The safety backup runs here (not in SyncNotifier)
/// because backup providers import sync providers; this widget layer may
/// import both.
Future<void> showAdoptReplacedLibraryDialog(
  BuildContext context,
  WidgetRef ref,
  LibraryEpochMarker marker,
) async {
  final l10n = context.l10n;
  final date = marker.replacedAt > 0
      ? DateFormat.yMMMd().add_jm().format(
          DateTime.fromMillisecondsSinceEpoch(marker.replacedAt),
        )
      : '?';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.settings_cloudSync_adopt_dialogTitle),
      content: Text(
        l10n.settings_cloudSync_adopt_dialogContent(marker.displayName, date),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.settings_cloudSync_adopt_notNow),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.settings_cloudSync_adopt_confirm),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  // A safety backup followed by a whole-library download runs for minutes on a
  // large library. Both used to happen behind a live page, so the user saw
  // nothing and their phone was free to lock mid-adopt (issue #1194).
  await runWithSyncMaintenanceProgress<void>(
    context: context,
    title: l10n.settings_cloudSync_adopt_progressTitle,
    task: (report) async {
      // Safety backup of this device's current data BEFORE it is overwritten.
      report(0, 0, l10n.settings_syncMaintenance_phase_backingUp);
      await ref.read(backupServiceProvider).performBackup(isAutomatic: true);
      report(0, 0, l10n.settings_syncMaintenance_phase_applyingLibrary);
      await ref.read(syncStateProvider.notifier).adoptReplacedLibrary();
    },
  );
}
