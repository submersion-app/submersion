/// Shorthand-tolerant token parsing for paper logbook values.
///
/// These functions never throw; unparseable input returns null.
library;

class QuantityToken {
  final double value;

  /// Canonical lowercase unit token
  /// ('m','ft','bar','psi','c','f','min','l','cuft','kg','lbs','%')
  /// or null when the number is bare.
  final String? unit;

  const QuantityToken(this.value, this.unit);
}

final _quantityRe = RegExp(
  r'^([0-9]+(?:[.,][0-9]+)?)\s*'
  r"(k|m|ft|'|bar|psi|°?\s*c|°?\s*f|min|mins|l|cuft|kg|lbs|%)?\s*$",
  caseSensitive: false,
);

QuantityToken? parseQuantity(String raw) {
  final match = _quantityRe.firstMatch(raw.trim());
  if (match == null) return null;
  var value = double.parse(match.group(1)!.replaceAll(',', '.'));
  var unit = match.group(2)?.toLowerCase().replaceAll('°', '').trim();
  if (unit == 'k') {
    // Pressure shorthand: "3K" = 3000. Unit stays unknown.
    value *= 1000;
    unit = null;
  }
  if (unit == "'") unit = 'ft';
  if (unit == 'mins') unit = 'min';
  return QuantityToken(value, unit);
}

const _months = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

final _monthNameDateRe = RegExp(
  r"^([0-9]{1,2})\s+([a-z]{3,9})\.?,?\s+'?([0-9]{2,4})$",
  caseSensitive: false,
);
final _numericDateRe = RegExp(
  r'^([0-9]{1,4})[/.\-]([0-9]{1,2})[/.\-]([0-9]{2,4})$',
);

DateTime? parseDateToken(String raw, {required bool preferDayFirst}) {
  final text = raw.trim();
  DateTime? result;

  final named = _monthNameDateRe.firstMatch(text);
  if (named != null) {
    final month = _months[named.group(2)!.toLowerCase().substring(0, 3)];
    if (month != null) {
      result = _buildDate(
        _expandYear(int.parse(named.group(3)!)),
        month,
        int.parse(named.group(1)!),
      );
    }
  }

  if (result == null) {
    final numeric = _numericDateRe.firstMatch(text);
    if (numeric != null) {
      final a = int.parse(numeric.group(1)!);
      final b = int.parse(numeric.group(2)!);
      final c = int.parse(numeric.group(3)!);
      if (a > 999) {
        // ISO: yyyy-mm-dd
        result = _buildDate(a, b, c);
      } else {
        final year = _expandYear(c);
        if (a > 12 && b <= 12) {
          result = _buildDate(year, b, a); // a must be the day
        } else if (b > 12 && a <= 12) {
          result = _buildDate(year, a, b); // b must be the day
        } else if (preferDayFirst) {
          result = _buildDate(year, b, a);
        } else {
          result = _buildDate(year, a, b);
        }
      }
    }
  }

  if (result == null) return null;
  if (result.isAfter(DateTime.now())) return null;
  return result;
}

int _expandYear(int y) {
  if (y >= 1000) return y;
  final currentTwoDigit = DateTime.now().year % 100;
  return y <= currentTwoDigit ? 2000 + y : 1900 + y;
}

DateTime? _buildDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final d = DateTime(year, month, day);
  // DateTime normalizes overflow (Feb 30 -> Mar 2); reject that.
  if (d.month != month || d.day != day) return null;
  return d;
}

final _durationColonRe = RegExp(r'^([0-9]{1,2}):([0-9]{2})$');
final _durationMinRe = RegExp(
  r'^([0-9]{1,3})\s*(?:min|mins)?$',
  caseSensitive: false,
);

Duration? parseDurationToken(String raw) {
  final text = raw.trim();
  final colon = _durationColonRe.firstMatch(text);
  if (colon != null) {
    return Duration(
      hours: int.parse(colon.group(1)!),
      minutes: int.parse(colon.group(2)!),
    );
  }
  final mins = _durationMinRe.firstMatch(text);
  if (mins != null) return Duration(minutes: int.parse(mins.group(1)!));
  return null;
}

final _clockRe = RegExp(
  r'^([0-9]{1,2}):([0-9]{2})\s*(a|p|am|pm)?\.?$',
  caseSensitive: false,
);

({int hour, int minute})? parseClockToken(String raw) {
  final match = _clockRe.firstMatch(raw.trim());
  if (match == null) return null;
  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final suffix = match.group(3)?.toLowerCase();
  if (suffix != null && suffix.startsWith('p') && hour < 12) hour += 12;
  if (suffix != null && suffix.startsWith('a') && hour == 12) hour = 0;
  if (hour > 23 || minute > 59) return null;
  return (hour: hour, minute: minute);
}

final _o2Re = RegExp(
  r'^(?:ean\s*|nitrox\s*)?([0-9]{2,3})\s*%?$',
  caseSensitive: false,
);

double? parseO2Percent(String raw) {
  final text = raw.trim();
  final hasKeyword = RegExp(
    r'ean|nitrox|%',
    caseSensitive: false,
  ).hasMatch(text);
  if (!hasKeyword) return null;
  final match = _o2Re.firstMatch(text);
  if (match == null) return null;
  final value = double.parse(match.group(1)!);
  if (value < 21 || value > 100) return null;
  return value;
}
