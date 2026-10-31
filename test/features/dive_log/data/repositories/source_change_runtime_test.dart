import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/dive_split_service.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

/// A dive's stored runtime wins over its timestamps in `Dive.effectiveRuntime`,
/// so an operation that re-points the dive's measured snapshot at another
/// source has to move the runtime with the entry and exit times. Left behind,
/// the dive claims a 60-minute runtime across a 50-minute entry-to-exit span
/// (issue #3899).
void main() {
  late AppDatabase db;
  late DiveRepository repository;
  late DiveSplitService splitter;
  late ProfileSeriesRepository profileSeries;

  final entry = DateTime.utc(2026, 3, 1, 10);
  final exitA = entry.add(const Duration(seconds: 3600));
  final exitB = entry.add(const Duration(seconds: 3000));

  Future<void> insertComputer(String id) async {
    final now = entry.millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value('Computer $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  /// A consolidated dive showing source A: 10:00 to 11:00, runtime 3600.
  Future<void> insertDive() async {
    final now = entry.millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-1'),
            computerId: const Value('dc-a'),
            diveDateTime: Value(now),
            entryTime: Value(now),
            exitTime: Value(exitA.millisecondsSinceEpoch),
            runtime: const Value(3600),
            bottomTime: const Value(3300),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertSource(
    String id,
    String computerId, {
    required bool isPrimary,
    int? duration,
    DateTime? entryTime,
    DateTime? exitTime,
  }) async {
    final createdAt = DateTime.utc(2026, 3, 1);
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: Value(id),
            diveId: const Value('dive-1'),
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            duration: Value(duration),
            entryTime: Value(entryTime),
            exitTime: Value(exitTime),
            importedAt: Value(createdAt),
            createdAt: Value(createdAt),
          ),
        );
  }

  Future<void> insertSourceA({int? duration = 3600}) => insertSource(
    'src-a',
    'dc-a',
    isPrimary: true,
    duration: duration,
    entryTime: entry,
    exitTime: exitA,
  );

  Future<Dive> getDive(String id) =>
      (db.select(db.dives)..where((t) => t.id.equals(id))).getSingle();

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
    splitter = DiveSplitService(repository);
    profileSeries = ProfileSeriesRepository();
    await insertComputer('dc-a');
    await insertComputer('dc-b');
    await insertDive();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('Set as primary', () {
    test('takes the runtime the new primary reports', () async {
      await insertSourceA();
      await insertSource(
        'src-b',
        'dc-b',
        isPrimary: false,
        duration: 3000,
        entryTime: entry,
        exitTime: exitB,
      );

      await repository.setPrimaryDataSource(
        diveId: 'dive-1',
        computerReadingId: 'src-b',
      );

      expect((await getDive('dive-1')).runtime, 3000);
      final dive = await repository.getDiveById('dive-1');
      expect(dive!.effectiveRuntime, const Duration(seconds: 3000));
    });

    test('falls back to the entry-to-exit span of a source that reports no '
        'runtime', () async {
      await insertSourceA();
      await insertSource(
        'src-b',
        'dc-b',
        isPrimary: false,
        entryTime: entry,
        exitTime: exitB,
      );

      await repository.setPrimaryDataSource(
        diveId: 'dive-1',
        computerReadingId: 'src-b',
      );

      expect((await getDive('dive-1')).runtime, 3000);
    });

    test('clears the runtime of a source with no timing, leaving the live '
        'profile to speak for it', () async {
      await insertSourceA();
      await insertSource('src-b', 'dc-b', isPrimary: false);
      await profileSeries.insertSeries(
        diveId: 'dive-1',
        computerId: 'dc-b',
        sourceId: 'src-b',
        isPrimary: false,
        samples: const [
          ProfileSample(timestamp: 0, depth: 0),
          ProfileSample(timestamp: 1200, depth: 20),
          ProfileSample(timestamp: 2400, depth: 0),
        ],
        now: 1000,
      );

      await repository.setPrimaryDataSource(
        diveId: 'dive-1',
        computerReadingId: 'src-b',
      );

      expect((await getDive('dive-1')).runtime, isNull);
      final dive = await repository.getDiveById('dive-1');
      expect(dive!.effectiveRuntime, const Duration(seconds: 2400));
    });

    test('swapping back restores the first runtime', () async {
      await insertSourceA();
      await insertSource(
        'src-b',
        'dc-b',
        isPrimary: false,
        duration: 3000,
        entryTime: entry,
        exitTime: exitB,
      );

      await repository.setPrimaryDataSource(
        diveId: 'dive-1',
        computerReadingId: 'src-b',
      );
      await repository.setPrimaryDataSource(
        diveId: 'dive-1',
        computerReadingId: 'src-a',
      );

      expect((await getDive('dive-1')).runtime, 3600);
    });

    test('bounds the derived bottom time by the fallback runtime', () async {
      await insertSourceA();
      await insertSource(
        'src-b',
        'dc-b',
        isPrimary: false,
        entryTime: entry,
        exitTime: entry.add(const Duration(seconds: 1000)),
      );
      // Samples run on past the exit: unbounded, they yield 1260 s.
      await profileSeries.insertSeries(
        diveId: 'dive-1',
        computerId: 'dc-b',
        sourceId: 'src-b',
        isPrimary: false,
        samples: const [
          ProfileSample(timestamp: 0, depth: 0),
          ProfileSample(timestamp: 60, depth: 30),
          ProfileSample(timestamp: 1260, depth: 30),
          ProfileSample(timestamp: 1320, depth: 0),
        ],
        now: 1000,
      );

      await repository.setPrimaryDataSource(
        diveId: 'dive-1',
        computerReadingId: 'src-b',
      );

      final row = await getDive('dive-1');
      expect(row.runtime, 1000);
      expect(row.bottomTime, 1000);
    });
  });

  test('switching to a series another source owns moves the runtime', () async {
    await insertSourceA();
    await insertSource(
      'src-b',
      'dc-b',
      isPrimary: false,
      duration: 3000,
      entryTime: entry,
      exitTime: exitB,
    );
    final seriesId = await profileSeries.insertSeries(
      diveId: 'dive-1',
      computerId: 'dc-b',
      sourceId: 'src-b',
      isPrimary: false,
      samples: const [
        ProfileSample(timestamp: 0, depth: 0),
        ProfileSample(timestamp: 3000, depth: 0),
      ],
      now: 1000,
    );

    await repository.setActiveProfileSeries('dive-1', seriesId);

    expect((await getDive('dive-1')).runtime, 3000);
  });

  group('Split into separate dive', () {
    test('the new dive takes the runtime its source reports', () async {
      await insertSourceA();
      await insertSource(
        'src-b',
        'dc-b',
        isPrimary: false,
        duration: 3000,
        entryTime: entry,
        exitTime: exitB,
      );

      final newDiveId = await splitter.split(
        diveId: 'dive-1',
        sourceId: 'src-b',
      );

      expect((await getDive(newDiveId)).runtime, 3000);
      final dive = await repository.getDiveById(newDiveId);
      expect(dive!.effectiveRuntime, const Duration(seconds: 3000));
      // The dive left behind still shows source A, so its runtime stays.
      expect((await getDive('dive-1')).runtime, 3600);
    });

    test('the new dive falls back to its own span', () async {
      await insertSourceA();
      await insertSource(
        'src-b',
        'dc-b',
        isPrimary: false,
        entryTime: entry,
        exitTime: exitB,
      );

      final newDiveId = await splitter.split(
        diveId: 'dive-1',
        sourceId: 'src-b',
      );

      expect((await getDive(newDiveId)).runtime, 3000);
    });

    test('a source with no timing keeps the dive\'s timestamps and the runtime '
        'that goes with them', () async {
      await insertSourceA();
      await insertSource('src-b', 'dc-b', isPrimary: false);

      final newDiveId = await splitter.split(
        diveId: 'dive-1',
        sourceId: 'src-b',
      );

      final row = await getDive(newDiveId);
      expect(row.exitTime, exitA.millisecondsSinceEpoch);
      expect(row.runtime, 3600);
    });

    test('a dive with an unusable span keeps its runtime when the source has '
        'no timing', () async {
      await (db.update(db.dives)..where((t) => t.id.equals('dive-1'))).write(
        const DivesCompanion(exitTime: Value(null)),
      );
      await insertSourceA();
      await insertSource('src-b', 'dc-b', isPrimary: false);

      final newDiveId = await splitter.split(
        diveId: 'dive-1',
        sourceId: 'src-b',
      );

      expect((await getDive(newDiveId)).runtime, 3600);
    });

    test('splitting the primary gives each dive its own runtime', () async {
      await insertSourceA();
      await insertSource(
        'src-b',
        'dc-b',
        isPrimary: false,
        duration: 3000,
        entryTime: entry,
        exitTime: exitB,
      );

      final newDiveId = await splitter.split(
        diveId: 'dive-1',
        sourceId: 'src-a',
      );

      expect((await getDive(newDiveId)).runtime, 3600);
      expect((await getDive('dive-1')).runtime, 3000);
      final dive = await repository.getDiveById('dive-1');
      expect(dive!.effectiveRuntime, const Duration(seconds: 3000));
    });

    test('the promoted source falls back to its own span', () async {
      await insertSourceA();
      await insertSource(
        'src-b',
        'dc-b',
        isPrimary: false,
        entryTime: entry,
        exitTime: exitB,
      );

      await splitter.split(diveId: 'dive-1', sourceId: 'src-a');

      expect((await getDive('dive-1')).runtime, 3000);
    });

    test('a promoted source with no timing keeps the dive\'s timestamps and '
        'runtime', () async {
      await insertSourceA();
      await insertSource('src-b', 'dc-b', isPrimary: false);

      await splitter.split(diveId: 'dive-1', sourceId: 'src-a');

      final row = await getDive('dive-1');
      expect(row.exitTime, exitA.millisecondsSinceEpoch);
      expect(row.runtime, 3600);
    });
  });
}
