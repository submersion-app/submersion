import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/byte_format.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/backup/data/services/backup_attribution.dart';
import 'package:submersion/features/backup/data/services/orphaned_backup_scan.dart';
import 'package:submersion/features/backup/presentation/providers/unrecognized_backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Backup files sitting in the backups folder that the history has lost track
/// of, and the one place in the app that offers to delete them.
///
/// Reached from the Storage usage page rather than shown inline there, because
/// that page is a measurement surface and this is an irreversible action on
/// what may be the only copy of someone's dive log. The navigation step buys
/// room to say which files are safe to remove and why the rest are not.
///
/// Only [BackupOwnership.thisDevice] entries are selectable. The service
/// re-checks that on the way through, so this widget's job is to avoid
/// offering the choice at all, not to be the thing that enforces it.
class UnrecognizedBackupsPage extends ConsumerStatefulWidget {
  const UnrecognizedBackupsPage({super.key});

  @override
  ConsumerState<UnrecognizedBackupsPage> createState() =>
      _UnrecognizedBackupsPageState();
}

class _UnrecognizedBackupsPageState
    extends ConsumerState<UnrecognizedBackupsPage> {
  /// Selected paths rather than selected entries, so a refresh that returns
  /// equal-but-not-identical entries keeps the user's ticks.
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scan = ref.watch(unrecognizedBackupsProvider);

    // Drop ticks the list no longer offers, before anything reads them. That
    // means gone, and it also means still listed but no longer this device's:
    // a sync reset changes the device id, so the next scan classifies the same
    // file as another device's. Pruning on presence alone would leave it ticked
    // behind a tile that shows "Another device" and no checkbox, with the bar
    // still counting it and a confirm reporting "Freed 0 B" once the service
    // refused it.
    if (scan.valueOrNull case final entries?) {
      final selectable = {
        for (final entry in entries)
          if (entry.isReclaimable) entry.path,
      };
      _selected.removeWhere((path) => !selectable.contains(path));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backup_unrecognized_appBar_title)),
      body: switch (scan) {
        AsyncData(:final value?) when value.isEmpty => _Message(
          l10n.backup_unrecognized_empty,
        ),
        AsyncData(:final value?) => _List(
          entries: value,
          selected: _selected,
          onToggle: (entry, selected) => setState(() {
            if (selected) {
              _selected.add(entry.path);
            } else {
              _selected.remove(entry.path);
            }
          }),
        ),
        // Null, not empty: the folder was never readable.
        AsyncData() => _Message(l10n.backup_unrecognized_unavailable),
        AsyncError() => _Message(l10n.backup_unrecognized_loadFailed),
        _ => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar: switch (scan) {
        AsyncData(:final value?) when value.isNotEmpty => _DeleteBar(
          selection: [
            for (final entry in value)
              if (_selected.contains(entry.path)) entry,
          ],
          onDelete: _confirmAndReclaim,
        ),
        _ => null,
      },
    );
  }

  Future<void> _confirmAndReclaim(List<UnrecognizedBackup> selection) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    // Read before the dialog, alongside the other two. showDialog defaults to
    // the ROOT navigator, so the dialog outlives this page being torn down
    // underneath it, and `ref` on an unmounted element throws StateError. The
    // service is a plain object once resolved, so holding it costs nothing and
    // removes the gap entirely rather than guarding it.
    final service = ref.read(unrecognizedBackupServiceProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backup_unrecognized_confirm_title),
        content: Text(
          l10n.backup_unrecognized_confirm_message(selection.length),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.common_action_delete),
          ),
        ],
      ),
    );
    // Both checked: the user may have said no, and the page may be gone.
    if (confirmed != true || !mounted) return;

    final int freed;
    try {
      freed = await service.reclaim(selection);
    } catch (_) {
      // Reported rather than swallowed: the page would otherwise redraw with
      // the files still listed and no explanation, which reads as the tap
      // having done nothing.
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.backup_unrecognized_deleteFailed)),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(_selected.clear);
    ref.invalidate(unrecognizedBackupsProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.backup_unrecognized_freed(formatBytes(freed))),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

class _List extends StatelessWidget {
  const _List({
    required this.entries,
    required this.selected,
    required this.onToggle,
  });

  final List<UnrecognizedBackup> entries;
  final Set<String> selected;
  final void Function(UnrecognizedBackup entry, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.builder(
      itemCount: entries.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              context.l10n.backup_unrecognized_explanation,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        final entry = entries[index - 1];
        return _BackupTile(
          entry: entry,
          selected: selected.contains(entry.path),
          onToggle: (value) => onToggle(entry, value),
        );
      },
    );
  }
}

class _BackupTile extends ConsumerWidget {
  const _BackupTile({
    required this.entry,
    required this.selected,
    required this.onToggle,
  });

  final UnrecognizedBackup entry;
  final bool selected;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));

    return ListTile(
      title: Text(entry.filename, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        l10n.backup_unrecognized_fileDetail(
          formatBytes(entry.sizeBytes),
          units.formatDateTime(entry.modified, l10n: l10n),
        ),
      ),
      trailing: entry.isReclaimable
          ? Checkbox(
              value: selected,
              onChanged: (value) => onToggle(value ?? false),
            )
          : Text(
              switch (entry.ownership) {
                BackupOwnership.otherDevice =>
                  l10n.backup_unrecognized_ownership_otherDevice,
                _ => l10n.backup_unrecognized_ownership_unattributed,
              },
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      onTap: entry.isReclaimable ? () => onToggle(!selected) : null,
    );
  }
}

class _DeleteBar extends StatelessWidget {
  const _DeleteBar({required this.selection, required this.onDelete});

  final List<UnrecognizedBackup> selection;
  final Future<void> Function(List<UnrecognizedBackup> selection) onDelete;

  @override
  Widget build(BuildContext context) {
    final bytes = selection.fold(0, (sum, entry) => sum + entry.sizeBytes);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: selection.isEmpty ? null : () => onDelete(selection),
            child: Text(
              context.l10n.backup_unrecognized_deleteSelected(
                selection.length,
                formatBytes(bytes),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
