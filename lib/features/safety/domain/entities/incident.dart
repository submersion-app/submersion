import 'package:equatable/equatable.dart';

/// Category taxonomy for near-miss reports, adapted from diving-incident
/// classifications. Structured categories keep entries reviewable later;
/// free-text-only logs rot.
enum IncidentCategory {
  buoyancy,
  gasSupply,
  equipment,
  buddySeparation,
  marineLife,
  boatSurface,
  medical,
  planning,
  other;

  String get dbValue => name;

  static IncidentCategory fromDbValue(String? value) {
    for (final c in IncidentCategory.values) {
      if (c.name == value) return c;
    }
    return IncidentCategory.other;
  }
}

/// Subjective severity of the near-miss.
enum IncidentSeverity {
  minor,
  moderate,
  serious;

  String get dbValue => name;

  static IncidentSeverity fromDbValue(String? value) {
    for (final s in IncidentSeverity.values) {
      if (s.name == value) return s;
    }
    return IncidentSeverity.minor;
  }
}

/// One near-miss report. Standalone (a boat/surface incident needs no logged
/// dive) but optionally linked to a dive. Private by default: synced between
/// the diver's own devices and included in backups, never in outbound
/// exports or shared logbook output.
class Incident extends Equatable {
  final String id;
  final String? diverId;
  final String? diveId;
  final DateTime occurredAt;
  final IncidentCategory category;
  final IncidentSeverity severity;
  final String narrative;
  final String? contributingFactors;
  final String? lessonsLearned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Incident({
    required this.id,
    this.diverId,
    this.diveId,
    required this.occurredAt,
    required this.category,
    required this.severity,
    required this.narrative,
    this.contributingFactors,
    this.lessonsLearned,
    required this.createdAt,
    required this.updatedAt,
  });

  Incident copyWith({
    String? id,
    String? diverId,
    String? diveId,
    bool clearDiveId = false,
    DateTime? occurredAt,
    IncidentCategory? category,
    IncidentSeverity? severity,
    String? narrative,
    String? contributingFactors,
    String? lessonsLearned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Incident(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      diveId: clearDiveId ? null : (diveId ?? this.diveId),
      occurredAt: occurredAt ?? this.occurredAt,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      narrative: narrative ?? this.narrative,
      contributingFactors: contributingFactors ?? this.contributingFactors,
      lessonsLearned: lessonsLearned ?? this.lessonsLearned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    diveId,
    occurredAt,
    category,
    severity,
    narrative,
    contributingFactors,
    lessonsLearned,
    createdAt,
    updatedAt,
  ];
}
