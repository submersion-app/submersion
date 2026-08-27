import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/media_status_badge.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Shared building blocks for media grids (dive and site sections).
///
/// These widgets deliberately take display strings as parameters instead of
/// reading `context.l10n` themselves: l10n lookups inside shared widgets
/// break consumer widget tests that pump without localization delegates,
/// and the dive/site sections want differently-worded labels anyway.

/// Empty state shown when a section has no media.
class MediaEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const MediaEmptyState({super.key, required this.icon, required this.message});

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
          Icon(icon, size: 48, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Purely visual thumbnail content for media items.
///
/// Tap, long-press, and drag gestures are handled by the enclosing grid.
/// Decides the orphaned-placeholder treatment itself so every consumer
/// gets it for free; badges (store transfer, video, document extension,
/// depth) self-hide when their data is absent.
class MediaThumbnailTile extends StatelessWidget {
  final MediaItem item;
  final AppSettings settings;
  final bool isSelectionMode;
  final bool isSelected;
  final String semanticsLabel;

  const MediaThumbnailTile({
    super.key,
    required this.item,
    required this.settings,
    required this.isSelectionMode,
    required this.isSelected,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final formatter = UnitFormatter(settings);

    return Semantics(
      label: semanticsLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail or placeholder.
            // Orphaned items show a distinct error tile; all other items
            // route through MediaItemView which dispatches to the correct
            // resolver for the item's sourceType (gallery, signature, etc.)
            // and renders UnavailableMediaPlaceholder for missing assets.
            if (item.isOrphaned)
              const OrphanedMediaPlaceholder()
            else
              MediaItemView(
                item: item,
                thumbnail: true,
                targetSize: const Size(200, 200),
                fit: BoxFit.cover,
              ),

            // Dimming overlay for unselected items in selection mode
            if (isSelectionMode && !isSelected)
              Container(color: Colors.black.withValues(alpha: 0.3)),

            // Selection overlay with primary border and tint
            if (isSelected)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.primary, width: 3),
                  color: colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),

            // Checkmark circle on selected items
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    size: 16,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),

            // Media store transfer badge (queued/uploading/failed only;
            // top-left so it never collides with the selection checkmark).
            Positioned(top: 4, left: 4, child: MediaStatusBadge(item: item)),

            // Video icon (top-right when no checkmark, hidden when checkmark)
            if (item.isVideo && !isSelected)
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

            // Document extension badge (top-right, mirrors the video slot).
            // Extensionless filenames yield '', which would draw an empty
            // black chip, so the badge is gated on having something to say.
            if (item.isDocument &&
                !isSelected &&
                item.documentExtension.isNotEmpty)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.documentExtension.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
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
}

/// Placeholder shown for orphaned media (file no longer exists)
class OrphanedMediaPlaceholder extends StatelessWidget {
  const OrphanedMediaPlaceholder({super.key});

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
