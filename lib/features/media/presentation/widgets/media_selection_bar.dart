import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/helpers/media_share_helper.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/dive_picker_sheet.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
import 'package:submersion/shared/selection/selection_controller.dart';

/// The library's contextual bar while a selection is active.
///
/// The chrome -- count, close, select all, deselect all, and the overflow --
/// comes from the shared [SelectionAppBar], so the library cannot drift from
/// every other selectable surface. This widget contributes only the
/// media-specific bulk actions and the logic behind them.
class MediaSelectionBar extends ConsumerWidget {
  const MediaSelectionBar({
    super.key,
    required this.controller,
    required this.selectableIds,
    required this.selectedItems,
  });

  /// The library's selection state machine, shared with the view that hosts
  /// this bar.
  final SelectionController controller;

  /// Every id currently on screen, which is what Select All checks.
  final List<String> selectableIds;

  /// The currently selected items, resolved by the caller from the visible
  /// entries so share/unlink operate on real MediaItems.
  final List<MediaItem> selectedItems;

  List<String> get _ids => selectedItems.map((m) => m.id).toList();

  /// The library's one destructive action.
  ///
  /// A dive or a site can unlink from its own side and leave the row alive
  /// for the other one, but the library IS every side at once: unlinking
  /// here clears every link the row has, and a row with no link cannot stay
  /// in the library. So the row, its cloud proxies and its thumbnails go,
  /// and only the original source file is left alone. That single outcome is
  /// why this surface no longer carries an unlink-per-link pair alongside a
  /// separate Delete.
  ///
  /// Routed through the deletion coordinator so the remote-blob delete
  /// intent is enqueued before the rows die (orphan-prevention spec 5.2).
  Future<void> _unlinkSelected(BuildContext context, WidgetRef ref) async {
    final ids = _ids;
    if (ids.isEmpty) return;

    // Everything else an unlink discards is derived and rebuilds from the
    // source file on a re-link. A caption and the favorite flag live only in
    // Submersion's own row, so they are the part worth naming.
    final atRisk = await ref
        .read(mediaRepositoryProvider)
        .idsWithUserMetadata(ids);
    if (!context.mounted) return;

    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.media_library_unlinkConfirmTitle(ids.length)),
        content: Text(
          atRisk.isEmpty
              ? l10n.media_library_unlinkConfirmBody
              : '${l10n.media_library_unlinkConfirmBody}\n\n'
                    '${l10n.media_library_unlinkMetadataNote(atRisk.length)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.media_library_unlinkSelected),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(mediaDeletionCoordinatorProvider).deleteMultipleMedia(ids);
    controller.exit();
  }

  Future<void> _moveToDive(BuildContext context, WidgetRef ref) async {
    final diveId = await showDivePickerSheet(context);
    if (diveId == null) return;
    await ref.read(mediaRepositoryProvider).reassignMediaToDive(_ids, diveId);
    controller.exit();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    // [onDelete] is null and Unlink is an ordinary action because this
    // surface has no control named Delete: unlinking here destroys the rows,
    // but calling it Delete would claim the source files go too, and they do
    // not. The shared bar's safety property is kept by other means --
    // [maxInlineActions] is 2, so the two benign actions hold the inline
    // slots and the destructive one is reached by open-then-choose, the same
    // deliberate gesture the baseline delete entry requires.
    return SelectionAppBar(
      controller: controller,
      selectableIds: selectableIds,
      shell: SelectionBarShell.pane,
      onDelete: null,
      maxInlineActions: 2,
      actions: [
        BulkAction(
          id: 'share',
          icon: Icons.share,
          label: l10n.common_action_share,
          onInvoke: () => shareMediaItems(context, ref, selectedItems),
        ),
        BulkAction(
          id: 'move_to_dive',
          icon: Icons.drive_file_move_outline,
          label: l10n.media_library_moveToDive,
          onInvoke: () => _moveToDive(context, ref),
        ),
        BulkAction(
          id: 'unlink',
          icon: Icons.link_off,
          label: l10n.media_library_unlinkSelected,
          isDestructive: true,
          onInvoke: () => _unlinkSelected(context, ref),
        ),
      ],
    );
  }
}
