import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProfileSeriesRepository repo;
  const now = 1750000000000;

  const samples = [
    ProfileSample(timestamp: 0, depth: 0.0),
    ProfileSample(timestamp: 10, depth: 12.0, temperature: 21.0, ndl: 2000),
    ProfileSample(timestamp: 20, depth: 18.5, ceiling: 3.0, decoType: 2),
    ProfileSample(timestamp: 30, depth: 5.0),
  ];

  setUp(() async {
    db = await setUpTestDatabase();
    repo = ProfileSeriesRepository();
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
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'comp-1',
            name: 'Perdix',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  group('insert and read', () {
    test('insertSeries stores the encoded samples and summary', () async {
      final id = await repo.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        samples: samples,
        now: now,
      );

      final row = await (db.select(
        db.diveProfileSeries,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(row.diveId, 'dive-1');
      expect(row.computerId, 'comp-1');
      expect(row.sourceId, isNull);
      expect(row.isPrimary, isTrue);
      expect(row.sampleCount, 4);
      expect(row.startTimestamp, 0);
      expect(row.endTimestamp, 30);
      expect(row.maxDepth, 18.5);
      expect(row.firstDepth, 0.0);
      expect(row.lastDepth, 5.0);
      expect(row.hasDecoType, isTrue);
      expect(row.hasDecoStop, isTrue);
      expect(row.hasPositiveCeiling, isTrue);
      expect(row.codecVersion, 1);
      expect(row.createdAt, now);
      expect(row.updatedAt, now);

      final read = await repo.getSeriesForDive('dive-1');
      expect(read, hasLength(1));
      expect(read.single.id, id);
      expect(read.single.samples, samples);
      expect(read.single.summary.sampleCount, 4);
      expect(read.single.points.map((p) => p.depth), [0.0, 12.0, 18.5, 5.0]);
    });

    test('insertSeries stamps an hlc through the sync repository', () async {
      final id = await repo.insertSeries(
        diveId: 'dive-1',
        samples: samples,
        now: now,
      );
      final row = await (db.select(
        db.diveProfileSeries,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(row.hlc, isNotNull);
      final pending = await (db.select(
        db.syncRecords,
      )..where((t) => t.recordId.equals(id))).getSingle();
      expect(pending.entityType, ProfileSeriesRepository.entityType);
    });

    test('insertSeries drops exact duplicate samples', () async {
      final id = await repo.insertSeries(
        diveId: 'dive-1',
        samples: [samples[0], samples[1], samples[1], samples[2]],
        now: now,
      );
      final read = await repo.getSeriesById(id);
      expect(read!.samples, [samples[0], samples[1], samples[2]]);
      expect(read.summary.sampleCount, 3);
    });

    test('insertSeries accepts a caller-supplied id', () async {
      final id = await repo.insertSeries(
        diveId: 'dive-1',
        samples: samples,
        id: 'fixed-id',
        now: now,
      );
      expect(id, 'fixed-id');
      expect(await repo.getSeriesById('fixed-id'), isNotNull);
    });

    test('an empty sample list is refused', () async {
      expect(
        () => repo.insertSeries(diveId: 'dive-1', samples: const []),
        throwsArgumentError,
      );
    });

    test('getSeriesForDive orders by start, not by id', () async {
      // The two keys disagree: 'b' starts first but sorts last by id.
      await repo.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: false,
        samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
        id: 'b',
        now: now,
      );
      await repo.insertSeries(
        diveId: 'dive-1',
        samples: const [
          ProfileSample(timestamp: 5, depth: 2.0),
          ProfileSample(timestamp: 30, depth: 6.0),
        ],
        id: 'a',
        now: now,
      );
      final all = await repo.getSeriesForDive('dive-1');
      expect(all.map((s) => s.id), ['b', 'a']);
      final primary = await repo.getSeriesForDive('dive-1', primaryOnly: true);
      expect(primary.map((s) => s.id), ['a']);
    });

    test('getSeriesForDive breaks an equal start on the id', () async {
      await repo.insertSeries(
        diveId: 'dive-1',
        samples: samples,
        id: 'b',
        now: now,
      );
      await repo.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        samples: samples,
        id: 'a',
        now: now,
      );
      final all = await repo.getSeriesForDive('dive-1');
      expect(all.map((s) => s.id), ['a', 'b']);
    });

    test('getSeriesById returns null for an unknown id', () async {
      expect(await repo.getSeriesById('nope'), isNull);
    });

    test(
      'getSeriesForDives groups by dive and omits dives without series',
      () async {
        await db
            .into(db.dives)
            .insert(
              const DivesCompanion(
                id: Value('dive-2'),
                diveDateTime: Value(now),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        await repo.insertSeries(
          diveId: 'dive-1',
          samples: samples,
          id: 'a',
          now: now,
        );
        await repo.insertSeries(
          diveId: 'dive-2',
          samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
          id: 'b',
          now: now,
        );
        final byDive = await repo.getSeriesForDives([
          'dive-1',
          'dive-2',
          'dive-9',
        ]);
        expect(byDive.keys.toSet(), {'dive-1', 'dive-2'});
        expect(byDive['dive-1']!.single.id, 'a');
        expect(byDive['dive-2']!.single.id, 'b');
        expect(await repo.getSeriesForDives(const []), isEmpty);
      },
    );
  });

  group('flags and deletes', () {
    late String computerSeries;
    late String editSeries;

    setUp(() async {
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion.insert(
              id: 'src-1',
              diveId: 'dive-1',
              computerId: const Value('comp-1'),
              isPrimary: const Value(true),
              importedAt: DateTime.fromMillisecondsSinceEpoch(now),
              createdAt: DateTime.fromMillisecondsSinceEpoch(now),
            ),
          );
      computerSeries = await repo.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        sourceId: 'src-1',
        samples: samples,
        now: now,
      );
      editSeries = await repo.insertSeries(
        diveId: 'dive-1',
        sourceId: 'src-1',
        samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
        now: now,
      );
    });

    test('demoteAll clears is_primary on every series of the dive', () async {
      expect(await repo.demoteAll('dive-1', now: now + 1), 2);
      final rows = await repo.getSeriesForDive('dive-1');
      expect(rows.map((s) => s.isPrimary), everyElement(isFalse));
      expect(rows.map((s) => s.updatedAt), everyElement(now + 1));
    });

    test('promoteOwnedBy matches the source FK first', () async {
      await repo.demoteAll('dive-1');
      final promoted = await repo.promoteOwnedBy(
        'dive-1',
        sourceId: 'src-1',
        computerId: 'comp-1',
        now: now + 2,
      );
      expect(promoted, 2, reason: 'both series carry source src-1');
    });

    test(
      'promoteOwnedBy falls back to computer id for rows without a source',
      () async {
        final legacy = await repo.insertSeries(
          diveId: 'dive-1',
          computerId: 'comp-1',
          isPrimary: false,
          samples: const [ProfileSample(timestamp: 0, depth: 3.0)],
          now: now,
        );
        await repo.demoteAll('dive-1');
        final promoted = await repo.promoteOwnedBy(
          'dive-1',
          sourceId: 'other-source',
          computerId: 'comp-1',
        );
        expect(promoted, 1);
        final row = await repo.getSeriesById(legacy);
        expect(row!.isPrimary, isTrue);
      },
    );

    test(
      'promoteOwnedBy with a null computer matches null, not everything',
      () async {
        final manual = await repo.insertSeries(
          diveId: 'dive-1',
          isPrimary: false,
          samples: const [ProfileSample(timestamp: 0, depth: 4.0)],
          now: now,
        );
        await repo.demoteAll('dive-1');
        final promoted = await repo.promoteOwnedBy(
          'dive-1',
          sourceId: 'other-source',
          computerId: null,
        );
        expect(promoted, 1);
        expect((await repo.getSeriesById(manual))!.isPrimary, isTrue);
        expect((await repo.getSeriesById(computerSeries))!.isPrimary, isFalse);
      },
    );

    test('promoteWinnerOwnedBy promotes the null-computer edit only', () async {
      await repo.demoteAll('dive-1');
      final promoted = await repo.promoteWinnerOwnedBy(
        'dive-1',
        sourceId: 'src-1',
        computerId: 'comp-1',
        now: now + 3,
      );
      expect(promoted, [
        editSeries,
      ], reason: 'a manual edit outranks its source over the same range');
      expect((await repo.getSeriesById(editSeries))!.isPrimary, isTrue);
      expect((await repo.getSeriesById(computerSeries))!.isPrimary, isFalse);
    });

    test(
      'promoteWinnerOwnedBy promotes every segment over a disjoint range',
      () async {
        // One computer, one dive logged in two pieces, neither carrying a
        // source row: the shape DiveMergeService leaves behind. The retired
        // row-per-sample SQL promoted the winner at EACH timestamp, so both
        // segments stayed live; promoting a single series would hand the
        // dive back half its profile.
        final first = await repo.insertSeries(
          diveId: 'dive-1',
          computerId: 'comp-1',
          isPrimary: false,
          samples: const [
            ProfileSample(timestamp: 0, depth: 1.0),
            ProfileSample(timestamp: 60, depth: 10.0),
          ],
          now: now,
        );
        final second = await repo.insertSeries(
          diveId: 'dive-1',
          computerId: 'comp-1',
          isPrimary: false,
          samples: const [
            ProfileSample(timestamp: 600, depth: 12.0),
            ProfileSample(timestamp: 660, depth: 3.0),
          ],
          now: now,
        );
        await repo.demoteAll('dive-1');

        final promoted = await repo.promoteWinnerOwnedBy(
          'dive-1',
          sourceId: 'no-such-source',
          computerId: 'comp-1',
          now: now + 4,
        );

        expect(promoted.toSet(), {first, second});
        expect((await repo.getSeriesById(first))!.isPrimary, isTrue);
        expect((await repo.getSeriesById(second))!.isPrimary, isTrue);
      },
    );

    test(
      'promoteWinnerOwnedBy returns nothing when nothing is owned',
      () async {
        expect(
          await repo.promoteWinnerOwnedBy(
            'dive-1',
            sourceId: 'other-source',
            computerId: 'other-computer',
          ),
          isEmpty,
        );
      },
    );

    test(
      'deleteOwnedBy removes the matching series and logs tombstones',
      () async {
        final deleted = await repo.deleteOwnedBy(
          'dive-1',
          sourceId: 'src-1',
          computerId: 'comp-1',
        );
        expect(deleted.toSet(), {computerSeries, editSeries});
        expect(await repo.getSeriesForDive('dive-1'), isEmpty);
        final tombstones =
            await (db.select(db.deletionLog)..where(
                  (t) =>
                      t.entityType.equals(ProfileSeriesRepository.entityType),
                ))
                .get();
        expect(tombstones, hasLength(2));
        expect(tombstones.map((t) => t.recordId).toSet(), {
          computerSeries,
          editSeries,
        });
      },
    );

    test('deleteForDive removes every series of the dive', () async {
      final deleted = await repo.deleteForDive('dive-1');
      expect(deleted, hasLength(2));
      expect(await repo.getSeriesForDive('dive-1'), isEmpty);
    });
  });

  group('unreadable blobs', () {
    /// Overwrites [id]'s blob with bytes the codec cannot decode. Storage
    /// can bit-rot even though the writer never produces this.
    Future<void> corrupt(String id) async {
      await (db.update(
        db.diveProfileSeries,
      )..where((t) => t.id.equals(id))).write(
        DiveProfileSeriesCompanion(
          samples: Value(Uint8List.fromList(const [1, 2, 3, 4])),
        ),
      );
    }

    test('getSeriesForDive skips the bad row and keeps the rest', () async {
      final badId = await repo.insertSeries(
        diveId: 'dive-1',
        samples: samples,
        now: now,
      );
      final goodId = await repo.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        samples: const [ProfileSample(timestamp: 100, depth: 3.0)],
        now: now,
      );
      await corrupt(badId);

      final read = await repo.getSeriesForDive('dive-1');
      expect(read.map((s) => s.id), [goodId]);
    });

    test('getSeriesForDives skips the bad row and keeps the rest', () async {
      final badId = await repo.insertSeries(
        diveId: 'dive-1',
        samples: samples,
        now: now,
      );
      final goodId = await repo.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        samples: const [ProfileSample(timestamp: 100, depth: 3.0)],
        now: now,
      );
      await corrupt(badId);

      final byDive = await repo.getSeriesForDives(['dive-1']);
      expect(byDive['dive-1']!.map((s) => s.id), [goodId]);
    });

    test('getSeriesById returns null for an unreadable row', () async {
      final badId = await repo.insertSeries(
        diveId: 'dive-1',
        samples: samples,
        now: now,
      );
      await corrupt(badId);
      expect(await repo.getSeriesById(badId), isNull);
    });
  });
}
