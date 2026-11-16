part of 'media_viewer_page.dart';

/// The photo/video gallery using PhotoView for zoom support on photos.
class _PhotoGallery extends ConsumerWidget {
  final List<MediaItem> mediaList;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final bool showOverlay;

  /// The viewer's fullscreen mode, passed on to video pages.
  final bool fullscreen;

  /// A tap on a Lightroom-linked video in fullscreen, which has no player of
  /// its own to report play/pause.
  final VoidCallback onFullscreenTap;
  final ValueChanged<bool> onSetOverlay;

  /// A video's controls bar asks for its controls to be held up, or lets
  /// them go.
  final void Function(VideoPlayerController video, bool held)
  onVideoHoldChanged;
  final void Function(String mediaId, VideoPlayerController? controller)
  onVideoControllerChanged;
  final int currentIndex;

  /// The viewer's people tag mode (issue #1745).
  final PeopleTagSession people;

  const _PhotoGallery({
    required this.mediaList,
    required this.pageController,
    required this.onPageChanged,
    required this.showOverlay,
    required this.fullscreen,
    required this.onFullscreenTap,
    required this.onSetOverlay,
    required this.onVideoHoldChanged,
    required this.onVideoControllerChanged,
    required this.currentIndex,
    required this.people,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PhotoViewGallery.builder(
      // Tag mode holds the page still, so dragging a box never swipes.
      scrollPhysics: people.active
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      pageController: pageController,
      // Build the page either side of the current one, so the next photo has
      // resolved and decoded before a swipe or arrow press brings it in.
      // Built on demand, it slid in empty and popped in afterwards (#3298).
      // Each page's decode is bounded by MediaItemView, so the extra
      // neighbour costs one viewport-sized bitmap, not an original.
      allowImplicitScrolling: true,
      itemCount: mediaList.length,
      onPageChanged: onPageChanged,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      builder: (context, index) {
        final item = mediaList[index];

        // Videos use custom player, photos use PhotoView
        if (item.isVideo) {
          // Lightroom-linked videos are poster-only (the original is never
          // downloaded), so show the poster with an Open-in-Lightroom play
          // affordance instead of the local player, which would otherwise
          // fail with "video file not found".
          if (item.sourceType == MediaSourceType.serviceConnector) {
            return PhotoViewGalleryPageOptions.customChild(
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.contained,
              child: _ConnectorVideoItem(
                item: item,
                fullscreen: fullscreen,
                showControls: showOverlay,
                onFullscreenTap: onFullscreenTap,
              ),
            );
          }
          return PhotoViewGalleryPageOptions.customChild(
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.contained, // No zoom for videos
            child: _VideoItem(
              item: item,
              isCurrent: index == currentIndex,
              showOverlay: showOverlay,
              fullscreen: fullscreen,
              onSetOverlay: onSetOverlay,
              onHoldChanged: onVideoHoldChanged,
              onControllerChanged: onVideoControllerChanged,
              people: people,
            ),
          );
        }

        return PhotoViewGalleryPageOptions.customChild(
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3.0,
          // Tag mode owns the gestures; a zoom already set stays, and the
          // editor inside the child maps taps through it.
          disableGestures: people.active,
          child: _PhotoItem(item: item, showBoxes: showOverlay, people: people),
        );
      },
      loadingBuilder: (context, event) =>
          const Center(child: CircularProgressIndicator(color: Colors.white54)),
    );
  }
}

/// Individual photo item that loads full-resolution image.
/// [item], from the list the viewer opened with, drawn with the live row's
/// colour adjustment and profile match (issue #3520): one saved since (the
/// panel, Apply to this dive) shows on every page, not only the current
/// one. Only those two: MediaItemView does not resolve the image again for
/// them, so a caption or time pin arriving while the page is open does not
/// reload the photo.
MediaItem _withLiveColor(WidgetRef ref, MediaItem item) {
  final live = ref.watch(mediaByIdProvider(item.id)).value;
  if (live == null) return item;
  return item.copyWith(
    colorAdjustment: live.colorAdjustment,
    enrichment: live.enrichment ?? item.enrichment,
  );
}

class _PhotoItem extends ConsumerWidget {
  final MediaItem item;

  /// Whether the face boxes show: they follow the viewer's controls.
  final bool showBoxes;
  final PeopleTagSession people;

  const _PhotoItem({
    required this.item,
    required this.showBoxes,
    required this.people,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageSize = people.imageSizeOf(item);
    // Inside the PhotoView child, so the boxes zoom with the photo and a
    // tag-mode tap lands in the photo's own coordinates.
    return Stack(
      fit: StackFit.expand,
      children: [
        MediaItemView(
          item: _withLiveColor(ref, item),
          fit: BoxFit.contain,
          showAccessActions: true,
          onImageSize: (size) => people.onImageSize(item.id, size),
        ),
        if (people.active && imageSize != null)
          PeopleTagEditor(
            mediaId: item.id,
            imageSize: imageSize,
            selectedTagId: people.selectedTagId,
            pendingBox: people.pendingBoxFor(item.id),
            canPlace: people.canPlace(item),
            onPlace: (box) => people.onPlace(item, box, null),
            onSelect: people.onSelect,
            onMove: people.onMove,
          )
        else if (!people.active)
          FaceBoxLayer(
            mediaId: item.id,
            imageSize: imageSize,
            visible: showBoxes,
          ),
      ],
    );
  }
}

/// A Lightroom-linked video: the original is never downloaded (only a poster
/// rendition is stored), so this shows the poster with a play badge that
/// opens the video in Lightroom rather than attempting local playback.
class _ConnectorVideoItem extends ConsumerWidget {
  final MediaItem item;

  /// In the viewer's fullscreen mode a tap reveals the exit control rather
  /// than opening Lightroom, and the play badge shows only with the revealed
  /// controls ([showControls]); the badge itself still opens Lightroom.
  final bool fullscreen;
  final bool showControls;
  final VoidCallback? onFullscreenTap;

  const _ConnectorVideoItem({
    required this.item,
    this.fullscreen = false,
    this.showControls = true,
    this.onFullscreenTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogId = ref
        .watch(lightroomAccountProvider)
        .value
        ?.accountIdentifier;
    final url = (catalogId != null && item.remoteAssetId != null)
        ? LightroomApiClient.assetWebUrl(catalogId, item.remoteAssetId!)
        : null;
    // Shared open action: drives both the pointer tap (GestureDetector) and the
    // semantic activation on the labeled play button so screen readers can
    // actually trigger it, not just announce it.
    final onOpen = url == null
        ? null
        : () => unawaited(
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          );
    final badge = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: url != null,
          label: context.l10n.media_lightroom_openInLightroom,
          onTap: onOpen,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
          ),
        ),
        if (url != null) ...[
          const SizedBox(height: 12),
          // Label already voiced by the Semantics button above.
          ExcludeSemantics(
            child: Text(
              context.l10n.media_lightroom_openInLightroom,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
            ),
          ),
        ],
      ],
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: fullscreen ? onFullscreenTap : onOpen,
      child: Stack(
        alignment: Alignment.center,
        children: [
          MediaItemView(item: _withLiveColor(ref, item), fit: BoxFit.contain),
          if (!fullscreen)
            badge
          else if (showControls)
            GestureDetector(onTap: onOpen, child: badge),
        ],
      ),
    );
  }
}
