// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3c.md`
// Task 8. The widget reads `cacheSizeProvider` from the Phase 3c Task 5
// providers file and exposes a confirmation dialog before invoking
// `CachedNetworkImageDiagnostics.clearCache()`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';

/// Settings -> Network Sources -> Cache management card.
///
/// Reads `cacheSizeProvider`, displays the size in a human-friendly format,
/// and offers a "Clear cache" action that calls
/// `CachedNetworkImageDiagnostics.clearCache()` and invalidates the size
/// provider so the row refreshes.
class NetworkCacheCard extends ConsumerWidget {
  const NetworkCacheCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSize = ref.watch(cacheSizeProvider);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child:
                // TODO(media): l10n
                Text(
                  'Cache management',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
          ),
          ListTile(
            leading: const Icon(Icons.sd_storage_outlined),
            // TODO(media): l10n
            title: const Text('Disk cache'),
            subtitle: asyncSize.when(
              // TODO(media): l10n
              loading: () => const Text('Calculating cache size…'),
              error: (e, _) => Text('Error: $e'),
              data: (bytes) => Text(_formatBytes(bytes)),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            // TODO(media): l10n
            title: const Text('Clear cache'),
            onTap: () => _confirmAndClear(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndClear(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        // TODO(media): l10n
        title: const Text('Clear network image cache?'),
        content: const Text(
          'Removes downloaded thumbnails and full-size network images. '
          'Linked media rows are kept; images will re-download on next view.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            // TODO(media): l10n
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            // TODO(media): l10n
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final diag = ref.read(cachedNetworkImageDiagnosticsProvider);
    try {
      await diag.clearCache();
      if (!context.mounted) return;
      ref.invalidate(cacheSizeProvider);
      messenger.showSnackBar(
        // TODO(media): l10n
        const SnackBar(content: Text('Cache cleared')),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        // TODO(media): l10n
        SnackBar(content: Text('Clear failed: $e')),
      );
    }
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
