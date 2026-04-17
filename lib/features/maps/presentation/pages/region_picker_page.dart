import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/region_download_dialog.dart';
import 'package:submersion/features/maps/presentation/widgets/region_selector.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Page for selecting a rectangular region on a map and opening the
/// [RegionDownloadDialog] for that region.
///
/// The user drags on the map to draw a bounding box, then confirms the
/// selection to launch the download dialog.
class RegionPickerPage extends ConsumerStatefulWidget {
  const RegionPickerPage({super.key});

  @override
  ConsumerState<RegionPickerPage> createState() => _RegionPickerPageState();
}

class _RegionPickerPageState extends ConsumerState<RegionPickerPage> {
  final MapController _mapController = MapController();

  Future<void> _onRegionSelected(LatLng southWest, LatLng northEast) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          RegionDownloadDialog(southWest: southWest, northEast: northEast),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.maps_offline_downloadNewRegion)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(20.0, 0.0),
              initialZoom: 2.0,
              minZoom: 2.0,
              maxZoom: ref.watch(mapTileMaxZoomProvider),
              interactionOptions: const InteractionOptions(
                flags:
                    InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: ref.watch(mapTileUrlProvider),
                userAgentPackageName: 'app.submersion',
                maxZoom: ref.watch(mapTileMaxZoomProvider),
                tileProvider: TileCacheService.instance.isInitialized
                    ? TileCacheService.instance.getTileProvider()
                    : null,
              ),
              const MapAttribution(),
            ],
          ),
          RegionSelector(
            mapController: _mapController,
            onRegionSelected: _onRegionSelected,
          ),
        ],
      ),
    );
  }
}
