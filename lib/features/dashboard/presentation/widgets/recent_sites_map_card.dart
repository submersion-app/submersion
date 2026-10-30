import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/locked_map_scroll_passthrough.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/submersion_tile_layer.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/defer_until_painted.dart';

/// Height of the map itself, exported because a card paired beside this one
/// has to match it: the dashboard grid top-aligns cards at their natural
/// heights rather than stretching them, so the partner sizes itself from
/// this value instead of repeating the number.
const double recentSitesMapHeight = 220;

/// Key of the flat panel that stands in for the map until it mounts.
const Key recentSitesMapPlaceholderKey = Key('recent-sites-map-placeholder');

/// Mini map with pins for the sites of the most recent dives.
///
/// A map is costly to mount and starts fetching tiles at once, so the card
/// shows a flat panel until it is on screen. That panel is usually up for a
/// single frame, which is why it is not worth caching anything to draw on it.
class RecentSitesMapCard extends ConsumerWidget {
  const RecentSitesMapCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinsAsync = ref.watch(recentSitesProvider);
    final pins = pinsAsync.valueOrNull ?? const [];
    if (pins.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final mapBackground = scheme.surfaceContainerHighest;
    final points = [for (final p in pins) LatLng(p.latitude, p.longitude)];
    final fit = points.length >= 2
        ? CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.all(40),
            maxZoom: 12,
          )
        : null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.dashboard_recentSites_title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.open_in_full, size: 16),
                  onPressed: () => context.go('/sites'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: recentSitesMapHeight,
                child: DeferUntilPainted(
                  placeholder: ColoredBox(
                    key: recentSitesMapPlaceholderKey,
                    color: mapBackground,
                    child: const SizedBox.expand(),
                  ),
                  child: LockedMapScrollPassthrough(
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: points.first,
                        initialZoom: 11,
                        initialCameraFit: fit,
                        // Matches the placeholder, so the swap does not flash
                        // flutter_map's default light grey before tiles arrive.
                        backgroundColor: mapBackground,
                        // Never interactive: a live map here would fight the
                        // parent scroll view for the gesture arena on every
                        // drag. The passthrough hands trackpad scrolls to the
                        // page, which the locked map would otherwise swallow.
                        // The expand icon above opens the full map.
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        submersionTileLayer(ref),
                        MarkerLayer(
                          markers: [
                            for (final p in pins)
                              Marker(
                                point: LatLng(p.latitude, p.longitude),
                                width: 34,
                                height: 34,
                                child: Tooltip(
                                  message: p.siteName ?? '',
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: scheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.place,
                                        size: 16,
                                        color: scheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // No map style switcher: the map is locked, and the
                        // full map the expand icon opens carries one.
                        const MapAttribution(),
                      ],
                    ),
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
