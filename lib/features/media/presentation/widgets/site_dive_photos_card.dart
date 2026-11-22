import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/core/utils/unit_formatter_settings.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/helpers/media_layout_aspect.dart';
import 'package:submersion/features/media/presentation/pages/site_media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_learned_aspect_provider.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/justified_media_block.dart';
import 'package:submersion/features/media/presentation/widgets/justified_row_packer.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The height the card's rows aim for (issue #4741).
const double kSiteDivePhotoRowHeight = 100;

/// The space between the card's tiles, across and down (issue #4741).
const double kSiteDivePhotoGap = 4;

/// Site Details card showing photos from the dives logged at the site
/// (issue #4502): one justified row of the newest, flush with the card, and
/// every photo in justified rows on "Show all" (issue #4741). Each photo
/// keeps its shape.
///
/// The page builds it only when [count] is non-zero. The strip reads
/// [recentMediaFromDivesAtSiteProvider], a capped query, so opening the page
/// never loads every photo at the site; the full chronological list is read
/// only once the diver expands the card. Read-only: photos are managed on
/// their dives.
class SiteDivePhotosCard extends ConsumerStatefulWidget {
  final String siteId;

  /// How many media items the site's dives hold, for the title and for
  /// deciding whether "Show all" has anything more to show.
  final int count;

  const SiteDivePhotosCard({
    super.key,
    required this.siteId,
    required this.count,
  });

  @override
  ConsumerState<SiteDivePhotosCard> createState() => _SiteDivePhotosCardState();
}

class _SiteDivePhotosCardState extends ConsumerState<SiteDivePhotosCard> {
  /// Page state only: every visit opens on the strip.
  bool _expanded = false;

  void _open(BuildContext context, MediaItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SiteMediaViewerPage(
          siteId: widget.siteId,
          initialMediaId: item.id,
          scope: SiteViewerScope.divePhotos,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(unitFormatterProvider).settings;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // The first layout waits for the learned shapes, as the library's does,
    // so a photo stored sideways never lays out wide and then jumps. A cache
    // that cannot be read loads as empty, so this never waits for good.
    final learned = ref.watch(mediaLearnedAspectsProvider).value;
    final async = _expanded
        ? ref.watch(flatMediaFromDivesAtSiteProvider(widget.siteId))
        : ref.watch(recentMediaFromDivesAtSiteProvider(widget.siteId));
    final photos = learned == null ? null : async.value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final ratios = photos == null
                ? null
                : mediaLayoutRatios(photos, learned!);
            // The strip shows its first row of what it read, and reads at
            // most the query's cap: anything past either needs Show all.
            final hasMore =
                !_expanded &&
                ratios != null &&
                widget.count > _firstRowCount(ratios, width);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.collections_outlined,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.media_siteDivePhotos_titleWithCount(
                          widget.count,
                        ),
                        style: textTheme.titleMedium,
                      ),
                    ),
                    if (_expanded || hasMore)
                      TextButton(
                        onPressed: () => setState(() => _expanded = !_expanded),
                        child: Text(
                          _expanded
                              ? context.l10n.media_siteDivePhotos_showLess
                              : context.l10n.media_siteDivePhotos_showAll,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _body(context, async, photos, ratios, settings),
              ],
            );
          },
        ),
      ),
    );
  }

  /// How many of [ratios] the strip's one row holds across [width].
  static int _firstRowCount(List<double> ratios, double width) {
    if (ratios.isEmpty || width <= 0) return 0;
    return packJustifiedRows(
      ratios: ratios,
      paneWidth: width,
      targetHeight: kSiteDivePhotoRowHeight,
      gap: kSiteDivePhotoGap,
      minTileWidth: kMediaThumbnailMinTileWidth,
    ).first.count;
  }

  Widget _body(
    BuildContext context,
    AsyncValue<List<MediaItem>> async,
    List<MediaItem>? photos,
    List<double>? ratios,
    UnitFormatterSettings settings,
  ) {
    if (photos != null && ratios != null) {
      return JustifiedMediaBlock(
        ratios: ratios,
        rowHeight: kSiteDivePhotoRowHeight,
        gap: kSiteDivePhotoGap,
        maxRows: _expanded ? null : 1,
        cellBuilder: (context, cell) {
          final item = photos[cell.index];
          return GestureDetector(
            key: ValueKey(item.id),
            onTap: () => _open(context, item),
            child: MediaThumbnailTile(
              item: item,
              settings: settings,
              isSelectionMode: false,
              isSelected: false,
              semanticsLabel:
                  context.l10n.media_siteMediaSection_divePhotoLabel,
              targetSize: mediaThumbnailDecodeTarget(cell.size),
              // Teaches the library a photo's displayed shape, which lays
              // this card out again too.
              onImageSize: (size) => ref
                  .read(mediaLearnedAspectsProvider.notifier)
                  .report(item, size),
            ),
          );
        },
      );
    }
    if (async.hasError) {
      return Text(
        context.l10n.media_diveMediaSection_errorLoading,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.error,
        ),
      );
    }
    return const SizedBox(
      height: kSiteDivePhotoRowHeight,
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
