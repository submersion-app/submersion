import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level guards. The O2 card renders inside a chart overlay where a
/// golden or pump test is awkward, so these assert on the source instead --
/// enough to stop an English literal or a hardcoded unit reappearing.
void main() {
  final source = File(
    'lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart',
  ).readAsStringSync();

  test('has no hardcoded English display strings', () {
    const banned = [
      "'This Dive'",
      "'Daily'",
      "'Weekly'",
      "'Start: ",
      "'Prior: ",
      "this dive'",
      // Quote-anchored so a plain code comment mentioning the section name
      // is not mistaken for a display string.
      "'CNS progress ",
      " percent',",
    ];
    for (final phrase in banned) {
      expect(
        source.contains(phrase),
        isFalse,
        reason: '$phrase must come from ARB, not a literal',
      );
    }
  });

  test('max ppO2 depth is not hardcoded to meters', () {
    expect(
      source.contains("maxPpO2Depth.toStringAsFixed(1)}m'"),
      isFalse,
      reason: 'depth must go through UnitFormatter.formatDepth',
    );
    expect(
      source.contains('units.formatDepth(exposure.maxPpO2Depth'),
      isTrue,
      reason: 'depth must convert for the diver unit',
    );
  });

  test('duration suffixes come from ARB', () {
    expect(
      source.contains("return '\${seconds}s'"),
      isFalse,
      reason: 'duration abbreviations are English and must be localized',
    );
    expect(source.contains('formatter_duration_seconds'), isTrue);
    expect(source.contains('formatter_duration_minutesSeconds'), isTrue);
  });

  test('ppO2 stays in bar', () {
    // ppO2 is a physics unit, universal in diving regardless of the diver's
    // pressure preference. Converting it to psi would be wrong.
    expect(source.contains("toStringAsFixed(2)} bar'"), isTrue);
    expect(source.contains('convertPressure(selectedPpO2'), isFalse);
  });
}
