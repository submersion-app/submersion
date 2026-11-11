import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/gear_photo_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/observation_tag_display.dart';
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

/// Media's Equipment gallery (issue #3355): every photo of the gear the
/// viewing diver can see, identification and check-in photos alike, grouped
/// by item. Gear photos stay out of the ordinary Library views; the
/// Library shows them only when its Attached to filter picks Equipment
/// (issue #4224).
///
/// [onOpenItem] replaces the navigation to an item's page, for tests.
class GearGalleryView extends ConsumerStatefulWidget {
  const GearGalleryView({super.key, this.onOpenItem});

  final void Function(String equipmentId)? onOpenItem;

  @override
  ConsumerState<GearGalleryView> createState() => _GearGalleryViewState();
}

class _GearGalleryViewState extends ConsumerState<GearGalleryView> {
  final SelectionController _selection = SelectionController();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  void _openItem(String equipmentId) {
    final open = widget.onOpenItem;
    if (open != null) {
      open(equipmentId);
    } else {
      context.push('/equipment/$equipmentId');
    }
  }

  /// Opens the viewer on [group], naming each check-in photo's check-in.
  Future<void> _openViewer(GearPhotoGroup group, MediaItem item) async {
    final l10n = context.l10n;
    final units = ref.read(unitFormatterProvider);
    final repository = ref.read(equipmentObservationRepositoryProvider);
    Future<EquipmentObservation?> read(String id) async {
      try {
        return await repository.getById(id);
      } catch (_) {
        // A check-in that cannot be read only loses its caption.
        return null;
      }
    }

    // Read together, not one after another, before the viewer opens.
    final found = await Future.wait([
      for (final id in {for (final m in group.items) ?m.observationId})
        read(id),
    ]);
    final checkIns = {for (final o in found.nonNulls) o.id: o};
    if (!mounted) return;
    openMediaViewer(
      context,
      group.items,
      item.id,
      captionFor: (m) => switch (checkIns[m.observationId]) {
        final o? => l10n.equipment_photos_checkInCaption(
          o.displayTitle(l10n),
          units.formatDate(o.observedAt),
        ),
        null => null,
      },
    );
  }

  Future<BulkActionOutcome> _removeSelected() async {
    final ids = _selection.value.checkedIds.toList();
    if (ids.isEmpty) return BulkActionOutcome.cancelled;
    final l10n = context.l10n;
    final confirmed = await confirmRemoveGearPhotos(context, ids.length);
    if (!confirmed || !mounted) return BulkActionOutcome.cancelled;
    try {
      await ref.read(mediaUnlinkServiceProvider).unlinkFromEquipment(ids);
      ref.invalidate(gearGalleryProvider);
      return BulkActionOutcome.completed;
    } catch (e) {
      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(gearGalleryProvider);
    final allIds = [
      for (final g in groupsAsync.value ?? const <GearPhotoGroup>[])
        for (final m in g.items) m.id,
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _selection.pruneToSettled(
          groupsAsync,
          (groups) => [
            for (final g in groups)
              for (final m in g.items) m.id,
          ],
        );
      }
    });
    return SelectableListScope(
      controller: _selection,
      selectableIds: allIds,
      child: ValueListenableBuilder<SelectionState>(
        valueListenable: _selection,
        builder: (context, selection, _) =>
            _buildBody(context, groupsAsync, selection, allIds),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue<List<GearPhotoGroup>> groupsAsync,
    SelectionState selection,
    List<String> allIds,
  ) {
    final l10n = context.l10n;
    final canAttach = ref.watch(deviceCapabilitiesProvider).mediaAttach;
    final colorScheme = Theme.of(context).colorScheme;
    return groupsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Text(
          l10n.media_diveMediaSection_errorLoading,
          style: TextStyle(color: colorScheme.error),
        ),
      ),
      data: (groups) {
        if (groups.isEmpty) {
          return MediaEmptyState(
            icon: Icons.backpack_outlined,
            message: l10n.media_gearGallery_empty,
          );
        }
        return Column(
          children: [
            if (selection.isActive)
              SelectionAppBar(
                controller: _selection,
                selectableIds: allIds,
                shell: SelectionBarShell.pane,
                onDelete: null,
                actions: [
                  BulkAction(
                    id: 'remove',
                    icon: Icons.link_off,
                    label: l10n.equipment_photos_remove,
                    onInvoke: _removeSelected,
                  ),
                ],
              )
            else if (canAttach)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  key: const ValueKey('enter_selection'),
                  icon: Icon(Icons.checklist, color: colorScheme.primary),
                  tooltip: l10n.common_selection_enterTooltip,
                  onPressed: _selection.enterExplicit,
                ),
              ),
            // Slivers, so only the tiles scrolled into view are built: a
            // diver's gear can hold hundreds of photos.
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        for (final group in groups)
                          _GroupSection(
                            group: group,
                            selection: selection,
                            // Leaving mid-selection would drop the pick.
                            onOpenItem: selection.isActive
                                ? null
                                : () => _openItem(group.equipmentId),
                            onTap: (item) => selection.isActive
                                ? _selection.toggle(item.id)
                                : _openViewer(group, item),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GroupSection extends ConsumerWidget {
  const _GroupSection({
    required this.group,
    required this.selection,
    required this.onOpenItem,
    required this.onTap,
  });

  final GearPhotoGroup group;
  final SelectionState selection;

  /// Opens the item's page; null while selecting, which keeps the header
  /// from leaving the page.
  final VoidCallback? onOpenItem;
  final void Function(MediaItem) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(unitFormatterProvider).settings;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: InkWell(
            onTap: onOpenItem,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      group.name.isEmpty
                          ? l10n.media_library_untitledEquipment
                          : group.name,
                      style: textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.media_gearGallery_count(group.items.length),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (onOpenItem != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 140,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: group.items.length,
          itemBuilder: (context, index) {
            final item = group.items[index];
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
                    semanticsLabel: item.isCheckInPhoto
                        ? l10n.media_gearGallery_checkInBadge
                        : l10n.equipment_photos_photoLabel,
                  ),
                  if (item.isCheckInPhoto)
                    Positioned(
                      key: ValueKey('checkin_badge_${item.id}'),
                      left: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.fact_check_outlined,
                          size: 14,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
