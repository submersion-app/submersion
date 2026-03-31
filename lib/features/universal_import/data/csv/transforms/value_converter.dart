import 'dart:math' as math;

import 'package:intl/intl.dart';

import 'package:submersion/features/universal_import/data/csv/transforms/unit_detector.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';

/// How a duration value is encoded in a CSV column.
enum DurationFormat {
  /// The value is a number of minutes (may be fractional, e.g. "45" or "45.5").
  minutes,

  /// The value is in H:MM:SS or M:SS / H:MM colon-separated format.
  hms,
}

/// Handles unit conversions, type coercion, and semantic field transforms
/// for CSV import.
///
/// All conversion methods are pure functions — no mutable state is kept.
class ValueConverter {
  const ValueConverter();

  // ---------------------------------------------------------------------------
  /// Convert [value] from [fromUnit] to the corresponding metric unit.
  ///
  /// Returns the value unchanged when [fromUnit] is already metric.
  /// Results for imperial conversions are rounded to 1 decimal place.
  double convertUnit(double value, DetectedUnit fromUnit) {
    switch (fromUnit) {
      case DetectedUnit.feet:
        return _round1(value * 0.3048);
      case DetectedUnit.fahrenheit:
        return _round1((value - 32) * 5 / 9);
      case DetectedUnit.psi:
        return _round1(value * 0.0689476);
      case DetectedUnit.cubicFeet:
        return _round1(value * 28.3168);
      case DetectedUnit.pounds:
        return _round1(value * 0.453592);
      case DetectedUnit.meters:
      case DetectedUnit.celsius:
      case DetectedUnit.bar:
      case DetectedUnit.liters:
      case DetectedUnit.kilograms:
        return value;
    }
  }

