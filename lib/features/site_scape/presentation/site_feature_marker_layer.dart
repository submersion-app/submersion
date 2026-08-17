import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart'
    as domain;
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
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
      :final wreckId,
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
          wreckId: wreckId,
          clearWreck: wreckId == null,
        ),
      );
    case SiteFeatureSheetDelete():
      await repository.deleteFeature(feature.id);
    case null:
      break;
  }
}

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
            child: GestureDetector(
              key: ValueKey('siteFeatureMarker-${f.id}'),
              onTap: () => editSiteFeature(context, ref, f),
              child: Transform.rotate(
                angle: (f.bearingDeg ?? 0) * math.pi / 180.0,
                child: SiteFeatureGlyph(typeName: f.typeName),
              ),
            ),
          ),
      ],
    );
  }
}

/// One circular glyph per feature type; an unknown type (from a newer app
/// version) renders a generic pin rather than disappearing.
class SiteFeatureGlyph extends StatelessWidget {
  final String typeName;
  final double size;

  const SiteFeatureGlyph({super.key, required this.typeName, this.size = 20});

  static (IconData, Color) styleFor(String typeName) {
    return switch (domain.SiteFeatureType.values.asNameMap()[typeName]) {
      domain.SiteFeatureType.wreck => (
        Icons.directions_boat,
        const Color(0xFF8B5CF6),
      ),
      domain.SiteFeatureType.mooring => (Icons.anchor, const Color(0xFF0EA5E9)),
      domain.SiteFeatureType.entry => (Icons.login, const Color(0xFF22C55E)),
      domain.SiteFeatureType.exit => (Icons.logout, const Color(0xFFF97316)),
      domain.SiteFeatureType.swimThrough => (
        Icons.u_turn_right,
        const Color(0xFF14B8A6),
      ),
      domain.SiteFeatureType.hazard => (
        Icons.warning_amber,
        const Color(0xFFEF4444),
      ),
      domain.SiteFeatureType.current => (
        Icons.navigation,
        const Color(0xFF3B82F6),
      ),
      null => (Icons.place, const Color(0xFFEF4444)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = styleFor(typeName);
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}
