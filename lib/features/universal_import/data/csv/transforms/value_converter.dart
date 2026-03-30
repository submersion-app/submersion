import 'package:submersion/features/universal_import/data/csv/transforms/unit_detector.dart';

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
  /// - [DurationFormat.hms]: expects colon-separated H:MM, M:SS, or H:MM:SS.
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
    if (s.contains('crystal') || s.contains('crystal clear')) {
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
  /// - ≤0 → 1
  /// - 1–5 → as-is
  /// - 6–10 → divide by 2 (rounded)
  /// - 11–100 → divide by 20 (rounded)
  /// - >100 → 5
  ///
  /// Returns null for null, empty, or non-numeric input.
  int? normalizeRating(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = double.tryParse(raw.trim());
    if (value == null) return null;

    if (value <= 0) return 1;
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
