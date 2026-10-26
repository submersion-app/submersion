import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// A dive site from the app's bundled public catalogue
/// (`assets/data/dive_sites.json`, from OpenStreetMap).
class CatalogSite {
  const CatalogSite({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.country,
    this.region,
    this.description,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? country;
  final String? region;
  final String? description;
}

/// A dive centre from `assets/data/dive_centers.json`.
class CatalogCenter {
  const CatalogCenter({
    required this.id,
    required this.name,
    this.country,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String? country;
  final double? latitude;
  final double? longitude;
}

class Catalog {
  const Catalog({
    required this.sites,
    required this.centers,
    this.speciesStrings = const [],
  });

  final List<CatalogSite> sites;
  final List<CatalogCenter> centers;

  /// Every text value in `assets/data/species.json` (names, scientific
  /// names, categories, descriptions): the app seeds this catalogue into
  /// every logbook, so real ones carry the same strings.
  final List<String> speciesStrings;

  /// Every catalogue name, for the privacy check's allow list: these are
  /// public, so a source that used the same name identifies nobody.
  Set<String> get publicStrings => {
    for (final s in sites) s.name,
    for (final s in sites)
      if (s.description != null) s.description!,
    for (final c in centers) c.name,
    ...speciesStrings,
  };

  static Catalog load(String dataDir) {
    Map<String, Object?> read(String name) =>
        jsonDecode(File(p.join(dataDir, name)).readAsStringSync())
            as Map<String, Object?>;
    double? asDouble(Object? v) => (v as num?)?.toDouble();
    final sites = [
      for (final raw in read('dive_sites.json')['sites']! as List)
        if (raw is Map &&
            (raw['name'] as String?)?.trim().isNotEmpty == true &&
            raw['latitude'] != null &&
            raw['longitude'] != null)
          CatalogSite(
            id: raw['id'] as String,
            name: (raw['name'] as String).trim(),
            latitude: asDouble(raw['latitude'])!,
            longitude: asDouble(raw['longitude'])!,
            country: raw['country'] as String?,
            region: raw['region'] as String?,
            description: raw['description'] as String?,
          ),
    ];
    final centers = [
      for (final raw in read('dive_centers.json')['centers']! as List)
        if (raw is Map && (raw['name'] as String?)?.trim().isNotEmpty == true)
          CatalogCenter(
            id: raw['id'] as String,
            name: (raw['name'] as String).trim(),
            country: raw['country'] as String?,
            latitude: asDouble(raw['latitude']),
            longitude: asDouble(raw['longitude']),
          ),
    ];
    final speciesStrings = [
      for (final raw in read('species.json')['species']! as List)
        if (raw is Map)
          for (final v in raw.values)
            if (v is String) v,
    ];
    return Catalog(
      sites: sites,
      centers: centers,
      speciesStrings: speciesStrings,
    );
  }
}
