import 'package:flutter/material.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/core/utils/unit_formatter_settings.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/helpers/media_layout_aspect.dart';
import 'package:submersion/features/media/presentation/pages/species_photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_learned_aspect_provider.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/justified_media_block.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grid.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The height the section's rows are packed at (issue #4740).
const double kSpeciesPhotoRowHeight = 150;

/// Between the section's tiles, across and down.
const double kSpeciesPhotoGap = 4;

/// The most rows the section shows before a "+N" tile.
const int kSpeciesPhotoMaxRows = 3;

/// The photos tagged with one species, on the species detail page.
///
/// Laid out in justified rows that keep each photo's shape, each captioned
/// with its dive's date and site, up to [kSpeciesPhotoMaxRows] rows (issue
/// #4740). Either header action is hidden when its callback is null, so the
/// section can be mounted before the flows behind the buttons exist.
class SpeciesPhotosSection extends ConsumerWidget {
  final String speciesId;
  final VoidCallback? onTagPhotos;
  final VoidCallback? onAddPhotos;

  /// Photos a species page's sitting holds to tag or to add at Save (issue
  /// #4527, phase 3), laid out ahead of the stored ones and never hidden by
  /// the row cap.
  final List<MediaItem> pendingItems;

  /// Drawn over each of [pendingItems], such as a button to take it back.
  final Widget Function(MediaItem item)? pendingOverlay;

  /// Marks the section as changed by the sitting, beside its title.
  final Widget? changedMark;

  const SpeciesPhotosSection({
    super.key,
    required this.speciesId,
    this.onTagPhotos,
    this.onAddPhotos,
    this.pendingItems = const [],
    this.pendingOverlay,
    this.changedMark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final entriesAsync = ref.watch(mediaEntriesForSpeciesProvider(speciesId));
    final entries = entriesAsync.value ?? const <MediaLibraryEntry>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.marineLife_speciesPhotos_title(entries.length),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            ?changedMark,
            if (onTagPhotos != null)
              TextButton.icon(
                key: const ValueKey('species_tag_photos'),
                onPressed: onTagPhotos,
                icon: const Icon(Icons.sell_outlined),
                label: Text(l10n.marineLife_speciesPhotos_tagPhotos),
              ),
            // A browser links no new media (issue #4121).
            if (onAddPhotos != null &&
                ref.watch(deviceCapabilitiesProvider).mediaAttach)
              TextButton.icon(
                key: const ValueKey('species_add_photos'),
                onPressed: onAddPhotos,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(l10n.marineLife_speciesPhotos_addPhotos),
              ),
          ],
        ),
        const SizedBox(height: 8),
        entriesAsync.when(
          loading: _loading,
          error: (error, _) => Text(
            '$error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          data: (entries) {
            if (entries.isEmpty && pendingItems.isEmpty) {
              return MediaEmptyState(
                icon: Icons.photo_library_outlined,
                message: l10n.marineLife_speciesPhotos_empty,
              );
            }
            // The first layout waits for the learned shapes, as the library
            // does, so a photo stored sideways never jumps into place.
            final learned = ref.watch(mediaLearnedAspectsProvider).value;
            if (learned == null) return _loading();
            return _rows(context, ref, entries, learned);
          },
        ),
      ],
    );
  }

  static Widget _loading() => const SizedBox(
    height: 80,
    child: Center(child: CircularProgressIndicator()),
  );

  Widget _rows(
    BuildContext context,
    WidgetRef ref,
    List<MediaLibraryEntry> allEntries,
    Map<String, LearnedAspect> learned,
  ) {
    final units = ref.watch(unitFormatterProvider);
    // Save writes a held photo's tag before the sitting lets it go, so for
    // a moment it is in both lists: draw it once, as the held one.
    final heldIds = {for (final item in pendingItems) item.id};
    final entries = [
      for (final e in allEntries)
        if (!heldIds.contains(e.item.id)) e,
    ];
    final items = [...pendingItems, for (final e in entries) e.item];
    return JustifiedMediaBlock(
      ratios: [
        for (final item in items)
          clampMediaAspect(mediaRawAspect(item, learned: learned[item.id])),
      ],
      rowHeight: kSpeciesPhotoRowHeight,
      gap: kSpeciesPhotoGap,
      maxRows: kSpeciesPhotoMaxRows,
      keepAtLeast: pendingItems.length,
      cellBuilder: (context, cell) {
        final item = items[cell.index];
        final stored = cell.index - pendingItems.length;
        final caption = stored < 0 ? null : _caption(units, entries[stored]);
        // The cap never hides a pending photo, so the first hidden item is
        // always a stored one.
        final firstHidden = cell.hiddenCount > 0
            ? entries[cell.index + 1 - pendingItems.length].item.id
            : null;
        return _SpeciesPhotoTile(
          key: ValueKey('species_photo_${item.id}'),
          item: item,
          settings: units.settings,
          cellSize: cell.size,
          caption: caption,
          hiddenCount: cell.hiddenCount,
          onTap: stored < 0 ? null : () => _openViewer(context, item.id),
          onTapMore: firstHidden == null
              ? null
              : () => _openViewer(context, firstHidden),
          // A pending photo may never be saved, so it teaches no shape.
          onImageSize: stored < 0
              ? null
              : (size) => ref
                    .read(mediaLearnedAspectsProvider.notifier)
                    .report(item, size),
          overlay: stored < 0 ? pendingOverlay?.call(item) : null,
        );
      },
    );
  }

  /// The dive's date, then its site when it has one; null with no dive.
  static String? _caption(UnitFormatter units, MediaLibraryEntry entry) {
    final date = entry.diveDateTime;
    if (date == null) return null;
    final site = entry.siteName;
    final formatted = units.formatDate(date);
    return site == null || site.isEmpty ? formatted : '$formatted · $site';
  }

  void _openViewer(BuildContext context, String mediaId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => SpeciesPhotoViewerPage(
          speciesId: speciesId,
          initialMediaId: mediaId,
        ),
      ),
    );
  }
}

