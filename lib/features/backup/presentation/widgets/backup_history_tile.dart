import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/backup/data/services/backup_origin.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/features/backup/presentation/widgets/pre_migration_badge.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Renders a single row in the backup history list.
///
/// Presentation + callbacks only. It reads [settingsProvider] so the backup
/// timestamp honours the diver's date and time format preferences, so a
/// `ProviderScope` must be in the tree above it.
class BackupHistoryTile extends ConsumerWidget {
  final BackupRecord record;

  /// The device that made this backup (issue #3651), or null when its name
  /// does not say.
  final BackupOrigin? origin;

  final IconData leadingIcon;
  final VoidCallback onPinToggle;
  final VoidCallback onRestore;

  /// Opens Save and Share for this backup (issue #3650), given this row's
  /// context so the iPad share popover can anchor to the row. Null disables
  /// the item, as while another backup operation runs.
  final ValueChanged<BuildContext>? onShare;
  final VoidCallback onDelete;

  /// False on Windows and Linux, which have no share sheet: the item then
  /// reads "Save a copy".
  final bool shareSheetAvailable;

  const BackupHistoryTile({
    super.key,
    required this.record,
    this.origin,
    required this.leadingIcon,
    required this.onPinToggle,
    required this.onRestore,
    this.onShare,
    required this.onDelete,
    required this.shareSheetAvailable,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final note = record.note;
    final counts = switch (record.type) {
      BackupType.preMigration =>
        context.l10n.backup_history_preMigrationSubtitle(record.formattedSize),
      // Copied from a database this build had already left behind, so it
      // carries no dive or site counts to report (issue #1589).
      BackupType.preDowngrade =>
        context.l10n.backup_history_preDowngradeSubtitle(record.formattedSize),
      // Found in the cloud folder with no record (issue #3214): the counts
      // lived only in the lost record, so claiming "0 dives" would be wrong.
      BackupType.manual
          when record.location == BackupLocation.cloud &&
              record.diveCount == null &&
              record.siteCount == null =>
        context.l10n.backup_history_cloudOnlySubtitle(record.formattedSize),
      // Two messages rather than one plus an appended "(auto)": where the
      // marker belongs in the sentence is the translator's call, not this
      // widget's.
      BackupType.manual =>
        record.isAutomatic
            ? context.l10n.backup_history_manualSubtitleAuto(
                record.diveCount ?? 0,
                record.siteCount ?? 0,
                record.formattedSize,
              )
            : context.l10n.backup_history_manualSubtitle(
                record.diveCount ?? 0,
                record.siteCount ?? 0,
                record.formattedSize,
              ),
    };
    final device = switch (origin) {
      null => null,
      BackupFromThisDevice() => context.l10n.backup_history_device_thisDevice,
      BackupFromNamedDevice(:final name) => name,
      BackupFromAnotherDevice() =>
        context.l10n.backup_history_device_anotherDevice,
    };
    final summary = Text(
      device == null
          ? counts
          : context.l10n.backup_history_subtitleWithDevice(counts, device),
    );

    return ListTile(
      leading: Icon(leadingIcon),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              units.formatDateTime(record.timestamp, l10n: context.l10n),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (record.type == BackupType.preMigration &&
              record.fromSchemaVersion != null &&
              record.toSchemaVersion != null) ...[
            const SizedBox(width: 8),
            PreMigrationBadge(
              fromVersion: record.fromSchemaVersion!,
              toVersion: record.toSchemaVersion!,
            ),
          ],
        ],
      ),
      isThreeLine: note != null,
      subtitle: note == null
          ? summary
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                summary,
              ],
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (record.pinnedOnAnotherDevice)
            // Only the device that pinned it can unpin it (issue #3503).
            IconButton(
              icon: const Icon(Icons.push_pin),
              tooltip: context.l10n.backup_history_pinnedOnAnotherDevice,
              onPressed: null,
            )
          else
            IconButton(
              icon: Icon(
                record.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: record.pinned ? theme.colorScheme.primary : null,
              ),
              tooltip: record.pinned
                  ? context.l10n.backup_history_pinAction_unpin
                  : context.l10n.backup_history_pinAction_pin,
              onPressed: onPinToggle,
            ),
          PopupMenuButton<String>(
            onSelected: (action) {
              switch (action) {
                case 'restore':
                  onRestore();
                case 'share':
                  onShare?.call(context);
                case 'delete':
                  onDelete();
              }
            },
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
                value: 'share',
                enabled: onShare != null,
                child: ListTile(
                  leading: Icon(
                    shareSheetAvailable ? Icons.share : Icons.save_alt,
                  ),
                  title: Text(
                    shareSheetAvailable
                        ? context.l10n.backup_history_action_share
                        : context.l10n.backup_history_action_saveCopy,
                  ),
                  enabled: onShare != null,
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
        ],
      ),
    );
  }
}
