import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_check_ins_sitting.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_photo_import_helper.dart';
import 'package:submersion/features/equipment/presentation/providers/gear_photo_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_launcher.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';

/// The gear page's Photos card (issue #3355): reference shots of the item
/// itself (the whole item, its serial number label, its markings). Photos
/// that back up a check-in live on that check-in instead.
///
/// One photo can be chosen as the item's cover, which stands for it in the
/// equipment list and the page header.
///
/// It offers nothing that changes the photos outside the open Photos card
/// (issue #4527, phase 3); in the page's sitting ([editing]) photos added
/// and removed and the cover chosen are held until Save, a remove asking
/// nothing, and a closed card shows what a sitting holds ([shown]).
class EquipmentPhotosSection extends ConsumerStatefulWidget {
  const EquipmentPhotosSection({
    super.key,
    required this.equipment,
    this.editing,
    this.shown,
  });

  /// The item as shown: the sitting's while unlocked, so its cover is the
  /// sitting's.
  final EquipmentItem equipment;

  /// The sitting photos are held in: the Photos card's editor.
  final EditSession<EquipmentItem>? editing;

  /// The sitting whose photos a closed card shows.
  final EditSession<EquipmentItem>? shown;

  @override
  ConsumerState<EquipmentPhotosSection> createState() =>
      _EquipmentPhotosSectionState();
}

