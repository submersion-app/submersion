import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/editing/course_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The course page's values and the rules its form keeps (issue #4527,
/// phase 3).
void main() {
  final course = Course(
    id: 'k1',
    diverId: 'd',
    name: 'Rescue',
    agency: 'padi',
    startDate: DateTime(2026, 3, 1),
    completionDate: DateTime(2026, 3, 9),
    instructorId: 'b1',
    instructorName: 'Sam',
    instructorNumber: '77',
    location: 'Reef Shop',
    notes: 'Good',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('switching completed on fills today', () {
    final today = DateTime(2026, 11, 19, 10, 30);
    expect(courseCompletedSwitched(true, now: today), today);
  });

  test('switching it off clears it', () {
    expect(courseCompletedSwitched(false), isNull);
  });

  test('a start after the completion date pulls it along', () {
    final picked = courseStartPicked(
      DateTime(2026, 4, 1),
      DateTime(2026, 3, 9),
    );
    expect(picked.start, DateTime(2026, 4, 1));
    expect(picked.completion, DateTime(2026, 4, 1));
  });

  test('a start before the completion date leaves it', () {
    final picked = courseStartPicked(
      DateTime(2026, 2, 1),
      DateTime(2026, 3, 9),
    );
    expect(picked.completion, DateTime(2026, 3, 9));
  });

  test('a blank name is invalid', () {
    expect(courseNameValid('  '), isFalse);
    expect(courseNameValid('Rescue'), isTrue);
  });

  test('bounds clamp a future start\'s completion picker', () {
    final bounds = courseDatePickerBounds(
      isStart: false,
      start: DateTime(2027, 6, 1),
      now: DateTime(2026, 11, 19),
    );
    expect(bounds.first, DateTime(2027, 6, 1));
    expect(bounds.last, DateTime(2100));
    expect(bounds.initial, DateTime(2027, 6, 1));
  });

  test('the start picker opens on the start, from 1950', () {
    final bounds = courseDatePickerBounds(
      isStart: true,
      start: DateTime(2028, 1, 1),
    );
    expect(bounds.first, DateTime(1950));
    expect(bounds.initial, DateTime(2028, 1, 1));
  });

  test('each field writes only its own value', () {
    final session = EditSession(course)
      ..set(courseNameField, ' Advanced ')
      ..set(courseLocationField, '  ')
      ..set(courseCompletionDateField, null)
      ..set(courseInstructorField, (id: null, name: 'Sam', number: null));

    final applied = session.applyTo(course);

    expect(applied.name, 'Advanced');
    expect(applied.location, isNull);
    expect(applied.completionDate, isNull);
    expect(applied.instructorId, isNull);
    expect(applied.instructorName, 'Sam');
    expect(applied.instructorNumber, isNull);
    expect(applied.notes, 'Good');
    expect(applied.agency, 'padi');
    expect(applied.startDate, DateTime(2026, 3, 1));
  });

  test('each field belongs to its card', () {
    expect(courseNameField.cardId, 'status');
    expect(courseAgencyField.cardId, 'details');
    expect(courseStartDateField.cardId, 'details');
    expect(courseCompletionDateField.cardId, 'details');
    expect(courseLocationField.cardId, 'details');
    expect(courseInstructorField.cardId, 'instructor');
    expect(courseNotesField.cardId, 'notes');
  });
}
