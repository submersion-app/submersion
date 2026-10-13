import 'dart:io';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/utils/byte_format.dart';
import 'package:submersion/features/settings/presentation/providers/database_reclaim_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Under the database's size on the Storage page: how much of the file is
/// free pages, and a way to have the next launch give them back to the disk
/// (issue #3333). The app also asks for that on its own once enough is
/// free; this is for a diver who wants it sooner. Shows nothing below 1 MB,
/// or when the database cannot be read.
class DatabaseReclaimRow extends ConsumerStatefulWidget {
  /// Whether the app can quit itself to compact now. Mobile apps cannot be
  /// relaunched by themselves, so there it waits for the next open.
  final bool isDesktop;

  /// Test seam for quitting.
  final Future<void> Function()? quitOverride;

  DatabaseReclaimRow({
    super.key,
    bool? isDesktop,
    @visibleForTesting this.quitOverride,
  }) : isDesktop =
           isDesktop ??
           (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  @override
  ConsumerState<DatabaseReclaimRow> createState() => _DatabaseReclaimRowState();
}

class _DatabaseReclaimRowState extends ConsumerState<DatabaseReclaimRow> {
  static const int _minimumShownBytes = 1024 * 1024;

  Future<void> _confirmCompact() async {
    final l10n = context.l10n;
    final prefs = await ref.read(databaseCompactionPrefsProvider.future);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settings_storageUsage_compactTitle),
        content: Text(l10n.settings_storageUsage_compactBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.settings_storageUsage_compact),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await prefs.request();
    if (mounted) setState(() {});
  }

  Future<void> _cancel() async {
    final prefs = await ref.read(databaseCompactionPrefsProvider.future);
    await prefs.decline();
    if (mounted) setState(() {});
  }

  Future<void> _quit() async {
    if (widget.quitOverride case final quit?) return quit();
    // Both databases closed first, as the startup page's close does, so
    // exit does not tear down a worker isolate mid-statement.
    try {
      await DatabaseService.instance.close();
    } catch (_) {}
    try {
      await LocalCacheDatabaseService.instance.close();
    } catch (_) {}
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final space = ref.watch(databaseSpaceProvider).value;
    final prefs = ref.watch(databaseCompactionPrefsProvider).value;
    if (space == null || prefs == null) return const SizedBox.shrink();
    final scheduled = prefs.isRequested;
    // A scheduled compaction always shows, so it can still be cancelled.
    if (!scheduled && space.reclaimableBytes < _minimumShownBytes) {
      return const SizedBox.shrink();
    }
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      key: const ValueKey('database-reclaim-row'),
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(
            scheduled
                ? l10n.settings_storageUsage_compactScheduled
                : l10n.settings_storageUsage_reclaimable(
                    formatBytes(space.reclaimableBytes),
                  ),
            style: muted,
          ),
          if (!scheduled)
            TextButton(
              onPressed: _confirmCompact,
              child: Text(l10n.settings_storageUsage_compact),
            )
          else ...[
            TextButton(
              onPressed: _cancel,
              child: Text(l10n.common_action_cancel),
            ),
            if (widget.isDesktop)
              TextButton(
                onPressed: _quit,
                child: Text(l10n.settings_storageUsage_quitNow),
              ),
          ],
        ],
      ),
    );
  }
}
