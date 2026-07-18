import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/lightroom/lightroom_api_client.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/media/data/services/metadata_write_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/lightroom_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/perdix_overlay/draggable_perdix_overlay.dart';
import 'package:submersion/features/media/presentation/widgets/perdix_overlay/perdix_face_resolver.dart';
import 'package:submersion/features/media/presentation/widgets/write_metadata_dialog.dart';
import 'package:submersion/features/media/presentation/widgets/mini_dive_profile_overlay.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Full-screen photo viewer with pinch-to-zoom and swipe navigation.
///
/// Displays photos linked to a dive with metadata overlay showing
/// depth, temperature, and timestamp information.
class PhotoViewerPage extends ConsumerStatefulWidget {
  /// The dive ID for loading related media.
  final String diveId;

  /// The initial media item ID to display.
  final String initialMediaId;

  const PhotoViewerPage({
    super.key,
    required this.diveId,
    required this.initialMediaId,
  });

  @override
  ConsumerState<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends ConsumerState<PhotoViewerPage> {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _showOverlay = true;

  /// Live video controllers hoisted from _VideoItem, keyed by media id, so
  /// the Perdix overlay (mounted at page level) can follow playback. Entries
  /// come and go as gallery pages initialize/dispose.
  final Map<String, VideoPlayerController> _videoControllers = {};

  void _onVideoControllerChanged(
    String mediaId,
    VideoPlayerController? controller,
  ) {
    if (!mounted) return;
    if (controller == null) {
      // The removal path runs from _VideoItemState.dispose, which can fire
      // while the tree is locked (viewer teardown, page eviction). Drop the
      // dead controller immediately so nothing reads it, but defer the
      // rebuild to the next frame.
      _videoControllers.remove(mediaId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() => _videoControllers[mediaId] = controller);
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Set immersive mode for full-screen experience
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(mediaForDiveProvider(widget.diveId));
    final diveAsync = ref.watch(diveProvider(widget.diveId));
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: mediaAsync.when(
        data: (mediaList) {
          if (mediaList.isEmpty) {
            return Center(
              child: Text(
                context.l10n.media_photoViewer_noPhotosAvailable,
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          // Find initial index
          final initialIndex = mediaList.indexWhere(
            (m) => m.id == widget.initialMediaId,
          );
          if (initialIndex != -1 && _pageController.hasClients == false) {
            _currentIndex = initialIndex;
            _pageController = PageController(initialPage: initialIndex);
          }

          final currentItem = mediaList[_currentIndex];
          final enrichment = currentItem.enrichment;

          // Get dive profile for the mini chart overlay
          final diveProfile = diveAsync.whenOrNull(
            data: (dive) => dive?.profile ?? [],
          );

          final dive = diveAsync.value;
          // Same source-aware profile/analysis pairing as the fullscreen
          // profile page: analysis curves are read by index, so the profile
          // passed to the resolver must be the one the analysis was computed
          // over (multi-computer dives).
          final activeSourceId = ref.watch(
            activeDiveSourceProvider(widget.diveId),
          );
          final analysis = ref
              .watch(
                sourceProfileAnalysisProvider((
                  diveId: widget.diveId,
                  sourceId: activeSourceId,
                )),
              )
              .value;
          final sourceProfiles =
              ref.watch(sourceProfilesProvider(widget.diveId)).value ??
              const {};
          final dataSources =
              ref.watch(diveDataSourcesProvider(widget.diveId)).value ??
              const [];
          final gasSwitches =
              ref.watch(gasSwitchesProvider(widget.diveId)).value ?? const [];
          final tankPressures = ref
              .watch(tankPressuresProvider(widget.diveId))
              .value;
          final primarySource =
              dataSources.where((s) => s.isPrimary).firstOrNull ??
              dataSources.firstOrNull;
          final activeSource = activeSourceId == null
              ? primarySource
              : dataSources.where((s) => s.id == activeSourceId).firstOrNull ??
                    primarySource;
          final activeProfile = activeSource == null
              ? null
              : sourceProfiles[activeSource.id];
          final perdixProfile =
              (dataSources.length >= 2 && activeProfile != null)
              ? activeProfile.points
              : dive?.profile ?? const [];
          // Rebuilt only on page-level setState (page swipes, toggles), not
          // per video frame; prefix-max and gas segments precompute here.
          final perdixResolver = PerdixFaceResolver(
            profile: perdixProfile,
            analysis: analysis,
            tanks: dive?.tanks ?? const [],
            gasSwitches: gasSwitches,
            tankPressures: tankPressures,
          );
          final perdixAvailable =
              enrichment?.elapsedSeconds != null &&
              enrichment!.matchConfidence != MatchConfidence.noProfile &&
              perdixResolver.isAvailable;

          return GestureDetector(
            // Swipe down to close (common pattern for fullscreen viewers)
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! > 300) {
                Navigator.of(context).pop();
              }
            },
            child: Stack(
              children: [
                // Photo/video gallery
                _PhotoGallery(
                  mediaList: mediaList,
                  pageController: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  showOverlay: _showOverlay,
                  onToggleOverlay: () =>
                      setState(() => _showOverlay = !_showOverlay),
                  onSetOverlay: (value) => setState(() => _showOverlay = value),
                  onVideoControllerChanged: _onVideoControllerChanged,
                  currentIndex: _currentIndex,
                ),

                // Transparent tap target to toggle overlays (photos only)
                // Videos handle their own tap gestures for play/pause
                if (!currentItem.isVideo)
                  Positioned.fill(
                    child: Semantics(
                      label: context.l10n.media_photoViewer_toggleOverlayLabel,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () =>
                            setState(() => _showOverlay = !_showOverlay),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),

                // Perdix dive computer overlay. Deliberately independent of
                // the _showOverlay chrome (which auto-hides during video
                // playback, exactly when this must stay up) and mounted
                // BELOW it so the toolbar keeps hit-test priority when the
                // chrome is visible (the default corner overlaps the top
                // bar). The face absorbs pointer events over its own bounds
                // (drags move it, taps do nothing); chrome-toggle and video
                // play/pause taps work anywhere outside it.
                if (perdixAvailable && settings.perdixOverlayEnabled)
                  DraggablePerdixOverlay(
                    // Re-key when the persisted seed first arrives so a late
                    // settings load re-seeds the position (same trick as the
                    // fullscreen readout card).
                    key: ValueKey(
                      'perdix-${currentItem.id}-'
                      '${settings.perdixOverlayX}-${settings.perdixOverlayY}',
                    ),
                    resolver: perdixResolver,
                    baseElapsedSeconds: enrichment.elapsedSeconds!,
                    settings: settings,
                    playback: currentItem.isVideo
                        ? _videoControllers[currentItem.id]
                        : null,
                    positionGetter:
                        currentItem.isVideo &&
                            _videoControllers[currentItem.id] != null
                        ? () =>
                              _videoControllers[currentItem.id]
                                  ?.value
                                  .position ??
                              Duration.zero
                        : null,
                    initialFraction:
                        (settings.perdixOverlayX != null &&
                            settings.perdixOverlayY != null)
                        ? Offset(
                            settings.perdixOverlayX!,
                            settings.perdixOverlayY!,
                          )
                        : null,
                    onDragEnd: (fraction) => ref
                        .read(settingsProvider.notifier)
                        .setPerdixOverlayPosition(fraction.dx, fraction.dy),
                  ),

                // Overlay controls (app bar and metadata)
                if (_showOverlay) ...[
                  // Top app bar
                  _TopOverlay(
                    currentIndex: _currentIndex,
                    totalCount: mediaList.length,
                    onClose: () => Navigator.of(context).pop(),
                    onShare: () => _shareCurrentPhoto(currentItem),
                    onWriteMetadata: () => _writeMetadataToPhoto(currentItem),
                    hasEnrichment: enrichment?.depthMeters != null,
                    showPerdixToggle: perdixAvailable,
                    perdixEnabled: settings.perdixOverlayEnabled,
                    onTogglePerdix: () => ref
                        .read(settingsProvider.notifier)
                        .setPerdixOverlayEnabled(
                          !settings.perdixOverlayEnabled,
                        ),
                    onOpenInLightroom: _lightroomWebUrl(currentItem) == null
                        ? null
                        : () => unawaited(
                            launchUrl(
                              Uri.parse(_lightroomWebUrl(currentItem)!),
                              mode: LaunchMode.externalApplication,
                            ),
                          ),
                  ),

                  // Mini dive profile overlay (lower right)
                  if (diveProfile != null &&
                      diveProfile.isNotEmpty &&
                      enrichment?.elapsedSeconds != null)
                    PositionedMiniProfileOverlay(
                      profile: diveProfile,
                      photoElapsedSeconds: enrichment!.elapsedSeconds!,
                      photoDepthMeters: enrichment.depthMeters,
                      settings: settings,
                      visible: _showOverlay,
                    ),

                  // Bottom metadata
                  _BottomMetadataOverlay(
                    item: currentItem,
                    settings: settings,
                    siteName: diveAsync.whenOrNull(
                      data: (dive) => dive?.site?.name,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (error, stack) => Center(
          child: Text(
            context.l10n.media_photoViewer_errorLoadingPhotos(error.toString()),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  /// The lightroom.adobe.com URL for a connector item, or null when the
  /// item is not Lightroom-linked or this device has no connected account
  /// (the catalog id lives only on the connected device).
  String? _lightroomWebUrl(MediaItem item) {
    // Lightroom "Open in Lightroom" action hidden pending Adobe review
    // (lightroomUiEnabled). Returning null here suppresses both the toolbar
    // button and the video-poster overlay, which are gated on this URL.
    if (!lightroomUiEnabled) return null;
    if (item.sourceType != MediaSourceType.serviceConnector ||
        item.remoteAssetId == null) {
      return null;
    }
    final catalogId = ref
        .watch(lightroomAccountProvider)
        .value
        ?.accountIdentifier;
    if (catalogId == null) return null;
    return LightroomApiClient.assetWebUrl(catalogId, item.remoteAssetId!);
  }

  Future<void> _shareCurrentPhoto(MediaItem item) async {
    final l10n = context.l10n;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      final resolvedResult = await ref.read(
        resolvedFullResolutionProvider(item).future,
      );

      if (resolvedResult.isUnavailable || resolvedResult.bytes == null) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        _showError(l10n.media_photoViewer_cannotShare);
        return;
      }

      final bytes = resolvedResult.bytes!;

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final filename = item.originalFilename ?? 'dive_photo.jpg';
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(bytes);

      // Dismiss loading - use rootNavigator to match where showDialog placed the dialog
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      // Share
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'image/jpeg')]),
      );
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showError(l10n.media_photoViewer_failedToShare(e.toString()));
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _writeMetadataToPhoto(MediaItem item) async {
    final l10n = context.l10n;
    debugPrint('[PhotoViewerPage] _writeMetadataToPhoto called');
    if (item.platformAssetId == null) {
      _showError(l10n.media_photoViewer_cannotWriteMetadata);
      return;
    }

    final settings = ref.read(settingsProvider);

    // Get dive site name for the metadata
    final diveAsync = ref.read(diveProvider(widget.diveId));
    String? siteName;
    if (diveAsync.hasValue && diveAsync.value != null) {
      final dive = diveAsync.value!;
      siteName = dive.site?.name;
    }

    // Show confirmation dialog
    debugPrint('[PhotoViewerPage] Showing confirmation dialog...');
    final dialogResult = await showWriteMetadataDialog(
      context: context,
      item: item,
      settings: settings,
      siteName: siteName,
    );

    debugPrint(
      '[PhotoViewerPage] Dialog result: confirmed=${dialogResult.confirmed}',
    );
    if (!dialogResult.confirmed || !mounted) return;

    // Show loading indicator
    debugPrint('[PhotoViewerPage] Showing loading dialog...');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
    debugPrint('[PhotoViewerPage] Loading dialog shown, calling service...');

    try {
      final metadataService = MetadataWriteService();
      final metadata = DiveMediaMetadata.fromMediaItem(
        item,
        siteName: siteName,
      );
      final isVideo = item.mediaType == MediaType.video;

      debugPrint('[PhotoViewerPage] Calling writeMetadata...');
      final success = await metadataService.writeMetadata(
        platformAssetId: item.platformAssetId!,
        metadata: metadata,
        isVideo: isVideo,
        keepOriginal: dialogResult.keepOriginal,
      );
      debugPrint('[PhotoViewerPage] writeMetadata returned: $success');

      // Dismiss loading - use rootNavigator to match where showDialog placed the dialog
      debugPrint('[PhotoViewerPage] Dismissing loading dialog...');
      if (mounted) {
        debugPrint(
          '[PhotoViewerPage] mounted=true, calling pop with rootNavigator...',
        );
        Navigator.of(context, rootNavigator: true).pop();
        debugPrint('[PhotoViewerPage] pop() completed');
      }

      debugPrint('[PhotoViewerPage] About to show success/error message...');
      if (success) {
        debugPrint('[PhotoViewerPage] Calling _showSuccess...');
        _showSuccess(
          isVideo
              ? l10n.media_photoViewer_diveDataWrittenToVideo
              : l10n.media_photoViewer_diveDataWrittenToPhoto,
        );
        debugPrint('[PhotoViewerPage] _showSuccess completed');

        // Invalidate the image cache so the photo reloads with updated metadata
        debugPrint('[PhotoViewerPage] Invalidating asset provider...');
        ref.invalidate(resolvedFullResolutionProvider(item));
      } else {
        _showError(l10n.media_photoViewer_failedToWriteMetadata);
      }
      debugPrint(
        '[PhotoViewerPage] _writeMetadataToPhoto completed successfully',
      );
    } on MetadataWriteException catch (e) {
      debugPrint('[PhotoViewerPage] MetadataWriteException: ${e.message}');
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showError(e.message);
    } catch (e) {
      debugPrint('[PhotoViewerPage] Exception: $e');
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showError(
        l10n.media_photoViewer_failedToWriteMetadataError(e.toString()),
      );
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }
}

/// The photo/video gallery using PhotoView for zoom support on photos.
class _PhotoGallery extends ConsumerWidget {
  final List<MediaItem> mediaList;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final bool showOverlay;
  final VoidCallback onToggleOverlay;
  final ValueChanged<bool> onSetOverlay;
  final void Function(String mediaId, VideoPlayerController? controller)
  onVideoControllerChanged;
  final int currentIndex;

  const _PhotoGallery({
    required this.mediaList,
    required this.pageController,
    required this.onPageChanged,
    required this.showOverlay,
    required this.onToggleOverlay,
    required this.onSetOverlay,
    required this.onVideoControllerChanged,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PhotoViewGallery.builder(
      scrollPhysics: const BouncingScrollPhysics(),
      pageController: pageController,
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
              child: _ConnectorVideoItem(item: item),
            );
          }
          return PhotoViewGalleryPageOptions.customChild(
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.contained, // No zoom for videos
            child: _VideoItem(
              item: item,
              showOverlay: showOverlay,
              onSetOverlay: onSetOverlay,
              onControllerChanged: onVideoControllerChanged,
            ),
          );
        }

        return PhotoViewGalleryPageOptions.customChild(
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3.0,
          child: _PhotoItem(item: item),
        );
      },
      loadingBuilder: (context, event) =>
          const Center(child: CircularProgressIndicator(color: Colors.white54)),
    );
  }
}

/// Individual photo item that loads full-resolution image.
class _PhotoItem extends StatelessWidget {
  final MediaItem item;

  const _PhotoItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return MediaItemView(item: item, fit: BoxFit.contain);
  }
}

/// A Lightroom-linked video: the original is never downloaded (only a poster
/// rendition is stored), so this shows the poster with a play badge that
/// opens the video in Lightroom rather than attempting local playback.
class _ConnectorVideoItem extends ConsumerWidget {
  final MediaItem item;

  const _ConnectorVideoItem({required this.item});

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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Stack(
        alignment: Alignment.center,
        children: [
          MediaItemView(item: item, fit: BoxFit.contain),
          Column(
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
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
              if (url != null) ...[
                const SizedBox(height: 12),
                // Label already voiced by the Semantics button above.
                ExcludeSemantics(
                  child: Text(
                    context.l10n.media_lightroom_openInLightroom,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Video player item that loads and plays video files.
class _VideoItem extends ConsumerStatefulWidget {
  final MediaItem item;
  final bool showOverlay;
  final ValueChanged<bool> onSetOverlay;

  /// Reports the live controller (or null on dispose) so the page can drive
  /// page-level overlays from playback position.
  final void Function(String mediaId, VideoPlayerController? controller)
  onControllerChanged;

  const _VideoItem({
    required this.item,
    required this.showOverlay,
    required this.onSetOverlay,
    required this.onControllerChanged,
  });

  @override
  ConsumerState<_VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends ConsumerState<_VideoItem> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLoading = true;
  String? _error;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  /// Handle keyboard events for video playback
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
      _togglePlayPause();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _initializeVideo() async {
    try {
      final path = await ref.read(resolvedFilePathProvider(widget.item).future);

      if (path == null) {
        setState(() {
          _error = 'videoFileNotFound';
          _isLoading = false;
        });
        return;
      }

      final controller = VideoPlayerController.file(File(path));
      await controller.initialize();

      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isInitialized = true;
        _isLoading = false;
      });
      widget.onControllerChanged(widget.item.id, controller);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'failedToLoadVideo';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    if (_controller != null) {
      // Unregister before disposing so the page never holds a dead
      // controller; guarded by mounted on the page side.
      widget.onControllerChanged(widget.item.id, null);
    }
    _controller?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null) return;

    final wasPlaying = controller.value.isPlaying;

    setState(() {
      if (wasPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });

    // Sync overlay state with play state:
    // - Paused (wasPlaying=true, now paused) → show overlay (true)
    // - Playing (wasPlaying=false, now playing) → hide overlay (false)
    widget.onSetOverlay(wasPlaying);
  }

  String _resolveVideoError(BuildContext context, String errorKey) {
    switch (errorKey) {
      case 'videoNotLinked':
        return context.l10n.media_photoViewer_videoNotLinked;
      case 'videoFileNotFound':
        return context.l10n.media_photoViewer_videoFileNotFound;
      case 'failedToLoadVideo':
        return context.l10n.media_photoViewer_failedToLoadVideo;
      default:
        return errorKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            Text(
              _resolveVideoError(context, _error!),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }

    // Request focus when video is ready to enable keyboard controls
    _focusNode.requestFocus();

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video player - tap anywhere on video to play/pause
          Semantics(
            button: true,
            label: context.l10n.media_photoViewer_playPauseVideoLabel,
            child: GestureDetector(
              onTap: _togglePlayPause,
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          ),

          // Play/pause button overlay (center) - visual indicator only when paused
          if (!controller.value.isPlaying)
            IgnorePointer(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),

          // Video controls overlay (bottom)
          if (widget.showOverlay)
            Positioned(
              left: 0,
              right: 0,
              bottom: 160, // Above the metadata overlay and mini profile
              child: _VideoControlsOverlay(controller: controller),
            ),
        ],
      ),
    );
  }
}

/// Video playback controls with tap-to-seek progress bar and time display.
///
/// Uses tap-to-seek instead of drag-to-seek to avoid gesture conflicts
/// with the PageView's horizontal swipe navigation.
class _VideoControlsOverlay extends StatefulWidget {
  final VideoPlayerController controller;

  const _VideoControlsOverlay({required this.controller});

  @override
  State<_VideoControlsOverlay> createState() => _VideoControlsOverlayState();
}

class _VideoControlsOverlayState extends State<_VideoControlsOverlay> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onVideoUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onVideoUpdate);
    super.dispose();
  }

  void _onVideoUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _seekToPosition(double tapX, double totalWidth) {
    if (totalWidth <= 0) return;

    final progress = (tapX / totalWidth).clamp(0.0, 1.0);
    final duration = widget.controller.value.duration;
    final newPosition = Duration(
      milliseconds: (progress * duration.inMilliseconds).toInt(),
    );
    widget.controller.seekTo(newPosition);
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.controller.value.position;
    final duration = widget.controller.value.duration;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Current time
          SizedBox(
            width: 48,
            child: Text(
              _formatDuration(position),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Tap-to-seek progress bar
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Semantics(
                  label: context.l10n.media_photoViewer_seekVideoLabel,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      _seekToPosition(
                        details.localPosition.dx,
                        constraints.maxWidth,
                      );
                    },
                    child: SizedBox(
                      height: 40, // Larger touch target
                      child: Center(
                        child: Stack(
                          children: [
                            // Background track
                            Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            // Progress track
                            FractionallySizedBox(
                              widthFactor: progress,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            // Thumb indicator
                            Positioned(
                              left: (constraints.maxWidth * progress) - 8,
                              top: -6,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Total time
          SizedBox(
            width: 48,
            child: Text(
              _formatDuration(duration),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Top overlay with close button, page indicator, share, and write metadata.
class _TopOverlay extends StatelessWidget {
  final int currentIndex;
  final int totalCount;
  final VoidCallback onClose;
  final VoidCallback onShare;
  final VoidCallback onWriteMetadata;
  final bool hasEnrichment;

  /// Whether the Perdix overlay toggle is shown (media synced to a profile).
  final bool showPerdixToggle;

  /// Whether the Perdix overlay is currently enabled (tints the icon).
  final bool perdixEnabled;

  final VoidCallback onTogglePerdix;

  /// Non-null only for Lightroom-linked items on the connected device.
  final VoidCallback? onOpenInLightroom;

  const _TopOverlay({
    required this.currentIndex,
    required this.totalCount,
    required this.onClose,
    required this.onShare,
    required this.onWriteMetadata,
    required this.hasEnrichment,
    required this.showPerdixToggle,
    required this.perdixEnabled,
    required this.onTogglePerdix,
    this.onOpenInLightroom,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: context.l10n.media_photoViewer_closeTooltip,
                  onPressed: onClose,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      context.l10n.media_photoViewer_pageIndicator(
                        currentIndex + 1,
                        totalCount,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                // Write metadata button (only shown if photo has dive data)
                if (hasEnrichment)
                  IconButton(
                    icon: const Icon(Icons.edit_note, color: Colors.white),
                    tooltip:
                        context.l10n.media_photoViewer_writeDiveDataTooltip,
                    onPressed: onWriteMetadata,
                  ),
                // Perdix dive computer overlay toggle (only when the media
                // can be synced to the dive profile)
                if (showPerdixToggle)
                  IconButton(
                    icon: Icon(
                      Icons.watch,
                      color: perdixEnabled
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white,
                    ),
                    tooltip: context.l10n.media_perdixOverlay_toggleTooltip,
                    onPressed: onTogglePerdix,
                  ),
                if (onOpenInLightroom != null)
                  IconButton(
                    icon: const Icon(Icons.open_in_new, color: Colors.white),
                    tooltip: context.l10n.media_lightroom_openInLightroom,
                    onPressed: onOpenInLightroom,
                  ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  tooltip: context.l10n.media_photoViewer_shareTooltip,
                  onPressed: onShare,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom overlay showing dive metadata for the current photo.
class _BottomMetadataOverlay extends StatelessWidget {
  final MediaItem item;
  final AppSettings settings;
  final String? siteName;

  const _BottomMetadataOverlay({
    required this.item,
    required this.settings,
    this.siteName,
  });

  @override
  Widget build(BuildContext context) {
    final enrichment = item.enrichment;
    final formatter = UnitFormatter(settings);
    final timeFormat = DateFormat.jm();
    final dateFormat = DateFormat.yMMMd();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Site name
                if (siteName != null && siteName!.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          siteName!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Metadata row
                Row(
                  children: [
                    // Depth
                    if (enrichment?.depthMeters != null) ...[
                      _MetadataChip(
                        icon: Icons.arrow_downward,
                        value: formatter.formatDepth(
                          enrichment!.depthMeters,
                          decimals: 1,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],

                    // Temperature
                    if (enrichment?.temperatureCelsius != null) ...[
                      _MetadataChip(
                        icon: Icons.thermostat,
                        value: formatter.formatTemperature(
                          enrichment!.temperatureCelsius,
                          decimals: 0,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],

                    // Elapsed time
                    if (enrichment?.elapsedSeconds != null) ...[
                      _MetadataChip(
                        icon: Icons.timer_outlined,
                        value: _formatElapsedTime(enrichment!.elapsedSeconds!),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 8),

                // Timestamp row
                Row(
                  children: [
                    Text(
                      '${dateFormat.format(item.takenAt)} at ${timeFormat.format(item.takenAt)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),

                    // Confidence indicator
                    if (enrichment != null &&
                        enrichment.matchConfidence != MatchConfidence.exact &&
                        enrichment.matchConfidence !=
                            MatchConfidence.interpolated) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          enrichment.matchConfidence.displayName,
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatElapsedTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '+$minutes:${secs.toString().padLeft(2, '0')}';
  }
}

/// Small metadata chip with icon and value.
class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String value;

  const _MetadataChip({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
