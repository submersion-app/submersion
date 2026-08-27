import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';

/// A recessive marker-cluster layer for built-in (bundled) dive sites.
/// Rendered BELOW the user-site layer and clustered separately, so built-in
/// markers never merge into the user's clusters. Markers are hollow grey pins,
/// smaller than the user's filled circles.
class BuiltInSiteMarkerLayer extends StatelessWidget {
  final List<ExternalDiveSite> sites;
  final String? selectedExternalId;
  final void Function(ExternalDiveSite) onTap;

  const BuiltInSiteMarkerLayer({
    super.key,
    required this.sites,
    required this.selectedExternalId,
    required this.onTap,
  });

  static const _grey = Color(0xFF607D8B); // muted slate-grey

  @override
  Widget build(BuildContext context) {
    if (sites.isEmpty) return const SizedBox.shrink();

    return MarkerClusterLayerWidget(
      options: MarkerClusterLayerOptions(
        maxClusterRadius: 80,
        size: const Size(40, 40),
        markers: sites.map((site) {
          final selected = site.externalId == selectedExternalId;
          return Marker(
            point: LatLng(site.latitude!, site.longitude!),
            width: selected ? 34 : 28,
            height: selected ? 40 : 34,
            child: Semantics(
              button: true,
              label: context.l10n.diveSites_map_semantics_builtInSiteMarker(
                site.name,
              ),
              child: GestureDetector(
                key: Key('builtInPin_${site.externalId}'),
                onTap: () => onTap(site),
                child: Icon(
                  Icons.location_on_outlined,
                  size: selected ? 36 : 30,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : _grey,
                ),
              ),
            ),
          );
        }).toList(),
        builder: (context, markers) => _cluster(markers.length),
        zoomToBoundsOnClick: true,
      ),
    );
  }

  Widget _cluster(int count) {
    return Container(
      decoration: BoxDecoration(
        color: _grey.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Center(
        child: Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
