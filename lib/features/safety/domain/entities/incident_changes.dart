import 'package:equatable/equatable.dart';

import 'package:submersion/features/safety/domain/entities/incident.dart';

/// What the near-miss editor's Save changes on a stored report (issue
/// #4527, phase 4); a null field is left as stored. Fields that can be
/// cleared are wrapped, so "clear" can be told from "unchanged".
class IncidentChanges extends Equatable {
  const IncidentChanges({
    this.occurredAt,
    this.category,
    this.severity,
    this.narrative,
    this.contributingFactors,
    this.lessonsLearned,
    this.equipmentId,
    this.link,
  });

  /// A timezone-stable wall-clock date, stored as UTC.
  final DateTime? occurredAt;
  final IncidentCategory? category;
  final IncidentSeverity? severity;
  final String? narrative;
  final ({String? value})? contributingFactors;
  final ({String? value})? lessonsLearned;
  final ({String? value})? equipmentId;

  /// The report's dive and its check-in, written together: a dive that came
  /// with a check-in goes when the check-in does.
  final ({String? diveId, String? observationId})? link;

  /// Nothing to write.
  bool get isEmpty =>
      occurredAt == null &&
      category == null &&
      severity == null &&
      narrative == null &&
      contributingFactors == null &&
      lessonsLearned == null &&
      equipmentId == null &&
      link == null;

  @override
  List<Object?> get props => [
    occurredAt,
    category,
    severity,
    narrative,
    contributingFactors,
    lessonsLearned,
    equipmentId,
    link,
  ];
}
