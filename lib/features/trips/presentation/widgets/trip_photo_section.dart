import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';

/// Maximum number of thumbnail photos to display in the preview row.
const int _maxVisibleThumbnails = 5;

/// Section widget displaying photos for a trip with preview row.
class TripPhotoSection extends ConsumerWidget {
  final String tripId;
  final VoidCallback? onScanPressed;

  const TripPhotoSection({super.key, required this.tripId, this.onScanPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaCountAsync = ref.watch(mediaCountForTripProvider(tripId));
    final mediaListAsync = ref.watch(flatMediaListForTripProvider(tripId));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(Icons.photo_library, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text('Photos', style: textTheme.titleMedium),
                const SizedBox(width: 8),
                // Count badge
                mediaCountAsync.when(
                  data: (count) {
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (error, stack) => const SizedBox.shrink(),
                ),
                const Spacer(),
                // Camera icon button for scanning
                mediaCountAsync.when(
                  data: (count) {
                    if (count == 0) return const SizedBox.shrink();
                    return IconButton(
                      icon: Icon(
                        Icons.photo_camera,
                        color: colorScheme.primary,
                      ),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Scan device gallery',
                      onPressed: onScanPressed,
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (error, stack) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Content
            mediaListAsync.when(
              data: (media) {
                if (media.isEmpty) {
                  return _EmptyState(onScanPressed: onScanPressed);
                }
                return _PhotoRow(tripId: tripId, media: media);
              },
              loading: () => const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (error, stack) => Text(
                'Error loading photos',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state shown when no photos exist for the trip.
class _EmptyState extends StatelessWidget {
  final VoidCallback? onScanPressed;

  const _EmptyState({this.onScanPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_camera_outlined,
            size: 48,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'No photos yet',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (onScanPressed != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onScanPressed,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Scan device gallery'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Horizontal scrollable row of photo thumbnails.
class _PhotoRow extends StatelessWidget {
  final String tripId;
  final List<MediaItem> media;

  const _PhotoRow({required this.tripId, required this.media});

  @override
  Widget build(BuildContext context) {
    final visibleCount = media.length > _maxVisibleThumbnails
        ? _maxVisibleThumbnails
        : media.length;
    final remainingCount = media.length - visibleCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 80,
          child: Row(
            children: [
              // Photo thumbnails
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: visibleCount + (remainingCount > 0 ? 1 : 0),
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index < visibleCount) {
                      return _PhotoThumbnail(
                        tripId: tripId,
                        item: media[index],
                      );
                    }
                    // More indicator
                    return _MoreIndicator(count: remainingCount);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // View All button
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push('/trips/$tripId/gallery'),
            child: const Text('View All'),
          ),
        ),
      ],
    );
  }
}

/// Individual photo thumbnail.
class _PhotoThumbnail extends ConsumerWidget {
  final String tripId;
  final MediaItem item;

  const _PhotoThumbnail({required this.tripId, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final mediaType = item.isVideo ? 'Video' : 'Photo';

    return Semantics(
      button: true,
      label: '$mediaType thumbnail. Tap to open gallery',
      child: GestureDetector(
        onTap: () => context.push('/trips/$tripId/gallery'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Thumbnail
                if (item.platformAssetId != null)
                  _buildAssetThumbnail(ref, colorScheme)
                else
                  _buildPlaceholder(colorScheme),

                // Video icon
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
        ),
      ),
    );
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
          cacheWidth: 160,
          cacheHeight: 160,
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
}

/// Badge showing "+N" for remaining photos beyond visible limit.
class _MoreIndicator extends StatelessWidget {
  final int count;

  const _MoreIndicator({required this.count});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: '$count more photos',
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '+$count',
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