class _EquipmentPhotosSectionState
    extends ConsumerState<EquipmentPhotosSection> {
  final SelectionController _selection = SelectionController();

  String get _equipmentId => widget.equipment.id;

  /// A browser shows the photos it can and links none (issue #4121).
  bool get _canAttach => ref.watch(deviceCapabilitiesProvider).mediaAttach;

  /// The item's cover: the sitting's while it holds one, since an open
  /// card's [EquipmentPhotosSection.equipment] is the record as it was when
  /// the card opened.
  String? get _coverId => switch (widget.editing ?? widget.shown) {
    final session? => session.valueOf(gearCoverField),
    null => widget.equipment.coverMediaId,
  };

  /// Whether a change may be made: only in the open card.
  bool get _canAct => widget.editing != null;

  Future<void> _addPhotos() async {
    final editing = widget.editing;
    if (editing == null) return;
    await GearPhotoImportHelper.holdPhotos(
      context: context,
      ref: ref,
      equipmentId: _equipmentId,
      // What the sitting unlinks here or on a check-in is gone at Save.
      ignoringMediaIds: {
        ...sittingMedia(editing).unlinked,
        ...checkInPhotoUnlinks(editing),
      },
      // A photo a check-in in the sitting holds is on the item already.
      onHold: (adds) => addMediaToSitting(
        editing,
        photosNotHeld(adds, checkInPhotoKeys(editing)),
      ),
    );
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  Future<BulkActionOutcome> _removeSelected(BuildContext context) async {
    final ids = _selection.value.checkedIds.toList();
    final editing = widget.editing;
    // Outside the open card nothing changes, however the selection was
    // started.
    if (ids.isEmpty || editing == null) return BulkActionOutcome.cancelled;
    // A remove asks nothing: Cancel brings it back. A cover among them is
    // cleared with them, as the unlink does.
    unlinkMediaInSitting(editing, ids.toSet());
    if (ids.contains(editing.valueOf(gearCoverField))) {
      editing.set(gearCoverField, null);
    }
    return BulkActionOutcome.completed;
  }

  /// Chooses the one checked photo as the cover, or clears the cover when
  /// that photo already is it.
  Future<BulkActionOutcome> _toggleCover() async {
    final ids = _selection.value.checkedIds;
    final editing = widget.editing;
    if (ids.length != 1 || editing == null) return BulkActionOutcome.cancelled;
    final id = ids.single;
    editing.set(gearCoverField, _coverId == id ? null : id);
    return BulkActionOutcome.completed;
  }

  @override
  Widget build(BuildContext context) {
    final sitting = widget.editing ?? widget.shown;
    if (sitting == null) return _buildStored(context, null);
    return ListenableBuilder(
      listenable: sitting,
      builder: (context, _) => _buildStored(context, sitting),
    );
  }

  Widget _buildStored(
    BuildContext context,
    EditSession<EquipmentItem>? sitting,
  ) {
    final stored = ref.watch(identificationPhotosProvider(_equipmentId));
    // The sitting's photos: those it unlinked gone, those it added in.
    final photosAsync = sitting == null
        ? stored
        : stored.whenData((rows) => mediaInSitting(sitting, rows));
    final visibleIds =
        photosAsync.value?.map((m) => m.id).toList() ?? const <String>[];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _selection.pruneToSettled(photosAsync, (rows) => rows.map((m) => m.id));
      }
    });
    return SelectableListScope(
      controller: _selection,
      selectableIds: visibleIds,
      child: ValueListenableBuilder<SelectionState>(
        valueListenable: _selection,
        builder: (context, selection, _) =>
            _buildCard(context, photosAsync, selection),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    AsyncValue<List<MediaItem>> photosAsync,
    SelectionState selection,
  ) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final photos = photosAsync.value ?? const <MediaItem>[];
    final coverId = _coverId;
    final singleChecked = selection.checkedIds.length == 1
        ? selection.checkedIds.single
        : null;
    // A cover is a still (issue #3355): a video is never offered, though a
    // cover that is one can still be cleared.
    final checkedItem = photos.where((m) => m.id == singleChecked).firstOrNull;
    final canToggleCover =
        singleChecked != null &&
        (singleChecked == coverId || checkedItem?.mediaType == MediaType.photo);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selection.isActive)
              SelectionAppBar(
                controller: _selection,
                selectableIds: photos.map((m) => m.id).toList(),
                shell: SelectionBarShell.pane,
                onDelete: null,
                actions: [
                  if (_canAct)
                    BulkAction(
                      id: 'remove',
                      icon: Icons.link_off,
                      label: l10n.equipment_photos_remove,
                      onInvoke: () => _removeSelected(context),
                    ),
                  if (canToggleCover && _canAct)
                    BulkAction(
                      id: 'setCover',
                      icon: singleChecked == coverId
                          ? Icons.star
                          : Icons.star_outline,
                      label: singleChecked == coverId
                          ? l10n.equipment_photos_clearCover
                          : l10n.equipment_photos_setCover,
                      maxCount: 1,
                      onInvoke: _toggleCover,
                    ),
                ],
              )
            else
              Row(
                children: [
                  Icon(Icons.photo_library, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.equipment_photos_title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (_canAttach && _canAct && photos.isNotEmpty)
                    IconButton(
                      key: const ValueKey('enter_selection'),
                      icon: Icon(Icons.checklist, color: colorScheme.primary),
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.common_selection_enterTooltip,
                      onPressed: _selection.enterExplicit,
                    ),
                  RecordCardPencil(cardTitle: l10n.equipment_photos_title),
                  if (_canAttach && _canAct)
                    IconButton(
                      key: const ValueKey('equipment_photos_add'),
                      icon: Icon(
                        Icons.add_photo_alternate,
                        color: colorScheme.primary,
                      ),
                      tooltip: l10n.equipment_photos_add,
                      onPressed: _addPhotos,
                    ),
                ],
              ),
            const SizedBox(height: 12),
            photosAsync.when(
              data: (photos) => photos.isEmpty
                  ? MediaEmptyState(
                      icon: Icons.photo_camera_outlined,
                      message: l10n.equipment_photos_empty,
                    )
                  : _PhotoGrid(
                      photos: photos,
                      coverId: coverId,
                      selection: selection,
                      onTap: (item) => selection.isActive
                          ? _selection.toggle(item.id)
                          : openMediaViewer(context, photos, item.id),
                    ),
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, _) => Text(
                l10n.media_diveMediaSection_errorLoading,
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoGrid extends ConsumerWidget {
  const _PhotoGrid({
    required this.photos,
    required this.coverId,
    required this.selection,
    required this.onTap,
  });

  final List<MediaItem> photos;
  final String? coverId;
  final SelectionState selection;
  final void Function(MediaItem) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(unitFormatterProvider).settings;
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final item = photos[index];
        final isCover = item.id == coverId;
        return GestureDetector(
          onTap: () => onTap(item),
          child: Stack(
            fit: StackFit.expand,
            children: [
              MediaThumbnailTile(
                item: item,
                settings: settings,
                isSelectionMode: selection.isActive,
                isSelected: selection.checkedIds.contains(item.id),
                semanticsLabel: isCover
                    ? l10n.equipment_photos_coverLabel
                    : l10n.equipment_photos_photoLabel,
              ),
              if (isCover)
                Positioned(
                  key: ValueKey('cover_badge_${item.id}'),
                  left: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.star,
                      size: 14,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
