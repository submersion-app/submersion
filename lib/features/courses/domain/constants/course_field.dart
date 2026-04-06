import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// Enumeration of every displayable field for the course table view.
enum CourseField implements EntityField {
  courseName,
  agency,
  startDate,
  completionDate,
  durationDays,
  instructorName,
  instructorNumber,
  location,
  isCompleted,
  notes;

  @override
  String get name => toString().split('.').last;

  @override
  String get displayName => switch (this) {
    CourseField.courseName => 'Name',
    CourseField.agency => 'Agency',
    CourseField.startDate => 'Start Date',
    CourseField.completionDate => 'Completion Date',
    CourseField.durationDays => 'Duration',
    CourseField.instructorName => 'Instructor Name',
    CourseField.instructorNumber => 'Instructor Number',
    CourseField.location => 'Location',
    CourseField.isCompleted => 'Completed',
    CourseField.notes => 'Notes',
  };

  @override
  String get shortLabel => switch (this) {
    CourseField.courseName => 'Name',
    CourseField.agency => 'Agency',
    CourseField.startDate => 'Started',
    CourseField.completionDate => 'Completed',
    CourseField.durationDays => 'Duration',
    CourseField.instructorName => 'Instructor',
    CourseField.instructorNumber => 'Instr. #',
    CourseField.location => 'Location',
    CourseField.isCompleted => 'Done',
    CourseField.notes => 'Notes',
  };

  @override
  IconData? get icon => switch (this) {
    CourseField.courseName => Icons.school,
    CourseField.agency => Icons.business,
    CourseField.startDate => Icons.play_arrow,
    CourseField.completionDate => Icons.flag,
    CourseField.durationDays => Icons.timer,
    CourseField.instructorName => Icons.person,
    CourseField.instructorNumber => Icons.badge,
    CourseField.location => Icons.place,
    CourseField.isCompleted => Icons.check_circle_outline,
    CourseField.notes => Icons.notes,
  };

  @override
  double get defaultWidth => switch (this) {
    CourseField.courseName => 150,
    CourseField.agency => 100,
    CourseField.startDate => 100,
    CourseField.completionDate => 100,
    CourseField.durationDays => 80,
    CourseField.instructorName => 120,
    CourseField.instructorNumber => 110,
    CourseField.location => 120,
    CourseField.isCompleted => 80,
    CourseField.notes => 150,
  };

  @override
  double get minWidth => switch (this) {
    CourseField.courseName => 80,
    CourseField.agency => 60,
    CourseField.startDate => 70,
    CourseField.completionDate => 70,
    CourseField.durationDays => 60,
    CourseField.instructorName => 80,
    CourseField.instructorNumber => 70,
    CourseField.location => 70,
    CourseField.isCompleted => 50,
    CourseField.notes => 60,
  };

  @override
  bool get sortable => switch (this) {
    CourseField.courseName => true,
    CourseField.agency => true,
    CourseField.startDate => true,
    CourseField.completionDate => true,
    CourseField.durationDays => true,
    CourseField.instructorName => true,
    CourseField.instructorNumber => false,
    CourseField.location => true,
    CourseField.isCompleted => true,
    CourseField.notes => false,
  };

  @override
  String get categoryName => switch (this) {
    CourseField.courseName => 'core',
    CourseField.agency => 'core',
    CourseField.location => 'core',
    CourseField.isCompleted => 'core',
    CourseField.startDate => 'dates',
    CourseField.completionDate => 'dates',
    CourseField.durationDays => 'dates',
    CourseField.instructorName => 'instructor',
    CourseField.instructorNumber => 'instructor',
    CourseField.notes => 'other',
  };

  @override
  bool get isRightAligned => switch (this) {
    CourseField.durationDays => true,
    _ => false,
  };
}

/// Adapter bridging [Course] entities with [CourseField] for the generic
/// table infrastructure.
class CourseFieldAdapter extends EntityFieldAdapter<Course, CourseField> {
  static final CourseFieldAdapter instance = CourseFieldAdapter._();
  CourseFieldAdapter._();

  static const List<CourseField> _allFields = CourseField.values;

  static final Map<String, List<CourseField>> _fieldsByCategory = () {
    final map = <String, List<CourseField>>{};
    for (final f in _allFields) {
      map.putIfAbsent(f.categoryName, () => []).add(f);
    }
    return map;
  }();

  static final DateFormat _dateFormat = DateFormat.yMMMd();

  @override
  List<CourseField> get allFields => _allFields;

  @override
  Map<String, List<CourseField>> get fieldsByCategory => _fieldsByCategory;

  @override
  dynamic extractValue(CourseField field, Course entity) {
    return switch (field) {
      CourseField.courseName => entity.name,
      CourseField.agency => entity.agency,
      CourseField.startDate => entity.startDate,
      CourseField.completionDate => entity.completionDate,
      CourseField.durationDays => entity.durationDays,
      CourseField.instructorName => entity.instructorName,
      CourseField.instructorNumber => entity.instructorNumber,
      CourseField.location => entity.location,
      CourseField.isCompleted => entity.isCompleted,
      CourseField.notes => entity.notes,
    };
  }

  @override
  String formatValue(CourseField field, dynamic value, UnitFormatter units) {
    if (value == null) return '--';
    return switch (field) {
      CourseField.agency => (value as CertificationAgency).name,
      CourseField.startDate => _dateFormat.format(value as DateTime),
      CourseField.completionDate => _dateFormat.format(value as DateTime),
      CourseField.durationDays => '${value as int} days',
      CourseField.isCompleted => (value as bool) ? 'Yes' : 'No',
      _ => value is String ? (value.isEmpty ? '--' : value) : value.toString(),
    };
  }

  @override
  CourseField fieldFromName(String name) {
    return CourseField.values.firstWhere((e) => e.name == name);
  }
}
