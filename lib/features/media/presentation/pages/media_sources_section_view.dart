import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/repair/watched_folder_scanner.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/helpers/media_source_labels.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_watcher_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Counts per source type for the browse list.
final sourceCountsProvider = FutureProvider<Map<MediaSourceType, int>>((
  ref,
) async {
  final repo = ref.watch(mediaLibraryRepositoryProvider);
  ref.invalidateSelfWhen(repo.watchMediaChanges());
  return repo.countBySourceType();
});

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

/// The Sources console section (Media section Phase 5): where media comes
/// from -- browse by source type, and manage the folders the repair watcher
/// keeps an eye on.
class MediaSourcesSectionView extends ConsumerWidget {
  const MediaSourcesSectionView({
    super.key,
    required this.onBrowseSource,
    this.pickFolderOverride,
  });

  /// Switches the console to the Library after the filter is set.
  final VoidCallback onBrowseSource;

  /// Test seam for the platform directory picker.
  @visibleForTesting
  final Future<String?> Function()? pickFolderOverride;

  Future<void> _addRoot(BuildContext context, WidgetRef ref) async {
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
    final locale = Localizations.localeOf(context).toString();

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
        for (final root in roots) _WatchedRootTile(root: root, locale: locale),
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
  const _WatchedRootTile({required this.root, required this.locale});

  final String root;
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stamp = ref.watch(watchedRootLastScanProvider(root)).value;
    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: Text(root, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        stamp == null
            ? context.l10n.media_sources_neverScanned
            : context.l10n.media_sources_lastScanned(
                DateFormat.yMMMd(locale).add_jm().format(stamp),
              ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () async {
          await ref.read(watchedFolderRepositoryProvider).removeRoot(root);
          _refreshRoots(ref);
        },
      ),
    );
  }
}
