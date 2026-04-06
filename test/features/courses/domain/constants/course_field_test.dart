import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/courses/domain/constants/course_field.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  // A UnitFormatter backed by metric default settings.
  const units = UnitFormatter(AppSettings());

  // A representative Course entity for adapter tests.
  final testCourse = Course(
    id: 'course-1',
    diverId: 'diver-1',
    name: 'Advanced Open Water',
    agency: CertificationAgency.padi,
    startDate: DateTime(2024, 3, 1),
    completionDate: DateTime(2024, 3, 5),
    instructorName: 'Jane Smith',
    instructorNumber: 'INST-789',
    location: 'Gozo, Malta',
    notes: 'Completed all dives',
    createdAt: DateTime(2024, 3, 1),
    updatedAt: DateTime(2024, 3, 5),
  );

  final dateFormat = DateFormat.yMMMd();

  group('CourseFieldAdapter.allFields', () {
    test('has expected count matching CourseField.values', () {
      expect(
        CourseFieldAdapter.instance.allFields.length,
        equals(CourseField.values.length),
      );
    });

    test('contains all CourseField values', () {
      expect(
        CourseFieldAdapter.instance.allFields,
        containsAll(CourseField.values),
      );
    });
  });

  group('CourseFieldAdapter.fieldsByCategory', () {
    test('groups core fields together', () {
      final byCategory = CourseFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['core'],
        containsAll([
          CourseField.courseName,
          CourseField.agency,
          CourseField.location,
          CourseField.isCompleted,
        ]),
      );
    });

    test('groups dates fields together', () {
      final byCategory = CourseFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['dates'],
        containsAll([
          CourseField.startDate,
          CourseField.completionDate,
          CourseField.durationDays,
        ]),
      );
    });

    test('groups instructor fields together', () {
      final byCategory = CourseFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['instructor'],
        containsAll([CourseField.instructorName, CourseField.instructorNumber]),
      );
    });

    test('groups other fields together', () {
      final byCategory = CourseFieldAdapter.instance.fieldsByCategory;
      expect(byCategory['other'], containsAll([CourseField.notes]));
    });

    test('covers all CourseField values across categories', () {
      final byCategory = CourseFieldAdapter.instance.fieldsByCategory;
      final allGrouped = byCategory.values.expand((v) => v).toList();
      expect(allGrouped.length, equals(CourseField.values.length));
    });
  });

  group('CourseFieldAdapter.extractValue', () {
    final adapter = CourseFieldAdapter.instance;

    test('returns course name', () {
      expect(
        adapter.extractValue(CourseField.courseName, testCourse),
        equals('Advanced Open Water'),
      );
    });

    test('returns agency enum', () {
      expect(
        adapter.extractValue(CourseField.agency, testCourse),
        equals(CertificationAgency.padi),
      );
    });

    test('returns startDate', () {
      expect(
        adapter.extractValue(CourseField.startDate, testCourse),
        equals(DateTime(2024, 3, 1)),
      );
    });

    test('returns completionDate', () {
      expect(
        adapter.extractValue(CourseField.completionDate, testCourse),
        equals(DateTime(2024, 3, 5)),
      );
    });

    test('returns durationDays computed from completionDate - startDate', () {
      // Mar 5 - Mar 1 = 4 days
      expect(
        adapter.extractValue(CourseField.durationDays, testCourse),
        equals(4),
      );
    });

    test('returns null durationDays when completionDate is null', () {
      final inProgress = testCourse.clearCompletionDate();
      expect(
        adapter.extractValue(CourseField.durationDays, inProgress),
        isNull,
      );
    });

    test('returns instructorName', () {
      expect(
        adapter.extractValue(CourseField.instructorName, testCourse),
        equals('Jane Smith'),
      );
    });

    test('returns instructorNumber', () {
      expect(
        adapter.extractValue(CourseField.instructorNumber, testCourse),
        equals('INST-789'),
      );
    });

    test('returns location', () {
      expect(
        adapter.extractValue(CourseField.location, testCourse),
        equals('Gozo, Malta'),
      );
    });

    test('returns isCompleted as true when completionDate set', () {
      expect(adapter.extractValue(CourseField.isCompleted, testCourse), isTrue);
    });

    test('returns isCompleted as false when completionDate is null', () {
      final inProgress = testCourse.clearCompletionDate();
      expect(
        adapter.extractValue(CourseField.isCompleted, inProgress),
        isFalse,
      );
    });

    test('returns notes when non-empty', () {
      expect(
        adapter.extractValue(CourseField.notes, testCourse),
        equals('Completed all dives'),
      );
    });

    test('returns empty string for notes when empty', () {
      final emptyNotes = testCourse.copyWith(notes: '');
      expect(adapter.extractValue(CourseField.notes, emptyNotes), equals(''));
    });

    test('returns null for nullable fields when not set', () {
      final minimal = Course(
        id: 'min-1',
        diverId: 'diver-1',
        name: 'Basic',
        agency: CertificationAgency.ssi,
        startDate: DateTime(2024, 1, 1),
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      expect(adapter.extractValue(CourseField.completionDate, minimal), isNull);
      expect(adapter.extractValue(CourseField.instructorName, minimal), isNull);
      expect(
        adapter.extractValue(CourseField.instructorNumber, minimal),
        isNull,
      );
      expect(adapter.extractValue(CourseField.location, minimal), isNull);
    });
  });

  group('CourseFieldAdapter.formatValue', () {
    final adapter = CourseFieldAdapter.instance;

    test('returns -- for null value', () {
      expect(
        adapter.formatValue(CourseField.courseName, null, units),
        equals('--'),
      );
    });

    test('formats agency as enum name', () {
      expect(
        adapter.formatValue(
          CourseField.agency,
          CertificationAgency.padi,
          units,
        ),
        equals('padi'),
      );
    });

    test('formats startDate with DateFormat.yMMMd()', () {
      final dt = DateTime(2024, 3, 1);
      expect(
        adapter.formatValue(CourseField.startDate, dt, units),
        equals(dateFormat.format(dt)),
      );
    });

    test('formats completionDate with DateFormat.yMMMd()', () {
      final dt = DateTime(2024, 3, 5);
      expect(
        adapter.formatValue(CourseField.completionDate, dt, units),
        equals(dateFormat.format(dt)),
      );
    });

    test('formats durationDays as "X days"', () {
      expect(
        adapter.formatValue(CourseField.durationDays, 4, units),
        equals('4 days'),
      );
    });

    test('formats isCompleted true as "Yes"', () {
      expect(
        adapter.formatValue(CourseField.isCompleted, true, units),
        equals('Yes'),
      );
    });

    test('formats isCompleted false as "No"', () {
      expect(
        adapter.formatValue(CourseField.isCompleted, false, units),
        equals('No'),
      );
    });

    test('returns string values for text fields', () {
      expect(
        adapter.formatValue(
          CourseField.courseName,
          'Advanced Open Water',
          units,
        ),
        equals('Advanced Open Water'),
      );
    });

    test('returns string for instructorName', () {
      expect(
        adapter.formatValue(CourseField.instructorName, 'Jane Smith', units),
        equals('Jane Smith'),
      );
    });

    test('returns string for location', () {
      expect(
        adapter.formatValue(CourseField.location, 'Gozo, Malta', units),
        equals('Gozo, Malta'),
      );
    });

    test('returns -- for empty string in text fields', () {
      expect(adapter.formatValue(CourseField.notes, '', units), equals('--'));
    });

    test('returns -- for null durationDays', () {
      expect(
        adapter.formatValue(CourseField.durationDays, null, units),
        equals('--'),
      );
    });

    test('returns -- for null completionDate', () {
      expect(
        adapter.formatValue(CourseField.completionDate, null, units),
        equals('--'),
      );
    });
  });

  group('CourseFieldAdapter.fieldFromName', () {
    final adapter = CourseFieldAdapter.instance;

    test('resolves courseName', () {
      expect(
        adapter.fieldFromName('courseName'),
        equals(CourseField.courseName),
      );
    });

    test('resolves agency', () {
      expect(adapter.fieldFromName('agency'), equals(CourseField.agency));
    });

    test('resolves startDate', () {
      expect(adapter.fieldFromName('startDate'), equals(CourseField.startDate));
    });

    test('resolves completionDate', () {
      expect(
        adapter.fieldFromName('completionDate'),
        equals(CourseField.completionDate),
      );
    });

    test('resolves durationDays', () {
      expect(
        adapter.fieldFromName('durationDays'),
        equals(CourseField.durationDays),
      );
    });

    test('resolves instructorName', () {
      expect(
        adapter.fieldFromName('instructorName'),
        equals(CourseField.instructorName),
      );
    });

    test('resolves instructorNumber', () {
      expect(
        adapter.fieldFromName('instructorNumber'),
        equals(CourseField.instructorNumber),
      );
    });

    test('resolves location', () {
      expect(adapter.fieldFromName('location'), equals(CourseField.location));
    });

    test('resolves isCompleted', () {
      expect(
        adapter.fieldFromName('isCompleted'),
        equals(CourseField.isCompleted),
      );
    });

    test('resolves notes', () {
      expect(adapter.fieldFromName('notes'), equals(CourseField.notes));
    });

    test('throws for unknown field name', () {
      expect(() => adapter.fieldFromName('nonExistentField'), throwsStateError);
    });
  });

  group('CourseField EntityField properties', () {
    test('displayName is set for all fields', () {
      expect(CourseField.courseName.displayName, equals('Name'));
      expect(CourseField.agency.displayName, equals('Agency'));
      expect(CourseField.startDate.displayName, equals('Start Date'));
      expect(CourseField.completionDate.displayName, equals('Completion Date'));
      expect(CourseField.durationDays.displayName, equals('Duration'));
      expect(CourseField.instructorName.displayName, equals('Instructor Name'));
      expect(
        CourseField.instructorNumber.displayName,
        equals('Instructor Number'),
      );
      expect(CourseField.location.displayName, equals('Location'));
      expect(CourseField.isCompleted.displayName, equals('Completed'));
      expect(CourseField.notes.displayName, equals('Notes'));
    });

    test('shortLabel is set for all fields', () {
      expect(CourseField.courseName.shortLabel, equals('Name'));
      expect(CourseField.agency.shortLabel, equals('Agency'));
      expect(CourseField.startDate.shortLabel, equals('Started'));
      expect(CourseField.completionDate.shortLabel, equals('Completed'));
      expect(CourseField.durationDays.shortLabel, equals('Duration'));
      expect(CourseField.instructorName.shortLabel, equals('Instructor'));
      expect(CourseField.instructorNumber.shortLabel, equals('Instr. #'));
      expect(CourseField.location.shortLabel, equals('Location'));
      expect(CourseField.isCompleted.shortLabel, equals('Done'));
      expect(CourseField.notes.shortLabel, equals('Notes'));
    });

    test('icon is set for all fields', () {
      expect(CourseField.courseName.icon, equals(Icons.school));
      expect(CourseField.agency.icon, equals(Icons.business));
      expect(CourseField.startDate.icon, equals(Icons.play_arrow));
      expect(CourseField.completionDate.icon, equals(Icons.flag));
      expect(CourseField.durationDays.icon, equals(Icons.timer));
      expect(CourseField.instructorName.icon, equals(Icons.person));
      expect(CourseField.instructorNumber.icon, equals(Icons.badge));
      expect(CourseField.location.icon, equals(Icons.place));
      expect(CourseField.isCompleted.icon, equals(Icons.check_circle_outline));
      expect(CourseField.notes.icon, equals(Icons.notes));
    });

    test('defaultWidth is positive for all fields', () {
      for (final field in CourseField.values) {
        expect(field.defaultWidth, greaterThan(0), reason: field.name);
      }
    });

    test('specific defaultWidth values', () {
      expect(CourseField.courseName.defaultWidth, equals(150));
      expect(CourseField.agency.defaultWidth, equals(100));
      expect(CourseField.startDate.defaultWidth, equals(100));
      expect(CourseField.completionDate.defaultWidth, equals(100));
      expect(CourseField.durationDays.defaultWidth, equals(80));
      expect(CourseField.instructorName.defaultWidth, equals(120));
      expect(CourseField.instructorNumber.defaultWidth, equals(110));
      expect(CourseField.location.defaultWidth, equals(120));
      expect(CourseField.isCompleted.defaultWidth, equals(80));
      expect(CourseField.notes.defaultWidth, equals(150));
    });

    test('minWidth is positive and <= defaultWidth for all fields', () {
      for (final field in CourseField.values) {
        expect(field.minWidth, greaterThan(0), reason: field.name);
        expect(
          field.minWidth,
          lessThanOrEqualTo(field.defaultWidth),
          reason: field.name,
        );
      }
    });

    test('specific minWidth values', () {
      expect(CourseField.courseName.minWidth, equals(80));
      expect(CourseField.agency.minWidth, equals(60));
      expect(CourseField.startDate.minWidth, equals(70));
      expect(CourseField.completionDate.minWidth, equals(70));
      expect(CourseField.durationDays.minWidth, equals(60));
      expect(CourseField.instructorName.minWidth, equals(80));
      expect(CourseField.instructorNumber.minWidth, equals(70));
      expect(CourseField.location.minWidth, equals(70));
      expect(CourseField.isCompleted.minWidth, equals(50));
      expect(CourseField.notes.minWidth, equals(60));
    });

    test('sortable is correct for all fields', () {
      expect(CourseField.courseName.sortable, isTrue);
      expect(CourseField.agency.sortable, isTrue);
      expect(CourseField.startDate.sortable, isTrue);
      expect(CourseField.completionDate.sortable, isTrue);
      expect(CourseField.durationDays.sortable, isTrue);
      expect(CourseField.instructorName.sortable, isTrue);
      expect(CourseField.instructorNumber.sortable, isFalse);
      expect(CourseField.location.sortable, isTrue);
      expect(CourseField.isCompleted.sortable, isTrue);
      expect(CourseField.notes.sortable, isFalse);
    });

    test('categoryName is set for all fields', () {
      expect(CourseField.courseName.categoryName, equals('core'));
      expect(CourseField.agency.categoryName, equals('core'));
      expect(CourseField.location.categoryName, equals('core'));
      expect(CourseField.isCompleted.categoryName, equals('core'));
      expect(CourseField.startDate.categoryName, equals('dates'));
      expect(CourseField.completionDate.categoryName, equals('dates'));
      expect(CourseField.durationDays.categoryName, equals('dates'));
      expect(CourseField.instructorName.categoryName, equals('instructor'));
      expect(CourseField.instructorNumber.categoryName, equals('instructor'));
      expect(CourseField.notes.categoryName, equals('other'));
    });

    test('isRightAligned is only true for durationDays', () {
      expect(CourseField.durationDays.isRightAligned, isTrue);
      for (final field in CourseField.values) {
        if (field != CourseField.durationDays) {
          expect(field.isRightAligned, isFalse, reason: field.name);
        }
      }
    });
  });
}
