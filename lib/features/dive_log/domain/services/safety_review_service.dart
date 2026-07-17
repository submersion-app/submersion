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
    findings.addAll(_missedDecoStopFindings(diveId, analysis, now, nextId));
    findings.addAll(_omittedSafetyStopFindings(diveId, analysis, now, nextId));
    findings.addAll(_highSurfaceGfFindings(diveId, analysis, now, nextId));

    return findings;
  }

  /// Contiguous ceiling-violation ranges shorter than this are ignored as
  /// sample noise.
  static const int _minViolationSeconds = 10;
  static const double _ceilingToleranceMeters = 0.5;

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

  /// Depth above (shallower than) the computed ceiling while in deco.
  List<SafetyFinding> _missedDecoStopFindings(
    String diveId,
    ProfileAnalysis analysis,
    DateTime now,
    String Function() nextId,
  ) {
    final samples = analysis.ascentRates;
    final n = samples.length;
    if (n == 0 ||
        analysis.ndlCurve.length != n ||
        analysis.ceilingCurve.length != n) {
      return const [];
    }

    final findings = <SafetyFinding>[];
    int? violationStart;
    var maxExcess = 0.0;

    void close(int endTimestamp) {
      if (violationStart == null) return;
      if (endTimestamp - violationStart! >= _minViolationSeconds) {
        findings.add(
          SafetyFinding(
            id: nextId(),
            diveId: diveId,
            ruleId: SafetyRuleId.missedDecoStop,
            severity: SafetySeverity.significant,
            startTimestamp: violationStart,
            endTimestamp: endTimestamp,
            value: maxExcess,
            engineVersion: engineVersion,
            createdAt: now,
          ),
        );
      }
      violationStart = null;
      maxExcess = 0.0;
    }

    for (var i = 0; i < n; i++) {
      final inDeco = analysis.ndlCurve[i] < 0;
      final ceiling = analysis.ceilingCurve[i];
      final depth = samples[i].depth;
      final excess = ceiling - depth; // positive = shallower than ceiling
      final violating =
          inDeco && ceiling > 0 && excess > _ceilingToleranceMeters;
      if (violating) {
        violationStart ??= samples[i].timestamp;
        if (excess > maxExcess) maxExcess = excess;
      } else {
        close(i > 0 ? samples[i - 1].timestamp : samples[i].timestamp);
      }
    }
    close(samples.last.timestamp);
    return findings;
  }

  static const double _safetyStopRelevantDepthMeters = 10.0;
  static const double _safetyStopCautionDepthMeters = 25.0;
  static const int _safetyStopRemainingThresholdSeconds = 30;
  static const double _surfacedDepthMeters = 1.0;

  /// The recommended safety stop was skipped or cut short. Reads the engine's
  /// own per-sample safety-stop credit (DecoStatus.safetyStopSeconds counts
  /// down as the diver accumulates time in the stop zone) instead of
  /// re-detecting stop holds.
  List<SafetyFinding> _omittedSafetyStopFindings(
    String diveId,
    ProfileAnalysis analysis,
    DateTime now,
    String Function() nextId,
  ) {
    if (analysis.decoStatuses.isEmpty || analysis.ascentRates.isEmpty) {
      return const [];
    }
    if (analysis.maxDepth <= _safetyStopRelevantDepthMeters) return const [];
    // Deco dives are handled by the missed-stop rule; the engine zeroes
    // safetyStopSeconds under a deco obligation anyway.
    if (analysis.hadDecoObligation) return const [];
    // Only meaningful when the profile actually ends at the surface.
    if (analysis.ascentRates.last.depth > _surfacedDepthMeters) {
      return const [];
    }
    final remaining = analysis.decoStatuses.last.safetyStopSeconds;
    if (remaining <= _safetyStopRemainingThresholdSeconds) return const [];
    return [
      SafetyFinding(
        id: nextId(),
        diveId: diveId,
        ruleId: SafetyRuleId.omittedSafetyStop,
        severity: analysis.maxDepth > _safetyStopCautionDepthMeters
            ? SafetySeverity.caution
            : SafetySeverity.info,
        startTimestamp: analysis.ascentRates.last.timestamp,
        endTimestamp: analysis.ascentRates.last.timestamp,
        value: remaining.toDouble(),
        engineVersion: engineVersion,
        createdAt: now,
      ),
    ];
  }

  /// Surfacing GF above the configured GF-high. Informational only: the
  /// diver ended the dive with less conservatism margin than they configured.
  List<SafetyFinding> _highSurfaceGfFindings(
    String diveId,
    ProfileAnalysis analysis,
    DateTime now,
    String Function() nextId,
  ) {
    if (analysis.decoStatuses.isEmpty) return const [];
    final last = analysis.decoStatuses.last;
    final surfGf = last.surfGf;
    final threshold = last.gfHigh * 100.0;
    if (surfGf <= threshold) return const [];
    return [
      SafetyFinding(
        id: nextId(),
        diveId: diveId,
        ruleId: SafetyRuleId.highSurfaceGf,
        severity: SafetySeverity.info,
        startTimestamp: analysis.ascentRates.isEmpty
            ? null
            : analysis.ascentRates.last.timestamp,
        endTimestamp: analysis.ascentRates.isEmpty
            ? null
            : analysis.ascentRates.last.timestamp,
        value: surfGf,
        engineVersion: engineVersion,
        createdAt: now,
      ),
    ];
  }
}