  // ---------------------------------------------------------------------------
  /// Parse a duration string according to [format].
  ///
  /// - [DurationFormat.minutes]: treats [raw] as a decimal number of minutes.
  /// - [DurationFormat.hms]: expects colon-separated M:SS or H:MM:SS.
  ///
  /// Returns null when [raw] is null, empty, or unparseable.
  Duration? parseDuration(String? raw, DurationFormat format) {
    if (raw == null || raw.trim().isEmpty) return null;
    final s = raw.trim();

    switch (format) {
      case DurationFormat.minutes:
        final minutes = double.tryParse(s);
        if (minutes == null) return null;
        return Duration(seconds: (minutes * 60).round());

      case DurationFormat.hms:
        final parts = s.split(':');
        if (parts.length == 2) {
          final a = int.tryParse(parts[0]);
          final b = int.tryParse(parts[1]);
          if (a == null || b == null) return null;
          // Two-part format is always M:SS (minutes:seconds).
          return Duration(minutes: a, seconds: b);
        } else if (parts.length == 3) {
          final h = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          final sec = int.tryParse(parts[2]);
          if (h == null || m == null || sec == null) return null;
          return Duration(hours: h, minutes: m, seconds: sec);
        }
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  /// Map a visibility string to a canonical identifier.
  ///
  /// Accepted identifiers: 'excellent', 'good', 'moderate', 'poor', 'unknown'.
  ///
  /// Also handles:
  /// - Descriptive phrases ("crystal clear", "murky").
  /// - Numeric strings interpreted as metres: >20→excellent, >10→good,
  ///   >5→moderate, ≤5→poor.
  ///
  /// Returns 'unknown' for unrecognised or null input.
  String parseVisibility(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'unknown';
    final s = raw.trim().toLowerCase();

    // Direct enum match.
    switch (s) {
      case 'excellent':
        return 'excellent';
      case 'good':
        return 'good';
      case 'moderate':
        return 'moderate';
      case 'poor':
        return 'poor';
      case 'unknown':
        return 'unknown';
    }

    // Descriptive text keywords.
    if (s.contains('crystal')) {
      return 'excellent';
    }
    if (s.contains('murky')) return 'poor';

    // Numeric metres.
    final metres = double.tryParse(s);
    if (metres != null) {
      if (metres > 20) return 'excellent';
      if (metres > 10) return 'good';
      if (metres > 5) return 'moderate';
      return 'poor';
    }

    return 'unknown';
  }

  // ---------------------------------------------------------------------------
  /// Normalize an arbitrary rating string to a 1–5 integer.
  ///
  /// Conversion rules:
  /// - ≤0 → null (no rating / unrated)
  /// - 1–5 → as-is
  /// - 6–10 → divide by 2 (rounded)
  /// - 11–100 → divide by 20 (rounded)
  /// - >100 → 5
  ///
  /// Returns null for null, empty, non-numeric, or zero/negative input.
  int? normalizeRating(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = double.tryParse(raw.trim());
    if (value == null) return null;

    if (value <= 0) return null;
    if (value <= 5) return value.round();
    if (value <= 10) return (value / 2).round();
    if (value <= 100) return (value / 20).round();
    return 5;
  }

  // ---------------------------------------------------------------------------
  /// Map a free-text dive type string to a canonical identifier.
  ///
  /// Known mappings (case-insensitive, matched by keyword):
  /// - training / student / course → 'training'
  /// - night → 'night'
  /// - deep → 'deep'
  /// - wreck → 'wreck'
  /// - drift → 'drift'
  /// - cave / cavern → 'cave'
  /// - technical / tec → 'technical'
  /// - freedive / free dive / apnea → 'freedive'
  /// - ice → 'ice'
  /// - altitude → 'altitude'
  /// - shore / beach → 'shore'
  /// - boat → 'boat'
  /// - liveaboard → 'liveaboard'
  ///
  /// Returns 'recreational' for null, empty, or unrecognised input.
  String parseDiveType(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'recreational';
    final s = raw.trim().toLowerCase();

    if (s.contains('training') ||
        s.contains('student') ||
        s.contains('course')) {
      return 'training';
    }
    if (s.contains('night')) return 'night';
    if (s.contains('deep')) return 'deep';
    if (s.contains('wreck')) return 'wreck';
    if (s.contains('drift')) return 'drift';
    if (s.contains('cavern') || s.contains('cave')) return 'cave';
    if (s.contains('technical') || s.contains('tec')) return 'technical';
    if (s.contains('freedive') ||
        s.contains('free dive') ||
        s.contains('apnea')) {
      return 'freedive';
    }
    if (s.contains('ice')) return 'ice';
    if (s.contains('altitude')) return 'altitude';
    if (s.contains('shore') || s.contains('beach')) return 'shore';
    if (s.contains('boat')) return 'boat';
    if (s.contains('liveaboard')) return 'liveaboard';

    return 'recreational';
  }

  // ---------------------------------------------------------------------------
  /// Parse [raw] as a [double], stripping commas and trailing non-numeric
  /// characters (but preserving leading minus and decimal points).
  ///
  /// Returns null for null, empty, or unparseable input.
  double? parseDouble(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    // Remove commas (thousands separators), then strip any chars that are not
    // digits, a decimal point, or a leading minus sign.
    final cleaned = raw
        .trim()
        .replaceAll(',', '')
        .replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  // ---------------------------------------------------------------------------
  /// Parse [raw] as an integer via [parseDouble] then rounding.
  ///
  /// Returns null for null, empty, or unparseable input.
  int? parseInt(String? raw) {
    final d = parseDouble(raw);
    return d?.round();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  double _round1(double value) {
    return (value * 10).round() / 10;
  }
}

/// Stateless service for applying [ValueTransform] enum transforms during
/// import.
///
/// All conversion functions are pure and side-effect-free. They handle
/// null and invalid inputs gracefully by returning null.
class ValueTransformService {
  const ValueTransformService();

  /// Apply a transform to a string value.
  ///
  /// Returns the transformed value, or null if the input is invalid.
  dynamic applyTransform(ValueTransform transform, String value) {
    if (value.trim().isEmpty) return null;

    return switch (transform) {
      ValueTransform.feetToMeters => feetToMeters(value),
      ValueTransform.fahrenheitToCelsius => fahrenheitToCelsius(value),
      ValueTransform.psiToBar => psiToBar(value),
      ValueTransform.cubicFeetToLiters => cubicFeetToLiters(value),
      ValueTransform.minutesToSeconds => minutesToSeconds(value),
      ValueTransform.hmsToSeconds => hmsToSeconds(value),
      ValueTransform.visibilityScale => parseVisibilityScale(value),
      ValueTransform.diveTypeMap => parseDiveType(value),
      ValueTransform.ratingScale => normalizeRating(value),
    };
  }

  // ======================== Unit Conversions ========================

  /// Convert feet to meters. Returns null if input is not a valid number.
  double? feetToMeters(String value) {
    final feet = _parseDouble(value);
    if (feet == null) return null;
    return _roundTo(feet * 0.3048, 1);
  }

  /// Convert Fahrenheit to Celsius. Returns null if input is not valid.
  double? fahrenheitToCelsius(String value) {
    final f = _parseDouble(value);
    if (f == null) return null;
    return _roundTo((f - 32) * 5 / 9, 1);
  }

  /// Convert PSI to bar. Returns null if input is not valid.
  double? psiToBar(String value) {
    final psi = _parseDouble(value);
    if (psi == null) return null;
    return _roundTo(psi * 0.0689476, 1);
  }

  /// Convert cubic feet to liters. Returns null if input is not valid.
  double? cubicFeetToLiters(String value) {
    final cuft = _parseDouble(value);
    if (cuft == null) return null;
    return _roundTo(cuft * 28.3168, 1);
  }

  /// Convert minutes string to Duration. Returns null if input is not valid.
  Duration? minutesToSeconds(String value) {
    final minutes = _parseDouble(value);
    if (minutes == null) return null;
    return Duration(seconds: (minutes * 60).round());
  }

  /// Convert H:M:S or M:S string to Duration.
  Duration? hmsToSeconds(String value) {
    final parts = value.split(':');
    if (parts.length == 3) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final s = int.tryParse(parts[2]);
      if (h != null && m != null && s != null) {
        return Duration(hours: h, minutes: m, seconds: s);
      }
    }
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]);
      final s = int.tryParse(parts[1]);
      if (m != null && s != null) {
        return Duration(minutes: m, seconds: s);
      }
    }
    return null;
  }

