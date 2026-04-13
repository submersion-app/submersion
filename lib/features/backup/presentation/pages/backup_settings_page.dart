import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/backup/presentation/pages/restore_complete_page.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_history_tile.dart';
import 'package:submersion/features/backup/presentation/widgets/export_bottom_sheet.dart';
import 'package:submersion/features/backup/presentation/widgets/restore_confirmation_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class BackupSettingsPage extends ConsumerWidget {
  const BackupSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(backupSettingsProvider);
    final operationState = ref.watch(backupOperationProvider);
    ref.listen<BackupOperationState>(backupOperationProvider, (previous, next) {
      if (next.status == BackupOperationStatus.restoreComplete &&
          context.mounted) {
        RestoreCompletePage.show(context);
      }
    });
    final historyAsync = ref.watch(backupHistoryProvider);
    final cloudProvider = ref.watch(cloudStorageProviderProvider);
    final isInProgress =
        operationState.status == BackupOperationStatus.inProgress;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.backup_appBar_title)),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          // Operation status message
          if (operationState.message != null &&
              operationState.status != BackupOperationStatus.idle)
            _buildStatusMessage(context, operationState),
          // Export card
          _buildActionCard(
            context: context,
            icon: Icons.backup,
            title: context.l10n.backup_export_title,
            subtitle: context.l10n.backup_export_subtitle,
            enabled: !isInProgress,
            onTap: () => _handleExport(context, ref),
          ),
          // Import card
          _buildActionCard(
            context: context,
            icon: Icons.restore,
            title: context.l10n.backup_import_title,
            subtitle: context.l10n.backup_import_subtitle,
            enabled: !isInProgress,
            onTap: () => _handleImport(context, ref),
          ),
          const SizedBox(height: 8),
          const Divider(),
          // Auto-backup section
          _buildAutoBackupSection(context, ref, settings, cloudProvider),
          const Divider(),
          // History section
          _buildHistorySection(context, ref, historyAsync),
        ],
      ),
    );
  }

  // ===========================================================================
  // Status Message
  // ===========================================================================

  Widget _buildStatusMessage(BuildContext context, BackupOperationState state) {
    final theme = Theme.of(context);
    Color color;
    switch (state.status) {
      case BackupOperationStatus.error:
        color = theme.colorScheme.error;
      case BackupOperationStatus.success:
      case BackupOperationStatus.restoreComplete:
        color = Colors.green;
      default:
        color = theme.colorScheme.onSurfaceVariant;
    }
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
            child: Text(state.message!, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Action Card
  // ===========================================================================

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Export Handler
  // ===========================================================================

  void _handleExport(BuildContext context, WidgetRef ref) {
    ExportBottomSheet.show(
      context,
      onSaveToFile: () async {
        final result = await FilePicker.saveFile(
          dialogTitle: context.l10n.backup_export_title,
          fileName: _generateDefaultFilename(),
          allowedExtensions: ['db', 'sqlite'],
          type: FileType.custom,
        );
        if (result != null && context.mounted) {
          ref.read(backupOperationProvider.notifier).exportToPath(result);
        }
      },
      onShare: () async {
        final file = await ref
            .read(backupOperationProvider.notifier)
            .exportForSharing();
        if (file != null && context.mounted) {
          await SharePlus.instance.share(
            ShareParams(files: [XFile(file.path)]),
          );
        }
      },
    );
  }

  String _generateDefaultFilename() {
    final now = DateTime.now();
    final formatted =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return 'submersion_backup_$formatted.db';
  }

  // ===========================================================================
  // Import Handler
  // ===========================================================================

  Future<void> _handleImport(BuildContext context, WidgetRef ref) async {
    final FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(type: FileType.any);
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file picker: $e')),
        );
      }
      return;
    }

    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;

    if (!context.mounted) return;

    // Show confirmation dialog with file info
    final file = File(filePath);
    final sizeBytes = await file.length();
    final record = BackupRecord(
      id: 'temp',
      filename: result.files.single.name,
      timestamp: await file.lastModified(),
      sizeBytes: sizeBytes,
      location: BackupLocation.local,
      diveCount: 0,
      siteCount: 0,
    );

    if (!context.mounted) return;

    final confirmed = await RestoreConfirmationDialog.show(
      context,
      record,
      currentSchemaVersion: AppDatabase.currentSchemaVersion,
    );
    if (confirmed) {
      ref.read(backupOperationProvider.notifier).restoreFromFilePath(filePath);
    }
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
    return BackupHistoryTile(
      record: record,
      leadingIcon: _locationIcon(record.location),
      onPinToggle: () => _togglePin(context, ref, record),
      onRestore: () => _handleHistoryAction(context, ref, 'restore', record),
      onDelete: () => _handleHistoryAction(context, ref, 'delete', record),
    );
  }

  // ===========================================================================
  // History Actions
  // ===========================================================================

  Future<void> _togglePin(
    BuildContext context,
    WidgetRef ref,
    BackupRecord record,
  ) async {
    final service = ref.read(backupServiceProvider);
    try {
      if (record.pinned) {
        await service.unpinBackup(record.id);
      } else {
        await service.pinBackup(record.id);
      }
      ref.invalidate(backupHistoryProvider);
    } catch (e, stackTrace) {
      debugPrint('Failed to update pin state: $e\n$stackTrace');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.backup_history_pinError)),
      );
    }
  }

  Future<void> _handleHistoryAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    BackupRecord record,
  ) async {
    switch (action) {
      case 'restore':
        final confirmed = await RestoreConfirmationDialog.show(
          context,
          record,
          currentSchemaVersion: AppDatabase.currentSchemaVersion,
        );
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
  // Auto-backup Section
  // ===========================================================================

  Widget _buildAutoBackupSection(
    BuildContext context,
    WidgetRef ref,
    BackupSettings settings,
    dynamic cloudProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            context.l10n.backup_section_auto,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        SwitchListTile(
          title: Text(context.l10n.backup_schedule_enabled),
          value: settings.enabled,
          onChanged: (value) =>
              ref.read(backupSettingsProvider.notifier).setEnabled(value),
        ),
        // Backup location
        ListTile(
          title: Text(context.l10n.backup_location_title),
          subtitle: Text(
            settings.backupLocation ?? context.l10n.backup_location_default,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: TextButton(
            onPressed: () async {
              final path = await FilePicker.getDirectoryPath(
                dialogTitle: context.l10n.backup_location_title,
              );
              if (path != null) {
                ref
                    .read(backupSettingsProvider.notifier)
                    .setBackupLocation(path);
              }
            },
            child: Text(context.l10n.backup_location_change),
          ),
        ),
        // Frequency
        if (settings.enabled)
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
        // Retention
        if (settings.enabled)
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
        // Cloud sync
        if (cloudProvider != null)
          SwitchListTile(
            title: Text(context.l10n.backup_cloud_enabled),
            subtitle: Text(context.l10n.backup_cloud_enabled_subtitle),
            value: settings.cloudBackupEnabled,
            onChanged: (value) => ref
                .read(backupSettingsProvider.notifier)
                .setCloudBackupEnabled(value),
          ),
        // Backup Now button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  ref.watch(backupOperationProvider).status ==
                      BackupOperationStatus.inProgress
                  ? null
                  : () => ref
                        .read(backupOperationProvider.notifier)
                        .performBackup(),
              icon: const Icon(Icons.backup),
              label: Text(context.l10n.backup_backupNow),
            ),
          ),
        ),
      ],
    );
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
}
