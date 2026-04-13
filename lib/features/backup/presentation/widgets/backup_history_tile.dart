import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/features/backup/presentation/widgets/pre_migration_badge.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Renders a single row in the backup history list.
///
/// Pure presentation + callbacks; no Riverpod/provider coupling, so it
/// can be tested in isolation.
class BackupHistoryTile extends StatelessWidget {
  final BackupRecord record;
  final IconData leadingIcon;
  final VoidCallback onPinToggle;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const BackupHistoryTile({
    super.key,
    required this.record,
    required this.leadingIcon,
    required this.onPinToggle,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd().add_jm();

    return ListTile(
      leading: Icon(leadingIcon),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              dateFormat.format(record.timestamp),
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
      subtitle: Text(
        record.type == BackupType.preMigration
            ? context.l10n.backup_history_preMigrationSubtitle(
                record.formattedSize,
              )
            : '${record.diveCount ?? 0} dives, '
                  '${record.siteCount ?? 0} sites - ${record.formattedSize}'
                  '${record.isAutomatic ? ' (auto)' : ''}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
