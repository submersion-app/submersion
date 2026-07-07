import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';
import 'package:submersion/features/ocr_import/domain/services/value_normalizer.dart';

class UnitDefaults {
  final bool depthFeet;
  final bool pressurePsi;
  final bool tempFahrenheit;
  final bool weightLbs;

  const UnitDefaults({
    required this.depthFeet,
    required this.pressurePsi,
    required this.tempFahrenheit,
    required this.weightLbs,
  });
}

/// Explicit unit tokens on the page vote for the page's unit system.
/// One imperial signal (ft or psi) makes the whole page imperial-leaning:
/// paper logs are written in one system. Blocks containing BOTH systems
/// ("5m/15ft stop", "bar/psi" template hints) are ambiguous and skipped.
UnitDefaults inferPageUnits(List<OcrTextBlock> blocks, UnitDefaults fallback) {
  var imperialVotes = 0;
  var metricVotes = 0;

  for (final b in blocks) {
    final text = b.text.toLowerCase();
    final hasImperial = RegExp(r'\b(ft|psi|f|lbs)\b').hasMatch(text);
    final hasMetric = RegExp(r'\b([0-9.]+\s*m|bar|c|kg)\b').hasMatch(text);
    if (hasImperial && hasMetric) continue; // template hint, ambiguous
    // Only count tokens attached to a number (real values, not prose).
    final q = parseQuantity(b.text);
    if (q?.unit == null) continue;
    switch (q!.unit) {
      case 'ft' || 'psi' || 'f' || 'lbs':
        imperialVotes++;
      case 'm' || 'bar' || 'c' || 'kg':
        metricVotes++;
    }
  }

  if (imperialVotes == metricVotes) return fallback;
  final imperial = imperialVotes > metricVotes;
  return UnitDefaults(
    depthFeet: imperial,
    pressurePsi: imperial,
    tempFahrenheit: imperial,
    weightLbs: imperial,
  );
}
