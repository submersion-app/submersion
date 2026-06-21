import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction.dart';

/// Map for the Match-Sites review: shows the focused dive's GPS point plus its
/// candidate sites. Tapping a candidate marker selects it.
class MatchSitesMap extends ConsumerStatefulWidget {
  const MatchSitesMap({
    super.key,
    required this.divePoint,
    required this.candidates,
    required this.onSelectCandidate,
    this.selectedCandidateId,
  });

  final GeoPoint divePoint;
  final List<MatchCandidateView> candidates;
  final String? selectedCandidateId;
  final void Function(String candidateId) onSelectCandidate;

  @override
  ConsumerState<MatchSitesMap> createState() => _MatchSitesMapState();
}

class _MatchSitesMapState extends ConsumerState<MatchSitesMap> {
  final MapController _controller = MapController();

  // The review page keys this widget by dive id, so a focus change recreates
  // it (fresh initialCameraFit below) rather than updating it in place.
  List<LatLng> get _points => [
    LatLng(widget.divePoint.latitude, widget.divePoint.longitude),
    for (final c in widget.candidates)
      LatLng(c.location.latitude, c.location.longitude),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pts = _points;
    final fit = pts.length >= 2
        ? CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(pts),
            padding: const EdgeInsets.all(40),
            maxZoom: 16,
          )
        : null;

    return MapInteractionDetector(
      mapController: _controller,
      builder: (context, interactionOptions) => FlutterMap(
        mapController: _controller,
        options: MapOptions(
          initialCenter: pts.first,
          initialZoom: 13,
          initialCameraFit: fit,
          interactionOptions: interactionOptions,
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
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(
                  widget.divePoint.latitude,
                  widget.divePoint.longitude,
                ),
                width: 38,
                height: 38,
                child: _pin(
                  scheme.primary,
                  Icons.my_location,
                  scheme.onPrimary,
                ),
              ),
              for (final c in widget.candidates)
                Marker(
                  point: LatLng(c.location.latitude, c.location.longitude),
                  width: c.id == widget.selectedCandidateId ? 46 : 38,
                  height: c.id == widget.selectedCandidateId ? 46 : 38,
                  child: GestureDetector(
                    onTap: () => widget.onSelectCandidate(c.id),
                    child: _pin(
                      c.id == widget.selectedCandidateId
                          ? scheme.secondary
                          : (c.isExisting ? Colors.teal : Colors.indigo),
                      Icons.place,
                      Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const MapAttribution(),
        ],
      ),
    );
  }

  Widget _pin(Color color, IconData icon, Color iconColor) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
    ),
    child: Center(child: Icon(icon, size: 18, color: iconColor)),
  );
}
