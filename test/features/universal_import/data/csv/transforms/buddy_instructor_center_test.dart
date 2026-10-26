import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/transforms/buddy_instructor_center.dart';

/// Cells shaped as my.divessi.com's "Dive Buddy / Instructor / Center"
/// column really exports them (#3629).
void main() {
  const tabs8 = '\t\t\t\t\t\t\t\t';
  const indent = '                                    ';

  test('a buddy and the dive centre', () {
    final people = splitBuddyInstructorCenter(
      'Alex Diver$tabs8${indent}Example Dive Centre',
    );
    expect(people.buddies, ['Alex Diver']);
    expect(people.instructors, isEmpty);
    expect(people.diveCenter, 'Example Dive Centre');
  });

  test('a buddy, an SSI pro and the dive centre', () {
    final people = splitBuddyInstructorCenter(
      'Sam $tabs8$tabs8\t\tSSI Pro: Robin K. (98962) $tabs8\t\t'
      '${indent}Example Dive Centre',
    );
    expect(people.buddies, ['Sam']);
    expect(people.instructors, ['Robin K.']);
    expect(people.diveCenter, 'Example Dive Centre');
  });

  test('a dive centre with nobody before it is still the dive centre', () {
    final people = splitBuddyInstructorCenter(
      '$tabs8${indent}Example Dive Centre',
    );
    expect(people.buddies, isEmpty);
    expect(people.diveCenter, 'Example Dive Centre');
  });

  test('a lone name is a buddy', () {
    final people = splitBuddyInstructorCenter('Pat Lee');
    expect(people.buddies, ['Pat Lee']);
    expect(people.instructors, isEmpty);
    expect(people.diveCenter, isNull);
  });

  test('runs of spaces inside a name close up', () {
    final people = splitBuddyInstructorCenter('Dana  Smith');
    expect(people.buddies, ['Dana Smith']);
  });

  test('an SSI pro without a number keeps the whole name', () {
    final people = splitBuddyInstructorCenter('SSI Pro: Robin K.');
    expect(people.buddies, isEmpty);
    expect(people.instructors, ['Robin K.']);
  });

  test('an empty cell has nobody', () {
    final people = splitBuddyInstructorCenter('   ');
    expect(people.buddies, isEmpty);
    expect(people.instructors, isEmpty);
    expect(people.diveCenter, isNull);
  });
}
