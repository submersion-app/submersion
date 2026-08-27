import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_leading.dart';

/// The transfer queue list: active, waiting, and failed transfers with
/// per-entry retry. Embedded by both the Settings TransfersPage (which adds
/// the app bar, clear-completed action, and bulk selection) and the Media
/// console's Transfers section.
///
/// Selection is owned by the host, not by this widget: the Settings page runs
/// the [SelectionController] behind its [SelectionAppBar] and passes the state
/// down, while the Media console embeds the plain list by omitting these. The
/// tile renders its checkbox in place of the state icon so the row root stays
/// the [ListTile] either way.
class TransfersView extends ConsumerWidget {
  const TransfersView({
    super.key,
    this.isSelectionMode = false,
    this.selectedIds = const {},
    this.onToggle,
  });

  final bool isSelectionMode;
  final Set<String> selectedIds;
  final ValueChanged<String>? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final entries = ref.watch(mediaTransferEntriesProvider);
    return entries.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text('${context.l10n.common_label_error}: $e')),
      data: (rows) => rows.isEmpty
          ? Center(child: Text(l10n.settings_mediaStorage_transfers_empty))
          : ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = rows[index];
                final id = entry.id.toString();
                final tile = _TransferTile(
                  entry: entry,
                  isSelectionMode: isSelectionMode,
                  isChecked: selectedIds.contains(id),
                  onCheckChanged: onToggle == null
                      ? null
                      : (_) => onToggle!(id),
                );
                // The tile has no tap handler of its own, so while selecting
                // the whole row has to toggle -- otherwise the checkbox is
                // the only target.
                return isSelectionMode && onToggle != null
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onToggle!(id),
                        child: tile,
                      )
                    : tile;
              },
            ),
    );
  }
}

class _TransferTile extends ConsumerWidget {
  const _TransferTile({
    required this.entry,
    this.isSelectionMode = false,
    this.isChecked = false,
    this.onCheckChanged,
  });

  final MediaTransferQueueEntry entry;
  final bool isSelectionMode;
  final bool isChecked;
  final ValueChanged<bool>? onCheckChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Delete entries (remote-blob cleanup for deleted media) share the
    // upload lifecycle but read differently: the active label says what is
    // actually happening, and the delete icon replaces every cloud icon so
    // a row never looks like an upload. 'failed' is the deliberate
    // exception - what went wrong outranks which direction it was going, so
    // both directions keep the error icon in the error color.
    final isDelete = entry.direction == 'delete';
    final (icon, label) = switch (entry.state) {
      'transferring' => (
        isDelete ? Icons.delete_outline : Icons.cloud_upload,
        isDelete
            ? l10n.settings_mediaStorage_transfers_state_deleting
            : l10n.settings_mediaStorage_transfers_state_transferring,
      ),
      'failed' => (
        Icons.error_outline,
        l10n.settings_mediaStorage_transfers_state_failed,
      ),
      'done' => (
        isDelete ? Icons.delete_outline : Icons.cloud_done,
        l10n.settings_mediaStorage_transfers_state_done,
      ),
      _ => (
        isDelete ? Icons.delete_outline : Icons.schedule,
        l10n.settings_mediaStorage_transfers_state_pending,
      ),
    };
    return ListTile(
      // The state icon becomes the checkbox in selection mode.
      leading: SelectionLeading(
        isSelectionMode: isSelectionMode,
        isChecked: isChecked,
        onChanged: onCheckChanged,
        child: Icon(
          icon,
          color: entry.state == 'failed'
              ? Theme.of(context).colorScheme.error
              : null,
        ),
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
