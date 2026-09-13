/// Characters a spreadsheet would treat as the start of a formula.
const _formulaLeaders = {'=', '+', '-', '@', '\t', '\r', '|'};

/// Sanitize a string value to prevent CSV injection attacks.
///
/// Prefixes values starting with dangerous characters (=, +, -, @, tab,
/// carriage return, pipe) with a single quote, which forces spreadsheet
/// applications to treat the value as plain text.
///
/// A value that already starts with a quote gets one more, so an import
/// can undo the guard unambiguously: one leading quote is dropped when a
/// dangerous character or another quote follows it (#1814).
///
/// References:
/// - OWASP CSV Injection: https://owasp.org/www-community/attacks/CSV_Injection
String sanitizeCsvField(String? value) {
  if (value == null || value.isEmpty) return '';
  final guarded = _formulaLeaders.contains(value[0]) || value[0] == "'";
  return guarded ? "'$value" : value;
}

/// Reverses [sanitizeCsvField]: drops one leading quote when a formula
/// character or another quote follows it, so every value the diver typed
/// survives the round trip.
String unsanitizeCsvField(String value) {
  final guarded =
      value.length >= 2 &&
      value[0] == "'" &&
      (_formulaLeaders.contains(value[1]) || value[1] == "'");
  return guarded ? value.substring(1) : value;
}

/// [value] with [decimals] places, trailing zeros (and a bare point)
/// removed, always with `.` as the decimal separator.
String trimFixed(double value, int decimals) {
  final text = value.toStringAsFixed(decimals);
  if (!text.contains('.')) return text;
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}
