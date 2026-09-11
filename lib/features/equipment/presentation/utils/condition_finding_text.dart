import 'package:flutter/material.dart';

import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
import 'package:submersion/features/equipment/presentation/utils/observation_tag_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A percentage, median or decline the evidence did not carry renders as
/// this, never as a fabricated 0 that would read as "output fell 0
/// percent". Counts and the cell slot fill integer plural placeholders
/// instead, so a row missing one reads as its rule's name (see
/// [_integersFor]) rather than as "Cell 0" or "on 0 dives".
const _unknown = '--';

/// The whole-number inputs each rule's sentence needs.
List<String> _integersFor(ConditionRuleId rule) => switch (rule) {
  ConditionRuleId.cellDivergent ||
  ConditionRuleId.cellCurrentLimited ||
  ConditionRuleId.transmitterDropoutHigh ||
  ConditionRuleId.issueRecurring ||
  ConditionRuleId.incidentLinked => const ['count'],
  ConditionRuleId.issueColdCorrelated => const [
    'coldIssueDives',
    'warmIssueDives',
  ],
  ConditionRuleId.issueDeepCorrelated => const [
    'deepIssueDives',
    'shallowIssueDives',
  ],
  ConditionRuleId.cellOutputDeclining ||
  ConditionRuleId.cellOutputLow ||
  ConditionRuleId.transmitterDropoutRising => const [],
};

bool _isSlotRule(ConditionRuleId rule) => switch (rule) {
  ConditionRuleId.cellOutputDeclining ||
  ConditionRuleId.cellOutputLow ||
  ConditionRuleId.cellDivergent ||
  ConditionRuleId.cellCurrentLimited => true,
  _ => false,
};

/// The sentence for a finding, composed at render time from its evidence
/// with every number in the diver's units. No template names a date
/// prediction, a remaining life or a probability.
String conditionFindingTitle(
  EquipmentFinding finding,
  AppLocalizations l10n,
  UnitFormatter units, {
  required ExposureThresholds thresholds,
}) {
  final e = finding.evidence;
  double? v(String key) => e.values[key];
  // A missing count or slot would have to be invented; name the rule.
  if ((_isSlotRule(finding.ruleId) && e.slot == null) ||
      _integersFor(finding.ruleId).any((k) => v(k) == null)) {
    return conditionFindingShortLabel(finding.ruleId, l10n);
  }
  int count(String key) => v(key)!.round();
  String pct(double? fraction) =>
      fraction == null ? _unknown : (fraction * 100).round().toString();
  // Through the display helper, so a comma locale reads "41,2".
  String one(double? x) => x == null ? _unknown : formatFixedForDisplay(x, 1);
  final slot = e.slot ?? 0; // Checked above for every rule that reads it.
  // The drop the engine measured, rebuilt from its evidence medians rather
  // than the stored value, which a stale or partial row could misstate.
  String decline() {
    final recent = v('recentMedian');
    final baseline = v('baselineMedian');
    if (recent == null || baseline == null || baseline <= 0) return _unknown;
    return (100 * (1 - recent / baseline)).round().toString();
  }

  return switch (finding.ruleId) {
    ConditionRuleId.cellOutputDeclining =>
      l10n.equipmentCondition_finding_cellOutputDeclining(
        slot,
        decline(),
        e.n,
        units.formatDate(e.windowStart),
      ),
    ConditionRuleId.cellOutputLow =>
      l10n.equipmentCondition_finding_cellOutputLow(
        slot,
        one(v('recentMedian')),
        e.n,
      ),
    ConditionRuleId.cellDivergent =>
      l10n.equipmentCondition_finding_cellDivergent(
        slot,
        one(v('worstP95')),
        count('count'),
        e.n,
      ),
    ConditionRuleId.cellCurrentLimited =>
      l10n.equipmentCondition_finding_cellCurrentLimited(
        slot,
        count('count'),
        e.n,
        pct(v('worstFraction')),
      ),
    ConditionRuleId.transmitterDropoutRising =>
      l10n.equipmentCondition_finding_transmitterDropoutRising(
        pct(v('recentMean')),
        pct(v('priorMean')),
        e.n - 5,
      ),
    ConditionRuleId.transmitterDropoutHigh =>
      l10n.equipmentCondition_finding_transmitterDropoutHigh(
        pct(v('recentMean')),
        e.n,
        count('count'),
      ),
    ConditionRuleId.issueRecurring =>
      l10n.equipmentCondition_finding_issueRecurring(
        _tagLabel(e.tag, l10n),
        count('count'),
        e.n,
      ),
    ConditionRuleId.issueColdCorrelated =>
      l10n.equipmentCondition_finding_issueColdCorrelated(
        count('coldIssueDives'),
        count('coldIssueDives') + count('warmIssueDives'),
        units.formatTemperature(thresholds.coldWaterC, decimals: 0),
        e.n,
      ),
    ConditionRuleId.issueDeepCorrelated =>
      l10n.equipmentCondition_finding_issueDeepCorrelated(
        count('deepIssueDives'),
        count('deepIssueDives') + count('shallowIssueDives'),
        units.formatDepth(thresholds.deepDiveM, decimals: 0),
        e.n,
      ),
    ConditionRuleId.incidentLinked =>
      l10n.equipmentCondition_finding_incidentLinked(count('count')),
  };
}

