import 'package:submersion/core/services/suunto_cloud/suunto_api_exception.dart';

/// A dive's header (summary fields) and time-series samples, in the same
/// shape the Suunto app's own "export as JSON" share feature produces (the
/// `DeviceLog.Header` / `DeviceLog.Samples` shape).
class SuuntoDiveExport {
  const SuuntoDiveExport({required this.header, required this.samples});

  final Map<String, dynamic> header;
  final List<Map<String, dynamic>> samples;
}

/// Normalizes a Suunto dive export -- either the Suunto *cloud* API's `sml`
/// shape (what [SuuntoCloudClient.fetchSmlJson] downloads) or the Suunto
/// *app*'s own manual "export as JSON" `DeviceLog` shape -- into a single
/// (header, samples) pair.
///
/// A Dart port of suunto2subsurface's `SuuntoConverter::convertBytes`
/// (https://github.com/dotanalon/suunto2subsurface), minus the JSON
/// re-serialization step that existed there only to hand the result back to
/// Subsurface's own DeviceLog-shaped file parser.
class SuuntoSmlNormalizer {
  const SuuntoSmlNormalizer._();

  static const int _suuntoActivityScuba = 51;

  /// Throws [SuuntoApiException] if [json] isn't a recognizable dive export
  /// (neither cloud 'sml' nor app 'DeviceLog' shape, or not a dive activity).
  static SuuntoDiveExport parse(Map<String, dynamic> json) {
    final normalized = _normalizeCloudJson(json);

    final Map<String, dynamic> header;
    final List<Map<String, dynamic>> samples;
    if (normalized != null) {
      header = normalized.header;
      samples = normalized.samples;
    } else {
      final deviceLog = json['DeviceLog'] as Map<String, dynamic>? ?? const {};
      header = deviceLog['Header'] as Map<String, dynamic>? ?? const {};
      samples = ((deviceLog['Samples'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>();
    }

    if (header.isEmpty) {
      throw const SuuntoApiException(
        "Suunto JSON: could not find dive header (checked both cloud 'sml' "
        "and app-export 'DeviceLog' shapes)",
      );
    }

    final activityType = (header['ActivityType'] as num?)?.toInt() ?? 0;
    if (activityType != _suuntoActivityScuba) {
      throw SuuntoApiException(
        'Suunto JSON: not a dive activity (ActivityType=$activityType)',
      );
    }

    return SuuntoDiveExport(header: header, samples: samples);
  }

  /// The Suunto *cloud* API's 'sml' export nests everything under
  /// `Summary`/`Data` .Samples[].Attributes['suunto/sml'][type] instead of
  /// a flat `DeviceLog.Header` / `DeviceLog.Samples[]`:
  ///  - `Summary.Samples[]` with an `Attributes['suunto/sml']['Header']`
  ///    entry and an `Attributes['suunto/sml']['DiveHeader']` entry (which
  ///    holds the real Gases list, as plain percentages, not the 0.0-1.0
  ///    fractions the DeviceLog shape uses).
  ///  - `Data.Samples[]` each wraps the per-instant fields (Depth, Ceiling,
  ///    NoDecTime, Cylinders, DiveEvents, Events, Temperature, ...) one level
  ///    deeper, in `Attributes['suunto/sml']['Sample']`.
  ///
  /// Returns null if [root] isn't cloud-shaped (no Summary/Data keys).
  static SuuntoDiveExport? _normalizeCloudJson(Map<String, dynamic> root) {
    if (!root.containsKey('Summary') || !root.containsKey('Data')) {
      return null;
    }

    final headerVal = _summaryType(root, 'Header');
    if (headerVal is! Map) return null;
    final header = Map<String, dynamic>.from(headerVal);

    final diveHeaderVal = _summaryType(root, 'DiveHeader');
    final diveHeader = diveHeaderVal is Map
        ? Map<String, dynamic>.from(diveHeaderVal)
        : <String, dynamic>{};
    final gases = (diveHeader['Gases'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final usedGases = gases
        .where((g) => (_asDouble(g['TankSize']) ?? 0) > 0)
        .toList();

    final diving = <String, dynamic>{};
    if (usedGases.isNotEmpty) {
      diving['Gases'] = usedGases
          .map(
            (g) => {
              'Oxygen': (_asDouble(g['Oxygen']) ?? 0) / 100.0,
              'Helium': (_asDouble(g['Helium']) ?? 0) / 100.0,
              'TankSize': _asDouble(g['TankSize']) ?? 0,
              'TankFillPressure': _fixPressureUnit(
                _asDouble(g['TankFillPressure']) ?? 0,
              ),
              'StartPressure': _fixPressureUnit(
                _asDouble(g['StartPressure']) ?? 0,
              ),
              'EndPressure': _fixPressureUnit(_asDouble(g['EndPressure']) ?? 0),
            },
          )
          .toList();
    }
    // GfLow/GfHigh aren't part of the app's own DeviceLog schema, but the
    // dive parser reads them from here so a single normalized export can
    // carry the gradient factors without a paired FIT.
    if (diveHeader['LowGf'] != null && diveHeader['HighGf'] != null) {
      diving['GfLow'] = diveHeader['LowGf'];
      diving['GfHigh'] = diveHeader['HighGf'];
    }
    if (diving.isNotEmpty) header['Diving'] = diving;

    final samples = <Map<String, dynamic>>[];
    final dataSamples =
        (root['Data'] as Map<String, dynamic>?)?['Samples'] as List<dynamic>? ??
        const [];
    for (final item in dataSamples) {
      final itemMap = item as Map<String, dynamic>;
      final attributes = itemMap['Attributes'] as Map<String, dynamic>?;
      final sml = attributes?['suunto/sml'] as Map<String, dynamic>?;
      if (sml == null || !sml.containsKey('Sample')) continue;
      final flat = Map<String, dynamic>.from(
        sml['Sample'] as Map<String, dynamic>,
      );
      flat['TimeISO8601'] = itemMap['TimeISO8601'];
      samples.add(flat);
    }

    return SuuntoDiveExport(header: header, samples: samples);
  }

  /// Looks up a `Summary.Samples[].Attributes['suunto/sml'][typeName]` block.
  static dynamic _summaryType(Map<String, dynamic> root, String typeName) {
    final summarySamples =
        (root['Summary'] as Map<String, dynamic>?)?['Samples']
            as List<dynamic>? ??
        const [];
    for (final entry in summarySamples) {
      final attributes =
          (entry as Map<String, dynamic>)['Attributes']
              as Map<String, dynamic>?;
      final sml = attributes?['suunto/sml'] as Map<String, dynamic>?;
      if (sml != null && sml.containsKey(typeName)) return sml[typeName];
    }
    return null;
  }

  /// Some dives report a gas's TankFillPressure/StartPressure/EndPressure
  /// already in bar instead of Pa -- seen on a real multi-gas dive where gas
  /// 0 correctly had 23200000 (Pa, == 232 bar) but gas 1 (a tank with no
  /// paired pressure transmitter) had a bare 232. No real dive pressure is
  /// ever this small in Pa, so treat anything in that range as already-bar
  /// and rescale it, rather than importing it as a near-zero working
  /// pressure.
  static double _fixPressureUnit(double value) {
    if (value > 0 && value < 10000) return value * 100000;
    return value;
  }

  static double? _asDouble(dynamic value) => (value as num?)?.toDouble();
}
