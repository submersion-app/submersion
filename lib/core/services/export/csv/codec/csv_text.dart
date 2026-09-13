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
///
/// A value the diver typed as a quote followed by a formula character
/// (`'=1+1`) is inert already, but it gets a second quote too, so that
/// [unsanitizeCsvField] hands it back exactly.
String sanitizeCsvField(String? value) {
  if (value == null || value.isEmpty) return '';
  final guarded =
      _formulaLeaders.contains(value[0]) ||
      (value.length >= 2 &&
          value[0] == "'" &&
          _formulaLeaders.contains(value[1]));
  return guarded ? "'$value" : value;
}

/// Reverses [sanitizeCsvField]: drops one leading quote only when it guards
/// a formula character, or a typed quote before one, so every value the
/// diver typed survives the round trip.
String unsanitizeCsvField(String value) {
  final guarded =
      value.length >= 2 &&
      value[0] == "'" &&
      (_formulaLeaders.contains(value[1]) ||
          (value.length >= 3 &&
              value[1] == "'" &&
              _formulaLeaders.contains(value[2])));
  return guarded ? value.substring(1) : value;
}

/// [value] with [decimals] places, trailing zeros (and a bare point)
/// removed, always with `.` as the decimal separator.
String trimFixed(double value, int decimals) {
  final text = value.toStringAsFixed(decimals);
  if (!text.contains('.')) return text;
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}
