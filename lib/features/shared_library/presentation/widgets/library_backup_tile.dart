import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/shared_library/backup/library_backup_record.dart';
import 'package:submersion/core/utils/byte_format.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where a library backup is kept, in the diver's words.
String libraryBackupPlace(AppLocalizations l10n, LibraryBackupRecord r) =>
    r.localPath != null && r.inStorage
    ? l10n.sharedLibrary_backups_both
    : r.inStorage
    ? l10n.sharedLibrary_backups_inStorage
    : l10n.sharedLibrary_backups_onDevice;

/// One backup of a shared site library (issue #2567): its date, note,
/// sites and size, how it was made and where it is kept, with a pin and a
/// menu for Export, Restore and Delete. Reads [settingsProvider] for the
/// diver's date format.
class LibraryBackupTile extends ConsumerWidget {
  const LibraryBackupTile({
    super.key,
    required this.record,
    required this.onPinToggle,
    required this.onExport,
    required this.onRestore,
    required this.onDelete,
  });

  final LibraryBackupRecord record;
  final VoidCallback onPinToggle;

  /// Gets the tile's context, so the share sheet can anchor on it.
  final void Function(BuildContext context) onExport;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final kind = record.beforeRestore
        ? l10n.sharedLibrary_backups_beforeRestore
        : record.automatic
        ? l10n.sharedLibrary_backups_automatic
        : null;
    final tagStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ListTile(
      leading: const Icon(Icons.inventory_2_outlined),
      title: Text(
        units.formatDateTime(record.createdAt.toLocal(), l10n: l10n),
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (record.note.isNotEmpty)
            Text(
              record.note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          Text(
            l10n.sharedLibrary_backups_summary(
              record.siteCount,
              formatBytes(record.sizeBytes),
            ),
          ),
          Wrap(
            spacing: 12,
            children: [
              if (kind != null) Text(kind, style: tagStyle),
              Text(libraryBackupPlace(l10n, record), style: tagStyle),
            ],
          ),
        ],
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
                ? l10n.sharedLibrary_backups_unpin
                : l10n.sharedLibrary_backups_pin,
            onPressed: onPinToggle,
          ),
          PopupMenuButton<String>(
            onSelected: (action) => switch (action) {
              'export' => onExport(context),
              'restore' => onRestore(),
              _ => onDelete(),
            },
            itemBuilder: (context) => [
              _item(
                'export',
                Icons.ios_share,
                l10n.sharedLibrary_backups_export,
              ),
              _item(
                'restore',
                Icons.restore,
                l10n.sharedLibrary_backups_restore,
              ),
              _item(
                'delete',
                Icons.delete_outline,
                l10n.sharedLibrary_backups_delete,
                color: theme.colorScheme.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static PopupMenuItem<String> _item(
    String value,
    IconData icon,
    String label, {
    Color? color,
  }) => PopupMenuItem(
    value: value,
    child: ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      contentPadding: EdgeInsets.zero,
      dense: true,
    ),
  );
}
