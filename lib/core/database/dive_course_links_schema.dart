library;

import 'package:drift/drift.dart';

import 'package:submersion/core/database/dive_course_identity.dart';

/// Unique index over the `dive_courses` junction, keyed on (dive, course).
const String kDiveCoursesUniqueIndexName =
    'idx_dive_courses_dive_course_unique';

Future<bool> _exists(
  DatabaseConnectionUser db,
  String type,
  String name,
) async {
  final rows = await db
      .customSelect(
        'SELECT 1 FROM sqlite_master WHERE type = ? AND name = ?',
        variables: [Variable<String>(type), Variable<String>(name)],
      )
      .get();
  return rows.isNotEmpty;
}

/// Whether [table] exists and has every one of [columns]. The backstops run
/// on every open, including on partial or very old schemas.
Future<bool> _hasColumns(
  DatabaseConnectionUser db,
  String table,
  List<String> columns,
) async {
  if (!await _exists(db, 'table', table)) return false;
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  final have = {for (final r in rows) r.read<String>('name')};
  return columns.every(have.contains);
}

/// One `dive_courses` row per (dive, course). Ids are deterministic, so a
/// duplicate pair can only come from a hand-written row; the collapse keeps
/// the lowest id so every device keeps the same survivor.
Future<void> assertDiveCourseUniqueness(DatabaseConnectionUser db) async {
  if (!await _exists(db, 'table', 'dive_courses')) return;
  if (await _exists(db, 'index', kDiveCoursesUniqueIndexName)) return;
  await db.customStatement('''
    DELETE FROM dive_courses WHERE rowid IN (
      SELECT rowid FROM (
        SELECT rowid, ROW_NUMBER() OVER (
          PARTITION BY dive_id, course_id ORDER BY id ASC
        ) AS rn FROM dive_courses
      ) WHERE rn > 1
    )
  ''');
  await db.customStatement(
    'CREATE UNIQUE INDEX IF NOT EXISTS $kDiveCoursesUniqueIndexName '
    'ON dive_courses(dive_id, course_id)',
  );
}

/// Copies each dive's representative `dives.course_id` into `dive_courses`
/// when that pair has no row yet. Returns how many rows it inserted.
///
/// Runs in the v286 rung, on every open, and after every sync apply. It only
/// ever ADDS: an older app version writes just the representative column, and
/// this is how its link reaches the set without stripping the dive's other
/// courses. It cannot resurrect a removed link, because removing a dive's
/// representative course always rewrites `dives.course_id` in the same
/// transaction. Local and idempotent: no hlc, nothing marked pending; every
/// device derives the same rows from the same synced dives.
Future<int> seedDiveCourseLinks(DatabaseConnectionUser db) async {
  if (!await _exists(db, 'table', 'dive_courses')) return 0;
  if (!await _exists(db, 'table', 'courses')) return 0;
  if (!await _hasColumns(db, 'dives', const ['id', 'course_id'])) return 0;
  final missing = await db.customSelect('''
    SELECT d.id AS dive_id, d.course_id AS course_id FROM dives d
    WHERE d.course_id IS NOT NULL
      AND EXISTS (SELECT 1 FROM courses c WHERE c.id = d.course_id)
      AND NOT EXISTS (
        SELECT 1 FROM dive_courses dc
        WHERE dc.dive_id = d.id AND dc.course_id = d.course_id
      )
  ''').get();
  var inserted = 0;
  final now = DateTime.now().millisecondsSinceEpoch;
  for (final row in missing) {
    final diveId = row.read<String>('dive_id');
    final courseId = row.read<String>('course_id');
    inserted += await db.customUpdate(
      'INSERT OR IGNORE INTO dive_courses (id, dive_id, course_id, created_at) '
      'VALUES (?, ?, ?, ?)',
      variables: [
        Variable<String>(diveCourseLinkId(diveId, courseId)),
        Variable<String>(diveId),
        Variable<String>(courseId),
        Variable<int>(now),
      ],
    );
  }
  return inserted;
}

/// The certification side becomes the truth (v286): a course's
/// `certification_id` that names a certification with no course claims it,
/// then every course's representative is recomputed from the certification
/// side (earliest issued, undated last, then name, then id). Runs in the rung
/// only. Deterministic over synced data, so it marks nothing pending.
Future<void> backfillCertificationCourseLinks(DatabaseConnectionUser db) async {
  if (!await _hasColumns(db, 'courses', const ['id', 'certification_id'])) {
    return;
  }
  if (!await _hasColumns(db, 'certifications', const [
    'id',
    'name',
    'issue_date',
    'course_id',
  ])) {
    return;
  }
  await db.customStatement('''
    UPDATE certifications SET course_id = (
      SELECT c.id FROM courses c
      WHERE c.certification_id = certifications.id
      ORDER BY c.id LIMIT 1
    )
    WHERE course_id IS NULL
      AND EXISTS (
        SELECT 1 FROM courses c WHERE c.certification_id = certifications.id
      )
  ''');
  await db.customStatement('''
    UPDATE courses SET certification_id = (
      SELECT k.id FROM certifications k WHERE k.course_id = courses.id
      ORDER BY k.issue_date IS NULL, k.issue_date, k.name, k.id LIMIT 1
    )
  ''');
}
