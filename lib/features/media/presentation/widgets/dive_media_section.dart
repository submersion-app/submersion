import 'dart:io';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Section widget displaying media (photos/videos) for a dive
class DiveMediaSection extends ConsumerWidget {
  final String diveId;
  final VoidCallback? onAddPressed;

  const DiveMediaSection({super.key, required this.diveId, this.onAddPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(mediaForDiveProvider(diveId));
    final settings = ref.watch(settingsProvider);
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
                Expanded(
                  child: Text('Photos & Video', style: textTheme.titleMedium),
                ),
                if (onAddPressed != null)
                  IconButton(
                    icon: Icon(
                      Icons.add_photo_alternate,
                      color: colorScheme.primary,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Add photo or video',
                    onPressed: onAddPressed,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Content
            mediaAsync.when(
              data: (media) {
                if (media.isEmpty) {
                  return const _EmptyMediaState();
                }
                return _MediaGrid(media: media, settings: settings);
              },
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (error, stack) => Text(
                'Error loading media',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state when no media is associated with the dive
class _EmptyMediaState extends StatelessWidget {
  const _EmptyMediaState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
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
        ],
      ),
    );
  }
}

/// Grid of media thumbnails
class _MediaGrid extends StatelessWidget {
  final List<MediaItem> media;
  final AppSettings settings;

  const _MediaGrid({required this.media, required this.settings});

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
        return _MediaThumbnail(item: media[index], settings: settings);
      },
    );
  }
}

/// Individual media thumbnail with badges
class _MediaThumbnail extends StatelessWidget {
  final MediaItem item;
  final AppSettings settings;

  const _MediaThumbnail({required this.item, required this.settings});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final formatter = UnitFormatter(settings);

    return GestureDetector(
      // TODO: Navigate to media detail/viewer page
      onTap: () {},
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail or placeholder
            if (item.isOrphaned)
              const _OrphanedPlaceholder()
            else if (item.thumbnailPath != null)
              Image.file(
                File(item.thumbnailPath!),
                fit: BoxFit.cover,
                // Limit decoded image size for memory efficiency
                cacheWidth: 200,
                cacheHeight: 200,
                errorBuilder: (context, error, stack) =>
                    _buildPlaceholder(colorScheme),
              )
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
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),

            // Depth badge (bottom-left)
            if (item.enrichment?.depthMeters != null)
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    formatter.formatDepth(
                      item.enrichment!.depthMeters,
                      decimals: 0,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(Icons.photo, color: colorScheme.onSurfaceVariant),
    );
  }
}

/// Placeholder shown for orphaned media (file no longer exists)
class _OrphanedPlaceholder extends StatelessWidget {
  const _OrphanedPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