  // ======================== Scale Conversions ========================

  /// Parse visibility from various text/numeric representations.
  ///
  /// Returns a normalized string matching Submersion's Visibility enum names.
  String? parseVisibilityScale(String value) {
    final lower = value.toLowerCase().trim();

    // Text-based
    if (lower.contains('excellent') ||
        lower.contains('>30') ||
        lower.contains('>100')) {
      return 'excellent';
    }
    if (lower.contains('good') ||
        lower.contains('15-30') ||
        lower.contains('50-100')) {
      return 'good';
    }
    if (lower.contains('moderate') ||
        lower.contains('fair') ||
        lower.contains('5-15') ||
        lower.contains('15-50')) {
      return 'moderate';
    }
    if (lower.contains('poor') ||
        lower.contains('<5') ||
        lower.contains('<15')) {
      return 'poor';
    }

    // Numeric (meters)
    final meters = double.tryParse(lower);
    if (meters != null) {
      if (meters > 30) return 'excellent';
      if (meters > 15) return 'good';
      if (meters > 5) return 'moderate';
      return 'poor';
    }

    return 'unknown';
  }

  /// Map dive type text to Submersion's dive type identifiers.
  String parseDiveType(String value) {
    final lower = value.toLowerCase().trim();
    if (lower.contains('training') || lower.contains('course')) {
      return 'training';
    }
    if (lower.contains('night')) return 'night';
    if (lower.contains('deep')) return 'deep';
    if (lower.contains('wreck')) return 'wreck';
    if (lower.contains('drift')) return 'drift';
    if (lower.contains('cave') || lower.contains('cavern')) return 'cave';
    if (lower.contains('tech')) return 'technical';
    if (lower.contains('free')) return 'freedive';
    if (lower.contains('ice')) return 'ice';
    if (lower.contains('altitude')) return 'altitude';
    if (lower.contains('shore')) return 'shore';
    if (lower.contains('boat')) return 'boat';
    if (lower.contains('liveaboard')) return 'liveaboard';
    return 'recreational';
  }

