import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('CourseRepository error handling', () {
    late CourseRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = CourseRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('methods handle database errors gracefully', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      final now = DateTime.now();
      final course = Course(
        id: 'cr1',
        diverId: 'diver1',
        name: 'Advanced Open Water',
        agency: CertificationAgency.padi,
        startDate: now,
        createdAt: now,
        updatedAt: now,
      );

      // getAllCourses - rethrows
      await expectLater(repository.getAllCourses(), throwsA(anything));

      // getCourseById - rethrows
      await expectLater(repository.getCourseById('cr1'), throwsA(anything));

      // getInProgressCourses - rethrows
      await expectLater(repository.getInProgressCourses(), throwsA(anything));

      // getCompletedCourses - rethrows
      await expectLater(repository.getCompletedCourses(), throwsA(anything));

      // getCoursesByAgency - rethrows
      await expectLater(
        repository.getCoursesByAgency(CertificationAgency.padi),
        throwsA(anything),
      );

      // getCourseForDive - rethrows
      await expectLater(
        repository.getCourseForDive('dive1'),
        throwsA(anything),
      );

      // getCourseForCertification - rethrows
      await expectLater(
        repository.getCourseForCertification('cert1'),
        throwsA(anything),
      );

      // getDiveCountForCourse - rethrows
      await expectLater(
        repository.getDiveCountForCourse('cr1'),
        throwsA(anything),
      );

      // createCourse - rethrows
      await expectLater(repository.createCourse(course), throwsA(anything));

      // updateCourse - rethrows
      await expectLater(repository.updateCourse(course), throwsA(anything));

      // deleteCourse - rethrows
      await expectLater(repository.deleteCourse('cr1'), throwsA(anything));

      // linkDiveToCourse - rethrows
      await expectLater(
        repository.linkDiveToCourse('dive1', 'cr1'),
        throwsA(anything),
      );

      // unlinkDiveFromCourse - rethrows
      await expectLater(
        repository.unlinkDiveFromCourse('dive1'),
        throwsA(anything),
      );

      // linkCourseToCertification - rethrows
      await expectLater(
        repository.linkCourseToCertification('cr1', 'cert1'),
        throwsA(anything),
      );
    });
  });
}
