/// Unit type categories for dive-related measurements.
enum UnitType { depth, temperature, pressure, volume, weight }

/// Specific unit values that may appear in CSV data.
enum DetectedUnit {
  meters,
  feet,
  celsius,
  fahrenheit,
  bar,
  psi,
  liters,
  cubicFeet,
  kilograms,
  pounds,
}

/// How the unit was determined.
enum UnitSource { header, preset, heuristic, userOverride }

/// Unit detection result for a single CSV column.
class ColumnUnitDetection {
  final String columnName;
  final UnitType unitType;
  final DetectedUnit detected;
  final UnitSource source;
  final double confidence;

  const ColumnUnitDetection({
    required this.columnName,
    required this.unitType,
    required this.detected,
    required this.source,
    required this.confidence,
  });

  /// Returns true when the detected unit is imperial/non-SI and requires
  /// conversion before storage (feet, fahrenheit, psi, cubicFeet, pounds).
  bool get needsConversion {
    switch (detected) {
      case DetectedUnit.feet:
      case DetectedUnit.fahrenheit:
      case DetectedUnit.psi:
      case DetectedUnit.cubicFeet:
      case DetectedUnit.pounds:
        return true;
      case DetectedUnit.meters:
      case DetectedUnit.celsius:
      case DetectedUnit.bar:
      case DetectedUnit.liters:
      case DetectedUnit.kilograms:
        return false;
    }
  }
}

/// Detects units from CSV column headers, presets, or value heuristics.
///
/// Detection is per-column, not global.
class UnitDetector {
  const UnitDetector();

  // ---------------------------------------------------------------------------
  // Regex to extract a bracketed unit suffix from a header string.
  // Matches the last [...] in the header (after optional parenthesised groups).
  static final _bracketedUnit = RegExp(r'\[([^\]]+)\]\s*$');

  // ---------------------------------------------------------------------------
  /// Parse a bracketed unit suffix from a column header.
  ///
  /// Handles headers like `maxdepth [m]`, `watertemp [F]`, and
  /// `startpressure (1) [psi]`. Returns null when no recognised unit is found.
  ColumnUnitDetection? parseHeaderUnit(String header) {
    final match = _bracketedUnit.firstMatch(header);
    if (match == null) return null;

    final rawUnit = match.group(1)!.trim().toLowerCase();
    final unitAndType = _resolveUnitString(rawUnit);
    if (unitAndType == null) return null;

    return ColumnUnitDetection(
      columnName: header,
      unitType: unitAndType.$2,
      detected: unitAndType.$1,
      source: UnitSource.header,
      confidence: 1.0,
    );
  }

  // ---------------------------------------------------------------------------
  /// Detect the unit for [columnName] of [unitType] by examining [samples].
  ///
  /// Uses heuristics based on typical value ranges for each unit type.
  /// Returns null when [samples] is empty.
  ColumnUnitDetection? detectFromValues({
    required String columnName,
    required UnitType unitType,
    required List<double> samples,
  }) {
    if (samples.isEmpty) return null;

    final avg = samples.reduce((a, b) => a + b) / samples.length;

    DetectedUnit detected;
    double confidence;

    switch (unitType) {
      case UnitType.depth:
        if (avg > 100) {
          detected = DetectedUnit.feet;
          confidence = 0.85;
        } else if (avg < 80) {
          detected = DetectedUnit.meters;
          confidence = 0.85;
        } else {
          // 80-100 is ambiguous — could be shallow feet or deep metres.
          detected = DetectedUnit.meters;
          confidence = 0.5;
        }

      case UnitType.temperature:
        if (avg > 50) {
          detected = DetectedUnit.fahrenheit;
          confidence = 0.85;
        } else {
          detected = DetectedUnit.celsius;
          confidence = 0.85;
        }

      case UnitType.pressure:
        if (avg > 300) {
          detected = DetectedUnit.psi;
          confidence = 0.85;
        } else {
          detected = DetectedUnit.bar;
          confidence = 0.85;
        }

      case UnitType.volume:
        if (avg > 20) {
          detected = DetectedUnit.cubicFeet;
          confidence = 0.85;
        } else {
          detected = DetectedUnit.liters;
          confidence = 0.85;
        }

      case UnitType.weight:
        if (avg > 30) {
          detected = DetectedUnit.pounds;
          confidence = 0.85;
        } else {
          detected = DetectedUnit.kilograms;
          confidence = 0.85;
        }
    }

    return ColumnUnitDetection(
      columnName: columnName,
      unitType: unitType,
      detected: detected,
      source: UnitSource.heuristic,
      confidence: confidence,
    );
  }

  // ---------------------------------------------------------------------------
  /// Map a field name to its [UnitType] by checking for known substrings.
  ///
  /// Returns null for fields that do not carry a physical unit (e.g. date, notes).
  static UnitType? unitTypeForField(String fieldName) {
    final lower = fieldName.toLowerCase();
    if (lower.contains('depth')) return UnitType.depth;
    if (lower.contains('temp')) return UnitType.temperature;
    if (lower.contains('pressure')) return UnitType.pressure;
    if (lower.contains('volume')) return UnitType.volume;
    if (lower.contains('weight')) return UnitType.weight;
    return null;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Resolve a lowercase unit token to a ([DetectedUnit], [UnitType]) pair.
  ///
  /// Returns null for unrecognised tokens.
  (DetectedUnit, UnitType)? _resolveUnitString(String unit) {
    switch (unit) {
      case 'm':
      case 'meters':
        return (DetectedUnit.meters, UnitType.depth);
      case 'ft':
      case 'feet':
        return (DetectedUnit.feet, UnitType.depth);
      case 'c':
      case 'celsius':
        return (DetectedUnit.celsius, UnitType.temperature);
      case 'f':
      case 'fahrenheit':
        return (DetectedUnit.fahrenheit, UnitType.temperature);
      case 'bar':
        return (DetectedUnit.bar, UnitType.pressure);
      case 'psi':
        return (DetectedUnit.psi, UnitType.pressure);
      case 'l':
      case 'liters':
      case 'litres':
        return (DetectedUnit.liters, UnitType.volume);
      case 'cuft':
        return (DetectedUnit.cubicFeet, UnitType.volume);
      case 'kg':
      case 'kilograms':
        return (DetectedUnit.kilograms, UnitType.weight);
      case 'lbs':
      case 'pounds':
        return (DetectedUnit.pounds, UnitType.weight);
      default:
        return null;
    }
  }
}
