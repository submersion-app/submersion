import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/core/utils/unit_formatter_settings.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/site_media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Smallest side of a strip tile; the tiles that fit grow to fill the row.
const double _kStripTileMinSize = 88;
const double _kTileGap = 8;

/// Site Details card showing photos from the dives logged at the site
/// (issue #4502): one row of the newest, and the full grid on "Show all".
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final fit = math.max(
              1,
              (width + _kTileGap) ~/ (_kStripTileMinSize + _kTileGap),
            );
            final hasMore = widget.count > fit;
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
                if (_expanded)
                  _AllPhotosGrid(
                    siteId: widget.siteId,
                    settings: settings,
                    onOpen: (item) => _open(context, item),
                  )
                else
                  _RecentPhotosStrip(
                    siteId: widget.siteId,
                    settings: settings,
                    width: width,
                    fit: fit,
                    onOpen: (item) => _open(context, item),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One row of the newest photos: [fit] square tiles sized to fill [width].
class _RecentPhotosStrip extends ConsumerWidget {
  final String siteId;
  final UnitFormatterSettings settings;
  final double width;
  final int fit;
  final ValueChanged<MediaItem> onOpen;

  const _RecentPhotosStrip({
    required this.siteId,
    required this.settings,
    required this.width,
    required this.fit,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tileSize = (width - _kTileGap * (fit - 1)) / fit;
    return _AsyncPhotos(
      async: ref.watch(recentMediaFromDivesAtSiteProvider(siteId)),
      loadingHeight: tileSize,
      builder: (photos) => Row(
        children: [
          for (final (i, item) in photos.take(fit).indexed) ...[
            if (i > 0) const SizedBox(width: _kTileGap),
            SizedBox.square(
              dimension: tileSize,
              child: _PhotoTile(item: item, settings: settings, onOpen: onOpen),
            ),
          ],
        ],
      ),
    );
  }
}

/// Every photo from the site's dives, chronological, as the old Site Media
/// group showed them. Mounted only once the card is expanded.
class _AllPhotosGrid extends ConsumerWidget {
  final String siteId;
  final UnitFormatterSettings settings;
  final ValueChanged<MediaItem> onOpen;

  const _AllPhotosGrid({
    required this.siteId,
    required this.settings,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AsyncPhotos(
      async: ref.watch(flatMediaFromDivesAtSiteProvider(siteId)),
      loadingHeight: 100,
      builder: (photos) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: _kTileGap,
          mainAxisSpacing: _kTileGap,
        ),
        itemCount: photos.length,
        itemBuilder: (context, index) =>
            _PhotoTile(item: photos[index], settings: settings, onOpen: onOpen),
      ),
    );
  }
}

/// Loading and error handling shared by the strip and the grid. A reload
/// that holds its rows keeps showing them.
class _AsyncPhotos extends StatelessWidget {
  final AsyncValue<List<MediaItem>> async;
  final double loadingHeight;
  final Widget Function(List<MediaItem> photos) builder;

  const _AsyncPhotos({
    required this.async,
    required this.loadingHeight,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final photos = async.value;
    if (photos != null) return builder(photos);
    if (async.hasError) {
      return Text(
        context.l10n.media_diveMediaSection_errorLoading,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.error,
        ),
      );
    }
    return SizedBox(
      height: loadingHeight,
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final MediaItem item;
  final UnitFormatterSettings settings;
  final ValueChanged<MediaItem> onOpen;

  const _PhotoTile({
    required this.item,
    required this.settings,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onOpen(item),
      child: MediaThumbnailTile(
        item: item,
        settings: settings,
        isSelectionMode: false,
        isSelected: false,
        semanticsLabel: context.l10n.media_siteMediaSection_divePhotoLabel,
      ),
    );
  }
}
