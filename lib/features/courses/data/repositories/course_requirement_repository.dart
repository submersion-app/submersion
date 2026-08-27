import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/course_templates.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';

/// Maps a Drift row to the domain entity.
CourseRequirement mapCourseRequirementRow(CourseRequirementRow row) {
  return CourseRequirement(
    id: row.id,
    courseId: row.courseId,
    name: row.name,
    kind: RequirementKind.fromName(row.kind),
    targetCount: row.targetCount,
    completedAt: row.completedAt != null
        ? DateTime.fromMillisecondsSinceEpoch(row.completedAt!)
        : null,
    sortOrder: row.sortOrder,
    notes: row.notes,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );
}

class CourseRequirementRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(CourseRequirementRepository);

  /// Deterministic junction id: the same (requirement, dive) pair yields the
  /// same id on every device, so concurrent links converge to one row under
  /// sync upsert and unlink tombstones match cross-device.
  static String linkIdFor(String requirementId, String diveId) =>
      const Uuid().v5(
        Namespace.url.value,
        'submersion:course-requirement-dive:$requirementId:$diveId',
      );

  /// Emits when either requirement table changes (sync writes included).
  Stream<void> watchRequirementsChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([
      _db.courseRequirements,
      _db.courseRequirementDives,
    ]),
  );

  /// All requirements of [courseId] with their credited dives, in
  /// sortOrder. One requirement query plus one joined link query -- no N+1.
  Future<CourseProgress> getCourseProgress(String courseId) async {
    try {
      final reqRows =
          await (_db.select(_db.courseRequirements)
                ..where((t) => t.courseId.equals(courseId))
                ..orderBy([
                  (t) => OrderingTerm.asc(t.sortOrder),
                  (t) => OrderingTerm.asc(t.createdAt),
                ]))
              .get();

      final linksByRequirement = <String, List<RequirementDiveSummary>>{};
      if (reqRows.isNotEmpty) {
        final linkQuery =
            _db.select(_db.courseRequirementDives).join([
                innerJoin(
                  _db.dives,
                  _db.dives.id.equalsExp(_db.courseRequirementDives.diveId),
                ),
                leftOuterJoin(
                  _db.diveSites,
                  _db.diveSites.id.equalsExp(_db.dives.siteId),
                ),
              ])
              ..where(
                _db.courseRequirementDives.requirementId.isIn(
                  reqRows.map((r) => r.id).toList(),
                ),
              )
              ..orderBy([OrderingTerm.asc(_db.dives.diveDateTime)]);

        for (final row in await linkQuery.get()) {
          final link = row.readTable(_db.courseRequirementDives);
          final dive = row.readTable(_db.dives);
          final site = row.readTableOrNull(_db.diveSites);
          linksByRequirement
              .putIfAbsent(link.requirementId, () => [])
              .add(
                RequirementDiveSummary(
                  linkId: link.id,
                  diveId: dive.id,
                  diveNumber: dive.diveNumber,
                  // Dive times are wall-clock-as-UTC; decode with isUtc so
                  // the shown date never shifts with the device timezone.
                  dateTime: DateTime.fromMillisecondsSinceEpoch(
                    dive.diveDateTime,
                    isUtc: true,
                  ),
                  siteName: site?.name,
                ),
              );
        }
      }

      return CourseProgress(
        courseId: courseId,
        requirements: [
          for (final row in reqRows)
            CourseRequirementProgress(
              requirement: mapCourseRequirementRow(row),
              linkedDives: linksByRequirement[row.id] ?? const [],
            ),
        ],
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get course progress for course: $courseId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<CourseRequirement> createRequirement({
    required String courseId,
    required String name,
    required RequirementKind kind,
    int targetCount = 1,
    String? notes,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final maxSortOrder = await _getMaxSortOrder(courseId);

      await _db
          .into(_db.courseRequirements)
          .insert(
            CourseRequirementsCompanion(
              id: Value(id),
              courseId: Value(courseId),
              name: Value(name.trim()),
              kind: Value(kind.name),
              targetCount: Value(targetCount),
              sortOrder: Value(maxSortOrder + 1),
              notes: Value(notes),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await _syncRepository.markRecordPending(
        entityType: 'courseRequirements',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Created requirement $id ($name) for course: $courseId');

      final row = await (_db.select(
        _db.courseRequirements,
      )..where((t) => t.id.equals(id))).getSingle();
      return mapCourseRequirementRow(row);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create requirement',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> updateRequirement(CourseRequirement requirement) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.courseRequirements,
      )..where((t) => t.id.equals(requirement.id))).write(
        CourseRequirementsCompanion(
          name: Value(requirement.name.trim()),
          kind: Value(requirement.kind.name),
          targetCount: Value(requirement.targetCount),
          // completedAt is only meaningful for checklist requirements. When
          // the kind is (or becomes) dive, force it NULL so a later switch
          // back to checklist does not resurface a stale completion; for
          // checklist leave the column untouched (setChecklistComplete owns
          // it) rather than overwriting with a possibly-unhydrated value.
          completedAt: requirement.kind == RequirementKind.dive
              ? const Value(null)
              : const Value.absent(),
          sortOrder: Value(requirement.sortOrder),
          notes: Value(requirement.notes),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'courseRequirements',
        recordId: requirement.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Updated requirement: ${requirement.id}');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update requirement: ${requirement.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> setChecklistComplete(String id, bool complete) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.courseRequirements,
      )..where((t) => t.id.equals(id))).write(
        CourseRequirementsCompanion(
          completedAt: Value(complete ? now : null),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'courseRequirements',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set checklist state: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a requirement. FK cascade removes its junction rows, but sync
  /// needs a tombstone PER ROW (issue #466 lesson) or another device
  /// resurrects the links.
  Future<void> deleteRequirement(String id) async {
    try {
      final links = await (_db.select(
        _db.courseRequirementDives,
      )..where((t) => t.requirementId.equals(id))).get();

      await (_db.delete(
        _db.courseRequirements,
      )..where((t) => t.id.equals(id))).go();

      await _syncRepository.logDeletion(
        entityType: 'courseRequirements',
        recordId: id,
      );
      for (final link in links) {
        await _syncRepository.logDeletion(
          entityType: 'courseRequirementDives',
          recordId: link.id,
        );
      }
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted requirement $id with ${links.length} links');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete requirement: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Append the template's rows to the course. Never destructive: applying
  /// twice duplicates rows, which is the user's explicit choice to fix.
  ///
  /// All rows insert in a single transaction, then the ids are marked pending
  /// and a single change notification fires (TripChecklistRepository pattern),
  /// instead of one write + markRecordPending + notifyLocalChange per row.
  Future<void> applyTemplate(String courseId, CourseTemplate template) async {
    if (template.requirements.isEmpty) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final pendingIds = <String>[];

      await _db.transaction(() async {
        var sortOrder = await _getMaxSortOrder(courseId);
        for (final item in template.requirements) {
          final id = _uuid.v4();
          await _db
              .into(_db.courseRequirements)
              .insert(
                CourseRequirementsCompanion(
                  id: Value(id),
                  courseId: Value(courseId),
                  name: Value(item.name.trim()),
                  kind: Value(item.kind.name),
                  targetCount: Value(item.targetCount),
                  sortOrder: Value(++sortOrder),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
          pendingIds.add(id);
        }
      });

      for (final id in pendingIds) {
        await _syncRepository.markRecordPending(
          entityType: 'courseRequirements',
          recordId: id,
          localUpdatedAt: now,
        );
      }
      SyncEventBus.notifyLocalChange();
      _log.info(
        'Applied template "${template.name}" '
        '(${pendingIds.length} requirements) to course: $courseId',
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to apply template to course: $courseId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Credit [diveId] toward [requirementId]. Idempotent: the deterministic
  /// id plus insertOrIgnore make a duplicate link a silent no-op. Bumps the
  /// parent requirement so the junction rides the parent's sync delta.
  Future<void> linkDive({
    required String requirementId,
    required String diveId,
  }) async {
    try {
      final id = linkIdFor(requirementId, diveId);
      // Once-per-course invariant: a dive credits at most one requirement
      // of a course (the suggestion query already assumes this, but the
      // same suggestion list renders under every unsatisfied requirement,
      // so two taps before providers refresh could double-count). This
      // also covers the duplicate-link case for the same requirement --
      // Drift's insert return value cannot distinguish an ignored
      // conflict, so the check is explicit (importDiveRole pattern), and
      // a no-op must not bump the parent hlc or emit sync churn. The
      // check+insert runs in a transaction: two concurrent taps each yield
      // at their SELECT, so without the transaction both could observe no
      // existing link and insert different deterministic ids. Drift
      // serializes transactions, so the second one's SELECT sees the first
      // commit and returns early. Enforced locally at write time;
      // concurrent links from two devices to different requirements still
      // merge via sync and are resolved by the user unlinking one.
      final inserted = await _db.transaction(() async {
        final existingInCourse = await _db
            .customSelect(
              'SELECT l.id FROM course_requirement_dives l '
              'JOIN course_requirements r ON r.id = l.requirement_id '
              'WHERE l.dive_id = ?1 AND r.course_id = '
              '(SELECT course_id FROM course_requirements WHERE id = ?2) '
              'LIMIT 1',
              variables: [
                Variable.withString(diveId),
                Variable.withString(requirementId),
              ],
            )
            .get();
        if (existingInCourse.isNotEmpty) return false;

        final now = DateTime.now().millisecondsSinceEpoch;
        await _db
            .into(_db.courseRequirementDives)
            .insert(
              CourseRequirementDivesCompanion(
                id: Value(id),
                requirementId: Value(requirementId),
                diveId: Value(diveId),
                createdAt: Value(now),
              ),
              mode: InsertMode.insertOrIgnore,
            );
        await _touchRequirement(requirementId, now);
        return true;
      });
      if (!inserted) return;

      SyncEventBus.notifyLocalChange();
      _log.info('Linked dive $diveId to requirement $requirementId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to link dive $diveId to requirement $requirementId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> unlinkDive({
    required String requirementId,
    required String diveId,
  }) async {
    try {
      final id = linkIdFor(requirementId, diveId);
      final deleted = await (_db.delete(
        _db.courseRequirementDives,
      )..where((t) => t.id.equals(id))).go();
      if (deleted == 0) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      await _syncRepository.logDeletion(
        entityType: 'courseRequirementDives',
        recordId: id,
      );
      await _touchRequirement(requirementId, now);
      SyncEventBus.notifyLocalChange();
      _log.info('Unlinked dive $diveId from requirement $requirementId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to unlink dive $diveId from requirement $requirementId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Candidate dives for crediting: the course diver's dives that are either
  /// assigned to this course (dives.course_id) or dated on/after the course
  /// start, excluding dives already credited to any requirement of this
  /// course. Newest first, capped at 10.
  Future<List<RequirementDiveSummary>> getSuggestedDives(
    String courseId,
  ) async {
    try {
      final course = await (_db.select(
        _db.courses,
      )..where((t) => t.id.equals(courseId))).getSingleOrNull();
      if (course == null) return const [];

      final rows = await _db
          .customSelect(
            '''
            SELECT d.id, d.dive_number, d.dive_date_time,
                   s.name AS site_name
            FROM dives d
            LEFT JOIN dive_sites s ON s.id = d.site_id
            WHERE d.diver_id = ?2
              AND (d.course_id = ?1 OR d.dive_date_time >= ?3)
              AND d.id NOT IN (
                SELECT l.dive_id
                FROM course_requirement_dives l
                JOIN course_requirements r ON r.id = l.requirement_id
                WHERE r.course_id = ?1
              )
            ORDER BY d.dive_date_time DESC
            LIMIT 10
            ''',
            variables: [
              Variable.withString(courseId),
              Variable.withString(course.diverId),
              Variable.withInt(course.startDate),
            ],
            readsFrom: {
              _db.dives,
              _db.diveSites,
              _db.courseRequirementDives,
              _db.courseRequirements,
            },
          )
          .get();

      return [
        for (final row in rows)
          RequirementDiveSummary(
            diveId: row.data['id'] as String,
            diveNumber: row.data['dive_number'] as int?,
            // Wall-clock-as-UTC, same as the linked-dive summaries above.
            dateTime: DateTime.fromMillisecondsSinceEpoch(
              row.data['dive_date_time'] as int,
              isUtc: true,
            ),
            siteName: row.data['site_name'] as String?,
          ),
      ];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get suggested dives for course: $courseId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Bump the parent requirement's updatedAt and mark it sync-pending so
  /// its hlc advances -- junction delta export is gated on the parent hlc.
  Future<void> _touchRequirement(String requirementId, int now) async {
    await (_db.update(_db.courseRequirements)
          ..where((t) => t.id.equals(requirementId)))
        .write(CourseRequirementsCompanion(updatedAt: Value(now)));
    await _syncRepository.markRecordPending(
      entityType: 'courseRequirements',
      recordId: requirementId,
      localUpdatedAt: now,
    );
  }

  Future<int> _getMaxSortOrder(String courseId) async {
    final result = await _db
        .customSelect(
          'SELECT MAX(sort_order) AS max_order FROM course_requirements '
          'WHERE course_id = ?1',
          variables: [Variable.withString(courseId)],
        )
        .getSingleOrNull();
    return (result?.data['max_order'] as int?) ?? 0;
  }
}
