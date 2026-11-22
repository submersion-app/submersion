import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/hand_set_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/hand_set_review_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// How the re-parse and resync dialog reads the values the diver set by
/// hand (issue #4909): in the diver's own units.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(
    AppSettings(
      depthUnit: DepthUnit.feet,
      temperatureUnit: TemperatureUnit.fahrenheit,
    ),
  );

  String text(HandSetField field, Object? value, [UnitFormatter? units]) =>
      handSetValueText(field, value, units ?? metric, l10n);

  test('depth and temperature follow the diver\'s units', () {
    expect(text(HandSetField.maxDepth, 30.0), metric.formatDepth(30));
    expect(text(HandSetField.maxDepth, 30.0, imperial), contains('ft'));
    expect(text(HandSetField.waterTemp, 24.0, imperial), contains('F'));
  });

  test('a duration shows its seconds, so close values read apart', () {
    expect(text(HandSetField.bottomTime, 2430), '40:30');
    expect(text(HandSetField.runtime, 2400), '40:00');
  });

  test('the start reads the entry time, else the dive\'s date', () {
    final instant = DateTime.utc(2026, 3, 1, 9, 30);
    final ms = instant.millisecondsSinceEpoch;
    expect(
      text(HandSetField.entryTime, (null, ms)),
      metric.formatDateTime(instant, l10n: l10n),
    );
    expect(
      text(HandSetField.entryTime, (ms, 0)),
      metric.formatDateTime(instant, l10n: l10n),
    );
  });

  test('mode, gradient factors and diluent read as on the dive page', () {
    expect(text(HandSetField.diveMode, 'ccr'), 'Closed Circuit Rebreather');
    expect(text(HandSetField.gradientFactorLow, 30), '30%');
    expect(text(HandSetField.diluent, (10.0, 50.0)), 'Tx 10/50');
  });

  test('a missing value reads as not set', () {
    expect(text(HandSetField.waterTemp, null), 'Not set');
    expect(text(HandSetField.diluent, (null, null)), 'Not set');
  });

  test('every field has a label', () {
    for (final field in HandSetField.values) {
      expect(handSetFieldLabel(field, l10n), isNotEmpty);
    }
  });
}
