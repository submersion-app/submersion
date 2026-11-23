import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/media/data/services/repair/watched_folder_scanner.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/helpers/media_source_labels.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_watcher_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/demo_mode/presentation/demo_seal_guard.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';

// no-tick: reads watched_roots in the device-local cache database, which no
// sync pull, merge, or repository bulk delete can touch, and which exposes no
// change stream. Its only writer is this device's scanner, and [_refreshRoots]
// below is the invalidation that owes for it.
/// When a watched root was last scanned, memoized per root.
///
/// A `FutureBuilder` built inline would re-issue this query on every
/// rebuild of the tile -- and every scan, add, and remove rebuilds the
/// whole list. Riverpod caches the result per root instead, so the query
/// runs once and re-runs only when something invalidates it.
final watchedRootLastScanProvider = FutureProvider.family<DateTime?, String>(
  (ref, root) => ref.watch(watchedFolderRepositoryProvider).lastScanAt(root),
);

/// Re-reads everything a mutation of the watched set can have changed.
/// Caching the stamps buys a query per rebuild but owes an invalidation:
/// without this a scan would leave the tiles reporting the previous pass.
void _refreshRoots(WidgetRef ref) {
  ref.invalidate(watchedRootsProvider);
  ref.invalidate(watchedRootLastScanProvider);
}

/// The body of the Media section's Sources page (Media section Phase 5,
/// a page of its own since #4587): where media comes from. Browse by source
/// type, and manage the folders the repair watcher keeps an eye on.
class MediaSourcesSectionView extends ConsumerWidget {
  const MediaSourcesSectionView({
    super.key,
    required this.onBrowseSource,
    this.pickFolderOverride,
  });

  /// Called once a source tile has set the Library's filter; the Sources
  /// page closes itself here so the Media section can show that Library.
  final VoidCallback onBrowseSource;

  /// Test seam for the platform directory picker.
  @visibleForTesting
  final Future<String?> Function()? pickFolderOverride;

  Future<void> _addRoot(BuildContext context, WidgetRef ref) async {
    if (!demoSealGuard(context, DemoSealedFeature.mediaImport)) {
      return;
    }
    final path =
        await (pickFolderOverride?.call() ?? FilePicker.getDirectoryPath());
    if (path == null) return;
    await ref.read(watchedFolderRepositoryProvider).addRoot(path);
    _refreshRoots(ref);
  }

  Future<void> _scanNow(BuildContext context, WidgetRef ref) async {
    // The automatic pass swallows failures by design; this one was asked
    // for, so silence would read as "nothing happened".
    WatcherScanReport report;
    try {
      report = await ref.read(watcherScannerProvider).scan(now: DateTime.now());
    } catch (e) {
      // A failed scan can still have stamped some roots before it threw.
      _refreshRoots(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.media_sources_scanFailed)),
      );
      return;
    }
    _refreshRoots(ref);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.media_sources_scanResult(
            report.filesIndexed,
            report.autoRepaired,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(sourceCountsProvider).value ?? const {};
    final roots = ref.watch(watchedRootsProvider).value ?? const [];
    final autoApply = ref.watch(watcherAutoApplyProvider);

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            context.l10n.media_sources_browseHeader,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final MapEntry(:key, :value) in counts.entries)
          ListTile(
            leading: const Icon(Icons.perm_media_outlined),
            title: Text(mediaSourceLabel(context, key)),
            trailing: Text('$value'),
            onTap: () {
              final notifier = ref.read(mediaLibraryFilterProvider.notifier);
              notifier.state = MediaLibraryFilter(sourceType: key);
              onBrowseSource();
            },
          ),
        const Divider(height: 24),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            context.l10n.media_sources_watchedHeader,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final root in roots) _WatchedRootTile(root: root),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.create_new_folder_outlined),
                label: Text(context.l10n.media_sources_addWatched),
                onPressed: () => _addRoot(context, ref),
              ),
              const Spacer(),
              if (roots.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.media_sources_scanNow),
                  onPressed: () => _scanNow(context, ref),
                ),
            ],
          ),
        ),
        SwitchListTile(
          title: Text(context.l10n.media_sources_autoApply),
          value: autoApply,
          onChanged: (value) =>
              ref.read(watcherAutoApplyProvider.notifier).setEnabled(value),
        ),
      ],
    );
  }
}

class _WatchedRootTile extends ConsumerWidget {
  const _WatchedRootTile({required this.root});

  final String root;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stamp = ref.watch(watchedRootLastScanProvider(root)).value;
    final units = ref.watch(unitFormatterProvider);
    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: Text(root, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        stamp == null
            ? context.l10n.media_sources_neverScanned
            : context.l10n.media_sources_lastScanned(
                units.formatDateTime(stamp, l10n: context.l10n),
              ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.clear),
        tooltip: context.l10n.common_action_remove,
        onPressed: () async {
          if (!await _confirmRemove(context) || !context.mounted) return;
          await ref.read(watchedFolderRepositoryProvider).removeRoot(root);
          _refreshRoots(ref);
        },
      ),
    );
  }

  /// Asks before the folder is dropped, with what it forgets (issue #4527,
  /// media library decision 3).
  Future<bool> _confirmRemove(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.media_sources_removeFolderTitle),
        content: Text(l10n.media_sources_removeFolderBody(root)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.common_action_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.common_action_remove),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}
