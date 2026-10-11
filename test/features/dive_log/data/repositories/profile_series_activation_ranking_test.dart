import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3189: a source owns every generation of its profile (the original
/// and each edit, over the same timestamps), and a primary swap back to it
/// must bring back the generation that was live when it was swapped away.
///
/// A file import names no computer, so before `activated_at` the edit and
/// its original tied on the null-computer key and the winner fell to the
/// greater id, a random v4 UUID. Every pre-edit series here carries an id
/// that sorts above any UUID, so the old ranking loses every time rather
/// than half the time.
void main() {
  late DiveRepository repository;
  late ProfileSeriesRepository seriesRepo;
  late AppDatabase db;

  const now = 1750000000000;

  Future<void> insertSource(String id, {required bool isPrimary}) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion(
          id: Value(id),
          diveId: const Value('dive-1'),
          isPrimary: Value(isPrimary),
          importedAt: Value(DateTime(2026, 1, 1)),
          createdAt: Value(DateTime(2026, 1, 1)),
        ),
      );

  List<ProfileSample> span(double maxDepth) => [
    const ProfileSample(timestamp: 0, depth: 0),
    ProfileSample(timestamp: 60, depth: maxDepth),
    const ProfileSample(timestamp: 120, depth: 0),
  ];

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
    seriesRepo = ProfileSeriesRepository();
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

  const edited = [
    DiveProfilePoint(timestamp: 0, depth: 0),
    DiveProfilePoint(timestamp: 60, depth: 28),
    DiveProfilePoint(timestamp: 120, depth: 0),
  ];

  List<double> depthsOf(List<DiveProfilePoint> points) => [
    for (final p in points) p.depth,
  ];

  group('two file-imported sources (no computer)', () {
    setUp(() async {
      await insertSource('src-a', isPrimary: true);
      await insertSource('src-b', isPrimary: false);
      await seriesRepo.insertSeries(
        id: 'zz-original-a',
        diveId: 'dive-1',
        sourceId: 'src-a',
        isPrimary: true,
        samples: span(20),
        now: now,
      );
      await seriesRepo.insertSeries(
        id: 'zz-original-b',
        diveId: 'dive-1',
        sourceId: 'src-b',
        isPrimary: false,
        samples: span(30),
        now: now,
      );
    });

    test('swapping primary away and back keeps the edit', () async {
      await repository.saveEditedProfileWithKind(
        diveId: 'dive-1',
        editedPoints: edited,
        editKind: 'profile_editor',
      );
      await repository.setPrimaryDataSource(
        diveId: 'dive-1',
        computerReadingId: 'src-b',
      );
      await repository.setPrimaryDataSource(
        diveId: 'dive-1',
        computerReadingId: 'src-a',
      );

      expect(depthsOf(await repository.getDiveProfile('dive-1')), [0, 28, 0]);
      final profiles = await repository.getProfilesByDataSource('dive-1');
      expect(profiles['src-a']!.isEdited, isTrue);
    });

    test('a demoted edited source reads as its edit', () async {
      await repository.saveEditedProfileWithKind(
        diveId: 'dive-1',
        editedPoints: edited,
        editKind: 'profile_editor',
      );
      await repository.setPrimaryDataSource(
        diveId: 'dive-1',
        computerReadingId: 'src-b',
      );

      final profiles = await repository.getProfilesByDataSource('dive-1');
      expect(depthsOf(profiles['src-a']!.points), [0, 28, 0]);
      expect(depthsOf(profiles['src-b']!.points), [0, 30, 0]);
    });
  });

  group('one downloaded source', () {
    setUp(() async {
      await db
          .into(db.diveComputers)
          .insert(
            const DiveComputersCompanion(
              id: Value('dc-a'),
              name: Value('Computer A'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-a'),
              diveId: const Value('dive-1'),
              computerId: const Value('dc-a'),
              isPrimary: const Value(true),
              importedAt: Value(DateTime(2026, 1, 1)),
              createdAt: Value(DateTime(2026, 1, 1)),
            ),
          );
      await insertSource('src-b', isPrimary: false);
      await seriesRepo.insertSeries(
        id: 'zz-original-a',
        diveId: 'dive-1',
        computerId: 'dc-a',
        sourceId: 'src-a',
        isPrimary: true,
        samples: span(20),
        now: now,
      );
      await seriesRepo.insertSeries(
        id: 'zz-original-b',
        diveId: 'dive-1',
        sourceId: 'src-b',
        isPrimary: false,
        samples: span(30),
        now: now,
      );
    });

    test(
      'a revision chosen from history survives a swap away and back',
      () async {
        await repository.saveEditedProfileWithKind(
          diveId: 'dive-1',
          editedPoints: edited,
          editKind: 'profile_editor',
        );
        // Back to the downloaded original through profile history, which keeps
        // the edit as a revision rather than deleting it.
        await repository.setActiveProfileSeries('dive-1', 'zz-original-a');
        await repository.setPrimaryDataSource(
          diveId: 'dive-1',
          computerReadingId: 'src-b',
        );
        await repository.setPrimaryDataSource(
          diveId: 'dive-1',
          computerReadingId: 'src-a',
        );

        expect(depthsOf(await repository.getDiveProfile('dive-1')), [0, 20, 0]);
      },
    );
  });

  group('ProfileSeriesRepository', () {
    setUp(() async {
      await insertSource('src-a', isPrimary: true);
    });

    Future<int?> activatedAtOf(String id) async => (await (db.select(
      db.diveProfileSeries,
    )..where((t) => t.id.equals(id))).getSingle()).activatedAt;

    test(
      'insertSeries stamps a primary series and not a demoted one',
      () async {
        await seriesRepo.insertSeries(
          id: 'live',
          diveId: 'dive-1',
          sourceId: 'src-a',
          samples: span(20),
          now: now,
        );
        await seriesRepo.insertSeries(
          id: 'demoted',
          diveId: 'dive-1',
          sourceId: 'src-a',
          isPrimary: false,
          samples: span(20),
          now: now,
        );

        expect(await activatedAtOf('live'), now);
        expect(await activatedAtOf('demoted'), isNull);
      },
    );

    test('insertSeries keeps an activation time it is given', () async {
      await seriesRepo.insertSeries(
        id: 'copied',
        diveId: 'dive-1',
        sourceId: 'src-a',
        isPrimary: false,
        activatedAt: const Value(now - 5),
        samples: span(20),
        now: now,
      );
      // A copy made primary of a series never activated stays unstamped,
      // or it would outrank the edit it was copied alongside.
      await seriesRepo.insertSeries(
        id: 'copied-never-live',
        diveId: 'dive-1',
        sourceId: 'src-a',
        activatedAt: const Value(null),
        samples: span(20),
        now: now,
      );

      expect(await activatedAtOf('copied'), now - 5);
      expect(await activatedAtOf('copied-never-live'), isNull);
    });

    test('the newer of two edits wins a promotion', () async {
      // An edit of an edit: both name no computer and cover one range.
      await seriesRepo.insertSeries(
        id: 'zz-first-edit',
        diveId: 'dive-1',
        sourceId: 'src-a',
        samples: span(20),
        now: now,
      );
      await seriesRepo.demoteAll('dive-1', now: now + 1);
      await seriesRepo.insertSeries(
        id: 'aa-second-edit',
        diveId: 'dive-1',
        sourceId: 'src-a',
        samples: span(25),
        now: now + 1,
      );
      await seriesRepo.demoteAll('dive-1', now: now + 2);

      final promoted = await seriesRepo.promoteWinnerOwnedBy(
        'dive-1',
        sourceId: 'src-a',
        computerId: null,
        now: now + 3,
      );

      expect(promoted, ['aa-second-edit']);
    });

    test('a re-parse inserted beneath a live edit stays beneath it', () async {
      // DiveReimportService._replaceProfile keeps the primary edit and lands
      // the fresh parse demoted, so the newest series is the original.
      await seriesRepo.insertSeries(
        id: 'aa-edit',
        diveId: 'dive-1',
        sourceId: 'src-a',
        samples: span(28),
        now: now,
      );
      await seriesRepo.insertSeries(
        id: 'zz-reparse',
        diveId: 'dive-1',
        sourceId: 'src-a',
        isPrimary: false,
        samples: span(20),
        now: now + 1,
      );
      await seriesRepo.demoteAll('dive-1', now: now + 2);

      final promoted = await seriesRepo.promoteWinnerOwnedBy(
        'dive-1',
        sourceId: 'src-a',
        computerId: null,
        now: now + 3,
      );

      expect(promoted, ['aa-edit']);
    });

    test('the restore fallback stamps what it promotes', () async {
      await seriesRepo.insertSeries(
        id: 'original',
        diveId: 'dive-1',
        sourceId: 'src-a',
        isPrimary: false,
        samples: span(20),
        now: now,
      );

      await seriesRepo.promoteAll('dive-1', now: now + 10);

      expect(await activatedAtOf('original'), now + 10);
    });

    test('hasLiveEdit sees only a primary series with no computer', () async {
      // A merge's synthetic surface fill: primary, no computer, no source.
      await seriesRepo.insertSeries(
        id: 'surface-fill',
        diveId: 'dive-1',
        samples: span(0),
        now: now,
      );
      await seriesRepo.insertSeries(
        id: 'demoted-edit',
        diveId: 'dive-1',
        sourceId: 'src-a',
        isPrimary: false,
        samples: span(20),
        now: now,
      );
      expect(
        await seriesRepo.hasLiveEdit('dive-1', sourceId: 'src-a'),
        isFalse,
      );

      await seriesRepo.insertSeries(
        id: 'live-edit',
        diveId: 'dive-1',
        sourceId: 'src-a',
        samples: span(28),
        now: now,
      );
      expect(await seriesRepo.hasLiveEdit('dive-1', sourceId: 'src-a'), isTrue);
      expect(
        await seriesRepo.hasLiveEdit('dive-1', sourceId: 'src-z'),
        isFalse,
      );
    });

    test('activating a series stamps it as the chosen generation', () async {
      await seriesRepo.insertSeries(
        id: 'original',
        diveId: 'dive-1',
        sourceId: 'src-a',
        isPrimary: false,
        samples: span(20),
        now: now,
      );
      await seriesRepo.insertSeries(
        id: 'edit',
        diveId: 'dive-1',
        sourceId: 'src-a',
        samples: span(28),
        now: now,
      );

      await seriesRepo.activateSeriesForDive(
        diveId: 'dive-1',
        seriesId: 'original',
        now: now + 10,
      );

      expect(await activatedAtOf('original'), now + 10);
      expect(await activatedAtOf('edit'), now);
    });
  });
}
