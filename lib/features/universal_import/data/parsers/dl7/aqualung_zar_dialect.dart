import 'package:submersion/features/universal_import/data/parsers/dl7/dl7_units.dart';

/// One `<TANK>` entry from an Aqualung ZAR block, converted to SI.
class AqualungZarTank {
  final String? name;
  final double? o2Percent;
  final double? startPressureBar;
  final double? endPressureBar;
  final double? workingPressureBar;
  final double? volumeLiters;

  const AqualungZarTank({
    this.name,
    this.o2Percent,
    this.startPressureBar,
    this.endPressureBar,
    this.workingPressureBar,
    this.volumeLiters,
  });
}

/// Structured data extracted from a `ZAR{<AQUALUNG>...}` block.
class AqualungZarData {
  final String? app;
  final String? duid;
  final String? title;
  final String? pdcModel;
  final String? pdcSerial;
  final String? pdcFirmware;
  final int? rating;
  final int? diveMode;
  final int? diveNumber;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final String? city;
  final String? stateProvince;
  final String? country;
  final Duration? elapsedDiveTime;
  final Duration? surfaceInterval;
  final double? maxDepthMeters;
  final double? minTempCelsius;
  final double? avgDepthMeters;
  final List<AqualungZarTank> tanks;
  final List<int> decoTimePerSample;

  const AqualungZarData({
    this.app,
    this.duid,
    this.title,
    this.pdcModel,
    this.pdcSerial,
    this.pdcFirmware,
    this.rating,
    this.diveMode,
    this.diveNumber,
    this.latitude,
    this.longitude,
    this.locationName,
    this.city,
    this.stateProvince,
    this.country,
    this.elapsedDiveTime,
    this.surfaceInterval,
    this.maxDepthMeters,
    this.minTempCelsius,
    this.avgDepthMeters,
    this.tanks = const [],
    this.decoTimePerSample = const [],
  });
}

/// Parses the DiverLog+/DiveCloud `<AQUALUNG>` ZAR dialect.
///
/// The block is pseudo-XML: `<TAG>payload</TAG>` lines where payloads are
/// comma-separated `KEY=value` pairs and values may be wrapped in square
/// brackets to escape embedded commas (`GPS=[lat,lon]`). Not parsed with an
/// XML parser on purpose — site names may contain unescaped ampersands.
/// Every field is optional; exporters drift (COUNTRY vs DIVESITE presence).
class AqualungZarDialect {
  AqualungZarDialect._();

  static final _tagPattern = RegExp(r'<([A-Z0-9_]+)>(.*?)</\1>', dotAll: true);

  static final _wrapperPattern = RegExp(
    r'<AQUALUNG>(.*?)</AQUALUNG>',
    dotAll: true,
  );

