import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_course_identity.dart';

/// Reads and writes a dive's courses (`dive_courses`, issue #2515) and keeps
/// the representative `dives.course_id` in step with the set. No transaction
/// and no notify: callers own both.
class DiveCourseLinks {
  DiveCourseLinks(this._db, this._sync);

  final AppDatabase _db;
  final SyncRepository _sync;

  static const int _chunkSize = 500;

  /// Each dive's course ids, the stored representative first, then by course
  /// start date, name and id. A dive with no junction rows falls back to its
  /// representative column (a link made by an older app version that the
  /// seed has not reached yet). Dives with no course are absent.
  Future<Map<String, List<String>>> courseIdsForDives(
    List<String> diveIds,
  ) async {
    final map = <String, List<String>>{};
    for (final chunk in _chunks(diveIds)) {
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await _db
          .customSelect(
            'SELECT dc.dive_id, dc.course_id FROM dive_courses dc '
            'JOIN courses c ON c.id = dc.course_id '
            'JOIN dives d ON d.id = dc.dive_id '
            'WHERE dc.dive_id IN ($placeholders) '
            'ORDER BY dc.dive_id, (dc.course_id IS d.course_id) DESC, '
            'c.start_date, c.name, c.id',
            variables: [for (final id in chunk) Variable<String>(id)],
            readsFrom: {_db.diveCourses, _db.courses, _db.dives},
          )
          .get();
      for (final r in rows) {
        (map[r.read<String>('dive_id')] ??= []).add(
          r.read<String>('course_id'),
        );
      }
      // Only the dives the junction did not resolve, and only two columns.
      final unresolved = [
        for (final id in chunk)
          if (!map.containsKey(id)) id,
      ];
      if (unresolved.isEmpty) continue;
      final d = _db.dives;
      final legacy =
          await (_db.selectOnly(d)
                ..addColumns([d.id, d.courseId])
                ..where(d.id.isIn(unresolved) & d.courseId.isNotNull()))
              .get();
      for (final row in legacy) {
        map[row.read(d.id)!] = [row.read(d.courseId)!];
      }
    }
    return map;
  }

  /// Makes [diveId]'s courses exactly [courseIds]: inserts new pairs, removes
  /// and tombstones dropped ones, leaves unchanged pairs alone, then rewrites
  /// the representative. Callers mark the dive itself pending.
  Future<void> writeCourseSet(
    String diveId,
    List<String> courseIds, {
    required int now,
  }) async {
    final want = courseIds.toSet();
    final existing = await (_db.select(
      _db.diveCourses,
    )..where((t) => t.diveId.equals(diveId))).get();
    final have = {for (final r in existing) r.courseId};
    for (final row in existing.where((r) => !want.contains(r.courseId))) {
      await (_db.delete(
        _db.diveCourses,
      )..where((t) => t.id.equals(row.id))).go();
      await _sync.logDeletion(entityType: 'diveCourses', recordId: row.id);
    }
    for (final courseId in want.difference(have)) {
      final id = diveCourseLinkId(diveId, courseId);
      // The id is deterministic, so a link removed and added back reuses it;
      // drop the old tombstone so peers see only the latest action.
      await _sync.removeDeletion(entityType: 'diveCourses', recordId: id);
      await _db
          .into(_db.diveCourses)
          .insert(
            DiveCoursesCompanion(
              id: Value(id),
              diveId: Value(diveId),
              courseId: Value(courseId),
              createdAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
      await _sync.markRecordPending(
        entityType: 'diveCourses',
        recordId: id,
        localUpdatedAt: now,
      );
    }
    await refreshRepresentative(diveId, now: now);
  }

  /// Rewrites `dives.course_id` from the set (earliest course start date,
  /// then name, then id) and returns it. With [markPending], a changed dive
  /// is also stamped for sync, for callers that are not already saving the
  /// dive, such as a course delete.
  Future<String?> refreshRepresentative(
    String diveId, {
    required int now,
    bool markPending = false,
  }) async {
    final rep = await _db
        .customSelect(
          'SELECT dc.course_id FROM dive_courses dc '
          'JOIN courses c ON c.id = dc.course_id '
          'WHERE dc.dive_id = ? '
          'ORDER BY c.start_date, c.name, c.id LIMIT 1',
          variables: [Variable<String>(diveId)],
          readsFrom: {_db.diveCourses, _db.courses},
        )
        .getSingleOrNull();
    final courseId = rep?.read<String>('course_id');
    final changed = await _db.customUpdate(
      markPending
          ? 'UPDATE dives SET course_id = ?1, updated_at = ?3 '
                'WHERE id = ?2 AND course_id IS NOT ?1'
          : 'UPDATE dives SET course_id = ?1 '
                'WHERE id = ?2 AND course_id IS NOT ?1',
      variables: [
        Variable<String>(courseId),
        Variable<String>(diveId),
        if (markPending) Variable<int>(now),
      ],
      updates: {_db.dives},
      updateKind: UpdateKind.update,
    );
    if (changed > 0 && markPending) {
      await _sync.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
    }
    return courseId;
  }

  /// Adds [courseIds] to each dive's set, keeping its other courses.
  Future<void> addCourses(
    List<String> diveIds,
    List<String> courseIds, {
    required int now,
  }) async {
    final current = await courseIdsForDives(diveIds);
    for (final diveId in diveIds) {
      await writeCourseSet(diveId, [
        ...?current[diveId],
        ...courseIds,
      ], now: now);
    }
  }

  /// Removes [courseIds] from each dive's set, keeping its other courses.
  Future<void> removeCourses(
    List<String> diveIds,
    List<String> courseIds, {
    required int now,
  }) async {
    final current = await courseIdsForDives(diveIds);
    final drop = courseIds.toSet();
    for (final diveId in diveIds) {
      await writeCourseSet(diveId, [
        for (final c in current[diveId] ?? const <String>[])
          if (!drop.contains(c)) c,
      ], now: now);
    }
  }

  /// {courseId: how many of [diveIds] are in it}, for the bulk editor.
  Future<Map<String, int>> courseCountsForDives(List<String> diveIds) async {
    final current = await courseIdsForDives(diveIds);
    final counts = <String, int>{};
    for (final ids in current.values) {
      for (final id in ids) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    return counts;
  }

  static Iterable<List<String>> _chunks(List<String> ids) sync* {
    for (var i = 0; i < ids.length; i += _chunkSize) {
      final end = i + _chunkSize > ids.length ? ids.length : i + _chunkSize;
      yield ids.sublist(i, end);
    }
  }
}
