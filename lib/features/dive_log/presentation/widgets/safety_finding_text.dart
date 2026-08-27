import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Full composed title for a finding (rule + key numbers), shared by the
/// safety section tiles and the chart lane callout.
String safetyFindingTitle(
  SafetyFinding finding,
  AppLocalizations l10n,
  UnitFormatter units,
) {
  // value is nullable in storage; a missing number (older/corrupt/malformed
  // sync row) must render a neutral placeholder rather than a fabricated 0
  // that would read as e.g. "Ascent exceeded 0/min".
  final value = finding.value;
  const unknown = '--';
  return switch (finding.ruleId) {
    SafetyRuleId.rapidAscent => l10n.safetyReview_rapidAscent_title(
      value == null ? unknown : '${units.formatDepth(value, decimals: 0)}/min',
      _durationOf(finding),
    ),
    SafetyRuleId.missedDecoStop => l10n.safetyReview_missedDecoStop_title(
      value == null ? unknown : units.formatDepth(value),
      _durationOf(finding),
    ),
    SafetyRuleId.omittedSafetyStop => l10n.safetyReview_omittedSafetyStop_title(
      value == null ? unknown : _formatSeconds(value.round()),
    ),
    // Sawtooth's only detail is the cycle count; with no value there is
    // nothing meaningful to interpolate, so fall back to the neutral rule
    // name instead of claiming "0 repeated up-and-down depth changes".
    SafetyRuleId.sawtoothProfile =>
      value == null
          ? l10n.safetySettings_rule_sawtoothProfile
          : l10n.safetyReview_sawtoothProfile_title(value.round()),
    SafetyRuleId.highSurfaceGf => l10n.safetyReview_highSurfaceGf_title(
      value == null ? unknown : '${value.toStringAsFixed(0)}%',
      // Pass a plain percentage (matching the surfaced-GF formatting) so the
      // localized template owns every word; no baked-in English "GF" token.
      '${units.settings.gfHigh}%',
    ),
  };
}

/// Localized rule name only (settings-page strings), for narrow contexts
/// like wide lane chips.
String safetyFindingShortLabel(SafetyFinding finding, AppLocalizations l10n) {
  return switch (finding.ruleId) {
    SafetyRuleId.rapidAscent => l10n.safetySettings_rule_rapidAscent,
    SafetyRuleId.missedDecoStop => l10n.safetySettings_rule_missedDecoStop,
    SafetyRuleId.omittedSafetyStop =>
      l10n.safetySettings_rule_omittedSafetyStop,
    SafetyRuleId.sawtoothProfile => l10n.safetySettings_rule_sawtoothProfile,
    SafetyRuleId.highSurfaceGf => l10n.safetySettings_rule_highSurfaceGf,
  };
}

String _durationOf(SafetyFinding finding) {
  final start = finding.startTimestamp;
  final end = finding.endTimestamp;
  if (start == null || end == null) return '--';
  return _formatSeconds(end - start);
}

String _formatSeconds(int totalSeconds) {
  if (totalSeconds < 60) return '${totalSeconds}s';
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return seconds == 0 ? '${minutes}m' : '${minutes}m ${seconds}s';
}
