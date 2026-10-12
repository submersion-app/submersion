import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_swatches.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/swatch_name.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('names a swatch by the nearest named equipment colour', () {
    expect(swatchName(l10n, const Color(0xFF00ACC1)), 'Cyan');
    expect(swatchName(l10n, const Color(0xFF3F51B5)), 'Blue');
    expect(swatchName(l10n, const Color(0xFFF44336)), 'Red');
  });

  test('names every swatch with a word, never a hex code', () {
    for (final c in profileMetricSwatches) {
      expect(swatchName(l10n, c), isNot(startsWith('#')));
    }
  });
}
