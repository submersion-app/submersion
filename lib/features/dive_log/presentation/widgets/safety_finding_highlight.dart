import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_highlight_range.dart';

/// Severity accent shared by the finding tile icon and the chart highlight.
/// Follows the safety spec's tone rules (muted, no alarm red): significant
/// maps to tertiary, everything else stays neutral.
Color safetySeverityColor(SafetySeverity severity, ColorScheme colorScheme) {
  return switch (severity) {
    SafetySeverity.significant => colorScheme.tertiary,
    SafetySeverity.info ||
    SafetySeverity.caution => colorScheme.onSurfaceVariant,
  };
}

/// Maps the selected finding to the chart's highlight parameter. Returns null
/// when nothing is selected or the finding has no start timestamp; a missing
/// end timestamp is treated as an instant at the start (the chart inflates
/// instants to a minimum-width band).
ProfileHighlightRange? profileHighlightRangeFor(
  SafetyFinding? finding,
  ColorScheme colorScheme,
) {
  if (finding == null) return null;
  final start = finding.startTimestamp;
  if (start == null) return null;
  final end = finding.endTimestamp ?? start;
  return ProfileHighlightRange(
    startTimestamp: start,
    endTimestamp: end,
    color: safetySeverityColor(finding.severity, colorScheme),
  );
}

/// The findings the profile chart's safety lane shows for [review]:
/// non-dismissed, rule-enabled, and placeable on the time axis (start
/// timestamp present), sorted by start time. [disabledRules] holds
/// [SafetyRuleId.dbValue] strings (settings.safetyReviewDisabledRules).
List<SafetyFinding> chartSafetyFindings(
  SafetyReview? review,
  Set<String> disabledRules,
) {
  if (review == null) return const [];
  final findings = review.findings
      .where(
        (f) =>
            !f.isDismissed &&
            !disabledRules.contains(f.ruleId.dbValue) &&
            f.startTimestamp != null,
      )
      .toList();
  findings.sort((a, b) => a.startTimestamp!.compareTo(b.startTimestamp!));
  return findings;
}
