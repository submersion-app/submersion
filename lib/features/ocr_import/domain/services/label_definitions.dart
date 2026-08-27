/// Printed label vocabulary observed on real logbook templates
/// (PADI blue pages, PADI training log, generic third-party pages).
library;

enum LogField {
  diveNumber,
  date,
  siteName,
  location,
  timeIn,
  timeOut,
  bottomTime,
  maxDepth,
  startPressure,
  endPressure,
  waterTemp,
  airTemp,
  visibility,
  weight,
  buddy,
  divemaster,
  notes,
  o2Percent,
  rating,
}

class LabelDefinition {
  final LogField field;
  final RegExp pattern;

  const LabelDefinition(this.field, this.pattern);
}

/// Negative guards: a block matching any of these is NOT a field label,
/// even if a positive pattern also matches. Checked first.
final List<RegExp> labelStopList = [
  RegExp(r'certification\s*(no|#)', caseSensitive: false),
  RegExp(r'bottom\s*time\s*to\s*date', caseSensitive: false),
  RegExp(r'cumulative', caseSensitive: false),
  RegExp(r'time\s*this\s*dive', caseSensitive: false),
  RegExp(r'planned\s*time', caseSensitive: false),
  RegExp(r'verification\s*signature', caseSensitive: false),
];

/// Positive label patterns. Anchored (^...$ with optional colon)
/// so instructional prose does not match.
final List<LabelDefinition> labelDefinitions = [
  LabelDefinition(
    LogField.diveNumber,
    RegExp(r'^dive\s*(no\.?|#|number)\s*:?$', caseSensitive: false),
  ),
  LabelDefinition(LogField.date, RegExp(r'^date\s*:?$', caseSensitive: false)),
  LabelDefinition(
    LogField.siteName,
    RegExp(
      r'^(location|site|location/site\s*name|dive\s*site)\s*:?$',
      caseSensitive: false,
    ),
  ),
  LabelDefinition(
    LogField.location,
    RegExp(r'^country(/region)?\s*:?$', caseSensitive: false),
  ),
  LabelDefinition(
    LogField.timeIn,
    RegExp(r'^time\s*\(?in\)?\s*:?$', caseSensitive: false),
  ),
  LabelDefinition(
    LogField.timeOut,
    RegExp(r'^time\s*\(?out\)?\s*:?$', caseSensitive: false),
  ),
  LabelDefinition(
    LogField.bottomTime,
    RegExp(r'^(bottom\s*time|abt\+?|time)\s*:?=?$', caseSensitive: false),
  ),
  LabelDefinition(
    LogField.maxDepth,
    RegExp(r'^(max\.?\s*depth|depth|max)\s*:?$', caseSensitive: false),
  ),
  LabelDefinition(
    LogField.startPressure,
    RegExp(
      r'^(start(\s*\(?(psi|bar)\)?)?|air\s*in|start\s*psi/bar|bar/psi\s*start)\s*:?$',
      caseSensitive: false,
    ),
  ),
  LabelDefinition(
    LogField.endPressure,
    RegExp(
      r'^(end(\s*\(?(psi|bar)\)?)?|air\s*out|end\s*psi/bar|bar/psi\s*end)\s*:?$',
      caseSensitive: false,
    ),
  ),
  LabelDefinition(
    LogField.waterTemp,
    RegExp(
      r'^(bottom|water\s*temp\.?(\s*bottom)?)\s*:?$',
      caseSensitive: false,
    ),
  ),
  LabelDefinition(LogField.airTemp, RegExp(r'^air$', caseSensitive: false)),
  LabelDefinition(
    LogField.visibility,
    RegExp(r'^visibility(\s*\(?(m/ft|ft|m)\)?)?\s*:?$', caseSensitive: false),
  ),
  LabelDefinition(
    LogField.weight,
    RegExp(r'^weight(\s*used)?\s*:?$', caseSensitive: false),
  ),
  LabelDefinition(
    LogField.buddy,
    RegExp(r'^buddy\s*:?$', caseSensitive: false),
  ),
  LabelDefinition(
    LogField.divemaster,
    RegExp(
      r'^(divemaster|instructor|dive\s*master)\s*:?$',
      caseSensitive: false,
    ),
  ),
  LabelDefinition(
    LogField.notes,
    RegExp(
      r'^(comments?|notes?|dive\s*notes(\s*&\s*observations)?)\s*:?$',
      caseSensitive: false,
    ),
  ),
  LabelDefinition(
    LogField.o2Percent,
    RegExp(r'^(nitrox|o2|ean)\s*%?\s*:?$', caseSensitive: false),
  ),
  LabelDefinition(
    LogField.rating,
    RegExp(r'^rating\s*:?$', caseSensitive: false),
  ),
];
