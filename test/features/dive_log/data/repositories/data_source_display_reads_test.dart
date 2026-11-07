import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show DiveProfilePoint;

import '../../../../helpers/bound_variables.dart';
import '../../../../helpers/drift_statement_log.dart';
import '../../../../helpers/test_database.dart';

/// Reading which sources a dive shows, and which of them owns each sample,
/// needs only a source row's scalar columns. A row can also hold a whole
/// computer download, which the column converter inflates on every read, so
/// these reads must leave the raw download columns out (issue #4253).
void main() {
  const now = 1750000000000;
  final firstDay = DateTime.utc(2026, 1, 1);

  late AppDatabase db;
  late DiveRepository repository;
  late ProfileSeriesRepository series;

  var counter = 0;

  final rawDownload = Uint8List.fromList(List.filled(4096, 7));
  final rawFingerprint = Uint8List.fromList([1, 2, 3, 4]);

  /// Whether [statement] fetches a raw download column: drift's full row
  /// read of the source table, or either column by name.
  bool readsRawDownload(String statement) => RegExp(
    r'SELECT \* FROM "dive_data_sources"|\braw_data\b|\braw_fingerprint\b',
  ).hasMatch(statement);

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
    required String computerId,
    bool isPrimary = false,
    int createdDay = 0,
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
          rawData: Value(rawDownload),
          rawFingerprint: Value(rawFingerprint),
        ),
      );

  Future<void> insertSeries(
    String diveId, {
    required String sourceId,
    required String computerId,
    required bool isPrimary,
  }) => series.insertSeries(
    id: 'series-${counter++}',
    diveId: diveId,
    sourceId: sourceId,
    computerId: computerId,
    isPrimary: isPrimary,
    now: now,
    samples: [
      for (var i = 0; i < 4; i++)
        ProfileSample(timestamp: i * 10, depth: 10.0 + i),
    ],
  );

  /// Two dives, each with a primary and a second computer, every source
  /// holding a download, and series that mix promoted and demoted rows so
  /// the merged read needs the primary source too.
  Future<List<String>> seedDives() => quietly(() async {
    await insertComputer('dc-a');
    await insertComputer('dc-b');
    final ids = ['d1', 'd2'];
    for (final id in ids) {
      await insertDive(id);
      await insertSource('$id-a', id, computerId: 'dc-a', isPrimary: true);
      await insertSource('$id-b', id, computerId: 'dc-b', createdDay: 1);
      await insertSeries(
        id,
        sourceId: '$id-a',
        computerId: 'dc-a',
        isPrimary: true,
      );
      await insertSeries(
        id,
        sourceId: '$id-b',
        computerId: 'dc-b',
        isPrimary: false,
      );
    }
    return ids;
  });

  Future<void> expectNoRawDownloadRead(Future<void> Function() read) async {
    final statements = await statementsOf(read);
    expect(statements, isNotEmpty);
    for (final statement in statements) {
      expect(readsRawDownload(statement), isFalse, reason: statement);
    }
  }

  group('source display reads', () {
    setUp(() async {
      db = setUpLoggingTestDatabase();
      repository = DiveRepository();
      series = ProfileSeriesRepository();
      counter = 0;
    });

    tearDown(tearDownTestDatabase);

    test('getDataSources reads no raw download', () async {
      await seedDives();

      await expectNoRawDownloadRead(() async {
        final sources = await repository.getDataSources('d1');
        expect([for (final s in sources) s.id], ['d1-a', 'd1-b']);
        expect(sources.first.isPrimary, isTrue);
      });
    });

    test('getProfilesByDataSource reads no raw download', () async {
      await seedDives();

      await expectNoRawDownloadRead(() async {
        final profiles = await repository.getProfilesByDataSource('d1');
        expect(profiles.keys, ['d1-a', 'd1-b']);
        expect(profiles['d1-a']!.points, hasLength(4));
        expect(profiles['d1-b']!.points, hasLength(4));
      });
    });

    test('reducePrimarySourceProfiles reads no raw download', () async {
      final ids = await seedDives();

      await expectNoRawDownloadRead(() async {
        final counts = await repository.reducePrimarySourceProfiles(
          ids,
          _pointCount,
        );
        expect(counts, {'d1': 4, 'd2': 4});
      });
    });

    test('getProfileHistory reads no raw download', () async {
      await seedDives();

      await expectNoRawDownloadRead(() async {
        final history = await repository.getProfileHistory('d1');
        expect({for (final r in history) r.sourceId}, {'d1-a', 'd1-b'});
      });
    });

    test('getMergedProfile reads no raw download', () async {
      await seedDives();

      await expectNoRawDownloadRead(() async {
        expect(await repository.getMergedProfile('d1'), isNotEmpty);
      });
    });

    test('getMergedProfilesForDives reads no raw download', () async {
      final ids = await seedDives();

      await expectNoRawDownloadRead(() async {
        final merged = await repository.getMergedProfilesForDives(ids);
        expect(merged.keys, unorderedEquals(ids));
      });
    });

    test('the tank primary source reads no raw download', () async {
      final ids = await seedDives();
      final tanks = TankPressureSeriesRepository();

      await expectNoRawDownloadRead(() async {
        expect(await tanks.primarySourceId('d1'), 'd1-a');
        expect(await tanks.primarySourceIdsForDives(ids), {
          'd1': 'd1-a',
          'd2': 'd2-a',
        });
      });
    });

    test('a primary switch keeps every raw download in place', () async {
      await seedDives();

      await quietly(
        () => repository.setPrimaryDataSource(
          diveId: 'd1',
          computerReadingId: 'd1-b',
        ),
      );

      final rows = await quietly(
        () => (db.select(
          db.diveDataSources,
        )..where((t) => t.diveId.equals('d1'))).get(),
      );
      expect(rows, hasLength(2));
      for (final row in rows) {
        expect(row.rawData, rawDownload, reason: row.id);
        expect(row.rawFingerprint, rawFingerprint, reason: row.id);
      }
      expect(rows.singleWhere((r) => r.isPrimary).id, 'd1-b');
    });
  });
}

/// Top level so the reduction can run off the UI isolate.
int _pointCount(List<DiveProfilePoint> points) => points.length;
