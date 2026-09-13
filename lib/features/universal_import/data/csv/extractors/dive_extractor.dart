import 'package:uuid/uuid.dart';

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
  /// Only known dive fields are copied. A new UUID is generated for 'id'.
  Map<String, dynamic> extract(Map<String, dynamic> row) {
    final dive = <String, dynamic>{'id': _uuid.v4()};

    for (final field in _diveFields) {
      if (row.containsKey(field)) {
        dive[field] = row[field];
      }
    }

    return dive;
  }
}
