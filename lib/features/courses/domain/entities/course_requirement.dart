import 'package:equatable/equatable.dart';

/// The two shapes a course requirement can take.
enum RequirementKind {
  /// Progress derives from dives linked via course_requirement_dives.
  dive,

  /// Manual check-off (knowledge development, EFR prerequisite, swim test).
  checklist;

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
  });

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
  ];
}
