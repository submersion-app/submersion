import 'package:flutter/material.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_photo_import_helper.dart';
import 'package:submersion/features/equipment/presentation/providers/gear_photo_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/gear_photo_remove_dialog.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_launcher.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
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
class EquipmentPhotosSection extends ConsumerStatefulWidget {
  const EquipmentPhotosSection({super.key, required this.equipment});

  final EquipmentItem equipment;

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

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  Future<BulkActionOutcome> _removeSelected(BuildContext context) async {
    final ids = _selection.value.checkedIds.toList();
    if (ids.isEmpty) return BulkActionOutcome.cancelled;
    final l10n = context.l10n;
    final confirmed = await confirmRemoveGearPhotos(context, ids.length);
    if (!confirmed || !context.mounted) {
      return BulkActionOutcome.cancelled;
    }
    try {
      await ref.read(mediaUnlinkServiceProvider).unlinkFromEquipment(ids);
      ref.invalidate(identificationPhotosProvider(_equipmentId));
      return BulkActionOutcome.completed;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.media_siteMediaSection_unlinkError(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return BulkActionOutcome.failed;
    }
  }

  /// Chooses the one checked photo as the cover, or clears the cover when
  /// that photo already is it.
  Future<BulkActionOutcome> _toggleCover() async {
    final ids = _selection.value.checkedIds;
    if (ids.length != 1) return BulkActionOutcome.cancelled;
    final id = ids.single;
    final isCover = widget.equipment.coverMediaId == id;
    try {
      await ref
          .read(gearPhotoRepositoryProvider)
          .setCover(_equipmentId, isCover ? null : id);
    } catch (_) {
      // A concurrent sync can delete the item mid-tap: say the cover did
      // not change rather than failing silently.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.common_error_tryAgain),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return BulkActionOutcome.failed;
    }
    ref.invalidate(equipmentCoverProvider(_equipmentId));
    return BulkActionOutcome.completed;
  }

  @override
  Widget build(BuildContext context) {
    final photosAsync = ref.watch(identificationPhotosProvider(_equipmentId));
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
    final coverId = widget.equipment.coverMediaId;
    final singleChecked = selection.checkedIds.length == 1
        ? selection.checkedIds.single
        : null;

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
                  BulkAction(
                    id: 'remove',
                    icon: Icons.link_off,
                    label: l10n.equipment_photos_remove,
                    onInvoke: () => _removeSelected(context),
                  ),
                  BulkAction(
                    id: 'setCover',
                    icon: singleChecked != null && singleChecked == coverId
                        ? Icons.star
                        : Icons.star_outline,
                    label: singleChecked != null && singleChecked == coverId
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
                  if (_canAttach && photos.isNotEmpty)
                    IconButton(
                      key: const ValueKey('enter_selection'),
                      icon: Icon(Icons.checklist, color: colorScheme.primary),
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.common_selection_enterTooltip,
                      onPressed: _selection.enterExplicit,
                    ),
                  if (_canAttach)
                    IconButton(
                      key: const ValueKey('equipment_photos_add'),
                      icon: Icon(
                        Icons.add_photo_alternate,
                        color: colorScheme.primary,
                      ),
                      tooltip: l10n.equipment_photos_add,
                      onPressed: () => GearPhotoImportHelper.importPhotos(
                        context: context,
                        ref: ref,
                        equipmentId: _equipmentId,
                      ),
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
