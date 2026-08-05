import 'package:equatable/equatable.dart';

/// The rule that produced a safety finding.
enum SafetyRuleId {
  rapidAscent,
  missedDecoStop,
  omittedSafetyStop,
  sawtoothProfile,
  highSurfaceGf;

  String get dbValue => name;

  static SafetyRuleId? fromDbValue(String value) {
    for (final rule in SafetyRuleId.values) {
      if (rule.name == value) return rule;
    }
    return null;
  }
}

/// Neutral severity scale for safety findings. Not alarm levels: the UI
/// renders these with muted styling per the safety-features spec.
enum SafetySeverity {
  info,
  caution,
  significant;

  String get dbValue => name;

  static SafetySeverity fromDbValue(String value) {
    for (final s in SafetySeverity.values) {
      if (s.name == value) return s;
    }
    return SafetySeverity.info;
  }
}

/// One observation from the post-dive safety review engine.
///
/// Findings carry the raw numbers (value, profile time range); user-facing
/// text is composed at display time from localized templates so stored rows
/// stay language-neutral.
class SafetyFinding extends Equatable {
  final String id;
  final String diveId;
  final SafetyRuleId ruleId;
  final SafetySeverity severity;

  /// Profile time range in seconds from dive start (null when the finding
  /// applies to the dive as a whole).
  final int? startTimestamp;
  final int? endTimestamp;

  /// Rule-specific value: peak ascent rate (m/min), max ceiling excess (m),
  /// remaining safety-stop seconds, sawtooth cycle count, or surface GF (%).
  final double? value;

  final int engineVersion;
  final DateTime? dismissedAt;
  final DateTime createdAt;

  const SafetyFinding({
    required this.id,
    required this.diveId,
    required this.ruleId,
    required this.severity,
    this.startTimestamp,
    this.endTimestamp,
    this.value,
    required this.engineVersion,
    this.dismissedAt,
    required this.createdAt,
  });

  bool get isDismissed => dismissedAt != null;

  SafetyFinding copyWith({
    String? id,
    String? diveId,
    SafetyRuleId? ruleId,
    SafetySeverity? severity,
    int? startTimestamp,
    int? endTimestamp,
    double? value,
    int? engineVersion,
    DateTime? dismissedAt,
    bool clearDismissedAt = false,
    DateTime? createdAt,
  }) {
    return SafetyFinding(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      ruleId: ruleId ?? this.ruleId,
      severity: severity ?? this.severity,
      startTimestamp: startTimestamp ?? this.startTimestamp,
      endTimestamp: endTimestamp ?? this.endTimestamp,
      value: value ?? this.value,
      engineVersion: engineVersion ?? this.engineVersion,
      dismissedAt: clearDismissedAt ? null : (dismissedAt ?? this.dismissedAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diveId,
    ruleId,
    severity,
    startTimestamp,
    endTimestamp,
    value,
    engineVersion,
    dismissedAt,
    createdAt,
  ];
}

/// A dive's stored safety review: the engine version it was produced with
/// plus all findings (including dismissed ones).
class SafetyReview extends Equatable {
  final String diveId;
  final int engineVersion;
  final DateTime reviewedAt;
  final List<SafetyFinding> findings;

  const SafetyReview({
    required this.diveId,
    required this.engineVersion,
    required this.reviewedAt,
    required this.findings,
  });

  List<SafetyFinding> get activeFindings =>
      findings.where((f) => !f.isDismissed).toList();

  @override
  List<Object?> get props => [diveId, engineVersion, reviewedAt, findings];
}
