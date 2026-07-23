import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Queue visibility (design spec section 9): active, waiting, and failed
/// transfers with per-entry retry and a clear-completed action.
class TransfersPage extends ConsumerWidget {
  const TransfersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final entries = ref.watch(mediaTransferEntriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings_mediaStorage_transfers_title),
        actions: [
          IconButton(
            key: const Key('transfers-clear-done'),
            tooltip: l10n.settings_mediaStorage_transfers_clearCompleted,
            icon: const Icon(Icons.clear_all),
            onPressed: () =>
                ref.read(mediaTransferQueueRepositoryProvider).deleteDone(),
          ),
        ],
      ),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) => rows.isEmpty
            ? Center(child: Text(l10n.settings_mediaStorage_transfers_empty))
            : ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    _TransferTile(entry: rows[index]),
              ),
      ),
    );
  }
}

class _TransferTile extends ConsumerWidget {
  const _TransferTile({required this.entry});

  final MediaTransferQueueEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final (icon, label) = switch (entry.state) {
      'transferring' => (
        Icons.cloud_upload,
        l10n.settings_mediaStorage_transfers_state_transferring,
      ),
      'failed' => (
        Icons.error_outline,
        l10n.settings_mediaStorage_transfers_state_failed,
      ),
      'done' => (
        Icons.cloud_done,
        l10n.settings_mediaStorage_transfers_state_done,
      ),
      _ => (Icons.schedule, l10n.settings_mediaStorage_transfers_state_pending),
    };
    return ListTile(
      leading: Icon(
        icon,
        color: entry.state == 'failed'
            ? Theme.of(context).colorScheme.error
            : null,
      ),
      title: Text(label),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entry.errorMessage != null)
            Text(entry.errorMessage!, maxLines: 2)
          else
            Text(entry.mediaId, maxLines: 1),
          if (entry.state == 'transferring')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(
                value:
                    (entry.progressBytes != null &&
                        entry.totalBytes != null &&
                        entry.totalBytes! > 0)
                    ? entry.progressBytes! / entry.totalBytes!
                    : null,
              ),
            ),
        ],
      ),
      // A row that already carries an error can be retried even while it is
      // still 'pending': its automatic backoff can stretch to a day or more
      // (see markFailed's retryAfter), and waiting that out is not something
      // to force on someone who is looking at the failure right now.
      //
      // Restricted to 'pending' on purpose: markTransferring does not clear
      // errorMessage, so an in-flight row can still carry an earlier attempt's
      // error. Offering Retry there would let a tap flip a row the worker is
      // actively uploading back to pending and have it processed twice.
      trailing:
          (entry.state == 'failed' ||
              (entry.state == 'pending' && entry.errorMessage != null))
          ? TextButton(
              onPressed: () => _retry(ref, entry),
              child: Text(l10n.settings_mediaStorage_transfers_retry),
            )
          : null,
    );
  }

  /// An explicit retry must clear the asset-resolution negative cache as well
  /// as the queue row. Resolution records an unresolvable item for 24h/3d/7d
  /// and short-circuits on that record without re-scanning the gallery, so
  /// requeueing alone would drain straight back into the same failure and the
  /// button would appear to do nothing.
  Future<void> _retry(WidgetRef ref, MediaTransferQueueEntry entry) async {
    await ref.read(localAssetCacheRepositoryProvider).clearEntry(entry.mediaId);
    await ref.read(mediaTransferQueueRepositoryProvider).retry(entry.id);
    final runtime = await ref.read(mediaStoreRuntimeProvider.future);
    await runtime?.worker?.drain();
  }
}
