import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_leading.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';

/// Queue visibility (design spec section 9): active, waiting, and failed
/// transfers with per-entry retry and a clear-completed action.
class TransfersPage extends ConsumerStatefulWidget {
  const TransfersPage({super.key});

  @override
  ConsumerState<TransfersPage> createState() => _TransfersPageState();
}

class _TransfersPageState extends ConsumerState<TransfersPage> {
  /// Owns the bulk-selection state machine for this page.
  ///
  /// Queue ids are ints, so they are stringified on the way in and parsed on
  /// the way out; the controller is id-based and type-agnostic.
  final SelectionController _selection = SelectionController();

  bool get _isSelectionMode => _selection.value.isActive;
  Set<String> get _selectedIds => _selection.value.checkedIds;

  /// Retry is safe only for a terminally failed entry. A `transferring` row
  /// must never be retried: the worker still holds it and a requeue would
  /// upload the same asset twice.
  static bool _isRetryable(MediaTransferQueueEntry e) =>
      e.state == 'failed' || (e.state == 'pending' && e.errorMessage != null);

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entries = ref.watch(mediaTransferEntriesProvider);
    final rows = entries.value ?? const <MediaTransferQueueEntry>[];
    final selectableIds = rows.map((e) => e.id.toString()).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selection.pruneTo(selectableIds);
    });

    return SelectableListScope(
      controller: _selection,
      selectableIds: selectableIds,
      child: ValueListenableBuilder<SelectionState>(
        valueListenable: _selection,
        builder: (context, selection, _) => Scaffold(
          appBar: selection.isActive
              ? SelectionAppBar(
                  controller: _selection,
                  selectableIds: selectableIds,
                  actions: [
                    BulkAction(
                      id: 'retry',
                      icon: Icons.refresh,
                      label: l10n.settings_mediaStorage_transfers_retry,
                      isEnabled: (ids) {
                        final checked = rows.where(
                          (e) => ids.contains(e.id.toString()),
                        );
                        return checked.isNotEmpty &&
                            checked.every(_isRetryable);
                      },
                      onInvoke: () => _retrySelected(rows),
                    ),
                  ],
                  shell: SelectionBarShell.appBar,
                  onDelete: () => _confirmAndDelete(rows),
                )
              : AppBar(
                  title: Text(l10n.settings_mediaStorage_transfers_title),
                  actions: [
                    IconButton(
                      key: const ValueKey('enter_selection'),
                      icon: const Icon(Icons.checklist),
                      tooltip: l10n.common_selection_enterTooltip,
                      onPressed: _selection.enterExplicit,
                    ),
                    IconButton(
                      key: const Key('transfers-clear-done'),
                      tooltip:
                          l10n.settings_mediaStorage_transfers_clearCompleted,
                      icon: const Icon(Icons.clear_all),
                      onPressed: () => ref
                          .read(mediaTransferQueueRepositoryProvider)
                          .deleteDone(),
                    ),
                  ],
                ),
          body: entries.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (rows) => rows.isEmpty
                ? Center(
                    child: Text(l10n.settings_mediaStorage_transfers_empty),
                  )
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = rows[index];
                      final tile = _TransferTile(
                        entry: entry,
                        isSelectionMode: _isSelectionMode,
                        isChecked: _selectedIds.contains(entry.id.toString()),
                        onCheckChanged: (_) =>
                            _selection.toggle(entry.id.toString()),
                      );
                      // The tile has no tap handler of its own, so while
                      // selecting the whole row has to toggle -- otherwise
                      // the checkbox is the only target.
                      return _isSelectionMode
                          ? GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  _selection.toggle(entry.id.toString()),
                              child: tile,
                            )
                          : tile;
                    },
                  ),
          ),
        ),
      ),
    );
  }

  /// Retry every checked entry, lifting the per-row retry wholesale -- the
  /// negative-cache clear included, or the requeue drains straight back into
  /// the same failure.
  Future<void> _retrySelected(List<MediaTransferQueueEntry> rows) async {
    final ids = _selectedIds.map(int.parse).toSet();
    final checked = rows.where((e) => ids.contains(e.id)).toList();
    if (checked.isEmpty) return;

    final assetCache = ref.read(localAssetCacheRepositoryProvider);
    final queue = ref.read(mediaTransferQueueRepositoryProvider);
    _selection.exit();

    for (final entry in checked) {
      await assetCache.clearEntry(entry.mediaId);
      await queue.retry(entry.id);
    }
    final runtime = await ref.read(mediaStoreRuntimeProvider.future);
    await runtime?.worker?.drain();
  }

  Future<void> _confirmAndDelete(List<MediaTransferQueueEntry> rows) async {
    final ids = _selectedIds.map(int.parse).toList();
    if (ids.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.common_bulkDelete_title(ids.length)),
        content: Text(ctx.l10n.common_bulkDelete_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(ctx.l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final queue = ref.read(mediaTransferQueueRepositoryProvider);
    _selection.exit();
    for (final id in ids) {
      await queue.delete(id);
    }
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(context.l10n.common_bulkDelete_snackbar(ids.length)),
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
