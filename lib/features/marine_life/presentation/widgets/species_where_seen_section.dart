import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_camera_animator.dart';
import 'package:submersion/features/marine_life/domain/entities/species_map_pins.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_map_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_map/species_map_markers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "Where seen" on a species' detail page (issue #4358): a small locked map
/// of the diver's logged and expected sites for the species, the top three
/// sites by count, and a way into the full species map.
///
/// Never draws the public layer and never calls GBIF: the full map is where
/// the diver chooses to.
class SpeciesWhereSeenSection extends ConsumerWidget {
  final String speciesId;

  static const double mapHeight = 160;

  const SpeciesWhereSeenSection({super.key, required this.speciesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final pinsAsync = ref.watch(speciesMapSpeciesPinsProvider(speciesId));
    final pins = pinsAsync.value ?? const <SpeciesSitePin>[];
    final logged = pins.where((p) => p.kind == SpeciesPinKind.logged).toList()
      ..sort((a, b) {
        final byCount = b.sightingCount.compareTo(a.sightingCount);
        return byCount != 0 ? byCount : a.siteName.compareTo(b.siteName);
      });
    final topSites = logged
        .take(3)
        .map(
          (p) => l10n.speciesMap_whereSeen_siteWithCount(
            p.siteName,
            p.sightingCount,
          ),
        )
        .join(', ');

    return Column(
      key: const ValueKey('species_where_seen_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          l10n.speciesMap_whereSeen_title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pins.isNotEmpty)
                SizedBox(
                  height: mapHeight,
                  child: _MiniMap(pins: pins),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        // A failed read says so; "not logged" would be a
                        // claim the page cannot make.
                        pinsAsync.hasError
                            ? l10n.speciesMap_error_loading
                            // Nothing to claim until the read is back.
                            : !pinsAsync.hasValue
                            ? ''
                            : topSites.isEmpty
                            ? l10n.speciesMap_whereSeen_empty
                            : topSites,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.map_outlined),
                      label: Text(l10n.speciesMap_whereSeen_openFullMap),
                      // Encoded, so an id holding '+' or '&' arrives intact.
                      onPressed: () => context.push(
                        Uri(
                          path: '/species/map',
                          queryParameters: {'species': speciesId},
                        ).toString(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniMap extends ConsumerWidget {
  final List<SpeciesSitePin> pins;

  const _MiniMap({required this.pins});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = [for (final p in pins) LatLng(p.latitude, p.longitude)];
    final urlTemplate = ref.watch(mapTileUrlProvider);
    return FlutterMap(
      // The camera frames the pins once, at creation, and the diver cannot
      // pan this map; a new set of sites is a new map, framed afresh.
      key: ValueKey(Object.hashAll(points)),
      options: MapOptions(
        initialCameraFit: MapCameraAnimator.fitAllCameraFit(
          points,
          singlePointZoom: 9,
          maxZoom: 10,
          padding: const EdgeInsets.all(24),
        ),
        // A preview strip: the full map is one tap away and carries the
        // style switcher and gestures.
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: urlTemplate,
          userAgentPackageName: 'app.submersion',
          maxZoom: ref.watch(mapTileMaxZoomProvider),
          tileProvider: TileCacheService.instance.tileProviderFor(
            urlTemplate: urlTemplate,
          ),
        ),
        MarkerLayer(
          markers: [
            for (final pin in pins)
              Marker(
                point: LatLng(pin.latitude, pin.longitude),
                width: 36,
                height: 36,
                child: pin.kind == SpeciesPinKind.logged
                    ? LoggedSpeciesMarker(
                        sightingCount: pin.sightingCount,
                        selected: false,
                      )
                    : const ExpectedSpeciesMarker(selected: false),
              ),
          ],
        ),
        const MapAttribution(),
      ],
    );
  }
}
