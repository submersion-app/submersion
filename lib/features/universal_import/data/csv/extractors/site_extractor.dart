import 'package:uuid/uuid.dart';

import 'package:submersion/features/universal_import/data/csv/extractors/entity_extractor.dart';
import 'package:submersion/features/universal_import/data/services/import_site_location.dart';

/// Extracts dive site records from transformed CSV rows.
///
/// Sites are deduplicated by name (case-insensitive). The first occurrence
/// of a name wins for GPS coordinates and for city, island, region and
/// country.
///
/// A row that carries `gps` but no site name is not dropped: the shared
/// contract names it from its own coordinates, so the position reaches the
/// log under a label rather than being discarded for want of one (#2212).
/// Such a site is keyed on that coordinate name, which makes two rows at the
/// same place one site, as two rows sharing a name already are.
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
      final name = _siteNameOf(row);
      if (name == null) continue;

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
        ..._placeFields(row),
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

  /// Returns the generated UUID for the site [row] belongs to, or null when
  /// the row named no site and carried no coordinates.
  ///
  /// This is the lookup the correlator needs: a row whose site exists only
  /// because of its `gps` has no name to look up, so the caller cannot use
  /// [siteIdForName] on its own.
  String? siteIdForRow(Map<String, dynamic> row) {
    final name = _siteNameOf(row);
    return name == null ? null : siteIdForName(name);
  }

  /// The name the site extracted from [row] is filed under, or null when the
  /// row describes no place at all.
  String? _siteNameOf(Map<String, dynamic> row) {
    final gps = _parseGps(row['gps']?.toString());
    return ImportSiteLocation.named(<String, dynamic>{
          if (row['siteName'] case final raw?) 'name': raw.toString(),
          if (gps != null) 'latitude': gps.$1,
          if (gps != null) 'longitude': gps.$2,
        })?['name']
        as String?;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// The site's city, island, region and country from a row's `siteCity`,
  /// `siteIsland`, `siteRegion` and `siteCountry` fields, keyed as the
  /// importer reads a site. Blank values are left out.
  Map<String, String> _placeFields(Map<String, dynamic> row) {
    const rowKeys = {
      'siteCity': 'city',
      'siteIsland': 'island',
      'siteRegion': 'region',
      'siteCountry': 'country',
    };
    return {
      for (final MapEntry(key: rowKey, value: siteKey) in rowKeys.entries)
        if (row[rowKey]?.toString().trim() case final value?
            when value.isNotEmpty)
          siteKey: value,
    };
  }

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
