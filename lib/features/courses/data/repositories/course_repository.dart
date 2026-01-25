import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/courses/domain/entities/course.dart'
    as domain;

class CourseRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(CourseRepository);

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
      _log.error('Failed to get all courses', e, stackTrace);
      rethrow;
    }
  }

  /// Get course by ID
  Future<domain.Course?> getCourseById(String id) async {
    try {
      final query = _db.select(_db.courses)..where((t) => t.id.equals(id));

      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToCourse(row) : null;
    } catch (e, stackTrace) {
      _log.error('Failed to get course by id: $id', e, stackTrace);
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
      _log.error('Failed to get in-progress courses', e, stackTrace);
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
      _log.error('Failed to get completed courses', e, stackTrace);
      rethrow;
    }
  }

  /// Get courses by agency
  Future<List<domain.Course>> getCoursesByAgency(
    CertificationAgency agency, {
    String? diverId,
  }) async {
    try {
      final query = _db.select(_db.courses)
        ..where((t) => t.agency.equals(agency.name))
        ..orderBy([(t) => OrderingTerm.desc(t.startDate)]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return rows.map(_mapRowToCourse).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get courses by agency: ${agency.name}',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get course for a specific dive
  Future<domain.Course?> getCourseForDive(String diveId) async {
    try {
      final results = await _db
          .customSelect(
            '''
        SELECT c.* FROM courses c
        INNER JOIN dives d ON d.course_id = c.id
        WHERE d.id = ?
      ''',
            variables: [Variable.withString(diveId)],
          )
          .get();

      if (results.isEmpty) return null;
      return _mapQueryRowToCourse(results.first);
    } catch (e, stackTrace) {
      _log.error('Failed to get course for dive: $diveId', e, stackTrace);
      rethrow;
    }
  }

  /// Get course for a specific certification
  Future<domain.Course?> getCourseForCertification(
    String certificationId,
  ) async {
    try {
      // Check bidirectional: certification.courseId OR course.certificationId
      final results = await _db
          .customSelect(
            '''
        SELECT c.* FROM courses c
        WHERE c.certification_id = ?
        UNION
        SELECT c.* FROM courses c
        INNER JOIN certifications cert ON cert.course_id = c.id
        WHERE cert.id = ?
      ''',
            variables: [
              Variable.withString(certificationId),
              Variable.withString(certificationId),
            ],
          )
          .get();

      if (results.isEmpty) return null;
      return _mapQueryRowToCourse(results.first);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get course for certification: $certificationId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get count of dives for a course
  Future<int> getDiveCountForCourse(String courseId) async {
    try {
      final result = await _db
          .customSelect(
            '''
        SELECT COUNT(*) as count FROM dives
        WHERE course_id = ?
      ''',
            variables: [Variable.withString(courseId)],
          )
          .getSingle();

      return result.data['count'] as int;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive count for course: $courseId',
        e,
        stackTrace,
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
      WHERE (LOWER(name) LIKE ?
         OR LOWER(location) LIKE ?)
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
              agency: Value(course.agency.name),
              startDate: Value(course.startDate.millisecondsSinceEpoch),
              completionDate: Value(
                course.completionDate?.millisecondsSinceEpoch,
              ),
              instructorId: Value(course.instructorId),
              instructorName: Value(course.instructorName),
              instructorNumber: Value(course.instructorNumber),
              certificationId: Value(course.certificationId),
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
      _log.error('Failed to create course: ${course.name}', e, stackTrace);
      rethrow;
    }
  }

  /// Update an existing course
  Future<void> updateCourse(domain.Course course) async {
    try {
      _log.info('Updating course: ${course.id}');
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(
        _db.courses,
      )..where((t) => t.id.equals(course.id))).write(
        CoursesCompanion(
          name: Value(course.name),
          agency: Value(course.agency.name),
          startDate: Value(course.startDate.millisecondsSinceEpoch),
          completionDate: Value(course.completionDate?.millisecondsSinceEpoch),
          instructorId: Value(course.instructorId),
          instructorName: Value(course.instructorName),
          instructorNumber: Value(course.instructorNumber),
          certificationId: Value(course.certificationId),
          location: Value(course.location),
          notes: Value(course.notes),
          updatedAt: Value(now),
        ),
      );

      await _syncRepository.markRecordPending(
        entityType: 'courses',
        recordId: course.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Updated course: ${course.id}');
    } catch (e, stackTrace) {
      _log.error('Failed to update course: ${course.id}', e, stackTrace);
      rethrow;
    }
  }

  /// Delete a course
  Future<void> deleteCourse(String id) async {
    try {
      _log.info('Deleting course: $id');

      // First, clear courseId from any linked dives
      await _db.customStatement(
        '''
        UPDATE dives SET course_id = NULL WHERE course_id = ?
      ''',
        [Variable.withString(id)],
      );

      // Clear courseId from any linked certifications
      await _db.customStatement(
        '''
        UPDATE certifications SET course_id = NULL WHERE course_id = ?
      ''',
        [Variable.withString(id)],
      );

      // Delete the course
      await (_db.delete(_db.courses)..where((t) => t.id.equals(id))).go();

      await _syncRepository.logDeletion(entityType: 'courses', recordId: id);
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted course: $id');
    } catch (e, stackTrace) {
      _log.error('Failed to delete course: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Link a dive to a course
  Future<void> linkDiveToCourse(String diveId, String courseId) async {
    try {
      _log.info('Linking dive $diveId to course $courseId');
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.customStatement(
        '''
        UPDATE dives SET course_id = ?, updated_at = ? WHERE id = ?
      ''',
        [
          Variable.withString(courseId),
          Variable.withInt(now),
          Variable.withString(diveId),
        ],
      );

      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error('Failed to link dive to course', e, stackTrace);
      rethrow;
    }
  }

  /// Unlink a dive from its course
  Future<void> unlinkDiveFromCourse(String diveId) async {
    try {
      _log.info('Unlinking dive $diveId from course');
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.customStatement(
        '''
        UPDATE dives SET course_id = NULL, updated_at = ? WHERE id = ?
      ''',
        [Variable.withInt(now), Variable.withString(diveId)],
      );

      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error('Failed to unlink dive from course', e, stackTrace);
      rethrow;
    }
  }

  /// Link course to certification (bidirectional)
  Future<void> linkCourseToCertification(
    String courseId,
    String certificationId,
  ) async {
    try {
      _log.info('Linking course $courseId to certification $certificationId');
      final now = DateTime.now().millisecondsSinceEpoch;

      // Update course with certificationId
      await _db.customStatement(
        '''
        UPDATE courses SET certification_id = ?, updated_at = ? WHERE id = ?
      ''',
        [
          Variable.withString(certificationId),
          Variable.withInt(now),
          Variable.withString(courseId),
        ],
      );

      // Update certification with courseId
      await _db.customStatement(
        '''
        UPDATE certifications SET course_id = ?, updated_at = ? WHERE id = ?
      ''',
        [
          Variable.withString(courseId),
          Variable.withInt(now),
          Variable.withString(certificationId),
        ],
      );

      await _syncRepository.markRecordPending(
        entityType: 'courses',
        recordId: courseId,
        localUpdatedAt: now,
      );
      await _syncRepository.markRecordPending(
        entityType: 'certifications',
        recordId: certificationId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error('Failed to link course to certification', e, stackTrace);
      rethrow;
    }
  }

  // Private mapping methods

  domain.Course _mapRowToCourse(Course row) {
    return domain.Course(
      id: row.id,
      diverId: row.diverId,
      name: row.name,
      agency: _parseCertificationAgency(row.agency),
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
      agency: _parseCertificationAgency(row.data['agency'] as String),
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

  CertificationAgency _parseCertificationAgency(String value) {
    return CertificationAgency.values.firstWhere(
      (a) => a.name == value,
      orElse: () => CertificationAgency.other,
    );
  }
}
