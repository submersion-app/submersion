import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_row_decoder.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/bound_variables.dart';
import '../../../../helpers/drift_statement_log.dart';
import '../../../../helpers/test_database.dart';

/// A selection of hundreds of dives has to find out which of them have a
/// profile without loading those profiles (#3856). These tests hold the
/// sample-free answer to exactly what the real read would have returned, and
/// to reading neither packed blob on the way.
void main() {
  const now = 1750000000000;
  final firstDay = DateTime.utc(2026, 1, 1);

  late AppDatabase db;
  late DiveRepository repository;
  late ProfileSeriesRepository series;

  var counter = 0;

  List<ProfileSample> samples(int count) => [
    for (var i = 0; i < count; i++)
      ProfileSample(timestamp: i * 10, depth: 10.0 + i),
  ];

  Future<void> insertDive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: const Value(now),
          createdAt: const Value(now),
          updatedAt: const Value(now),
        ),
      );

  Future<void> insertComputer(String id) => db
      .into(db.diveComputers)
      .insert(
        DiveComputersCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: const Value(now),
          updatedAt: const Value(now),
        ),
      );

  Future<void> insertSource(
    String id,
    String diveId, {
    String? computerId,
    bool isPrimary = false,
    int createdDay = 0,
    Uint8List? rawData,
  }) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion(
          id: Value(id),
          diveId: Value(diveId),
          computerId: Value(computerId),
          isPrimary: Value(isPrimary),
          importedAt: Value(firstDay.add(Duration(days: createdDay))),
          createdAt: Value(firstDay.add(Duration(days: createdDay))),
          rawData: Value(rawData),
        ),
      );

  Future<void> insertSeries(
    String diveId,
    int sampleCount, {
    String? sourceId,
    String? computerId,
    bool isPrimary = true,
  }) => series.insertSeries(
    id: 'series-${counter++}',
    diveId: diveId,
    sourceId: sourceId,
    computerId: computerId,
    isPrimary: isPrimary,
    now: now,
    samples: samples(sampleCount),
  );

  /// What [DiveRepository.getProfilesByDataSource] gives the dive's primary
  /// source, which is what the comparison ends up drawing.
  Future<int> pointsOnRealRead(String diveId) async {
    final profiles = await repository.getProfilesByDataSource(diveId);
    return profiles.values.firstOrNull?.points.length ?? 0;
  }

  group('getPrimarySourceSampleCounts', () {
    setUp(() async {
      db = await setUpTestDatabase();
      repository = DiveRepository();
      series = ProfileSeriesRepository();
      counter = 0;
    });

    tearDown(tearDownTestDatabase);

    test('agrees with the real read on every shape of dive', () async {
      // One source, one series.
      await insertDive('plain');
      await insertSource('plain-src', 'plain', isPrimary: true);
      await insertSeries('plain', 5, sourceId: 'plain-src');

      // Older imports predate dive_data_sources.
      await insertDive('legacy');
      await insertSeries('legacy', 4);

      // A file import can leave no primary series and no source row (#623).
      await insertDive('demoted');
      await insertSeries('demoted', 4, isPrimary: false);

      // A manual log has nothing at all.
      await insertDive('manual');

      // Too short to draw, though it holds a sample.
      await insertDive('one-sample');
      await insertSource('one-src', 'one-sample', isPrimary: true);
      await insertSeries('one-sample', 1, sourceId: 'one-src');

      // The primary source holds no samples while a second computer does: the
      // dive has data, but none of it is the profile the comparison shows.
      await insertComputer('dc-a');
      await insertComputer('dc-b');
      await insertDive('empty-primary');
      await insertSource(
        'ep-primary',
        'empty-primary',
        computerId: 'dc-a',
        isPrimary: true,
      );
      await insertSource(
        'ep-second',
        'empty-primary',
        computerId: 'dc-b',
        createdDay: 1,
      );
      await insertSeries(
        'empty-primary',
        9,
        sourceId: 'ep-second',
        computerId: 'dc-b',
        isPrimary: false,
      );

      // Two computers: only the primary's samples are the dive's profile.
      await insertDive('two-computers');
      await insertSource(
        'tc-primary',
        'two-computers',
        computerId: 'dc-a',
        isPrimary: true,
      );
      await insertSource(
        'tc-second',
        'two-computers',
        computerId: 'dc-b',
        createdDay: 1,
      );
      await insertSeries(
        'two-computers',
        6,
        sourceId: 'tc-primary',
        computerId: 'dc-a',
      );
      await insertSeries(
        'two-computers',
        20,
        sourceId: 'tc-second',
        computerId: 'dc-b',
        isPrimary: false,
      );

      // setPrimaryDataSource can leave a file-imported dive whose primary
      // source owns only demoted series (#623). The flag does not decide
      // whose samples these are, so counting is_primary would lose the dive.
      await insertDive('all-demoted');
      await insertSource('ad-primary', 'all-demoted', isPrimary: true);
      await insertSeries(
        'all-demoted',
        4,
        sourceId: 'ad-primary',
        isPrimary: false,
      );

      // Both computers' series flagged primary: the primary source still
      // shows only its own.
      await insertDive('both-flagged');
      await insertSource(
        'bf-primary',
        'both-flagged',
        computerId: 'dc-a',
        isPrimary: true,
      );
      await insertSource(
        'bf-second',
        'both-flagged',
        computerId: 'dc-b',
        createdDay: 1,
      );
      await insertSeries(
        'both-flagged',
        6,
        sourceId: 'bf-primary',
        computerId: 'dc-a',
      );
      await insertSeries(
        'both-flagged',
        11,
        sourceId: 'bf-second',
        computerId: 'dc-b',
      );

      // A saved edit supersedes its original.
      await insertDive('edited');
      await insertSource(
        'ed-primary',
        'edited',
        computerId: 'dc-a',
        isPrimary: true,
      );
      await insertSeries(
        'edited',
        30,
        sourceId: 'ed-primary',
        computerId: 'dc-a',
        isPrimary: false,
      );
      await insertSeries('edited', 7, sourceId: 'ed-primary');

      // A Combine keeps one source row per segment; they collapse into one
      // chip and it owns the segments of both.
      await insertDive('combined');
      await insertSource(
        'cb-first',
        'combined',
        computerId: 'dc-a',
        isPrimary: true,
      );
      await insertSource(
        'cb-second',
        'combined',
        computerId: 'dc-a',
        createdDay: 1,
      );
      await insertSeries(
        'combined',
        3,
        sourceId: 'cb-first',
        computerId: 'dc-a',
      );
      await insertSeries(
        'combined',
        8,
        sourceId: 'cb-second',
        computerId: 'dc-a',
      );

      const ids = [
        'plain',
        'legacy',
        'demoted',
        'manual',
        'one-sample',
        'empty-primary',
        'two-computers',
        'all-demoted',
        'both-flagged',
        'edited',
        'combined',
      ];
      final counts = await repository.getPrimarySourceSampleCounts(ids);

      for (final id in ids) {
        expect(
          counts[id] ?? 0,
          await pointsOnRealRead(id),
          reason: 'the count for "$id" must match what the read returns',
        );
      }
      expect(counts['two-computers'], 6);
      expect(counts['all-demoted'], 4);
      expect(counts['both-flagged'], 6);
      expect(counts['edited'], 7);
      expect(counts['empty-primary'] ?? 0, 0);
      expect(counts.containsKey('manual'), isFalse);
    });

    test('an empty selection asks nothing', () async {
      expect(await repository.getPrimarySourceSampleCounts(const []), isEmpty);
    });
  });

  group('getPrimarySourceSampleCounts statements', () {
    setUp(() async {
      db = setUpLoggingTestDatabase();
      repository = DiveRepository();
      series = ProfileSeriesRepository();
      counter = 0;
    });

    tearDown(tearDownTestDatabase);

    Future<List<String>> seedDives(int count) => quietly(() async {
      final ids = [for (var i = 0; i < count; i++) 'dive-$count-$i'];
      for (final id in ids) {
        await insertDive(id);
        await insertSource(
          '$id-src',
          id,
          isPrimary: true,
          rawData: Uint8List.fromList(List.filled(32, 7)),
        );
        await insertSeries(id, 3, sourceId: '$id-src');
      }
      return ids;
    });

    test('reads neither packed blob', () async {
      final ids = await seedDives(3);

      final statements = await statementsOf(() async {
        expect(await repository.getPrimarySourceSampleCounts(ids), {
          for (final id in ids) id: 3,
        });
      });

      expect(statements, isNotEmpty);
      for (final statement in statements) {
        expect(readsSeriesBlob(statement), isFalse, reason: statement);
        expect(statement, isNot(contains('raw_data')));
        expect(statement, isNot(contains('raw_fingerprint')));
      }
    });

    test('costs the same statements for 8, 80 and 800 dives', () async {
      final statementCounts = <int>[];
      for (final count in [8, 80, 800]) {
        final ids = await seedDives(count);
        final statements = await statementsOf(() async {
          expect(
            await repository.getPrimarySourceSampleCounts(ids),
            hasLength(count),
          );
        });
        statementCounts.add(statements.length);
      }

      expect(statementCounts.toSet(), hasLength(1));
      expect(statementCounts.first, 2);
    });

    test('stays within the variable budget past one chunk', () async {
      final ids = await seedDives(950);

      final most = await maxBoundVariables(() async {
        expect(
          await repository.getPrimarySourceSampleCounts(ids),
          hasLength(950),
        );
      });

      expect(most, lessThanOrEqualTo(sqliteVariableLimit));
    });
  });

  group('getUndecodedSeriesForDives', () {
    setUp(() async {
      db = await setUpTestDatabase();
      repository = DiveRepository();
      series = ProfileSeriesRepository();
      counter = 0;
    });

    tearDown(tearDownTestDatabase);

    test('matches a full row with its blob left undecoded', () async {
      await insertComputer('dc-a');
      await insertDive('d1');
      await insertDive('d2');
      await insertSource('d1-src', 'd1', computerId: 'dc-a', isPrimary: true);
      await insertSeries('d1', 6, sourceId: 'd1-src', computerId: 'dc-a');
      await insertSeries('d1', 4, isPrimary: false);
      await insertSeries('d2', 5);

      final headers = await series.getUndecodedSeriesForDives(['d1', 'd2']);

      final full = await series.getRowsForDives(['d1', 'd2']);
      expect(headers, full.map(undecodedProfileSeriesRow).toList());
      expect(headers.every((s) => s.samples.isEmpty), isTrue);
      expect(headers.first.summary.sampleCount, greaterThan(0));
    });

    test('an empty list asks nothing', () async {
      expect(await series.getUndecodedSeriesForDives(const []), isEmpty);
    });
  });
}
