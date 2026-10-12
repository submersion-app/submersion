import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/courses/data/course_certification_links.dart';
import 'package:submersion/features/courses/data/dive_course_links.dart';
import 'package:submersion/features/courses/domain/entities/course.dart'
    as domain;
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

class CourseRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(CourseRepository);

  /// A dive's courses (issue #2515).
  DiveCourseLinks get _diveLinks => DiveCourseLinks(_db, _syncRepository);

  /// A course's certifications (issue #2515).
  CourseCertificationLinks get _certLinks =>
      CourseCertificationLinks(_db, _syncRepository);

  /// Get all courses ordered by start date (newest first)
  Future<List<domain.Course>> getAllCourses({String? diverId}) async {
    try {
      final query = _db.select(_db.courses)
        ..orderBy([
          (t) => OrderingTerm.desc(t.startDate),
          (t) => OrderingTerm.asc(t.name),
        ]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return rows.map(_mapRowToCourse).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get all courses', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Emits whenever the `courses` table changes so list providers can
  /// refresh after a sync or any other write.
  Stream<void> watchCoursesChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.courses));

  /// Emits whenever a dive-to-course or course-to-certification link may have
  /// changed (issue #2515), including through a sync apply.
  Stream<void> watchCourseLinkChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.dives),
      TableUpdateQuery.onTable(_db.diveCourses),
      TableUpdateQuery.onTable(_db.certifications),
    ]),
  );

  /// Get course by ID
  Future<domain.Course?> getCourseById(String id) async {
    try {
      final query = _db.select(_db.courses)..where((t) => t.id.equals(id));

      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToCourse(row) : null;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get course by id: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get courses for a specific diver
  Future<List<domain.Course>> getCoursesForDiver(String diverId) async {
    return getAllCourses(diverId: diverId);
  }

  /// Get in-progress courses (completionDate is null)
  Future<List<domain.Course>> getInProgressCourses({String? diverId}) async {
    try {
      final query = _db.select(_db.courses)
        ..where((t) => t.completionDate.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.startDate)]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return rows.map(_mapRowToCourse).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get in-progress courses',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get completed courses (completionDate is not null)
  Future<List<domain.Course>> getCompletedCourses({String? diverId}) async {
    try {
      final query = _db.select(_db.courses)
        ..where((t) => t.completionDate.isNotNull())
        ..orderBy([(t) => OrderingTerm.desc(t.completionDate)]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return rows.map(_mapRowToCourse).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get completed courses',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get courses by agency
  Future<List<domain.Course>> getCoursesByAgency(
    String agencyId, {
    String? diverId,
  }) async {
    try {
      final query = _db.select(_db.courses)
        ..where((t) => t.agency.equals(agencyId))
        ..orderBy([(t) => OrderingTerm.desc(t.startDate)]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return rows.map(_mapRowToCourse).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get courses by agency: $agencyId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// A dive's courses, the representative (`dives.course_id`) first, then by
  /// start date, name and id (issue #2515).
  // stats-scope-exempt: course credit is deliberate, not descriptive
  Future<List<domain.Course>> getCoursesForDive(String diveId) async {
    try {
      final results = await _db
          .customSelect(
            '''
        SELECT * FROM (
          SELECT c.* FROM dive_courses dc
          JOIN courses c ON c.id = dc.course_id
          WHERE dc.dive_id = ?1
          UNION
          SELECT c.* FROM dives d
          JOIN courses c ON c.id = d.course_id
          WHERE d.id = ?1
            AND NOT EXISTS (
              SELECT 1 FROM dive_courses x WHERE x.dive_id = d.id
            )
        ) u
        ORDER BY (u.id IS (SELECT course_id FROM dives WHERE id = ?1)) DESC,
          u.start_date, u.name, u.id
      ''',
            // The second arm is a representative-only link from an older app
            // version that the seed has not reached yet.
            variables: [Variable.withString(diveId)],
            readsFrom: {_db.diveCourses, _db.courses, _db.dives},
          )
          .get();
      return results.map(_mapQueryRowToCourse).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get courses for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get course for a specific certification
  Future<domain.Course?> getCourseForCertification(
    String certificationId,
  ) async {
    try {
      // The certification side is the truth since v288 (#2515);
      // courses.certification_id is only a representative.
      final results = await _db
          .customSelect(
            '''
        SELECT c.* FROM courses c
        INNER JOIN certifications cert ON cert.course_id = c.id
        WHERE cert.id = ?
      ''',
            variables: [Variable.withString(certificationId)],
          )
          .get();

      if (results.isEmpty) return null;
      return _mapQueryRowToCourse(results.first);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get course for certification: $certificationId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get count of dives for a course
  /// Deliberately does NOT apply DiveStatsScope. The diver linked this dive
  /// to the course on purpose; excluding it from statistics is a statement
  /// about their logbook averages, not a retraction of course credit. Do not
  /// "fix" this.
  // stats-scope-exempt: course credit is deliberate, not descriptive
  Future<int> getDiveCountForCourse(String courseId) async {
    try {
      final result = await _db
          .customSelect(
            '''
        SELECT COUNT(*) as count FROM dive_courses
        WHERE course_id = ?
      ''',
            variables: [Variable.withString(courseId)],
          )
          .getSingle();

      return result.data['count'] as int;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive count for course: $courseId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Search courses by name
  Future<List<domain.Course>> searchCourses(
    String query, {
    String? diverId,
  }) async {
    final searchTerm = '%${query.toLowerCase()}%';

    final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
    final variables = [
      Variable.withString(searchTerm),
      Variable.withString(searchTerm),
      if (diverId != null) Variable.withString(diverId),
    ];

    final results = await _db.customSelect('''
      SELECT * FROM courses
      WHERE (unicode_lower(name) LIKE ?
         OR unicode_lower(location) LIKE ?)
      $diverFilter
      ORDER BY start_date DESC, name ASC
    ''', variables: variables).get();

    return results.map(_mapQueryRowToCourse).toList();
  }

  /// Create a new course
  Future<domain.Course> createCourse(domain.Course course) async {
    try {
      _log.info('Creating course: ${course.name}');
      final id = course.id.isEmpty ? _uuid.v4() : course.id;
      final now = DateTime.now();

      await _db
          .into(_db.courses)
          .insert(
            CoursesCompanion(
              id: Value(id),
              diverId: Value(course.diverId),
              name: Value(course.name),
              agency: Value(course.agency),
              startDate: Value(course.startDate.millisecondsSinceEpoch),
              completionDate: Value(
                course.completionDate?.millisecondsSinceEpoch,
              ),
              instructorId: Value(course.instructorId),
              instructorName: Value(course.instructorName),
              instructorNumber: Value(course.instructorNumber),
              // certification_id is derived; CourseCertificationLinks owns
              // it (#2515).
              location: Value(course.location),
              notes: Value(course.notes),
              createdAt: Value(now.millisecondsSinceEpoch),
              updatedAt: Value(now.millisecondsSinceEpoch),
            ),
          );

      await _syncRepository.markRecordPending(
        entityType: 'courses',
        recordId: id,
        localUpdatedAt: now.millisecondsSinceEpoch,
      );
      SyncEventBus.notifyLocalChange();

      _log.info('Created course with id: $id');
      return course.copyWith(id: id, createdAt: now, updatedAt: now);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create course: ${course.name}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update an existing course
  Future<void> updateCourse(domain.Course course) async {
    try {
      _log.info('Updating course: ${course.id}');
      final now = DateTime.now().millisecondsSinceEpoch;

      final rowsAffected =
          await (_db.update(
            _db.courses,
          )..where((t) => t.id.equals(course.id))).write(
            CoursesCompanion(
              name: Value(course.name),
              agency: Value(course.agency),
              startDate: Value(course.startDate.millisecondsSinceEpoch),
              completionDate: Value(
                course.completionDate?.millisecondsSinceEpoch,
              ),
              instructorId: Value(course.instructorId),
              instructorName: Value(course.instructorName),
              instructorNumber: Value(course.instructorNumber),
              // certification_id is derived; CourseCertificationLinks owns
              // it (#2515).
              location: Value(course.location),
              notes: Value(course.notes),
              updatedAt: Value(now),
            ),
          );

      // A `where` clause that matches nothing is not an error to SQLite, so an
      // update against a missing (or empty) id would otherwise report success
      // while persisting nothing. Fail loudly instead of losing the edit.
      if (rowsAffected == 0) {
        throw StateError('No course found to update with id "${course.id}"');
      }

      await _syncRepository.markRecordPending(
        entityType: 'courses',
        recordId: course.id,
        localUpdatedAt: now,
      );
      // A dive's representative is its earliest course by start date, then
      // name, so editing either can move it (#2515). Only a dive whose value
      // actually changes is stamped for sync.
      final links = await (_db.select(
        _db.diveCourses,
      )..where((t) => t.courseId.equals(course.id))).get();
      for (final link in links) {
        await _diveLinks.refreshRepresentative(
          link.diveId,
          now: now,
          markPending: true,
        );
      }
      SyncEventBus.notifyLocalChange();
      _log.info('Updated course: ${course.id}');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update course: ${course.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a course
  ///
  /// The FK clears, the course delete, and every tombstone are wrapped in a
  /// single transaction (TripRepository.deleteTrip pattern). The requirement
  /// and link children are removed by FK cascade the moment the course row is
  /// deleted, but sync needs per-row tombstones (issue #466) or peers
  /// resurrect them; a non-atomic delete that failed after the cascade but
  /// before the tombstones would leave the children permanently gone locally
  /// yet un-tombstoned, so a peer would re-send them.
  Future<void> deleteCourse(String id) async {
    try {
      _log.info('Deleting course: $id');

      await _db.transaction(() async {
        final now = DateTime.now().millisecondsSinceEpoch;
        // Its documents go with it, tombstoned (issue #2613).
        await DocumentRepository().deleteForOwner(DocumentOwnerKind.course, id);

        // Its dive links go with it, tombstoned, and each affected dive's
        // representative moves to its next course (#2515). A dive that only
        // names the course in its representative column (an older app
        // version's link) is cleared the same way.
        final diveLinks = await (_db.select(
          _db.diveCourses,
        )..where((t) => t.courseId.equals(id))).get();
        final legacyDives = await (_db.select(
          _db.dives,
        )..where((t) => t.courseId.equals(id))).get();
        await (_db.delete(
          _db.diveCourses,
        )..where((t) => t.courseId.equals(id))).go();
        for (final link in diveLinks) {
          await _syncRepository.logDeletion(
            entityType: 'diveCourses',
            recordId: link.id,
          );
        }
        for (final diveId in {
          for (final l in diveLinks) l.diveId,
          for (final d in legacyDives) d.id,
        }) {
          await _diveLinks.refreshRepresentative(
            diveId,
            now: now,
            markPending: true,
          );
        }

        // Clear courseId from any linked certifications
        final certIds = [
          for (final c in await (_db.select(
            _db.certifications,
          )..where((t) => t.courseId.equals(id))).get())
            c.id,
        ];
        await _db.customStatement(
          'UPDATE certifications SET course_id = NULL, updated_at = ? '
          'WHERE course_id = ?',
          [now, id],
        );
        for (final certId in certIds) {
          await _syncRepository.markRecordPending(
            entityType: 'certifications',
            recordId: certId,
            localUpdatedAt: now,
          );
        }

        // Collect requirement/link ids before the cascade removes the rows.
        final requirements = await (_db.select(
          _db.courseRequirements,
        )..where((t) => t.courseId.equals(id))).get();
        final requirementIds = requirements.map((r) => r.id).toList();
        final links = requirementIds.isEmpty
            ? <CourseRequirementDiveRow>[]
            : await (_db.select(
                _db.courseRequirementDives,
              )..where((t) => t.requirementId.isIn(requirementIds))).get();

        // Delete the course (FK cascade removes requirements and links)
        await (_db.delete(_db.courses)..where((t) => t.id.equals(id))).go();

        await _syncRepository.logDeletion(entityType: 'courses', recordId: id);
        for (final requirement in requirements) {
          await _syncRepository.logDeletion(
            entityType: 'courseRequirements',
            recordId: requirement.id,
          );
        }
        for (final link in links) {
          await _syncRepository.logDeletion(
            entityType: 'courseRequirementDives',
            recordId: link.id,
          );
        }
      });

      SyncEventBus.notifyLocalChange();
      _log.info('Deleted course: $id');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete course: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Adds [courseId] to [diveId]'s courses (#2515).
  Future<void> linkDiveToCourse(String diveId, String courseId) =>
      _changeDiveCourses(diveId, add: courseId);

  /// Removes [courseId] from [diveId]'s courses, keeping its others (#2515).
  Future<void> unlinkDiveFromCourse(String diveId, String courseId) =>
      _changeDiveCourses(diveId, remove: courseId);

  Future<void> _changeDiveCourses(
    String diveId, {
    String? add,
    String? remove,
  }) async {
    try {
      _log.info('Changing courses of dive $diveId: +$add -$remove');
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.transaction(() async {
        final current =
            (await _diveLinks.courseIdsForDives([diveId]))[diveId] ??
            const <String>[];
        await _diveLinks.writeCourseSet(diveId, [
          for (final c in current)
            if (c != remove) c,
          ?add,
        ], now: now);
        await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
          DivesCompanion(updatedAt: Value(now)),
        );
        await _syncRepository.markRecordPending(
          entityType: 'dives',
          recordId: diveId,
          localUpdatedAt: now,
        );
      });
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to change the courses of dive $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Makes [courseId]'s earned certifications exactly [certificationIds]
  /// (#2515). A certification linked to another course moves here.
  Future<void> setCourseCertifications(
    String courseId,
    List<String> certificationIds,
  ) async {
    try {
      _log.info('Setting certifications of course $courseId');
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.transaction(
        () => _certLinks.setCourseCertifications(
          courseId,
          certificationIds,
          now: now,
        ),
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set certifications of course $courseId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // Private mapping methods

  domain.Course _mapRowToCourse(Course row) {
    return domain.Course(
      id: row.id,
      diverId: row.diverId,
      name: row.name,
      agency: row.agency,
      startDate: DateTime.fromMillisecondsSinceEpoch(row.startDate),
      completionDate: _parseDateTime(row.completionDate),
      instructorId: row.instructorId,
      instructorName: row.instructorName,
      instructorNumber: row.instructorNumber,
      certificationId: row.certificationId,
      location: row.location,
      notes: row.notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }

  domain.Course _mapQueryRowToCourse(QueryRow row) {
    return domain.Course(
      id: row.data['id'] as String,
      diverId: row.data['diver_id'] as String,
      name: row.data['name'] as String,
      agency: row.data['agency'] as String,
      startDate: DateTime.fromMillisecondsSinceEpoch(
        row.data['start_date'] as int,
      ),
      completionDate: _parseDateTime(row.data['completion_date'] as int?),
      instructorId: row.data['instructor_id'] as String?,
      instructorName: row.data['instructor_name'] as String?,
      instructorNumber: row.data['instructor_number'] as String?,
      certificationId: row.data['certification_id'] as String?,
      location: row.data['location'] as String?,
      notes: (row.data['notes'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.data['created_at'] as int,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.data['updated_at'] as int,
      ),
    );
  }

  DateTime? _parseDateTime(int? timestamp) {
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }
}
