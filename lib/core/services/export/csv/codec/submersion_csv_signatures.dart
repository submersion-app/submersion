import 'package:submersion/core/services/export/csv/codec/csv_header.dart';

/// Which of Submersion's own CSV exports a file is.
enum SubmersionCsvKind { dives, sites, equipment }

/// Recognises Submersion's CSV exports by their full set of column base
/// names (unit and format suffixes stripped, case ignored), so a file
/// exported in either mode, in any unit system, is recognised, and a CSV
/// from another app cannot match by accident.
abstract final class SubmersionCsvSignatures {
  static const _dives = {
    'dive number',
    'name',
    'date',
    'time',
    'site',
    'location',
    'max depth',
    'avg depth',
    'bottom time',
    'runtime',
    'water temp',
    'air temp',
    'visibility',
    'visibility rating',
    'dive type',
    'buddy',
    'dive master',
    'rating',
    'start pressure',
    'end pressure',
    'tank volume',
    'o2 %',
    'dive computer',
    'serial number',
    'firmware version',
    'notes',
    'wind speed',
    'wind direction',
    'cloud cover',
    'precipitation',
    'humidity',
    'weather description',
  };

  static const _sites = {
    'name',
    'country',
    'region',
    'latitude',
    'longitude',
    'max depth',
    'water type',
    'current',
    'entry type',
    'rating',
    'description',
    'notes',
  };

  static const _equipment = {
    'name',
    'type',
    'brand',
    'model',
    'serial number',
    'size',
    'thickness',
    'purchase date',
    'last service',
    'next service due',
    'buoyancy',
    'dry weight',
    'attributes',
    'components',
    'active',
    'notes',
  };

  /// The export [headers] came from, or null.
  static SubmersionCsvKind? match(List<String> headers) {
    final bases = {
      for (final h in headers)
        if (!h.trim().toLowerCase().startsWith('custom:'))
          CsvHeader.parse(h).key,
    };
    if (bases.containsAll(_dives)) return SubmersionCsvKind.dives;
    if (bases.containsAll(_equipment)) return SubmersionCsvKind.equipment;
    if (bases.containsAll(_sites)) return SubmersionCsvKind.sites;
    return null;
  }
}
