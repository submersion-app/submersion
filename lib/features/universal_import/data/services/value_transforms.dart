import 'dart:math' as math;

import 'package:intl/intl.dart';

/// Available value transforms for import field mapping.
///
/// Each transform converts a value from one unit/format to Submersion's
/// internal representation (metric units, Dart DateTime, etc.).
enum ValueTransform {
  feetToMeters,
  fahrenheitToCelsius,
  psiToBar,
  cubicFeetToLiters,
  minutesToSeconds,
  hmsToSeconds,
  visibilityScale,
  diveTypeMap,
  ratingScale;

  String get displayName => switch (this) {
    feetToMeters => 'ft -> m',
    fahrenheitToCelsius => 'F -> C',
    psiToBar => 'psi -> bar',
    cubicFeetToLiters => 'cuft -> L',
    minutesToSeconds => 'min -> sec',
    hmsToSeconds => 'H:M:S -> sec',
    visibilityScale => 'Visibility',
    diveTypeMap => 'Dive Type',
    ratingScale => 'Rating',
  };
}

/// Stateless service for applying value transforms during import.
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
        return DateFormat(format).parseStrict(value);
      } catch (_) {
        continue;
      }
    }

    return DateTime.tryParse(value);
  }

  /// Parse a time string using common time formats.
  DateTime? parseTime(String value) {
    final formats = ['HH:mm', 'H:mm', 'hh:mm a', 'h:mm a', 'HH:mm:ss'];

    for (final format in formats) {
      try {
        return DateFormat(format).parse(value);
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
