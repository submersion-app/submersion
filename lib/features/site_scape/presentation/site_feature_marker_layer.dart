import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart'
    as domain;
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_glyph.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_info_sheet.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_sheet.dart';

/// Opens the edit sheet for [feature] and persists whatever comes back.
/// Shared by the map markers and the site detail Features section so both
/// paths behave identically.
Future<void> editSiteFeature(
  BuildContext context,
  WidgetRef ref,
  domain.SiteFeature feature,
) async {
  final result = await showSiteFeatureSheet(context, existing: feature);
  final repository = ref.read(siteFeatureRepositoryProvider);
  switch (result) {
    case SiteFeatureSheetSave(
      :final typeName,
      :final name,
      :final bearingDeg,
      :final depthMeters,
      :final notes,
    ):
      await repository.updateFeature(
        feature.copyWith(
          typeName: typeName,
          name: name,
          bearingDeg: bearingDeg,
          clearBearing: bearingDeg == null,
          depthMeters: depthMeters,
          clearDepth: depthMeters == null,
          notes: notes,
        ),
      );
    case SiteFeatureSheetDelete():
      await repository.deleteFeature(feature.id);
    case null:
      break;
  }
}

/// Zoom a marker tap settles on: close enough to read the feature and its
/// neighbours, but never a zoom OUT, so tapping while already zoomed in
/// keeps the detail the diver had.
const double _featureTapZoom = 17.0;

/// Diver-placed features for the selected site, as flutter_map markers.
/// Renders nothing without a selection (features are a selected-site
/// concern, matching the depth overlay's scoping).
class SiteFeatureMarkerLayer extends ConsumerWidget {
  final String? siteId;

  const SiteFeatureMarkerLayer({super.key, required this.siteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = siteId;
    if (id == null) return const SizedBox.shrink();
    final features = ref.watch(siteFeaturesProvider(id)).valueOrNull;
    if (features == null || features.isEmpty) return const SizedBox.shrink();
    return MarkerLayer(
      markers: [
        for (final f in features)
          Marker(
            point: LatLng(f.latitude, f.longitude),
            width: 36,
            height: 36,
            child: Builder(
              // Builder, not the layer's own context: MapController.of
              // needs a context BELOW the FlutterMap that hosts this layer.
              builder: (markerContext) => GestureDetector(
                key: ValueKey('siteFeatureMarker-${f.id}'),
                onTap: () => _onFeatureTap(markerContext, ref, f),
                child: Transform.rotate(
                  angle: (f.bearingDeg ?? 0) * math.pi / 180.0,
                  child: SiteFeatureGlyph(typeName: f.typeName),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Zoom to the feature, then show what the diver recorded. Editing is one
  /// deliberate step further in, behind the sheet's edit button, so a tap
  /// meant as "look closer" can no longer open an editor by accident.
  void _onFeatureTap(
    BuildContext context,
    WidgetRef ref,
    domain.SiteFeature feature,
  ) {
    final target = LatLng(feature.latitude, feature.longitude);
    final controller = MapController.of(context);
    controller.move(
      target,
      math.max(MapCamera.of(context).zoom, _featureTapZoom),
    );
    showSiteFeatureInfoSheet(
      context,
      ref,
      feature,
      onEdit: () => editSiteFeature(context, ref, feature),
    );
  }
}
