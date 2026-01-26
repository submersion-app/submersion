import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/media/data/services/metadata_write_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/widgets/write_metadata_dialog.dart';
import 'package:submersion/features/media/presentation/widgets/mini_dive_profile_overlay.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

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
            return const Center(
              child: Text(
                'No photos available',
                style: TextStyle(color: Colors.white),
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
                // Photo gallery
                _PhotoGallery(
                  mediaList: mediaList,
                  pageController: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                ),

                // Transparent tap target to toggle overlays
                // This sits above the photo but below other overlays
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => setState(() => _showOverlay = !_showOverlay),
                    child: const SizedBox.expand(),
                  ),
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
            'Error loading photos: $error',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Future<void> _shareCurrentPhoto(MediaItem item) async {
    if (item.platformAssetId == null) {
      _showError('Cannot share this photo');
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      final bytes = await ref.read(
        assetFullResolutionProvider(item.platformAssetId!).future,
      );

      if (bytes == null) {
        throw Exception('Could not load image');
      }

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
      _showError('Failed to share: $e');
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
    debugPrint('[PhotoViewerPage] _writeMetadataToPhoto called');
    if (item.platformAssetId == null) {
      _showError('Cannot write metadata - media not linked to library');
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
          isVideo ? 'Dive data written to video' : 'Dive data written to photo',
        );
        debugPrint('[PhotoViewerPage] _showSuccess completed');

        // Invalidate the image cache so the photo reloads with updated metadata
        debugPrint('[PhotoViewerPage] Invalidating asset provider...');
        ref.invalidate(assetFullResolutionProvider(item.platformAssetId!));
      } else {
        _showError('Failed to write metadata');
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
      _showError('Failed to write metadata: $e');
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }
}

/// The photo gallery using PhotoView for zoom support.
class _PhotoGallery extends ConsumerWidget {
  final List<MediaItem> mediaList;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;

  const _PhotoGallery({
    required this.mediaList,
    required this.pageController,
    required this.onPageChanged,
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
class _PhotoItem extends ConsumerWidget {
  final MediaItem item;

  const _PhotoItem({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.platformAssetId == null) {
      return const Center(
        child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
      );
    }

    final imageAsync = ref.watch(
      assetFullResolutionProvider(item.platformAssetId!),
    );

    return imageAsync.when(
      data: (bytes) {
        if (bytes == null) {
          return const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
          );
        }
        return PhotoView(
          imageProvider: MemoryImage(bytes),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3.0,
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          loadingBuilder: (context, event) => const Center(
            child: CircularProgressIndicator(color: Colors.white54),
          ),
          errorBuilder: (context, error, stack) => const Center(
            child: Icon(Icons.error_outline, color: Colors.white54, size: 64),
          ),
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white54)),
      error: (error, stack) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            Text(
              'Failed to load image',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
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

  const _TopOverlay({
    required this.currentIndex,
    required this.totalCount,
    required this.onClose,
    required this.onShare,
    required this.onWriteMetadata,
    required this.hasEnrichment,
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
                  onPressed: onClose,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${currentIndex + 1} / $totalCount',
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
                    tooltip: 'Write dive data to photo',
                    onPressed: onWriteMetadata,
                  ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
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
