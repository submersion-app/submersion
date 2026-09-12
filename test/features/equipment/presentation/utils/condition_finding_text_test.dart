import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
import 'package:submersion/features/equipment/presentation/utils/condition_finding_text.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

/// Sentences are composed at render time from the evidence, in the diver's
/// units. No template names a date prediction or a probability.
void main() {
  final l10n = AppLocalizationsEn();
  const metric = UnitFormatter(AppSettings());
  const thresholds = ExposureThresholds.defaults;

  // DateFormat and the decimal separator read the process-global
  // Intl.defaultLocale, not an app locale; pin it so the English
  // expectations hold on any host.
  late String? savedLocale;
  setUp(() {
    savedLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() => Intl.defaultLocale = savedLocale);

  EquipmentFinding finding(
    ConditionRuleId rule, {
    Map<String, double> values = const {},
    int? slot,
    String? tag,
    double? value,
    int n = 14,
  }) {
    final evidence = FindingEvidence(
      n: n,
      windowStart: DateTime(2026, 3, 3),
      windowEnd: DateTime(2026, 6, 9),
      diveIds: const ['d1', 'd2'],
      values: values,
      slot: slot,
      tag: tag,
    );
    return EquipmentFinding(
      id: conditionFindingId('reg', rule, slot: slot, tag: tag),
      equipmentId: 'reg',
      ruleId: rule,
      severity: rule.severity,
      value: value,
      evidence: evidence,
      evidenceFingerprint: evidenceFingerprint(evidence),
      engineVersion: 1,
      createdAt: DateTime(2026, 6, 9),
    );
  }

  test(
    'the decline sentence carries slot, percent, n and the window start',
    () {
      final f = finding(
        ConditionRuleId.cellOutputDeclining,
        slot: 2,
        value: 22.4,
        values: {'recentMedian': 41.2, 'baselineMedian': 52.8},
      );
      expect(
        conditionFindingTitle(f, l10n, metric, thresholds: thresholds),
        'Cell 2 output fell 22 percent across 14 dives since Mar 3, 2026',
      );
    },
  );

  test('the decline percentage comes from its evidence medians', () {
    // The sentence is composed from the evidence. A stale or missing
    // stored value must not show a wrong figure, and missing medians show
    // the placeholder whatever the value says.
    final stale = finding(
      ConditionRuleId.cellOutputDeclining,
      slot: 2,
      value: 99,
      values: {'recentMedian': 41.2, 'baselineMedian': 52.8},
    );
    expect(
      conditionFindingTitle(stale, l10n, metric, thresholds: thresholds),
      contains('fell 22 percent'),
    );
    final noMedians = finding(
      ConditionRuleId.cellOutputDeclining,
      slot: 2,
      value: 22.4,
      values: const {},
    );
    expect(
      conditionFindingTitle(noMedians, l10n, metric, thresholds: thresholds),
      contains('fell -- percent'),
    );
  });

  test('a finding missing a count or its slot shows the rule name', () {
    // Counts and the slot fill integer plural placeholders. A malformed
    // row without them must not read "Cell 0" or "on 0 dives": the title
    // falls back to the rule's own name rather than invent a number.
    String title(EquipmentFinding f) =>
        conditionFindingTitle(f, l10n, metric, thresholds: thresholds);
    for (final f in [
      finding(
        ConditionRuleId.cellDivergent,
        slot: 2,
        values: {'worstP95': 0.2},
      ),
      finding(ConditionRuleId.cellOutputLow, values: {'recentMedian': 35}),
      finding(ConditionRuleId.incidentLinked),
      finding(
        ConditionRuleId.issueColdCorrelated,
        values: {'coldIssueDives': 3, 'coldDives': 8, 'warmDives': 33},
      ),
    ]) {
      expect(
        title(f),
        conditionFindingShortLabel(f.ruleId, l10n),
        reason: f.ruleId.name,
      );
    }
    // A complete row still reads as a sentence.
    expect(
      title(finding(ConditionRuleId.incidentLinked, values: {'count': 2})),
      isNot(conditionFindingShortLabel(ConditionRuleId.incidentLinked, l10n)),
    );
  });

  test('the cold correlation sentence shows the threshold in diver units', () {
    final f = finding(
      ConditionRuleId.issueColdCorrelated,
      values: {
        'coldIssueDives': 3,
        'coldDives': 8,
        'warmIssueDives': 1,
        'warmDives': 33,
      },
      n: 41,
    );
    const imperial = UnitFormatter(
      AppSettings(temperatureUnit: TemperatureUnit.fahrenheit),
    );
    expect(
      conditionFindingTitle(f, l10n, imperial, thresholds: thresholds),
      // The engine counts dives with an issue, not reports.
      '3 of 4 dives with an issue were colder than 50°F, over 41 dives '
      'with this item',
    );
    expect(
      conditionFindingTitle(f, l10n, metric, thresholds: thresholds),
      startsWith('3 of 4 dives with an issue were colder than 10°C'),
    );
  });

  test('cell sentences stay in bar for a psi diver', () {
    // A millivolt-per-bar gain and a ppO2 disagreement are sensor
    // quantities read against oxygen partial pressure, which the app
    // shows in bar everywhere; converting them to psi would name a figure
    // no dive computer or cell datasheet uses.
    const psi = UnitFormatter(AppSettings(pressureUnit: PressureUnit.psi));
    final low = finding(
      ConditionRuleId.cellOutputLow,
      slot: 1,
      values: {'recentMedian': 41.2},
    );
    final divergent = finding(
      ConditionRuleId.cellDivergent,
      slot: 3,
      values: {'worstP95': 0.2, 'count': 4},
    );
    for (final units in [psi, metric]) {
      expect(
        conditionFindingTitle(low, l10n, units, thresholds: thresholds),
        'Cell 1 output is 41.2 mV per bar over the last 14 dives',
      );
      expect(
        conditionFindingTitle(divergent, l10n, units, thresholds: thresholds),
        'Cell 3 disagreed with its peers by up to 0.2 bar on 4 of the '
        'last 14 dives',
      );
    }
  });

  test('the recurring sentence names the tag', () {
    final f = finding(
      ConditionRuleId.issueRecurring,
      values: {'count': 3},
      tag: 'freeFlow',
      n: 20,
    );
    expect(
      conditionFindingTitle(f, l10n, metric, thresholds: thresholds),
      'Free flow reported 3 times in the last 20 dives',
    );
  });

  test('linked incidents pluralise', () {
    expect(
      conditionFindingTitle(
        finding(ConditionRuleId.incidentLinked, values: {'count': 1}),
        l10n,
        metric,
        thresholds: thresholds,
      ),
      '1 incident names this item',
    );
    expect(
      conditionFindingTitle(
        finding(ConditionRuleId.incidentLinked, values: {'count': 3}),
        l10n,
        metric,
        thresholds: thresholds,
      ),
      '3 incidents name this item',
    );
  });

  test('a missing value renders a placeholder, never a fabricated zero', () {
    final f = finding(ConditionRuleId.cellOutputLow, slot: 1, n: 3);
    expect(
      conditionFindingTitle(f, l10n, metric, thresholds: thresholds),
      'Cell 1 output is -- mV per bar over the last 3 dives',
    );
  });

  test('the transmitter sentences use whole percentages', () {
    final rising = finding(
      ConditionRuleId.transmitterDropoutRising,
      values: {'recentMean': 0.12, 'priorMean': 0.03},
      n: 15,
    );
    expect(
      conditionFindingTitle(rising, l10n, metric, thresholds: thresholds),
      'Pressure dropped out for 12 percent of the last 5 dives, up from 3 '
      'percent over the 10 before',
    );
  });

  test('the window line counts dives and formats the range', () {
    final f = finding(ConditionRuleId.cellOutputLow, n: 1);
    expect(
      conditionFindingWindow(f, l10n, metric),
      '1 dive, Mar 3 - Jun 9, 2026',
    );
  });

  test('an incident window gives the range alone', () {
    // Its n counts incidents, and an incident need not name a dive, so
    // "3 dives" there would claim dives the evidence does not list.
    final f = finding(ConditionRuleId.incidentLinked, n: 3);
    expect(conditionFindingWindow(f, l10n, metric), 'Mar 3 - Jun 9, 2026');
  });

  test('one-decimal values use the locale decimal separator', () {
    final f = finding(
      ConditionRuleId.cellOutputLow,
      slot: 1,
      n: 3,
      values: {'recentMedian': 41.2},
    );
    Intl.defaultLocale = 'de';
    expect(
      conditionFindingTitle(f, l10n, metric, thresholds: thresholds),
      contains('41,2'),
    );
  });

  test('short labels reuse the settings rule names', () {
    expect(
      conditionFindingShortLabel(ConditionRuleId.cellDivergent, l10n),
      'Cell disagrees with its peers',
    );
  });

  test('severity colours follow the service clock palette', () {
    const scheme = ColorScheme.light();
    expect(
      conditionSeverityColor(ConditionSeverity.significant, scheme),
      scheme.error,
    );
    expect(
      conditionSeverityColor(ConditionSeverity.caution, scheme),
      scheme.tertiary,
    );
    expect(
      conditionSeverityColor(ConditionSeverity.info, scheme),
      scheme.onSurfaceVariant,
    );
  });
}
