import 'package:uuid/uuid.dart';

import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';

/// Pure rules engine for the post-dive safety review.
///
/// Consumes a completed [ProfileAnalysis] (the Buhlmann replay of a recorded
/// profile) and emits neutral [SafetyFinding]s. Every rule runs every time;
/// per-rule visibility toggles are applied at display time so stored results
/// do not depend on settings.
class SafetyReviewService {
  /// Bump when rule logic or thresholds change. Stored reviews with an older
  /// version are recomputed lazily, so history is re-graded honestly instead
  /// of silently diverging from what the user was shown.
  static const int engineVersion = 1;

  const SafetyReviewService();

  List<SafetyFinding> review({
    required String diveId,
    required ProfileAnalysis analysis,
    required DateTime now,
    String Function()? idGenerator,
  }) {
    final nextId = idGenerator ?? const Uuid().v4;
    final findings = <SafetyFinding>[];

    findings.addAll(_rapidAscentFindings(diveId, analysis, now, nextId));

    return findings;
  }

  List<SafetyFinding> _rapidAscentFindings(
    String diveId,
    ProfileAnalysis analysis,
    DateTime now,
    String Function() nextId,
  ) {
    return [
      for (final violation in analysis.ascentRateViolations)
        SafetyFinding(
          id: nextId(),
          diveId: diveId,
          ruleId: SafetyRuleId.rapidAscent,
          severity: violation.isCritical
              ? SafetySeverity.significant
              : SafetySeverity.caution,
          startTimestamp: violation.startTimestamp,
          endTimestamp: violation.endTimestamp,
          value: violation.maxRate,
          engineVersion: engineVersion,
          createdAt: now,
        ),
    ];
  }
}
