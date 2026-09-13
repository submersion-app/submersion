/// Characters a spreadsheet would treat as the start of a formula.
const _formulaLeaders = {'=', '+', '-', '@', '\t', '\r', '|'};

/// Sanitize a string value to prevent CSV injection attacks.
///
/// Prefixes values starting with dangerous characters (=, +, -, @, tab,
/// carriage return, pipe) with a single quote, which forces spreadsheet
/// applications to treat the value as plain text.
///
/// References:
/// - OWASP CSV Injection: https://owasp.org/www-community/attacks/CSV_Injection
String sanitizeCsvField(String? value) {
  if (value == null || value.isEmpty) return '';
  return _formulaLeaders.contains(value[0]) ? "'$value" : value;
}

/// Reverses [sanitizeCsvField]: drops a leading quote only when it guards a
/// formula character, so a value the diver typed with a leading quote
/// survives the round trip.
String unsanitizeCsvField(String value) {
  if (value.length >= 2 &&
      value[0] == "'" &&
      _formulaLeaders.contains(value[1])) {
    return value.substring(1);
  }
  return value;
}

/// [value] with [decimals] places, trailing zeros (and a bare point)
/// removed, always with `.` as the decimal separator.
String trimFixed(double value, int decimals) {
  final text = value.toStringAsFixed(decimals);
  if (!text.contains('.')) return text;
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}
