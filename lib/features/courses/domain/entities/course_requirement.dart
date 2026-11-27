import 'package:equatable/equatable.dart';

/// The shapes a course requirement can take.
enum RequirementKind {
  /// Progress derives from dives linked via course_requirement_dives.
  dive,

  /// Manual check-off (knowledge development, EFR prerequisite, swim test).
  checklist,

  /// Hours of closed-circuit time in the logbook, on any rebreather or on
  /// one from the equipment list. targetCount is in hours.
  ccrHours,

  /// Dives in the logbook matching a saved dive query (say, twenty dives
  /// deeper than 30 m). targetCount is the number of dives.
  diveQuery;

  /// Whether progress is counted from the logbook rather than from credited
  /// dives or a tick.
  bool get isDerived => this == ccrHours || this == diveQuery;

  static RequirementKind fromName(String? name) =>
      RequirementKind.values.asNameMap()[name] ?? RequirementKind.dive;
}

/// One countable requirement of a training course, e.g. "Deep adventure
/// dive" (dive, target 1) or "Knowledge development" (checklist).
class CourseRequirement extends Equatable {
  final String id;
  final String courseId;
  final String name;
  final RequirementKind kind;
  final int targetCount;
  final DateTime? completedAt;
  final int sortOrder;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The rebreather a [RequirementKind.ccrHours] requirement counts; null
  /// counts CCR time on any unit.
  final String? equipmentId;

  /// The stored dive query of a [RequirementKind.diveQuery] requirement.
  final String? queryJson;

  const CourseRequirement({
    required this.id,
    required this.courseId,
    required this.name,
    required this.kind,
    this.targetCount = 1,
    this.completedAt,
    this.sortOrder = 0,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.equipmentId,
    this.queryJson,
  });

  /// [equipmentId] and [queryJson] take a getter so a caller can set them to
  /// null: `equipmentId: () => null`.
  CourseRequirement copyWith({
    String? id,
    String? courseId,
    String? name,
    RequirementKind? kind,
    int? targetCount,
    DateTime? completedAt,
    int? sortOrder,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? Function()? equipmentId,
    String? Function()? queryJson,
  }) {
    return CourseRequirement(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      targetCount: targetCount ?? this.targetCount,
      completedAt: completedAt ?? this.completedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      equipmentId: equipmentId != null ? equipmentId() : this.equipmentId,
      queryJson: queryJson != null ? queryJson() : this.queryJson,
    );
  }

  /// copyWith cannot null out completedAt; unchecking a checklist item
  /// goes through this instead (same pattern as Course.clearCompletionDate).
  CourseRequirement clearCompletedAt() {
    return CourseRequirement(
      id: id,
      courseId: courseId,
      name: name,
      kind: kind,
      targetCount: targetCount,
      completedAt: null,
      sortOrder: sortOrder,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
      equipmentId: equipmentId,
      queryJson: queryJson,
    );
  }

  @override
  List<Object?> get props => [
    id,
    courseId,
    name,
    kind,
    targetCount,
    completedAt,
    sortOrder,
    notes,
    createdAt,
    updatedAt,
    equipmentId,
    queryJson,
  ];
}
