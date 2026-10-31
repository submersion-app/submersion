import 'package:uuid/uuid.dart';

import 'package:submersion/features/universal_import/data/csv/extractors/entity_extractor.dart';
import 'package:submersion/features/universal_import/data/services/import_site_location.dart';

/// Extracts dive site records from transformed CSV rows.
///
/// Sites are deduplicated by name (case-insensitive), except that rows which
/// state different places are different sites: a shared name is not a shared
/// place (#4015). A blank cell contradicts nothing, since a spreadsheet often
/// fills a place on only some of a site's rows, so such a row joins the first
/// site of its name and fills what that site was missing. Otherwise the first
/// occurrence wins, for GPS coordinates and for city, island, region and
/// country.
///
/// A row that carries `gps` but no site name is not dropped: the shared
/// contract names it from its own coordinates, so the position reaches the
/// log under a label rather than being discarded for want of one (#2212).
/// Such a site is keyed on that coordinate name, which makes two rows at the
/// same place one site, as two rows sharing a name already are.
class SiteExtractor implements EntityExtractor<Map<String, dynamic>> {
  final Uuid _uuid;

  /// Map from lowercase site name to the sites filed under it in file order,
  /// populated during extraction.
  Map<String, List<Map<String, dynamic>>> _sitesByName = const {};

  SiteExtractor({Uuid uuid = const Uuid()}) : _uuid = uuid;

  @override
  List<Map<String, dynamic>> extractFromRows(List<Map<String, dynamic>> rows) {
    final sites = <Map<String, dynamic>>[];
    final sitesByName = <String, List<Map<String, dynamic>>>{};

    for (final row in rows) {
      final name = _siteNameOf(row);
      if (name == null) continue;

      final place = _placeFields(row);
      final namesakes = sitesByName[name.toLowerCase()] ??= [];
      final host = _hostOf(namesakes, place);
      if (host != null) {
        // Filled so that a later row is judged against all this site is known
        // to be, not only what its first row said. Filling a gap cannot make
        // the site contradict a row it already took.
        for (final MapEntry(:key, :value) in place.entries) {
          host.putIfAbsent(key, () => value);
        }
        continue;
      }

      final id = _uuid.v4();
      final gps = _parseGps(row['gps']?.toString());

      final site = <String, dynamic>{
        'id': id,
        'uddfId': id,
        'name': name,
        'latitude': gps?.$1,
        'longitude': gps?.$2,
        ...place,
      };
      namesakes.add(site);
      sites.add(site);
    }

    _sitesByName = sitesByName;
    return sites;
  }

  /// Returns the generated UUID for a site name, or null if not seen. Of
  /// several sites sharing the name, this is the first.
  ///
  /// The lookup is case-insensitive.
  String? siteIdForName(String name) {
    return _sitesByName[name.toLowerCase()]?.first['id'] as String?;
  }

  /// Returns the generated UUID for the site [row] belongs to, or null when
  /// the row named no site and carried no coordinates.
  ///
  /// This is the lookup the correlator needs: a row whose site exists only
  /// because of its `gps` has no name to look up, so the caller cannot use
  /// [siteIdForName] on its own.
  String? siteIdForRow(Map<String, dynamic> row) {
    final name = _siteNameOf(row);
    if (name == null) return null;
    final namesakes = _sitesByName[name.toLowerCase()];
    if (namesakes == null) return null;
    return _hostOf(namesakes, _placeFields(row))?['id'] as String?;
  }

  /// The first of [namesakes] that [place] does not contradict, or null.
  Map<String, dynamic>? _hostOf(
    List<Map<String, dynamic>> namesakes,
    Map<String, String> place,
  ) => namesakes
      .where((site) => !ImportSiteLocation.placesConflict(site, place))
      .firstOrNull;

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
