import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/byte_format.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/providers/cross_device_retention_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_actions.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_choice_dialog.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_encryption_section.dart';
import 'package:submersion/features/backup/presentation/widgets/cross_device_retention_actions.dart';
import 'package:submersion/features/backup/presentation/widgets/quarantined_databases_section.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_section_helpers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

/// The controls a diver rarely needs, each with its page and dialogs
/// unchanged (spec section 8.2): how many backups to keep, the backup
/// folder on this device, saving a backup file, password protection and
/// set-aside databases.
class BackupAdvancedSection extends ConsumerWidget {
  const BackupAdvancedSection({super.key});

  static const retentionChoices = [5, 10, 15, 20, 30];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(backupSettingsProvider);
    final notifier = ref.read(backupSettingsProvider.notifier);
    final busy =
        ref.watch(backupOperationProvider).status ==
        BackupOperationStatus.inProgress;
    final folder = settings.backupLocation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: buildSettingsSectionHeader(
            context,
            l10n.settings_data_header_advanced,
          ),
        ),
        ListTile(
          // A new number waits until a cross-device change in flight ends.
          enabled: !ref.watch(crossDeviceRetentionBusyProvider),
          leading: const Icon(Icons.layers_outlined),
          title: Text(l10n.settings_backups_keepLast(settings.retentionCount)),
          subtitle: const _RetentionSubtitle(),
          onTap: () async {
            final picked = await showBackupChoiceDialog(
              context,
              title: l10n.backup_schedule_retention,
              values: retentionChoices,
              selected: settings.retentionCount,
              label: (n) => '$n',
            );
            if (picked != null && context.mounted) {
              await changeRetentionCount(context, ref, picked);
            }
          },
        ),
        if (ref.watch(crossDeviceRetentionAvailableProvider))
          const _CrossDeviceRetentionTile(),
        ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: Text(l10n.settings_backups_folder),
          subtitle: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notifier.locationLabel ??
                    folder ??
                    l10n.backup_location_default,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Wrap(
                spacing: 16,
                children: [
                  TileSubtitleAction(
                    actionKey: const Key('backup-folder-change'),
                    onPressed: () => pickBackupFolder(context, ref),
                    label: l10n.backup_location_change,
                  ),
                  if (folder != null)
                    TileSubtitleAction(
                      onPressed: notifier.useDefaultBackupLocation,
                      label: l10n.settings_backups_useDefault,
                    ),
                ],
              ),
            ],
          ),
          isThreeLine: true,
        ),
        // Builder so the iPad share popover anchors to this tile.
        Builder(
          builder: (tileContext) => ListTile(
            leading: const Icon(Icons.save_alt),
            title: Text(l10n.settings_backups_saveFile),
            enabled: !busy,
            onTap: () => saveBackupFile(tileContext, ref),
          ),
        ),
        const BackupEncryptionSection(),
        // Renders nothing when a restore set nothing aside (issue #1923).
        const QuarantinedDatabasesSection(),
      ],
    );
  }
}

/// The retention explanation plus what the retained backups cost, so the
/// count is chosen knowing that every backup is a full copy of the database
/// (issue #1376).
class _RetentionSubtitle extends ConsumerWidget {
  const _RetentionSubtitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final history = ref.watch(backupHistoryProvider).value;
    final explanation = Text(l10n.backup_schedule_retention_subtitle);
    // With the switch on the number governs the cloud folder, so the cost
    // shown is the folder's: the rows its listing showed (issue #3503).
    final acrossDevices =
        ref.watch(crossDeviceRetentionActiveProvider).value ?? false;
    final String? footprint;
    if (acrossDevices) {
      final listed = [...?history?.where((r) => r.cloudCopyListed)];
      footprint = listed.isEmpty
          ? null
          : l10n.backup_retention_cloudFootprint(
              listed.length,
              formatBytes(listed.fold<int>(0, (sum, r) => sum + r.sizeBytes)),
            );
    } else {
      footprint = history == null || history.isEmpty
          ? null
          : l10n.backup_schedule_retention_footprint(
              history.length,
              formatBytes(history.fold<int>(0, (sum, r) => sum + r.sizeBytes)),
            );
    }
    if (footprint == null) return explanation;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        explanation,
        Text(footprint, key: const ValueKey('backup_retention_footprint')),
      ],
    );
  }
}

/// "Count backups from all devices" (issue #3503): off by default, and on
/// only for the cloud folder it was confirmed for. Disabled while a change
/// is still listing, asking or pruning, so a second tap cannot start
/// another.
class _CrossDeviceRetentionTile extends ConsumerWidget {
  const _CrossDeviceRetentionTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final on = ref.watch(crossDeviceRetentionActiveProvider).value ?? false;
    final busy = ref.watch(crossDeviceRetentionBusyProvider);
    final keep = ref.watch(
      backupSettingsProvider.select((s) => s.retentionCount),
    );
    return SwitchListTile(
      secondary: const Icon(Icons.devices_outlined),
      title: Text(l10n.backup_retention_allDevices_title),
      subtitle: Text(
        on
            ? l10n.backup_retention_allDevices_on(keep)
            : l10n.backup_retention_allDevices_off,
      ),
      value: on,
      onChanged: busy
          ? null
          : (value) => setCrossDeviceRetention(context, ref, value),
    );
  }
}
