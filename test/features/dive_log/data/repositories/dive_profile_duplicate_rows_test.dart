import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// A repeated download or import can leave a dive with two identical copies of
/// every profile row. Both reads that feed the analysis pipeline have to
/// collapse them: a duplicated series halves every computed ascent rate,
/// because half the sample pairs share a timestamp and contribute a zero.
void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  Future<void> duplicateProfileRows(String diveId) async {
    final rows = await (db.select(
      db.diveProfiles,
    )..where((t) => t.diveId.equals(diveId))).get();
    for (final row in rows) {
      await db
          .into(db.diveProfiles)
          .insert(row.toCompanion(false).copyWith(id: Value('${row.id}-copy')));
    }
  }

  test('getMergedProfile collapses exact duplicate rows', () async {
    await repository.createDive(
      domain.Dive(
        id: 'dup',
        dateTime: DateTime.utc(2026, 8, 1, 10),
        profile: [
          // Populated sample fields, so this proves whole-row equality rather
          // than only equality across a row of nulls.
          for (var t = 0; t <= 300; t += 10)
            domain.DiveProfilePoint(
              timestamp: t,
              depth: t / 10.0,
              temperature: 24.5,
              heartRate: 70 + t ~/ 100,
            ),
        ],
      ),
    );
    await duplicateProfileRows('dup');

    final merged = await repository.getMergedProfile('dup');

    expect(merged, hasLength(31));
    expect(
      merged.map((p) => p.timestamp).toList(),
      equals([for (var t = 0; t <= 300; t += 10) t]),
    );
  });

  test('getDiveById stays in step with getMergedProfile', () async {
    await repository.createDive(
      domain.Dive(
        id: 'dup2',
        dateTime: DateTime.utc(2026, 8, 1, 11),
        profile: [
          for (var t = 0; t <= 300; t += 10)
            domain.DiveProfilePoint(timestamp: t, depth: t / 10.0),
        ],
      ),
    );
    await duplicateProfileRows('dup2');

    final full = await repository.getDiveById('dup2');
    final merged = await repository.getMergedProfile('dup2');

    // Analysis curves are index-aligned against the profile the detail page
    // holds, so these two lists must never differ in length.
    expect(
      full!.profile.map((p) => p.timestamp).toList(),
      equals(merged.map((p) => p.timestamp).toList()),
    );
  });

  test('samples matching on timestamp and depth but not on other recorded '
      'fields are kept', () async {
    // Two computers can agree on depth at the same second and still each
    // carry data the other does not. Keying only on (timestamp, depth) would
    // silently throw one computer's temperature or heart rate away.
    await repository.createDive(
      domain.Dive(
        id: 'meta',
        dateTime: DateTime.utc(2026, 8, 1, 13),
        profile: [
          for (var t = 0; t <= 100; t += 10)
            domain.DiveProfilePoint(timestamp: t, depth: t / 10.0),
        ],
      ),
    );
    final rows = await (db.select(
      db.diveProfiles,
    )..where((t) => t.diveId.equals('meta'))).get();
    for (final row in rows) {
      await db
          .into(db.diveProfiles)
          .insert(
            row
                .toCompanion(false)
                .copyWith(
                  id: Value('${row.id}-hr'),
                  heartRate: const Value(72),
                ),
          );
    }

    expect(await repository.getMergedProfile('meta'), hasLength(22));
  });

  test('samples that share a timestamp but differ in depth are kept', () async {
    // Two dive computers on one dive legitimately record different depths at
    // the same second. That is a source-attribution question, not a duplicate.
    await repository.createDive(
      domain.Dive(
        id: 'twosrc',
        dateTime: DateTime.utc(2026, 8, 1, 12),
        profile: [
          for (var t = 0; t <= 100; t += 10)
            domain.DiveProfilePoint(timestamp: t, depth: t / 10.0),
        ],
      ),
    );
    final rows = await (db.select(
      db.diveProfiles,
    )..where((t) => t.diveId.equals('twosrc'))).get();
    for (final row in rows) {
      await db
          .into(db.diveProfiles)
          .insert(
            row
                .toCompanion(false)
                .copyWith(
                  id: Value('${row.id}-b'),
                  depth: Value(row.depth + 0.4),
                ),
          );
    }

    expect(await repository.getMergedProfile('twosrc'), hasLength(22));
  });
}
