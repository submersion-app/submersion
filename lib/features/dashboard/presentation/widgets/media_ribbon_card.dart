import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dashboard/presentation/providers/media_ribbon_providers.dart';
import 'package:submersion/features/media/presentation/pages/photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Ribbon tile size in logical pixels.
const double _tileWidth = 128;
const double _tileHeight = 96;

/// Horizontal ribbon of the newest dive photos and videos.
class MediaRibbonCard extends ConsumerWidget {
  const MediaRibbonCard({super.key});

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
              height: _tileHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: media.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = media[index];
                  final diveId = item.diveId;
                  return InkWell(
                    onTap: diveId == null
                        ? null
                        : () => _openViewer(context, diveId, item.id),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: _tileWidth,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            MediaItemView(
                              item: item,
                              thumbnail: true,
                              targetSize: thumbnailTarget,
                            ),
                            // A video thumbnail is just a still frame, so
                            // without a badge it is indistinguishable from a
                            // photo in the ribbon.
                            if (item.isVideo)
                              const Positioned(
                                right: 4,
                                bottom: 4,
                                child: _VideoBadge(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
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
