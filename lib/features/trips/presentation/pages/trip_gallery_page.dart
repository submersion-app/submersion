import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';

/// Full gallery page showing all photos for a trip, organized by dive.
class TripGalleryPage extends ConsumerWidget {
  final String tripId;
  final String? initialMediaId;

  const TripGalleryPage({super.key, required this.tripId, this.initialMediaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaByDiveAsync = ref.watch(mediaForTripProvider(tripId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Photos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_camera),
            tooltip: 'Scan device gallery',
            onPressed: () => _showScanDialog(context, ref),
          ),
        ],
      ),
      body: mediaByDiveAsync.when(
        data: (mediaByDive) {
          if (mediaByDive.isEmpty) {
            return const _EmptyGallery();
          }
          return _GalleryContent(
            tripId: tripId,
            mediaByDive: mediaByDive,
            initialMediaId: initialMediaId,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Error loading photos: $error')),
      ),
    );
  }

  void _showScanDialog(BuildContext context, WidgetRef ref) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Photo scanning coming soon')));
  }
}

/// Empty state shown when no photos exist for the trip.
class _EmptyGallery extends StatelessWidget {
  const _EmptyGallery();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 80,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No photos in this trip',
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the camera icon to scan your gallery',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Main gallery content showing photos grouped by dive.
class _GalleryContent extends StatelessWidget {
  final String tripId;
  final Map<Dive, List<MediaItem>> mediaByDive;
  final String? initialMediaId;

  const _GalleryContent({
    required this.tripId,
    required this.mediaByDive,
    this.initialMediaId,
  });

  @override
  Widget build(BuildContext context) {
    // Sort dives by date (chronological order)
    final sortedDives = mediaByDive.keys.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDives.length,
      itemBuilder: (context, index) {
        final dive = sortedDives[index];
        final media = mediaByDive[dive] ?? [];
        return _DivePhotoSection(tripId: tripId, dive: dive, media: media);
      },
    );
  }
}

/// ExpansionTile section for photos from a single dive.
class _DivePhotoSection extends StatelessWidget {
  final String tripId;
  final Dive dive;
  final List<MediaItem> media;

  const _DivePhotoSection({
    required this.tripId,
    required this.dive,
    required this.media,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.MMMd();
    final siteName = dive.site?.name ?? 'Unknown Site';
    final diveNumber = dive.diveNumber ?? '-';
    final photoCount = media.length;
    final photoLabel = photoCount == 1 ? 'photo' : 'photos';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text('Dive #$diveNumber - $siteName'),
        subtitle: Text(
          '${dateFormat.format(dive.dateTime)} ($photoCount $photoLabel)',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _PhotoGrid(tripId: tripId, media: media),
          ),
        ],
      ),
    );
  }
}

/// Grid of photo thumbnails.
class _PhotoGrid extends StatelessWidget {
  final String tripId;
  final List<MediaItem> media;

  const _PhotoGrid({required this.tripId, required this.media});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: media.length,
      itemBuilder: (context, index) {
        return _GridThumbnail(tripId: tripId, item: media[index]);
      },
    );
  }
}

/// Individual thumbnail in the grid.
class _GridThumbnail extends ConsumerWidget {
  final String tripId;
  final MediaItem item;

  const _GridThumbnail({required this.tripId, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _openViewer(context, ref),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail or placeholder
            if (item.isOrphaned)
              _buildOrphanedPlaceholder(colorScheme)
            else if (item.platformAssetId != null)
              _buildAssetThumbnail(ref, colorScheme)
            else
              _buildPlaceholder(colorScheme),

            // Video icon (top-right)
            if (item.isVideo)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.videocam,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, WidgetRef ref) {
    // Will navigate to TripPhotoViewerPage in Task 5
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Photo viewer coming soon')));
  }

  Widget _buildAssetThumbnail(WidgetRef ref, ColorScheme colorScheme) {
    final thumbnailAsync = ref.watch(
      assetThumbnailProvider(item.platformAssetId!),
    );

    return thumbnailAsync.when(
      data: (bytes) {
        if (bytes == null) {
          return _buildPlaceholder(colorScheme);
        }
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          cacheWidth: 200,
          cacheHeight: 200,
          errorBuilder: (context, error, stack) =>
              _buildPlaceholder(colorScheme),
        );
      },
      loading: () => Container(
        color: colorScheme.surfaceContainerHighest,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, stack) => _buildPlaceholder(colorScheme),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(Icons.photo, color: colorScheme.onSurfaceVariant),
    );
  }

  Widget _buildOrphanedPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.errorContainer,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}
