import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';

/// A course's certifications (issue #2515). `certifications.course_id` is the
/// truth; `courses.certification_id` is a representative kept for older app
/// versions and single-value exports. No transaction and no notify: callers
/// own both.
class CourseCertificationLinks {
  CourseCertificationLinks(this._db, this._sync);

  final AppDatabase _db;
  final SyncRepository _sync;

  /// Makes [courseId]'s certifications exactly [certificationIds]. A ticked
  /// certification that belonged to another course moves here, and that
  /// course's representative is recomputed too.
  Future<void> setCourseCertifications(
    String courseId,
    List<String> certificationIds, {
    required int now,
  }) async {
    final want = certificationIds.toSet();
    final current = await (_db.select(
      _db.certifications,
    )..where((t) => t.courseId.equals(courseId))).get();
    final have = {for (final c in current) c.id};
    final touchedCourses = <String>{courseId};

    for (final id in have.difference(want)) {
      await _setCourse(id, null, now);
    }
    for (final id in want.difference(have)) {
      final cert = await (_db.select(
        _db.certifications,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (cert == null) continue;
      if (cert.courseId != null) touchedCourses.add(cert.courseId!);
      await _setCourse(id, courseId, now);
    }
    for (final id in touchedCourses) {
      await refreshRepresentative(id, now: now);
    }
  }

  Future<void> _setCourse(
    String certificationId,
    String? courseId,
    int now,
  ) async {
    await (_db.update(
      _db.certifications,
    )..where((t) => t.id.equals(certificationId))).write(
      CertificationsCompanion(courseId: Value(courseId), updatedAt: Value(now)),
    );
    await _sync.markRecordPending(
      entityType: 'certifications',
      recordId: certificationId,
      localUpdatedAt: now,
    );
  }

  /// Rewrites `courses.certification_id` to the earliest-issued linked
  /// certification (undated last, then name, then id), marking the course
  /// pending only when the value changed.
  Future<void> refreshRepresentative(
    String courseId, {
    required int now,
  }) async {
    final rep = await _db
        .customSelect(
          'SELECT id FROM certifications WHERE course_id = ? '
          'ORDER BY issue_date IS NULL, issue_date, name, id LIMIT 1',
          variables: [Variable<String>(courseId)],
          readsFrom: {_db.certifications},
        )
        .getSingleOrNull();
    final certId = rep?.read<String>('id');
    final changed = await _db.customUpdate(
      'UPDATE courses SET certification_id = ?1, updated_at = ?2 '
      'WHERE id = ?3 AND certification_id IS NOT ?1',
      variables: [
        Variable<String>(certId),
        Variable<int>(now),
        Variable<String>(courseId),
      ],
      updates: {_db.courses},
      updateKind: UpdateKind.update,
    );
    if (changed > 0) {
      await _sync.markRecordPending(
        entityType: 'courses',
        recordId: courseId,
        localUpdatedAt: now,
      );
    }
  }
}
