import 'package:submersion/features/buddies/presentation/editing/instructor_card_editor.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/editing/course_card_ids.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';

/// The course page's values a sitting edits, and the rules its form keeps
/// (issue #4527, phase 3).

final String _status = CourseCardId.status.name;
final String _details = CourseCardId.details.name;
final String _instructor = CourseCardId.instructor.name;
final String _notes = CourseCardId.notes.name;

const Object _keep = Object();

T? _or<T>(Object? value, T? kept) =>
    identical(value, _keep) ? kept : value as T?;

/// [c] with the given values, every other one kept. [Course.copyWith]
/// cannot clear a value, so the fields build the course whole, as the edit
/// form's save does.
Course _with(
  Course c, {
  String? name,
  String? agency,
  DateTime? startDate,
  Object? completionDate = _keep,
  Object? instructorId = _keep,
  Object? instructorName = _keep,
  Object? instructorNumber = _keep,
  Object? location = _keep,
  String? notes,
}) => Course(
  id: c.id,
  diverId: c.diverId,
  name: name ?? c.name,
  agency: agency ?? c.agency,
  startDate: startDate ?? c.startDate,
  completionDate: _or<DateTime>(completionDate, c.completionDate),
  instructorId: _or<String>(instructorId, c.instructorId),
  instructorName: _or<String>(instructorName, c.instructorName),
  instructorNumber: _or<String>(instructorNumber, c.instructorNumber),
  certificationId: c.certificationId,
  location: _or<String>(location, c.location),
  notes: notes ?? c.notes,
  createdAt: c.createdAt,
  updatedAt: c.updatedAt,
);

/// A blank optional value is stored as none, as the form stores it.
String? _orNone(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

bool _sameText(String? a, String? b) => _orNone(a) == _orNone(b);

/// The course's name, required, shown in the bar and edited on Status.
final courseNameField = EditField<Course, String>(
  id: 'name',
  cardId: _status,
  read: (c) => c.name,
  write: (c, v) => _with(c, name: v.trim()),
  equals: (a, b) => a.trim() == b.trim(),
);

final courseAgencyField = EditField<Course, String>(
  id: 'agency',
  cardId: _details,
  read: (c) => c.agency,
  write: (c, v) => _with(c, agency: v),
);

final courseStartDateField = EditField<Course, DateTime>(
  id: 'startDate',
  cardId: _details,
  read: (c) => c.startDate,
  write: (c, v) => _with(c, startDate: v),
);

/// When the course was completed; none while in progress. A Details value,
/// which the Status card's Mark completed also sets.
final courseCompletionDateField = EditField<Course, DateTime?>(
  id: 'completionDate',
  cardId: _details,
  read: (c) => c.completionDate,
  write: (c, v) => _with(c, completionDate: v),
);

final courseLocationField = EditField<Course, String?>(
  id: 'location',
  cardId: _details,
  read: (c) => c.location,
  write: (c, v) => _with(c, location: _orNone(v)),
  equals: _sameText,
);

/// The instructor: the buddy picked, and the name and number recorded. One
/// value, so a pick that fills all three is one change.
final courseInstructorField = EditField<Course, InstructorValue>(
  id: 'instructor',
  cardId: _instructor,
  read: (c) =>
      (id: c.instructorId, name: c.instructorName, number: c.instructorNumber),
  write: (c, v) => _with(
    c,
    instructorId: v.id,
    instructorName: _orNone(v.name),
    instructorNumber: _orNone(v.number),
  ),
  equals: (a, b) =>
      a.id == b.id &&
      _sameText(a.name, b.name) &&
      _sameText(a.number, b.number),
);

final courseNotesField = EditField<Course, String>(
  id: 'notes',
  cardId: _notes,
  read: (c) => c.notes,
  write: (c, v) => _with(c, notes: v.trim()),
  equals: (a, b) => a.trim() == b.trim(),
);

/// Whether [name] may be saved: the form's rule, a name is required.
bool courseNameValid(String name) => name.trim().isNotEmpty;

/// The completion date after the completed switch is set [on]: today, or
/// none, as the form does.
DateTime? courseCompletedSwitched(bool on, {DateTime? now}) =>
    on ? (now ?? DateTime.now()) : null;

/// The dates after a start date is picked: a completion date before the new
/// start becomes the start, as the form does.
({DateTime start, DateTime? completion}) courseStartPicked(
  DateTime start,
  DateTime? completion,
) => (
  start: start,
  completion: completion != null && completion.isBefore(start)
      ? start
      : completion,
);

/// The range and the opening date of a course's date picker, as the form's:
/// the start from 1950, the completion from the start, both to 2100, the
/// opening date clamped into that range (a completion defaults to today,
/// which precedes a future start).
({DateTime first, DateTime last, DateTime initial}) courseDatePickerBounds({
  required bool isStart,
  required DateTime start,
  DateTime? completion,
  DateTime? now,
}) {
  final first = isStart ? DateTime(1950) : start;
  final last = DateTime(2100);
  var initial = isStart ? start : (completion ?? now ?? DateTime.now());
  if (initial.isBefore(first)) {
    initial = first;
  } else if (initial.isAfter(last)) {
    initial = last;
  }
  return (first: first, last: last, initial: initial);
}
