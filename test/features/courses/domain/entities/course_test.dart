import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';

Course _course({required DateTime startDate, DateTime? completionDate}) =>
    Course(
      id: 'c1',
      diverId: 'd1',
      name: 'Open Water',
      agency: CertificationAgency.padi,
      startDate: startDate,
      completionDate: completionDate,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('Course.durationDays', () {
    test('is null while in progress (no completion date)', () {
      final c = _course(startDate: DateTime(2026, 5, 27));
      expect(c.durationDays, isNull);
    });

    test('counts a 3-day course inclusively (start, middle, end)', () {
      // The user-reported case: an Open Water course from May 27 through
      // May 29 spans three training days, not two. Plain difference().inDays
      // is exclusive of the start, so this is an off-by-one against the
      // diver's mental model.
      final c = _course(
        startDate: DateTime(2026, 5, 27),
        completionDate: DateTime(2026, 5, 29),
      );
      expect(c.durationDays, 3);
    });

    test('a same-day course is 1 day, not 0', () {
      final c = _course(
        startDate: DateTime(2026, 5, 27),
        completionDate: DateTime(2026, 5, 27),
      );
      expect(c.durationDays, 1);
    });

    test('ignores time-of-day when counting calendar days', () {
      // The edit page seeds _startDate with DateTime.now() (has hh:mm),
      // while showDatePicker returns midnight. So saved courses can mix the
      // two. Duration must count calendar days regardless, not hours.
      final c = _course(
        startDate: DateTime(2026, 5, 27, 14, 0),
        completionDate: DateTime(2026, 5, 29, 9, 0),
      );
      expect(c.durationDays, 3);
    });
  });
}