/// One tile of the section: the thumbnail, its caption bar, and on the
/// last tile shown the "+N" for the photos the cap left out.
class _SpeciesPhotoTile extends StatelessWidget {
  const _SpeciesPhotoTile({
    super.key,
    required this.item,
    required this.settings,
    required this.cellSize,
    required this.caption,
    required this.hiddenCount,
    required this.onTap,
    required this.onTapMore,
    required this.onImageSize,
    required this.overlay,
  });

  final MediaItem item;
  final UnitFormatterSettings settings;
  final Size cellSize;
  final String? caption;
  final int hiddenCount;
  final VoidCallback? onTap;
  final VoidCallback? onTapMore;
  final ValueChanged<Size>? onImageSize;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final caption = this.caption;
    final label = l10n.marineLife_speciesPhotos_thumbnailLabel;
    final thumbnail = Stack(
      fit: StackFit.expand,
      children: [
        MediaThumbnailTile(
          item: item,
          settings: settings,
          isSelectionMode: false,
          isSelected: false,
          semanticsLabel: caption == null ? label : '$label, $caption',
          targetSize: mediaThumbnailDecodeTarget(cellSize),
          onImageSize: onImageSize,
        ),
        // Below the library's detail width a caption would show only an
        // ellipsis; the label above still carries it.
        if (caption != null && cellSize.width >= kMediaTileDetailWidth)
          _CaptionBar(
            key: ValueKey('species_photo_caption_${item.id}'),
            text: caption,
          ),
      ],
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Under a "+N" the photo is only a backdrop: the count is the one
          // control a screen reader reaches there.
          ExcludeSemantics(
            excluding: hiddenCount > 0,
            child: onTap == null
                ? thumbnail
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    child: thumbnail,
                  ),
          ),
          if (hiddenCount > 0)
            _MoreOverlay(count: hiddenCount, onTap: onTapMore),
          ?overlay,
        ],
      ),
    );
  }
}

/// The dive's date and site along the bottom of a tile, on a fade that
/// keeps it legible over a bright photo in either theme.
class _CaptionBar extends StatelessWidget {
  const _CaptionBar({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0),
                Colors.black.withValues(alpha: 0.6),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 12, 6, 4),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dims the last tile shown and counts the photos past it.
class _MoreOverlay extends StatelessWidget {
  const _MoreOverlay({required this.count, required this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.marineLife_speciesPhotos_moreLabel(count),
      // excludeSemantics drops the detector's own tap action, so the node
      // carries it.
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.all(4),
            // A tall photo can leave the last tile narrower than a
            // three-digit count: scale it down rather than wrap it.
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '+$count',
                  maxLines: 1,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
