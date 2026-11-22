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

  test('values that read alike show more decimals', () {
    final pair = handSetValueTexts(
      const HandSetChange(
        field: HandSetField.maxDepth,
        storedValue: 30.04,
        parsedValue: 30.0,
      ),
      metric,
      l10n,
    );
    expect(pair.stored, metric.formatDepth(30.04, decimals: 2));
    expect(pair.parsed, metric.formatDepth(30.0, decimals: 2));
    expect(pair.stored, isNot(pair.parsed));
  });

  test('times that read alike show their seconds', () {
    final stored = DateTime.utc(2026, 3, 1, 9, 30, 0);
    final parsed = DateTime.utc(2026, 3, 1, 9, 30, 20);
    final start = handSetValueTexts(
      HandSetChange(
        field: HandSetField.entryTime,
        storedValue: (stored.millisecondsSinceEpoch, 0),
        parsedValue: (parsed.millisecondsSinceEpoch, 0),
      ),
      metric,
      l10n,
    );
    expect(start.stored, isNot(start.parsed));
    expect(start.parsed, contains(metric.formatTimeWithSeconds(parsed)));
    final exit = handSetValueTexts(
      HandSetChange(
        field: HandSetField.exitTime,
        storedValue: stored.millisecondsSinceEpoch,
        parsedValue: parsed.millisecondsSinceEpoch,
      ),
      metric,
      l10n,
    );
    expect(exit.parsed, metric.formatTimeWithSeconds(parsed));
  });

  test('values that read apart keep the usual decimals', () {
    final pair = handSetValueTexts(
      const HandSetChange(
        field: HandSetField.waterTemp,
        storedValue: 26.0,
        parsedValue: 22.0,
      ),
      metric,
      l10n,
    );
    expect(pair.stored, metric.formatTemperature(26));
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

  test('the exit reads as a time of day', () {
    final instant = DateTime.utc(2026, 3, 1, 10, 15);
    expect(
      text(HandSetField.exitTime, instant.millisecondsSinceEpoch),
      metric.formatTime(instant),
    );
  });

  test('mode, gradient factors and diluent read as on the dive page', () {
    expect(text(HandSetField.diveMode, 'ccr'), 'Closed Circuit Rebreather');
    expect(text(HandSetField.diveMode, 'oc'), 'Open Circuit');
    expect(text(HandSetField.diveMode, 'scr'), 'Semi-Closed Rebreather');
    expect(text(HandSetField.diveMode, 'gauge'), 'Gauge');
    expect(text(HandSetField.decoConservatism, 2), '2');
    expect(text(HandSetField.gradientFactorLow, 30), '30%');
    expect(text(HandSetField.diluent, (10.0, 50.0)), 'Tx 10/50');
  });

  test('a missing value reads as not set', () {
    expect(text(HandSetField.waterTemp, null), 'Not set');
    expect(text(HandSetField.diluent, null), 'Not set');
  });

  test('every field has a label', () {
    for (final field in HandSetField.values) {
      expect(handSetFieldLabel(field, l10n), isNotEmpty);
    }
  });

  testWidgets('a value switched to Replace and back is kept', (tester) async {
    Set<HandSetField>? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showHandSetReviewDialog(
              context,
              changes: const [
                HandSetChange(
                  field: HandSetField.waterTemp,
                  storedValue: 26.0,
                  parsedValue: 22.0,
                ),
                HandSetChange(
                  field: HandSetField.bottomTime,
                  storedValue: 2400,
                  parsedValue: 2280,
                ),
              ],
              source: HandSetReviewSource.file,
              units: metric,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Resync this dive?'), findsOneWidget);

    Finder choice(HandSetField field, String label) => find.descendant(
      of: find.byKey(ValueKey('handSetChoice_${field.name}')),
      matching: find.text(label),
    );
    await tester.tap(choice(HandSetField.waterTemp, 'Replace'));
    await tester.tap(choice(HandSetField.bottomTime, 'Replace'));
    await tester.pump();
    await tester.tap(choice(HandSetField.waterTemp, 'Keep'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Resync'));
    await tester.pumpAndSettle();

    expect(result, {HandSetField.bottomTime});
  });
}
