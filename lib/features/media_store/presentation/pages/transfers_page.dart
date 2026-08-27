import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/widgets/transfers_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';

/// Queue visibility (design spec section 9): active, waiting, and failed
/// transfers with per-entry retry, a clear-completed action, and bulk
/// selection. The list itself lives in [TransfersView], shared with the Media
/// console; this page owns the selection state and passes it down.
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

  @override
  void initState() {
    super.initState();
    // Opening this page resumes the queue (issue #1270).
    //
    // The dashboard's "N uploads pending" chip pushes straight here, and this
    // route is a plain `builder` nested under media-storage, so
    // MediaStoragePage - whose build resolves the runtime, and which is
    // therefore the app's only reliable drain trigger - never runs on the way
    // in. Someone arriving to ask why nothing is uploading was shown the
    // stuck rows and nothing else.
    //
    // Resolving the runtime IS the kick: see the unawaited worker.drain() at
    // the end of mediaStoreRuntimeProvider. Deliberately a read from
    // initState rather than a watch in build whose value is thrown away - the
    // list's rebuilds have nothing to do with the store's lifecycle, and the
    // intent should not have to be inferred from an unused expression.
    unawaited(ref.read(mediaStoreRuntimeProvider.future));
  }

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
          body: TransfersView(
            isSelectionMode: _isSelectionMode,
            selectedIds: _selectedIds,
            onToggle: _selection.toggle,
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
