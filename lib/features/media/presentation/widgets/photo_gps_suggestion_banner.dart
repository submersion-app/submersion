import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

/// Banner widget that suggests using GPS coordinates from photos
/// when a dive has no site or the site has no coordinates.
///
/// Shows when:
/// - Dive has photos with GPS coordinates
/// - AND (dive has no site OR site has no coordinates)
class PhotoGpsSuggestionBanner extends ConsumerWidget {
  final String diveId;
  final DiveSite? currentSite;
  final VoidCallback onCreateSite;
  final void Function(GeoPoint gps) onUpdateSite;
  final VoidCallback onDismiss;

  const PhotoGpsSuggestionBanner({
    super.key,
    required this.diveId,
    required this.currentSite,
    required this.onCreateSite,
    required this.onUpdateSite,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Don't show if site already has coordinates
    if (currentSite?.hasCoordinates == true) {
      return const SizedBox.shrink();
    }

    final gpsAsync = ref.watch(divePhotoGpsProvider(diveId));

    return gpsAsync.when(
      data: (gps) {
        if (gps == null) return const SizedBox.shrink();

        return _buildBanner(context, gps);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildBanner(
    BuildContext context,
    ({double latitude, double longitude}) gps,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'GPS found in photos',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Dismiss GPS suggestion',
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Coordinates: ${gps.latitude.toStringAsFixed(5)}, '
              '${gps.longitude.toStringAsFixed(5)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (currentSite == null) ...[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onCreateSite,
                      icon: const Icon(Icons.add_location_alt, size: 18),
                      label: const Text('Create Site'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          onUpdateSite(GeoPoint(gps.latitude, gps.longitude)),
                      icon: const Icon(Icons.edit_location_alt, size: 18),
                      label: const Text('Add to Site'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
