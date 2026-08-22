import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// The PDF exporter needs depth profiles for many dives at once, but
/// `getAllDives` deliberately skips profile hydration for performance, so the
/// export path loads them itself.
///
/// It must not reach for `getDiveProfile`: that filters `isPrimary = true`,
/// and per #623 `setPrimaryDataSource` can leave a file-imported dive with no
/// primary rows at all. Those dives would silently render a blank chart. The
/// batch loader mirrors `getMergedProfile` instead.
void main() {
  late DiveRepository repository;
  late AppDatabase db;

  const now = 1750000000000;

  Future<void> insertDive(String id) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: const Value(now),
            createdAt: const Value(now),
            updatedAt: const Value(now),
          ),
        );
  }

  var rowCounter = 0;
  Future<void> insertProfileRow({
    required String diveId,
    required int timestamp,
    required double depth,
    String? computerId,
    bool isPrimary = true,
  }) async {
    await db
        .into(db.diveProfiles)
        .insert(
          DiveProfilesCompanion(
            id: Value('prof-${rowCounter++}'),
            diveId: Value(diveId),
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            timestamp: Value(timestamp),
            depth: Value(depth),
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
    rowCounter = 0;
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('returns profiles for several dives in one call', () async {
    await insertDive('diveA');
    await insertDive('diveB');
    await insertProfileRow(diveId: 'diveA', timestamp: 0, depth: 0);
    await insertProfileRow(diveId: 'diveA', timestamp: 60, depth: 12);
    await insertProfileRow(diveId: 'diveB', timestamp: 0, depth: 0);
    await insertProfileRow(diveId: 'diveB', timestamp: 60, depth: 30);

    final result = await repository.getMergedProfilesForDives([
      'diveA',
      'diveB',
    ]);

    expect(result['diveA'], hasLength(2));
    expect(result['diveB'], hasLength(2));
    expect(result['diveB']!.last.depth, 30);
  });

  test('returns rows for a dive whose samples are all non-primary', () async {
    await insertDive('imported');
    await insertProfileRow(
      diveId: 'imported',
      timestamp: 0,
      depth: 0,
      isPrimary: false,
    );
    await insertProfileRow(
      diveId: 'imported',
      timestamp: 60,
      depth: 18,
      isPrimary: false,
    );

    final result = await repository.getMergedProfilesForDives(['imported']);

    expect(
      result['imported'],
      isNotEmpty,
      reason:
          'an isPrimary filter would silently drop file-imported dives (#623)',
    );
    expect(result['imported'], hasLength(2));
  });

  test('drops the originals a saved edit superseded', () async {
    await insertDive('edited');
    // Demoted originals, as saveEditedProfile leaves them.
    await insertProfileRow(
      diveId: 'edited',
      timestamp: 0,
      depth: 0,
      isPrimary: false,
    );
    await insertProfileRow(
      diveId: 'edited',
      timestamp: 60,
      depth: 10,
      isPrimary: false,
    );
    await insertProfileRow(
      diveId: 'edited',
      timestamp: 120,
      depth: 20,
      isPrimary: false,
    );
    // The edited replacement, promoted: a trim that removed the tail.
    await insertProfileRow(diveId: 'edited', timestamp: 0, depth: 0);
    await insertProfileRow(diveId: 'edited', timestamp: 60, depth: 10);

    final result = await repository.getMergedProfilesForDives(['edited']);

    expect(
      result['edited'],
      hasLength(2),
      reason: 'the demoted originals must not be unioned back in',
    );
    expect(result['edited']!.map((p) => p.timestamp), [0, 60]);
  });

  test('omits dives that have no profile rows', () async {
    await insertDive('bare');
    final result = await repository.getMergedProfilesForDives(['bare']);
    expect(result['bare'], anyOf(isNull, isEmpty));
  });

  test('handles more dives than one query chunk', () async {
    final ids = List.generate(120, (i) => 'dive$i');
    for (final id in ids) {
      await insertDive(id);
      await insertProfileRow(diveId: id, timestamp: 0, depth: 0);
      await insertProfileRow(diveId: id, timestamp: 60, depth: 15);
    }

    final result = await repository.getMergedProfilesForDives(ids);

    expect(result, hasLength(120));
    expect(result['dive119'], hasLength(2));
  });
}
