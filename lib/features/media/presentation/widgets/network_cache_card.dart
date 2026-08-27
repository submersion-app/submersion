// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3c.md`
// Task 8. The widget reads `cacheSizeProvider` from the Phase 3c Task 5
// providers file and exposes a confirmation dialog before invoking
// `CachedNetworkImageDiagnostics.clearCache()`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              context.l10n.media_cache_cardTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sd_storage_outlined),
            title: Text(context.l10n.media_cache_diskCache),
            subtitle: asyncSize.when(
              loading: () => Text(context.l10n.media_cache_calculating),
              error: (e, _) => Text(context.l10n.media_cache_error('$e')),
              data: (bytes) => Text(_formatBytes(bytes)),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(context.l10n.media_cache_clearAction),
            onTap: () => _confirmAndClear(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndClear(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.media_cache_clearTitle),
        content: Text(dialogContext.l10n.media_cache_clearBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.media_cache_clearConfirm),
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
        SnackBar(content: Text(context.l10n.media_cache_cleared)),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.media_cache_clearError('$e'))),
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
