import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dashboard/presentation/providers/media_ribbon_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/recent_sites_map_card.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// Ribbon tile size in logical pixels.
const double _tileWidth = 128;
const double _tileHeight = 96;

/// Gap between tiles, along the ribbon and between its rows.
const double _tileSpacing = 8;

/// Horizontal ribbon of the newest dive photos and videos.
class MediaRibbonCard extends ConsumerWidget {
  /// How many rows of tiles to stack, for filling the height of a taller
  /// card sharing the row. Honoured only at desktop widths: below the
  /// breakpoint the grid dissolves every pairing into a plain stack, where
  /// extra rows would just make a taller card for nothing.
  final int rows;

  const MediaRibbonCard({this.rows = 1, super.key})
    : assert(rows >= 1, 'a ribbon needs at least one row of tiles');

  /// Opens the full-screen viewer on the item itself, with the rest of its
  /// dive's gallery swipeable alongside it. Pushed on the root navigator
  /// because the dashboard sits inside the shell route, whose bottom nav
  /// would otherwise render over the immersive viewer.
  void _openViewer(BuildContext context, String diveId, String mediaId) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            PhotoViewerPage(diveId: diveId, initialMediaId: mediaId),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(recentMediaProvider);
    final media = mediaAsync.valueOrNull ?? const [];
    if (media.isEmpty) return const SizedBox.shrink();

    // ThumbnailSize reaches PHImageManager (and its Android counterpart) in
    // DEVICE pixels, so a tile-sized request has to be scaled or it lands
    // soft on a 2x/3x screen. Square, like every other tile request in the
    // app, so BoxFit.cover does the cropping here rather than in
    // photo_manager. Even at 3x this is ~0.15 MP against the ~12 MP original
    // the unsized request used to decode.
    final thumbnailTarget = Size.square(
      _tileWidth * MediaQuery.devicePixelRatioOf(context),
    );

    // A pairing only exists at desktop widths; below the breakpoint the card
    // stands alone in a single column and stays the compact one-row ribbon.
    final stacked = rows > 1 && ResponsiveBreakpoints.isDesktop(context);
    // Sized from the map's own constant, so the pair stays aligned if that
    // height ever moves rather than silently drifting apart.
    final contentHeight = stacked ? recentSitesMapHeight : _tileHeight;

    Widget tile(MediaItem item) {
      final diveId = item.diveId;
      return InkWell(
        onTap: diveId == null
            ? null
            : () => _openViewer(context, diveId, item.id),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              MediaItemView(
                item: item,
                thumbnail: true,
                targetSize: thumbnailTarget,
              ),
              // A video thumbnail is just a still frame, so without a badge
              // it is indistinguishable from a photo in the ribbon.
              if (item.isVideo)
                const Positioned(right: 4, bottom: 4, child: _VideoBadge()),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.dashboard_media_title,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: contentHeight,
              child: stacked
                  // Scrolls horizontally like the ribbon it replaces, so
                  // crossAxisCount is the row count and mainAxisExtent the
                  // tile width. Tile height falls out of the fixed content
                  // height, which is what makes the card match its partner.
                  ? GridView.builder(
                      scrollDirection: Axis.horizontal,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: rows,
                        mainAxisExtent: _tileWidth,
                        mainAxisSpacing: _tileSpacing,
                        crossAxisSpacing: _tileSpacing,
                      ),
                      itemCount: media.length,
                      itemBuilder: (context, index) => tile(media[index]),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: media.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: _tileSpacing),
                      itemBuilder: (context, index) => SizedBox(
                        width: _tileWidth,
                        child: tile(media[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Play glyph marking a ribbon tile as a video.
///
/// Drawn on its own scrim rather than tinted onto the thumbnail, because the
/// underlying frame can be any colour and a bare white icon disappears
/// against a bright surface shot.
class _VideoBadge extends StatelessWidget {
  const _VideoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.play_arrow, size: 14, color: Colors.white),
    );
  }
}