  /// Normalize rating from various scales to 1-5.
  int? normalizeRating(String value) {
    final rating = _parseDouble(value);
    if (rating == null || rating <= 0) return null;

    // Already 1-5
    if (rating >= 1 && rating <= 5) return rating.round();

    // 1-10 scale
    if (rating > 5 && rating <= 10) {
      return (rating / 2).round().clamp(1, 5);
    }

    // 1-100 scale
    if (rating > 10 && rating <= 100) {
      return (rating / 20).round().clamp(1, 5);
    }

    return rating.round().clamp(1, 5);
  }

  // ======================== Date Parsing ========================

  /// Parse a date string using common date formats.
  ///
  /// Returns a UTC DateTime (wall-time convention). For naive strings without
  /// timezone info, the parsed components are stored as-is in UTC. For
  /// offset-aware ISO 8601 strings (e.g. "...Z" or "...+02:00"),
  /// `DateTime.tryParse` normalizes to UTC per the Dart spec.
  /// Tries multiple formats in order. Returns null if none match.
  DateTime? parseDate(String value) {
    final formats = [
      'yyyy-MM-dd',
      'MM/dd/yyyy',
      'dd/MM/yyyy',
      'yyyy/MM/dd',
      'dd-MM-yyyy',
      'MM-dd-yyyy',
      'dd.MM.yyyy',
      'yyyy.MM.dd',
    ];

    for (final format in formats) {
      try {
        return DateFormat(format).parseStrict(value, true);
      } catch (_) {
        continue;
      }
    }

    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    if (parsed.isUtc) return parsed;
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }

  /// Parse a time string using common time formats.
  ///
  /// Returns a UTC DateTime (wall-time convention).
  DateTime? parseTime(String value) {
    final formats = ['HH:mm', 'H:mm', 'hh:mm a', 'h:mm a', 'HH:mm:ss'];

    for (final format in formats) {
      try {
        return DateFormat(format).parse(value, true);
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  // ======================== Auto-Inference ========================

  /// Infer whether depth values are likely in feet (imperial) based on
  /// sample values and column name hints.
  ///
  /// Heuristic: values > 100 with "ft" or "feet" in header suggest imperial.
  static bool isLikelyFeet(List<String> sampleValues, String columnName) {
    final lower = columnName.toLowerCase();
    if (lower.contains('ft') || lower.contains('feet')) return true;
    if (lower.contains('meter') || lower.contains('m)')) return false;

    // Check if values look like feet (> 100 for recreational dives)
    final values = sampleValues
        .map((v) => double.tryParse(v.replaceAll(RegExp(r'[^\d.-]'), '')))
        .whereType<double>()
        .toList();
    if (values.isEmpty) return false;

    // If most values are > 100, likely feet
    final overHundred = values.where((v) => v > 100).length;
    return overHundred > values.length / 2;
  }

  /// Infer whether temperature values are likely Fahrenheit.
  static bool isLikelyFahrenheit(List<String> sampleValues, String columnName) {
    final lower = columnName.toLowerCase();
    if (lower.contains('f)') || lower.contains('fahrenheit')) return true;
    if (lower.contains('c)') || lower.contains('celsius')) return false;

    final values = sampleValues
        .map((v) => double.tryParse(v.replaceAll(RegExp(r'[^\d.-]'), '')))
        .whereType<double>()
        .toList();
    if (values.isEmpty) return false;

    // Water temps > 50 are likely Fahrenheit
    final overFifty = values.where((v) => v > 50).length;
    return overFifty > values.length / 2;
  }

  /// Infer whether pressure values are likely PSI.
  static bool isLikelyPsi(List<String> sampleValues, String columnName) {
    final lower = columnName.toLowerCase();
    if (lower.contains('psi')) return true;
    if (lower.contains('bar')) return false;

    final values = sampleValues
        .map((v) => double.tryParse(v.replaceAll(RegExp(r'[^\d.-]'), '')))
        .whereType<double>()
        .toList();
    if (values.isEmpty) return false;

    // Pressures > 500 are likely PSI (common range 2000-3500 psi vs 200-300 bar)
    final overFiveHundred = values.where((v) => v > 500).length;
    return overFiveHundred > values.length / 2;
  }

  // ======================== Helpers ========================

  double? _parseDouble(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^\d.-]'), '');
    return double.tryParse(cleaned);
  }

  double _roundTo(double value, int places) {
    final mod = math.pow(10.0, places);
    return (value * mod).roundToDouble() / mod;
  }
}