  static AqualungZarData? parse(
    String zarContent, {
    Dl7Units units = const Dl7Units(),
  }) {
    if (!zarContent.contains('<AQUALUNG>')) return null;

    // Strip the outer wrapper BEFORE matching inner tags: with dotAll, the
    // lazy tag pattern would otherwise match <AQUALUNG>...</AQUALUNG> as one
    // giant token and allMatches would skip everything inside it. Tolerate a
    // missing closing tag (truncated exports) by taking everything after the
    // opening tag.
    final inner =
        _wrapperPattern.firstMatch(zarContent)?.group(1) ??
        zarContent.substring(
          zarContent.indexOf('<AQUALUNG>') + '<AQUALUNG>'.length,
        );

    final tags = <String, List<String>>{};
    for (final match in _tagPattern.allMatches(inner)) {
      (tags[match.group(1)!] ??= []).add(match.group(2)!.trim());
    }

    String? text(String tag) {
      final value = tags[tag]?.first.trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    final gearUnitsImperial = _gearUnitsImperial(text('GEAR'));

    // LOCATION: GPS=[lat,lon],LOCNAME=[..],CITY=[..],STATE/PROVINCE=[..],...
    final location = parseKeyValues(text('LOCATION') ?? '');
    double? latitude;
    double? longitude;
    final gps = location['GPS'];
    if (gps != null) {
      final parts = gps.split(',');
      if (parts.length == 2) {
        latitude = double.tryParse(parts[0].trim());
        longitude = double.tryParse(parts[1].trim());
      }
    }

    final stats = parseKeyValues(text('DIVESTATS') ?? '');
    final statMaxDepth = double.tryParse(stats['MAXDEPTH'] ?? '');
    final statMinTemp =
        double.tryParse(stats['MINTEMP'] ?? '') ??
        double.tryParse(location['MINTEMP'] ?? '');
    final statAvgDepth = double.tryParse(stats['AVGDEPTH'] ?? '');

    final tanks = <AqualungZarTank>[];
    for (final tankText in tags['TANK'] ?? const <String>[]) {
      tanks.add(_parseTank(tankText, gearUnitsImperial: gearUnitsImperial));
    }

    return AqualungZarData(
      app: text('APP'),
      duid: text('DUID'),
      title: text('TITLE'),
      pdcModel: text('PDC_MODEL'),
      pdcSerial: text('PDC_SERIAL'),
      pdcFirmware: text('PDC_FIRMWARE'),
      rating: int.tryParse(text('RATING') ?? ''),
      diveMode: int.tryParse(text('DIVE_MODE') ?? ''),
      diveNumber: int.tryParse(stats['DIVENO'] ?? ''),
      latitude: latitude,
      longitude: longitude,
      locationName: _nonEmpty(location['LOCNAME'] ?? location['DIVESITE']),
      city: _nonEmpty(location['CITY']),
      stateProvince: _nonEmpty(location['STATE/PROVINCE']),
      country: _nonEmpty(location['COUNTRY']),
      elapsedDiveTime: _parseHhmmss(stats['EDT']),
      surfaceInterval: _parseHhmmss(stats['SI']),
      maxDepthMeters: statMaxDepth != null
          ? units.depthToMeters(statMaxDepth)
          : null,
      minTempCelsius: statMinTemp != null
          ? units.tempToCelsius(statMinTemp)
          : null,
      avgDepthMeters: statAvgDepth != null
          ? units.depthToMeters(statAvgDepth)
          : null,
      tanks: tanks,
      decoTimePerSample: _parseIntArray(text('DECOTIME')),
    );
  }

  /// Splits `KEY=value,KEY=value` where a value wrapped in `[...]` may
  /// contain commas. Bracket wrapping is stripped from returned values.
  static Map<String, String> parseKeyValues(String input) {
    final result = <String, String>{};
    if (input.isEmpty) return result;
    final parts = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '[') {
        depth++;
      } else if (char == ']') {
        if (depth > 0) depth--;
      } else if (char == ',' && depth == 0) {
        parts.add(input.substring(start, i));
        start = i + 1;
      }
    }
    parts.add(input.substring(start));
    for (final part in parts) {
      final eq = part.indexOf('=');
      if (eq <= 0) continue;
      final key = part.substring(0, eq).trim();
      var value = part.substring(eq + 1).trim();
      if (value.startsWith('[') && value.endsWith(']')) {
        value = value.substring(1, value.length - 1).trim();
      }
      result[key] = value;
    }
    return result;
  }

  static bool _gearUnitsImperial(String? gearText) {
    if (gearText == null) return false;
    final gear = parseKeyValues(gearText);
    // GEAR_UNITS=0 means imperial in DiverLog+ exports.
    return gear['GEAR_UNITS'] == '0';
  }

  static AqualungZarTank _parseTank(
    String tankText, {
    required bool gearUnitsImperial,
  }) {
    final kv = parseKeyValues(tankText);

    double? positiveOrNull(double? value) =>
        (value == null || value <= 0) ? null : value;

    // WORKINGPRESSURE/CYLSIZE carry their own unit suffix ('3000PSI',
    // '80.0CU FT'); STARTPRESSURE/ENDPRESSURE are bare numbers whose unit
    // follows GEAR_UNITS (0 = PSI, 1 = bar).
    final working = _numberWithSuffix(kv['WORKINGPRESSURE']);
    final workingIsPsi = working == null
        ? gearUnitsImperial
        : working.suffix.contains('PSI');
    final workingBar = positiveOrNull(
      working == null
          ? null
          : (workingIsPsi ? working.value * Dl7Units.psiToBar : working.value),
    );

    double? barePressureToBar(String? raw) {
      final value = positiveOrNull(double.tryParse(raw ?? ''));
      if (value == null) return null;
      return gearUnitsImperial ? value * Dl7Units.psiToBar : value;
    }

    final size = _numberWithSuffix(kv['CYLSIZE']);
    final sizeIsCuFt = size == null
        ? gearUnitsImperial
        : size.suffix.contains('CU');
    double? volumeLiters;
    final sizeValue = positiveOrNull(size?.value);
    if (sizeValue != null) {
      if (sizeIsCuFt) {
        // Cubic-foot cylinder sizes are free-gas capacity at working
        // pressure; water capacity needs the working pressure to convert.
        if (workingBar != null) {
          volumeLiters = sizeValue * Dl7Units.cubicFeetToLiters / workingBar;
        }
      } else {
        volumeLiters = sizeValue;
      }
    }

    return AqualungZarTank(
      name: _nonEmpty(kv['CYLNAME']),
      o2Percent: positiveOrNull(double.tryParse(kv['FO2'] ?? '')),
      startPressureBar: barePressureToBar(kv['STARTPRESSURE']),
      endPressureBar: barePressureToBar(kv['ENDPRESSURE']),
      workingPressureBar: workingBar,
      volumeLiters: volumeLiters,
    );
  }

  static ({double value, String suffix})? _numberWithSuffix(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final match = RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*(.*)$').firstMatch(raw);
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!);
    if (value == null) return null;
    return (value: value, suffix: match.group(2)!.trim().toUpperCase());
  }

  static Duration? _parseHhmmss(String? raw) {
    final digits = raw?.trim();
    if (digits == null || !RegExp(r'^\d{6}$').hasMatch(digits)) return null;
    final result = Duration(
      hours: int.parse(digits.substring(0, 2)),
      minutes: int.parse(digits.substring(2, 4)),
      seconds: int.parse(digits.substring(4, 6)),
    );
    return result == Duration.zero ? null : result;
  }

  static List<int> _parseIntArray(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return [for (final part in raw.split(',')) ?int.tryParse(part.trim())];
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
