import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/test_database.dart';

/// Regression cover for #1161 ("Trim End does not work").
///
/// `saveEditedProfile` demotes the original rows to `isPrimary = false` and
/// inserts the edited rows as the new primary, so the originals stay
/// restorable. `Dive.profile` is built from an unfiltered `dive_profiles`
/// read, so before this fix an edited dive surfaced the demoted originals
/// alongside the edited rows: a trim (which removes points rather than
/// changing their depth) appeared to do nothing once the editor was saved.
void main() {
  late DiveRepository repository;
  late AppDatabase db;

  const now = 1750000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();

    await db
        .into(db.dives)
        .insert(
          const DivesCompanion(
            id: Value('dive-1'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  var profileRowCounter = 0;
  Future<void> insertProfileRow({
    required int timestamp,
    required double depth,
    required String? computerId,
    required bool isPrimary,
  }) async {
    await db
        .into(db.diveProfiles)
        .insert(
          DiveProfilesCompanion(
            id: Value('prof-${profileRowCounter++}'),
            diveId: const Value('dive-1'),
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            timestamp: Value(timestamp),
            depth: Value(depth),
          ),
        );
  }

  Future<void> insertComputer(String id) => db
      .into(db.diveComputers)
      .insert(
        DiveComputersCompanion(
          id: Value(id),
          name: Value('Computer $id'),
          createdAt: const Value(now),
          updatedAt: const Value(now),
        ),
      );

  Future<void> insertDataSource({
    required String id,
    required String? computerId,
    required bool isPrimary,
  }) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion(
          id: Value(id),
          diveId: const Value('dive-1'),
          computerId: Value(computerId),
          isPrimary: Value(isPrimary),
          importedAt: Value(DateTime(2026, 1, 1)),
          createdAt: Value(DateTime(2026, 1, 1)),
        ),
      );

  List<(int, double)> asPairs(List<DiveProfilePoint> points) => [
    for (final p in points) (p.timestamp, p.depth),
  ];

  group('trim end persists (#1161)', () {
    test('file-imported dive: getDiveById drops the trimmed tail', () async {
      // A file import writes profile rows with a null computerId.
      for (final (ts, depth) in [
        (0, 0.0),
        (4, 10.0),
        (8, 20.0),
        (12, 10.0),
        (16, 0.0),
        (20, 0.0),
        (24, 0.0),
      ]) {
        await insertProfileRow(
          timestamp: ts,
          depth: depth,
          computerId: null,
          isPrimary: true,
        );
      }

      // Trim End keeps a single surface point after the last real depth.
      await repository.saveEditedProfile('dive-1', const [
        DiveProfilePoint(timestamp: 0, depth: 0.0),
        DiveProfilePoint(timestamp: 4, depth: 10.0),
        DiveProfilePoint(timestamp: 8, depth: 20.0),
        DiveProfilePoint(timestamp: 12, depth: 10.0),
        DiveProfilePoint(timestamp: 16, depth: 0.0),
      ]);

      final dive = await repository.getDiveById('dive-1');

      expect(asPairs(dive!.profile), [
        (0, 0.0),
        (4, 10.0),
        (8, 20.0),
        (12, 10.0),
        (16, 0.0),
      ]);
    });

    test(
      'computer-downloaded dive: getDiveById drops the trimmed tail',
      () async {
        await insertComputer('dc-a');
        await insertDataSource(
          id: 'src-a',
          computerId: 'dc-a',
          isPrimary: true,
        );
        for (final (ts, depth) in [(0, 0.0), (4, 20.0), (8, 0.0), (12, 0.0)]) {
          await insertProfileRow(
            timestamp: ts,
            depth: depth,
            computerId: 'dc-a',
            isPrimary: true,
          );
        }

        await repository.saveEditedProfile('dive-1', const [
          DiveProfilePoint(timestamp: 0, depth: 0.0),
          DiveProfilePoint(timestamp: 4, depth: 20.0),
          DiveProfilePoint(timestamp: 8, depth: 0.0),
        ]);

        final dive = await repository.getDiveById('dive-1');

        expect(asPairs(dive!.profile), [(0, 0.0), (4, 20.0), (8, 0.0)]);
      },
    );

    test(
      'getMergedProfile agrees with getDiveById for an edited dive',
      () async {
        await insertComputer('dc-a');
        await insertDataSource(
          id: 'src-a',
          computerId: 'dc-a',
          isPrimary: true,
        );
        for (final (ts, depth) in [(0, 0.0), (4, 20.0), (8, 0.0), (12, 0.0)]) {
          await insertProfileRow(
            timestamp: ts,
            depth: depth,
            computerId: 'dc-a',
            isPrimary: true,
          );
        }

        await repository.saveEditedProfile('dive-1', const [
          DiveProfilePoint(timestamp: 0, depth: 0.0),
          DiveProfilePoint(timestamp: 4, depth: 20.0),
          DiveProfilePoint(timestamp: 8, depth: 0.0),
        ]);

        final dive = await repository.getDiveById('dive-1');
        final merged = await repository.getMergedProfile('dive-1');

        expect(asPairs(merged), asPairs(dive!.profile));
      },
    );
  });

  group('non-edited reads are unchanged', () {
    test(
      'a second computer keeps its samples after the primary is edited',
      () async {
        await insertComputer('dc-a');
        await insertComputer('dc-b');
        await insertDataSource(
          id: 'src-a',
          computerId: 'dc-a',
          isPrimary: true,
        );
        await insertDataSource(
          id: 'src-b',
          computerId: 'dc-b',
          isPrimary: false,
        );

        for (final (ts, depth) in [(0, 0.0), (4, 20.0), (8, 0.0)]) {
          await insertProfileRow(
            timestamp: ts,
            depth: depth,
            computerId: 'dc-a',
            isPrimary: true,
          );
        }
        // Secondary computers are always stored demoted.
        for (final (ts, depth) in [(0, 0.1), (4, 20.5), (8, 0.2)]) {
          await insertProfileRow(
            timestamp: ts,
            depth: depth,
            computerId: 'dc-b',
            isPrimary: false,
          );
        }

        await repository.saveEditedProfile('dive-1', const [
          DiveProfilePoint(timestamp: 0, depth: 0.0),
          DiveProfilePoint(timestamp: 4, depth: 20.0),
        ]);

        final dive = await repository.getDiveById('dive-1');

        // dc-a's demoted originals are superseded by the edit; dc-b's are not.
        // Rows sharing a timestamp have no defined order, so compare unordered.
        expect(
          asPairs(dive!.profile),
          unorderedEquals(<(int, double)>[
            (0, 0.0),
            (0, 0.1),
            (4, 20.0),
            (4, 20.5),
            (8, 0.2),
          ]),
        );
      },
    );

    test('an unedited multi-computer dive keeps every sample', () async {
      await insertComputer('dc-a');
      await insertComputer('dc-b');
      await insertDataSource(id: 'src-a', computerId: 'dc-a', isPrimary: true);
      await insertDataSource(id: 'src-b', computerId: 'dc-b', isPrimary: false);

      for (final (ts, depth) in [(0, 0.0), (4, 20.0)]) {
        await insertProfileRow(
          timestamp: ts,
          depth: depth,
          computerId: 'dc-a',
          isPrimary: true,
        );
      }
      for (final (ts, depth) in [(0, 0.1), (4, 20.5)]) {
        await insertProfileRow(
          timestamp: ts,
          depth: depth,
          computerId: 'dc-b',
          isPrimary: false,
        );
      }

      final dive = await repository.getDiveById('dive-1');

      expect(
        asPairs(dive!.profile),
        unorderedEquals(<(int, double)>[
          (0, 0.0),
          (0, 0.1),
          (4, 20.0),
          (4, 20.5),
        ]),
      );
    });

    test('a dive with no primary rows at all keeps its samples', () async {
      // setPrimaryDataSource can strand a file import with zero primary rows;
      // nothing was edited, so nothing may be dropped.
      for (final (ts, depth) in [(0, 0.0), (4, 20.0), (8, 0.0)]) {
        await insertProfileRow(
          timestamp: ts,
          depth: depth,
          computerId: null,
          isPrimary: false,
        );
      }

      final dive = await repository.getDiveById('dive-1');

      expect(asPairs(dive!.profile), [(0, 0.0), (4, 20.0), (8, 0.0)]);
    });
  });
}
