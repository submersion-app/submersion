import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/restore_confirmation_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class BackupSettingsPage extends ConsumerWidget {
  const BackupSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(backupSettingsProvider);
    final operationState = ref.watch(backupOperationProvider);
    final historyAsync = ref.watch(backupHistoryProvider);
    final cloudProvider = ref.watch(cloudStorageProviderProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.backup_appBar_title)),
      body: ListView(
        children: [
          _buildStatusCard(context, ref, settings, operationState),
          const Divider(),
          _buildScheduleSection(context, ref, settings),
          if (cloudProvider != null) ...[
            const Divider(),
            _buildCloudSection(context, ref, settings),
          ],
          const Divider(),
          _buildHistorySection(context, ref, historyAsync),
        ],
      ),
    );
  }

  // ===========================================================================
  // Status Card
  // ===========================================================================

  Widget _buildStatusCard(
    BuildContext context,
    WidgetRef ref,
    BackupSettings settings,
    BackupOperationState operationState,
  ) {
    final theme = Theme.of(context);
    final isInProgress =
        operationState.status == BackupOperationStatus.inProgress;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row
          Row(
            children: [
              _buildStatusIcon(context, settings),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusTitle(context, settings),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getStatusSubtitle(context, settings),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Operation status message
          if (operationState.message != null &&
              operationState.status != BackupOperationStatus.idle)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                operationState.message!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: operationState.status == BackupOperationStatus.error
                      ? theme.colorScheme.error
                      : operationState.status == BackupOperationStatus.success
                      ? Colors.green
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

          // Backup Now button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isInProgress
                  ? null
                  : () => ref
                        .read(backupOperationProvider.notifier)
                        .performBackup(),
              icon: isInProgress
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.backup),
              label: Text(
                isInProgress
                    ? context.l10n.backup_backingUp
                    : context.l10n.backup_backupNow,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context, BackupSettings settings) {
    final theme = Theme.of(context);

    if (!settings.enabled) {
      return Icon(
        Icons.backup_outlined,
        size: 40,
        color: theme.colorScheme.onSurfaceVariant,
      );
    }

    if (settings.lastBackupTime == null) {
      return Icon(
        Icons.warning_amber_rounded,
        size: 40,
        color: Colors.orange.shade700,
      );
    }

    if (settings.isBackupDue) {
      return Icon(
        Icons.warning_amber_rounded,
        size: 40,
        color: Colors.orange.shade700,
      );
    }

    return const Icon(Icons.check_circle, size: 40, color: Colors.green);
  }

  String _getStatusTitle(BuildContext context, BackupSettings settings) {
    if (!settings.enabled) {
      return context.l10n.backup_status_disabled;
    }
    if (settings.lastBackupTime == null) {
      return context.l10n.backup_status_neverBackedUp;
    }
    if (settings.isBackupDue) {
      return context.l10n.backup_status_overdue;
    }
    return context.l10n.backup_status_upToDate;
  }

  String _getStatusSubtitle(BuildContext context, BackupSettings settings) {
    if (settings.lastBackupTime == null) {
      return context.l10n.backup_status_noBackupsYet;
    }
    final formatted = _formatRelativeTime(context, settings.lastBackupTime!);
    return context.l10n.backup_status_lastBackup(formatted);
  }

  // ===========================================================================
  // Schedule Section
  // ===========================================================================

  Widget _buildScheduleSection(
    BuildContext context,
    WidgetRef ref,
    BackupSettings settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            context.l10n.backup_section_schedule,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        SwitchListTile(
          title: Text(context.l10n.backup_schedule_enabled),
          subtitle: Text(context.l10n.backup_schedule_enabled_subtitle),
          value: settings.enabled,
          onChanged: (value) =>
              ref.read(backupSettingsProvider.notifier).setEnabled(value),
        ),
        if (settings.enabled) ...[
          ListTile(
            title: Text(context.l10n.backup_schedule_frequency),
            trailing: DropdownButton<BackupFrequency>(
              value: settings.frequency,
              underline: const SizedBox(),
              onChanged: (value) {
                if (value != null) {
                  ref.read(backupSettingsProvider.notifier).setFrequency(value);
                }
              },
              items: BackupFrequency.values.map((f) {
                return DropdownMenuItem(
                  value: f,
                  child: Text(_frequencyLabel(context, f)),
                );
              }).toList(),
            ),
          ),
          ListTile(
            title: Text(context.l10n.backup_schedule_retention),
            subtitle: Text(context.l10n.backup_schedule_retention_subtitle),
            trailing: DropdownButton<int>(
              value: settings.retentionCount,
              underline: const SizedBox(),
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(backupSettingsProvider.notifier)
                      .setRetentionCount(value);
                }
              },
              items: [5, 10, 15, 20, 30].map((count) {
                return DropdownMenuItem(value: count, child: Text('$count'));
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // Cloud Section
  // ===========================================================================

  Widget _buildCloudSection(
    BuildContext context,
    WidgetRef ref,
    BackupSettings settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            context.l10n.backup_section_cloud,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        SwitchListTile(
          title: Text(context.l10n.backup_cloud_enabled),
          subtitle: Text(context.l10n.backup_cloud_enabled_subtitle),
          value: settings.cloudBackupEnabled,
          onChanged: (value) => ref
              .read(backupSettingsProvider.notifier)
              .setCloudBackupEnabled(value),
        ),
      ],
    );
  }

  // ===========================================================================
  // History Section
  // ===========================================================================

  Widget _buildHistorySection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<BackupRecord>> historyAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            context.l10n.backup_section_history,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        historyAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.l10n.backup_history_error(error.toString()),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          data: (history) {
            if (history.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    context.l10n.backup_history_empty,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }
            return Column(
              children: history
                  .map((record) => _buildHistoryTile(context, ref, record))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHistoryTile(
    BuildContext context,
    WidgetRef ref,
    BackupRecord record,
  ) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd().add_jm();

    return ListTile(
      leading: Icon(_locationIcon(record.location)),
      title: Text(dateFormat.format(record.timestamp)),
      subtitle: Text(
        '${record.diveCount} dives, ${record.siteCount} sites - ${record.formattedSize}'
        '${record.isAutomatic ? ' (auto)' : ''}',
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (action) =>
            _handleHistoryAction(context, ref, action, record),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'restore',
            child: ListTile(
              leading: const Icon(Icons.restore),
              title: Text(context.l10n.backup_history_action_restore),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete, color: theme.colorScheme.error),
              title: Text(
                context.l10n.backup_history_action_delete,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Actions
  // ===========================================================================

  Future<void> _handleHistoryAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    BackupRecord record,
  ) async {
    switch (action) {
      case 'restore':
        final confirmed = await RestoreConfirmationDialog.show(context, record);
        if (confirmed) {
          ref.read(backupOperationProvider.notifier).restoreFromBackup(record);
        }
      case 'delete':
        final confirmed = await _showDeleteConfirmation(context);
        if (confirmed) {
          ref.read(backupOperationProvider.notifier).deleteBackup(record);
        }
    }
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.backup_delete_dialog_title),
        content: Text(context.l10n.backup_delete_dialog_content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.backup_delete_dialog_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.backup_delete_dialog_delete),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  IconData _locationIcon(BackupLocation location) {
    switch (location) {
      case BackupLocation.local:
        return Icons.phone_android;
      case BackupLocation.cloud:
        return Icons.cloud;
      case BackupLocation.both:
        return Icons.cloud_done;
    }
  }

  String _frequencyLabel(BuildContext context, BackupFrequency frequency) {
    switch (frequency) {
      case BackupFrequency.daily:
        return context.l10n.backup_frequency_daily;
      case BackupFrequency.weekly:
        return context.l10n.backup_frequency_weekly;
      case BackupFrequency.monthly:
        return context.l10n.backup_frequency_monthly;
    }
  }

  String _formatRelativeTime(BuildContext context, DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return context.l10n.backup_time_justNow;
    if (diff.inMinutes < 60) {
      return context.l10n.backup_time_minutesAgo(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return context.l10n.backup_time_hoursAgo(diff.inHours);
    }
    return context.l10n.backup_time_daysAgo(diff.inDays);
  }
}
