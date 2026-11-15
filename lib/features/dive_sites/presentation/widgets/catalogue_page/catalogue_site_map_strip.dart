import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/bathymetry/presentation/bathymetry_depth_overlay_layer.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_kind_glyph.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/locked_map_scroll_passthrough.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_corner_controls.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction_options.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/maps/presentation/widgets/world_copies.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Wider than the strip on the diver's own site page (14), which shows a
/// place they know. A built-in site is somewhere they have not been, and
/// at 14 one out at sea is a blue rectangle: at 12 the strip takes in
/// about 15 km and the nearest coast with it.
const _stripZoom = 12.0;

/// Where a built-in site is, as a strip at the top of its page: a map of
/// its position with the depth overlay and the glyph its pin has.
///
/// The strip takes no gestures: it sits in a scrolling page, and a map
/// that pans there catches the wheel or a drag as soon as it scrolls under
/// the pointer (issue #3156). Its corner button opens the same position on
/// a map that does pan and zoom.
///
/// Only for a record with coordinates.
class CatalogueSiteMapStrip extends ConsumerWidget {
  const CatalogueSiteMapStrip({super.key, required this.site});

  final CatalogueSite site;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final location = site.location!;
    final point = LatLng(location.latitude, location.longitude);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 200,
        child: Stack(
          children: [
            LockedMapScrollPassthrough(
              child: FlutterMap(
                key: ValueKey('${location.latitude}_${location.longitude}'),
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: _stripZoom,
                  minZoom: 2.0,
                  maxZoom: 18.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: _layers(ref, site, point),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Material(
                color: colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
                child: Semantics(
                  button: true,
                  label:
                      context.l10n.diveSites_detail_semantics_viewFullscreenMap,
                  child: InkWell(
                    key: const ValueKey('catalogueMapFullscreen'),
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _FullscreenCatalogueMap(site: site),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.fullscreen,
                        size: 20,
                        color: colorScheme.primary,
                      ),
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

/// The record's position on a map the diver can pan, zoom and restyle.
/// It shows the one position, not the Sites map with its other pins.
class _FullscreenCatalogueMap extends ConsumerStatefulWidget {
  const _FullscreenCatalogueMap({required this.site});

  final CatalogueSite site;

  @override
  ConsumerState<_FullscreenCatalogueMap> createState() =>
      _FullscreenCatalogueMapState();
}

class _FullscreenCatalogueMapState
    extends ConsumerState<_FullscreenCatalogueMap> {
  final _controller = MapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    final location = site.location!;
    final point = LatLng(location.latitude, location.longitude);

    return Scaffold(
      appBar: AppBar(title: Text(site.name)),
      body: Stack(
        children: [
          TrackpadZoomMap(
            controller: _controller,
            child: FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: point,
                initialZoom: _stripZoom,
                minZoom: 2.0,
                maxZoom: 18.0,
                interactionOptions: rotatableMapInteraction,
                cameraConstraint: worldMapCameraConstraint,
              ),
              children: _layers(ref, site, point),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: MapCornerControls(controller: _controller),
          ),
        ],
      ),
    );
  }
}

/// The tiles, the depth overlay for the position, the record's glyph and
/// the map credit: the same on the strip and on the map it opens.
List<Widget> _layers(WidgetRef ref, CatalogueSite site, LatLng point) {
  final tileUrl = ref.watch(mapTileUrlProvider);
  return [
    TileLayer(
      urlTemplate: tileUrl,
      userAgentPackageName: 'app.submersion',
      maxZoom: ref.watch(mapTileMaxZoomProvider),
      tileProvider: TileCacheService.instance.tileProviderFor(
        urlTemplate: tileUrl,
      ),
    ),
    BathymetryDepthOverlayLayer(location: site.location),
    MarkerLayer(
      markers: [
        Marker(
          point: point,
          width: 48,
          height: 48,
          child: _RecordMarker(kind: site.kind),
        ),
      ],
    ),
    const MapAttribution(),
  ];
}

/// The record's glyph on a light disc, so it reads over any tiles: not
/// the filled circle the diver's own sites have, because this is not one.
class _RecordMarker extends StatelessWidget {
  const _RecordMarker({required this.kind});

  final CatalogueKind kind;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: colorScheme.outline, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          catalogueKindIcon(kind),
          key: const ValueKey('catalogueStripGlyph'),
          size: 26,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
