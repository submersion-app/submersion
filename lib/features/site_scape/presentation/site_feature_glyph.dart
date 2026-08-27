import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart'
    as domain;

/// One circular glyph per feature type; an unknown type (from a newer app
/// version) renders a generic pin rather than disappearing.
///
/// Lives apart from any one surface: the 2D marker layer, the features
/// list, and the read-only info sheet all stamp the same glyph, so a
/// feature looks the same wherever the diver meets it.
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
