import 'package:uuid/uuid.dart';

import 'package:submersion/features/universal_import/data/csv/extractors/entity_extractor.dart';

/// Extracts dive site records from transformed CSV rows.
///
/// Sites are deduplicated by name (case-insensitive). The first occurrence
/// of a name wins for GPS coordinates.
class SiteExtractor implements EntityExtractor<Map<String, dynamic>> {
  final Uuid _uuid;

  /// Map from lowercase site name to generated UUID, populated during extraction.
  Map<String, String> _siteNameToId = const {};

  SiteExtractor({Uuid uuid = const Uuid()}) : _uuid = uuid;

  @override
  List<Map<String, dynamic>> extractFromRows(List<Map<String, dynamic>> rows) {
    final sites = <Map<String, dynamic>>[];
    final nameToId = <String, String>{};

    for (final row in rows) {
      final rawName = row['siteName'];
      if (rawName == null) continue;
      final name = rawName.toString().trim();
      if (name.isEmpty) continue;

      final key = name.toLowerCase();
      if (nameToId.containsKey(key)) continue;

      final id = _uuid.v4();
      nameToId[key] = id;

      final gps = _parseGps(row['gps']?.toString());

      sites.add({
        'id': id,
        'uddfId': id,
        'name': name,
        'latitude': gps?.$1,
        'longitude': gps?.$2,
      });
    }

    _siteNameToId = nameToId;
    return sites;
  }

  /// Returns the generated UUID for a site name, or null if not seen.
  ///
  /// The lookup is case-insensitive.
  String? siteIdForName(String name) {
    return _siteNameToId[name.toLowerCase()];
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Parse Subsurface GPS format: "lat lon" (space-separated floats).
  ///
  /// Returns null when the value is absent or unparseable.
  (double, double)? _parseGps(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parts = raw.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    final lat = double.tryParse(parts[0]);
    final lon = double.tryParse(parts[1]);
    if (lat == null || lon == null) return null;
    return (lat, lon);
  }
}
