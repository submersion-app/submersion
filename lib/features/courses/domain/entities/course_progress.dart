import 'package:equatable/equatable.dart';

import 'package:submersion/features/courses/domain/entities/course_requirement.dart';

/// A dive shown in the requirement tracker: either credited to a
/// requirement (linkId set) or offered as a suggestion (linkId null).
class RequirementDiveSummary extends Equatable {
  final String? linkId;
  final String diveId;
  final int? diveNumber;
  final DateTime dateTime;
  final String? siteName;

  const RequirementDiveSummary({
    this.linkId,
    required this.diveId,
    this.diveNumber,
    required this.dateTime,
    this.siteName,
  });

  @override
  List<Object?> get props => [linkId, diveId, diveNumber, dateTime, siteName];
}

/// A requirement plus its credited dives. Progress is derived, never stored:
/// stored counters would need cross-device conflict resolution, derived
/// counts just merge junction rows and recompute.
class CourseRequirementProgress extends Equatable {
  final CourseRequirement requirement;
  final List<RequirementDiveSummary> linkedDives;

  const CourseRequirementProgress({
    required this.requirement,
    required this.linkedDives,
  });

  int get creditCount => linkedDives.length;

  bool get isSatisfied => requirement.kind == RequirementKind.checklist
      ? requirement.completedAt != null
      : creditCount >= requirement.targetCount;

  @override
  List<Object?> get props => [requirement, linkedDives];
}

/// Roll-up of all requirements of one course.
class CourseProgress extends Equatable {
  final String courseId;
  final List<CourseRequirementProgress> requirements;

  const CourseProgress({required this.courseId, required this.requirements});

  int get satisfiedCount => requirements.where((r) => r.isSatisfied).length;

  int get totalCount => requirements.length;

  bool get isComplete => totalCount > 0 && satisfiedCount == totalCount;

  @override
  List<Object?> get props => [courseId, requirements];
}
