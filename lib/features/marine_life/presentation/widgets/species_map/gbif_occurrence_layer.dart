import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/data/services/gbif_species_map_service.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_map_prefs_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_map_providers.dart';

/// GBIF's licence-filtered occurrence tiles for one species, drawn under the
/// diver's own pins (issue #4358).
///
/// Renders nothing while the public layer is off, and in that case never
/// reads the taxon key, so nothing is sent. With no key to draw (no
/// confident match, no scientific name, GBIF unreachable) it renders nothing
/// either; the page says why.
class GbifOccurrenceLayer extends ConsumerWidget {
  final String speciesId;

  const GbifOccurrenceLayer({super.key, required this.speciesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(speciesMapPublicLayerProvider)) {
      return const SizedBox.shrink();
    }
    final key = ref.watch(speciesGbifTaxonKeyProvider(speciesId)).value;
    if (key == null) return const SizedBox.shrink();
    return Opacity(
      opacity: 0.8,
      child: TileLayer(
        urlTemplate: GbifSpeciesMapService.tileUrlTemplate(key),
        userAgentPackageName: 'app.submersion',
        // GBIF draws records up to its own detail level; beyond it the
        // hexagons only get bigger.
        maxNativeZoom: 14,
        // A failed tile is dropped once out of view, so panning back asks
        // GBIF again instead of keeping the gap.
        evictErrorTileStrategy: EvictErrorTileStrategy.notVisibleRespectMargin,
        // A tile that fails (offline, rate limited) is not drawn, and the
        // page says the records did not load.
        tileProvider: NetworkTileProvider(
          // Not const: flutter_map writes its own entries into this map.
          headers: {'User-Agent': GbifSpeciesMapService.userAgent},
          silenceExceptions: true,
        ),
        errorTileCallback: (tile, error, stackTrace) {
          if (!context.mounted) return;
          final failed = ref.read(
            speciesMapPublicTilesFailedProvider(speciesId).notifier,
          );
          if (!failed.state) failed.state = true;
        },
      ),
    );
  }
}