/// "{n} dives, {range}": the evidence window under the sentence. For an
/// incident finding the range alone: its n counts incidents, which need not
/// name a dive, and the sentence above already gives the count.
String conditionFindingWindow(
  EquipmentFinding finding,
  AppLocalizations l10n,
  UnitFormatter units,
) {
  final e = finding.evidence;
  final range = units.formatDateRange(e.windowStart, e.windowEnd, l10n: l10n);
  if (finding.ruleId == ConditionRuleId.incidentLinked) return range;
  return l10n.equipmentCondition_finding_window(e.n, range);
}

/// Localized rule name only, the settings-page strings.
String conditionFindingShortLabel(ConditionRuleId rule, AppLocalizations l10n) {
  return switch (rule) {
    ConditionRuleId.cellOutputDeclining =>
      l10n.equipmentConditionSettings_rule_cellOutputDeclining,
    ConditionRuleId.cellOutputLow =>
      l10n.equipmentConditionSettings_rule_cellOutputLow,
    ConditionRuleId.cellDivergent =>
      l10n.equipmentConditionSettings_rule_cellDivergent,
    ConditionRuleId.cellCurrentLimited =>
      l10n.equipmentConditionSettings_rule_cellCurrentLimited,
    ConditionRuleId.transmitterDropoutRising =>
      l10n.equipmentConditionSettings_rule_transmitterDropoutRising,
    ConditionRuleId.transmitterDropoutHigh =>
      l10n.equipmentConditionSettings_rule_transmitterDropoutHigh,
    ConditionRuleId.issueRecurring =>
      l10n.equipmentConditionSettings_rule_issueRecurring,
    ConditionRuleId.issueColdCorrelated =>
      l10n.equipmentConditionSettings_rule_issueColdCorrelated,
    ConditionRuleId.issueDeepCorrelated =>
      l10n.equipmentConditionSettings_rule_issueDeepCorrelated,
    ConditionRuleId.incidentLinked =>
      l10n.equipmentConditionSettings_rule_incidentLinked,
  };
}

/// The service clock palette, so one page reads one scale: significant is
/// the overdue colour, caution the due-soon colour, info stays quiet.
Color conditionSeverityColor(ConditionSeverity severity, ColorScheme scheme) {
  return switch (severity) {
    ConditionSeverity.significant => scheme.error,
    ConditionSeverity.caution => scheme.tertiary,
    ConditionSeverity.info => scheme.onSurfaceVariant,
  };
}

String _tagLabel(String? dbValue, AppLocalizations l10n) {
  if (dbValue == null) return _unknown;
  final tag = ObservationTag.fromDbValue(dbValue);
  return tag?.localizedName(l10n) ?? dbValue;
}
