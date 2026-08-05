import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/course_templates.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_requirement_repository.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';

import '../../../../helpers/test_database.dart';

Future<void> _seedDiverAndCourse({int startDate = 5000}) async {
  final db = DatabaseService.instance.database;
  await db.customStatement(
    "INSERT INTO divers (id, name, created_at, updated_at) "
    "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
  );
  await db.customStatement(
    "INSERT INTO courses (id, diver_id, name, agency, start_date, "
    "created_at, updated_at) "
    "VALUES ('course-1', 'diver-1', 'AOW', 'padi', $startDate, 1000, 1000)",
  );
}

Future<void> _seedDive(
  String id, {
  int dateTime = 9000,
  String diverId = 'diver-1',
  String? courseId,
  String? siteId,
}) async {
  final db = DatabaseService.instance.database;
  final courseCol = courseId != null ? "'$courseId'" : 'NULL';
  final siteCol = siteId != null ? "'$siteId'" : 'NULL';
  await db.customStatement(
    "INSERT INTO dives (id, diver_id, dive_date_time, course_id, site_id, "
    "created_at, updated_at) "
    "VALUES ('$id', '$diverId', $dateTime, $courseCol, $siteCol, 1000, 1000)",
  );
}

void main() {
  late CourseRequirementRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = CourseRequirementRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('requirement CRUD', () {
    test('create assigns uuid, sortOrder increments per course', () async {
      await _seedDiverAndCourse();
      final first = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Deep adventure dive',
        kind: RequirementKind.dive,
      );
      final second = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Knowledge development',
        kind: RequirementKind.checklist,
      );
      expect(first.id.length, 36);
      expect(second.sortOrder, greaterThan(first.sortOrder));

      final progress = await repository.getCourseProgress('course-1');
      expect(progress.requirements.length, 2);
      expect(
        progress.requirements.first.requirement.name,
        'Deep adventure dive',
      );
    });

    test('setChecklistComplete sets and clears completedAt', () async {
      await _seedDiverAndCourse();
      final req = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Knowledge development',
        kind: RequirementKind.checklist,
      );
      await repository.setChecklistComplete(req.id, true);
      var progress = await repository.getCourseProgress('course-1');
      expect(progress.requirements.single.isSatisfied, isTrue);

      await repository.setChecklistComplete(req.id, false);
      progress = await repository.getCourseProgress('course-1');
      expect(progress.requirements.single.isSatisfied, isFalse);
    });

    test('switching a checked checklist requirement to dive clears '
        'completedAt', () async {
      await _seedDiverAndCourse();
      final req = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Knowledge development',
        kind: RequirementKind.checklist,
      );
      await repository.setChecklistComplete(req.id, true);
      var progress = await repository.getCourseProgress('course-1');
      expect(progress.requirements.single.requirement.completedAt, isNotNull);

      await repository.updateRequirement(
        progress.requirements.single.requirement.copyWith(
          kind: RequirementKind.dive,
        ),
      );

      progress = await repository.getCourseProgress('course-1');
      final updated = progress.requirements.single.requirement;
      expect(updated.kind, RequirementKind.dive);
      expect(updated.completedAt, isNull);
    });

    test('editing a checklist requirement preserves completedAt', () async {
      await _seedDiverAndCourse();
      final req = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Knowledge development',
        kind: RequirementKind.checklist,
      );
      await repository.setChecklistComplete(req.id, true);
      var progress = await repository.getCourseProgress('course-1');
      final completedAt = progress.requirements.single.requirement.completedAt;
      expect(completedAt, isNotNull);

      await repository.updateRequirement(
        progress.requirements.single.requirement.copyWith(name: 'Renamed'),
      );

      progress = await repository.getCourseProgress('course-1');
      final updated = progress.requirements.single.requirement;
      expect(updated.name, 'Renamed');
      expect(updated.completedAt, completedAt);
    });

    test(
      'deleteRequirement removes row and logs tombstones for links',
      () async {
        await _seedDiverAndCourse();
        await _seedDive('dive-1');
        final req = await repository.createRequirement(
          courseId: 'course-1',
          name: 'Deep adventure dive',
          kind: RequirementKind.dive,
        );
        await repository.linkDive(requirementId: req.id, diveId: 'dive-1');
        await repository.deleteRequirement(req.id);

        final progress = await repository.getCourseProgress('course-1');
        expect(progress.requirements, isEmpty);

        final db = DatabaseService.instance.database;
        final tombstones = await db
            .customSelect(
              "SELECT entity_type, record_id FROM deletion_log "
              "ORDER BY entity_type",
            )
            .get();
        final types = tombstones
            .map((r) => r.data['entity_type'] as String)
            .toList();
        expect(types, contains('courseRequirements'));
        expect(types, contains('courseRequirementDives'));
      },
    );
  });

  group('applyTemplate', () {
    test('copies all rows in order and appends on second apply', () async {
      await _seedDiverAndCourse();
      final aow = CourseTemplateCatalog.templates.firstWhere(
        (t) => t.id == 'advanced-open-water',
      );
      await repository.applyTemplate('course-1', aow);
      var progress = await repository.getCourseProgress('course-1');
      expect(progress.requirements.length, aow.requirements.length);
      expect(
        progress.requirements.first.requirement.name,
        aow.requirements.first.name,
      );

      await repository.applyTemplate('course-1', aow);
      progress = await repository.getCourseProgress('course-1');
      expect(progress.requirements.length, aow.requirements.length * 2);
    });
  });

  group('linkDive / unlinkDive', () {
    test(
      'link credits dive with deterministic id; relink is a no-op',
      () async {
        await _seedDiverAndCourse();
        await _seedDive('dive-1');
        final req = await repository.createRequirement(
          courseId: 'course-1',
          name: 'Elective adventure dives',
          kind: RequirementKind.dive,
          targetCount: 3,
        );
        await repository.linkDive(requirementId: req.id, diveId: 'dive-1');

        // A duplicate link must be a TRUE no-op: no parent updatedAt/hlc
        // bump, no sync churn (PR #601 review).
        final db = DatabaseService.instance.database;
        await db.customStatement(
          "UPDATE course_requirements SET updated_at = 1 "
          "WHERE id = '${req.id}'",
        );
        await repository.linkDive(requirementId: req.id, diveId: 'dive-1');
        final row = await db
            .customSelect(
              "SELECT updated_at FROM course_requirements "
              "WHERE id = '${req.id}'",
            )
            .getSingle();
        expect(row.data['updated_at'], 1);

        final progress = await repository.getCourseProgress('course-1');
        final reqProgress = progress.requirements.single;
        expect(reqProgress.creditCount, 1);
        expect(
          reqProgress.linkedDives.single.linkId,
          CourseRequirementRepository.linkIdFor(req.id, 'dive-1'),
        );
        expect(reqProgress.isSatisfied, isFalse);
      },
    );

    test('unlink removes credit and logs junction tombstone', () async {
      await _seedDiverAndCourse();
      await _seedDive('dive-1');
      final req = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Deep adventure dive',
        kind: RequirementKind.dive,
      );
      await repository.linkDive(requirementId: req.id, diveId: 'dive-1');
      await repository.unlinkDive(requirementId: req.id, diveId: 'dive-1');

      final progress = await repository.getCourseProgress('course-1');
      expect(progress.requirements.single.creditCount, 0);

      final db = DatabaseService.instance.database;
      final tombstones = await db
          .customSelect(
            "SELECT record_id FROM deletion_log "
            "WHERE entity_type = 'courseRequirementDives'",
          )
          .get();
      expect(
        tombstones.single.data['record_id'],
        CourseRequirementRepository.linkIdFor(req.id, 'dive-1'),
      );
    });

    test('a dive credits at most one requirement per course, but may '
        'credit requirements of a different course', () async {
      await _seedDiverAndCourse();
      await _seedDive('dive-1');
      final db = DatabaseService.instance.database;
      await db.customStatement(
        "INSERT INTO courses (id, diver_id, name, agency, start_date, "
        "created_at, updated_at) "
        "VALUES ('course-2', 'diver-1', 'Deep', 'padi', 1000, 1000, 1000)",
      );

      final deep = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Deep adventure dive',
        kind: RequirementKind.dive,
      );
      final elective = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Elective adventure dives',
        kind: RequirementKind.dive,
        targetCount: 3,
      );
      final otherCourse = await repository.createRequirement(
        courseId: 'course-2',
        name: 'Deep training dives',
        kind: RequirementKind.dive,
        targetCount: 4,
      );

      await repository.linkDive(requirementId: deep.id, diveId: 'dive-1');
      // Same course, different requirement: blocked (once per course).
      await repository.linkDive(requirementId: elective.id, diveId: 'dive-1');
      // Different course: allowed (deliberate, agencies differ).
      await repository.linkDive(
        requirementId: otherCourse.id,
        diveId: 'dive-1',
      );

      final course1 = await repository.getCourseProgress('course-1');
      final byId = {for (final p in course1.requirements) p.requirement.id: p};
      expect(byId[deep.id]!.creditCount, 1);
      expect(byId[elective.id]!.creditCount, 0);

      final course2 = await repository.getCourseProgress('course-2');
      expect(course2.requirements.single.creditCount, 1);
    });

    test('concurrent links of one dive to two requirements credit only '
        'one (once-per-course is atomic)', () async {
      await _seedDiverAndCourse();
      await _seedDive('dive-1');
      final deep = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Deep adventure dive',
        kind: RequirementKind.dive,
      );
      final elective = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Elective adventure dives',
        kind: RequirementKind.dive,
        targetCount: 3,
      );

      // Two rapid taps before providers refresh: both begin before either
      // commits. The transaction in linkDive must serialize them so the
      // dive is credited to exactly one requirement of the course.
      await Future.wait([
        repository.linkDive(requirementId: deep.id, diveId: 'dive-1'),
        repository.linkDive(requirementId: elective.id, diveId: 'dive-1'),
      ]);

      final progress = await repository.getCourseProgress('course-1');
      final total = progress.requirements.fold<int>(
        0,
        (sum, p) => sum + p.creditCount,
      );
      expect(total, 1);
    });

    test('linking bumps the parent requirement updatedAt (sync gate)', () async {
      await _seedDiverAndCourse();
      await _seedDive('dive-1');
      final req = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Deep adventure dive',
        kind: RequirementKind.dive,
      );
      final db = DatabaseService.instance.database;
      await db.customStatement(
        "UPDATE course_requirements SET updated_at = 1 WHERE id = '${req.id}'",
      );
      await repository.linkDive(requirementId: req.id, diveId: 'dive-1');
      final row = await db
          .customSelect(
            "SELECT updated_at FROM course_requirements "
            "WHERE id = '${req.id}'",
          )
          .getSingle();
      expect(row.data['updated_at'] as int, greaterThan(1));
    });
  });

  group('getSuggestedDives', () {
    test('suggests course-assigned and post-start dives, excludes linked '
        'and other-diver dives, newest first, capped at 10', () async {
      await _seedDiverAndCourse(startDate: 5000);

      final db = DatabaseService.instance.database;
      await db.customStatement(
        "INSERT INTO divers (id, name, created_at, updated_at) "
        "VALUES ('diver-2', 'Other', 1000, 1000)",
      );

      await _seedDive('before-start', dateTime: 4000);
      await _seedDive('after-start', dateTime: 6000);
      await _seedDive('assigned-old', dateTime: 3000, courseId: 'course-1');
      await _seedDive('other-diver', dateTime: 7000, diverId: 'diver-2');
      await _seedDive('linked', dateTime: 8000);

      final req = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Deep adventure dive',
        kind: RequirementKind.dive,
      );
      await repository.linkDive(requirementId: req.id, diveId: 'linked');

      final suggested = await repository.getSuggestedDives('course-1');
      final ids = suggested.map((s) => s.diveId).toList();
      expect(ids, ['after-start', 'assigned-old']);
      expect(ids, isNot(contains('before-start')));
      expect(ids, isNot(contains('other-diver')));
      expect(ids, isNot(contains('linked')));
      expect(suggested.first.linkId, isNull);
    });
  });

  group('deleteCourse tombstones', () {
    test(
      'deleting a course logs tombstones for requirements and links',
      () async {
        await _seedDiverAndCourse();
        await _seedDive('dive-1');
        final req = await repository.createRequirement(
          courseId: 'course-1',
          name: 'Deep adventure dive',
          kind: RequirementKind.dive,
        );
        await repository.linkDive(requirementId: req.id, diveId: 'dive-1');

        final courseRepository = CourseRepository();
        await courseRepository.deleteCourse('course-1');

        final db = DatabaseService.instance.database;
        final tombstones = await db
            .customSelect('SELECT entity_type FROM deletion_log')
            .get();
        final types = tombstones
            .map((r) => r.data['entity_type'] as String)
            .toSet();
        expect(
          types,
          containsAll({
            'courses',
            'courseRequirements',
            'courseRequirementDives',
          }),
        );
      },
    );
  });
}
