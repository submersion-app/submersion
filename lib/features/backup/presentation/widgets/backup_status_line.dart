import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/domain/data_health/data_row_status.dart';
import 'package:submersion/features/settings/presentation/providers/data_health_providers.dart';
import 'package:submersion/features/settings/presentation/providers/data_row_status_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/data_row_status_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The backup or restore running now, or the one that just finished.
class BackupOperationMessage extends ConsumerWidget {
  const BackupOperationMessage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(backupOperationProvider);
    final message = state.message;
    if (message == null || state.status == BackupOperationStatus.idle) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final color = switch (state.status) {
      BackupOperationStatus.error => theme.colorScheme.error,
      BackupOperationStatus.success ||
      BackupOperationStatus.restoreComplete => Colors.green,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (state.status == BackupOperationStatus.inProgress)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Expanded(
            child: Text(message, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}

/// What is true of the last backup, in the sentence the Settings > Data row
/// shows (spec section 8.2): where the last backup went, never where the
/// current settings would send the next one.
class BackupStatusLine extends ConsumerWidget {
  const BackupStatusLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(backupSettingsProvider);
    final destination = settings.lastBackupDestination;
    final status = backupsRowStatus(
      health: ref.watch(backupHealthProvider),
      lastBackup: settings.lastBackupTime,
      destination: destination,
      cloudAccountLabel: destination == LastBackupDestination.cloud
          ? ref.watch(lastBackupCloudAccountLabelProvider).value
          : null,
    );
    final failed = status.kind == DataRowStatusKind.backupsFailed;
    final theme = Theme.of(context);
    return ListTile(
      key: const Key('backup-status-line'),
      leading: Icon(
        failed ? Icons.error_outline : Icons.history,
        color: failed ? theme.colorScheme.error : null,
      ),
      title: Text(dataRowStatusText(context.l10n, status, DateTime.now())),
    );
  }
}
