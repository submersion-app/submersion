import 'package:uuid/uuid.dart';

import 'package:submersion/features/universal_import/data/services/import_site_location.dart';

/// Known standardized field names that map directly to dive records.
const _diveFields = <String>[
  'diveNumber',
  'name',
  'dateTime',
  'date',
  'time',
  'maxDepth',
  'avgDepth',
  'duration',
  'runtime',
  'waterTemp',
  'airTemp',
  'bottomTemp',
  'visibility',
  'visibilityMeters',
  'diveType',
  'diveTypeIds',
  'diveMode',
  'buddy',
  'diveMaster',
  'notes',
  'rating',
  'siteName',
  'siteId',
  'sac',
  'gradientFactorLow',
  'gradientFactorHigh',
  'diveComputerModel',
  'diveComputerSerial',
  'diveComputerFirmware',
  'weight',
  'weightUsed',
  'windSpeed',
  'windDirection',
  'cloudCover',
  'precipitation',
  'humidity',
  'weatherDescription',
  'customFields',
];

/// Extracts core dive fields from a single transformed CSV row.
///
/// Each dive gets a freshly generated UUID for its 'id' field.
class DiveExtractor {
  final Uuid _uuid;

  const DiveExtractor({Uuid uuid = const Uuid()}) : _uuid = uuid;

  /// Extract a single dive map from [row].
  ///
  /// Only known dive fields are copied, plus a 'suit' line appended to the
  /// notes. A new UUID is generated for 'id'.
  Map<String, dynamic> extract(Map<String, dynamic> row) {
    final dive = <String, dynamic>{'id': _uuid.v4()};

    for (final field in _diveFields) {
      if (row.containsKey(field)) {
        dive[field] = row[field];
      }
    }

    // The row's own position, kept on the dive whether or not sites are
    // being imported (#2212). `gps` is deliberately not in `_diveFields`:
    // it is a Subsurface-style "lat lon" pair, not a dive column, so it is
    // parsed rather than copied. It is then judged by the same rule the
    // site is, so a cell `SiteExtractor` rejects cannot reach the dive
    // instead. `UddfEntityImporter` reads the result into
    // `Dive.entryLocation`.
    final gps = _parseGps(row['gps']?.toString());
    final fix = gps == null ? null : ImportSiteLocation.fix(gps.$1, gps.$2);
    if (fix != null) {
      dive['latitude'] = fix.latitude;
      dive['longitude'] = fix.longitude;
    }

    // A dive has no suit field, so the suit is kept in the notes, as the
    // Subsurface XML import keeps it. When equipment is imported the suit
    // also becomes gear linked to the dive (CsvCorrelator, #1824).
    final suit = row['suit']?.toString().trim() ?? '';
    if (suit.isNotEmpty) {
      final notes = dive['notes']?.toString() ?? '';
      dive['notes'] = notes.trim().isEmpty
          ? 'Suit: $suit'
          : '$notes\nSuit: $suit';
    }

    return dive;
  }

  /// Parse Subsurface GPS format: "lat lon" (space-separated floats).
  ///
  /// Returns null when the value is absent or unparseable. Mirrors
  /// `SiteExtractor`, which reads the same column for the site.
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
