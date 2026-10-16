import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_empty_parse.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

/// A re-parse that comes back with no samples or no duration must leave the
/// source, the dive and its profile untouched (issue #3368).
void main() {
  late AppDatabase db;
  late ReparseService service;
  late ProfileSeriesRepository profileSeries;

  final nowMs = DateTime.utc(2026, 1, 15, 10, 0).millisecondsSinceEpoch;
  final storedStartMs = DateTime.utc(2025, 6, 1, 9, 30).millisecondsSinceEpoch;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    service = ReparseService(db: db);
    profileSeries = ProfileSeriesRepository(
      database: db,
      syncRepository: SyncRepository(database: db),
    );

    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: const Value('comp-1'),
            name: const Value('Mares Genius'),
            createdAt: Value(nowMs),
            updatedAt: Value(nowMs),
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-1'),
            diveDateTime: Value(storedStartMs),
            entryTime: Value(storedStartMs),
            maxDepth: const Value(31.5),
            avgDepth: const Value(18.2),
            runtime: const Value(2880),
            bottomTime: const Value(2400),
            notes: const Value(''),
            createdAt: Value(nowMs),
            updatedAt: Value(nowMs),
          ),
        );
    final importedAt = DateTime.fromMillisecondsSinceEpoch(nowMs);
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: const Value('src-1'),
            diveId: const Value('dive-1'),
            computerId: const Value('comp-1'),
            isPrimary: const Value(true),
            sourceFormat: const Value('dive_computer'),
            maxDepth: const Value(31.5),
            duration: const Value(2880),
            descriptorVendor: const Value('Mares'),
            descriptorProduct: const Value('Smart'),
            descriptorModel: const Value(16),
            rawData: Value(Uint8List.fromList([1, 2, 3])),
            importedAt: Value(importedAt),
            createdAt: Value(importedAt),
          ),
        );
    await profileSeries.insertSeries(
      id: 'prof-1',
      diveId: 'dive-1',
      computerId: 'comp-1',
      sourceId: 'src-1',
      isPrimary: true,
      samples: const [
        ProfileSample(timestamp: 0, depth: 0),
        ProfileSample(timestamp: 600, depth: 31.5),
        ProfileSample(timestamp: 2880, depth: 0),
      ],
      now: 1000,
    );
  });

  tearDown(() => db.close());

  pigeon.ParsedDive parsedWith({
    required int durationSeconds,
    required double maxDepthMeters,
    required List<pigeon.ProfileSample> samples,
  }) {
    return pigeon.ParsedDive(
      fingerprint: 'fp',
      dateTimeYear: 0,
      dateTimeMonth: 0,
      dateTimeDay: 0,
      dateTimeHour: 0,
      dateTimeMinute: 0,
      dateTimeSecond: 0,
      maxDepthMeters: maxDepthMeters,
      avgDepthMeters: 0,
      durationSeconds: durationSeconds,
      samples: samples,
      tanks: const [],
      gasMixes: const [],
      events: const [],
    );
  }

  /// The parse the reporter's Mares Genius came back with: nothing at all.
  final emptyParse = parsedWith(
    durationSeconds: 0,
    maxDepthMeters: 0,
    samples: const [],
  );

  Future<void> expectUntouched() async {
    final dive = await (db.select(
      db.dives,
    )..where((t) => t.id.equals('dive-1'))).getSingle();
    expect(dive.maxDepth, 31.5);
    expect(dive.avgDepth, 18.2);
    expect(dive.runtime, 2880);
    expect(dive.bottomTime, 2400);
    expect(dive.diveDateTime, storedStartMs);
    expect(dive.updatedAt, nowMs);

    final source = await (db.select(
      db.diveDataSources,
    )..where((t) => t.id.equals('src-1'))).getSingle();
    expect(source.maxDepth, 31.5);
    expect(source.duration, 2880);
    expect(source.lastParsedAt, isNull);

    final series = await profileSeries.getSeriesForDive('dive-1');
    expect(series.map((s) => s.id), ['prof-1']);
    expect(series.single.isPrimary, isTrue);
    expect(series.single.samples, hasLength(3));

    // Nothing was staged for sync, so a peer is not handed a no-op rewrite.
    final staged = await db.select(db.syncRecords).get();
    expect(
      staged.where(
        (r) => r.entityType == 'dives' || r.entityType == 'diveDataSources',
      ),
      isEmpty,
    );
  }

  Future<pigeon.ParsedDive> Function(String, String, int, Uint8List) returning(
    pigeon.ParsedDive parsed,
  ) =>
      (_, _, _, _) async => parsed;

  group('isEmptyParse', () {
    test('is true for a parse with no samples', () {
      expect(
        isEmptyParse(
          parsedWith(durationSeconds: 2880, maxDepthMeters: 31, samples: []),
        ),
        isTrue,
      );
    });

    test('is true for a parse with samples but no duration', () {
      expect(
        isEmptyParse(
          parsedWith(
            durationSeconds: 0,
            maxDepthMeters: 31,
            samples: [pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0)],
          ),
        ),
        isTrue,
      );
    });

    test('is false for a parse with samples and a duration', () {
      expect(
        isEmptyParse(
          parsedWith(
            durationSeconds: 60,
            maxDepthMeters: 5,
            samples: [pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0)],
          ),
        ),
        isFalse,
      );
    });
  });

  group('ReparseService with an empty parse (issue #3368)', () {
    test('applyParsedUpdate throws and writes nothing', () async {
      await expectLater(
        service.applyParsedUpdate(
          diveId: 'dive-1',
          sourceRowId: 'src-1',
          parsed: emptyParse,
          descriptorVendor: 'Mares',
          descriptorProduct: 'Smart',
          descriptorModel: 16,
          libdivecomputerVersion: '0.10.0',
        ),
        throwsA(isA<EmptyParseException>()),
      );
      await expectUntouched();
    });

    test('a parse with a header but no samples keeps the profile', () async {
      await expectLater(
        service.applyParsedUpdate(
          diveId: 'dive-1',
          sourceRowId: 'src-1',
          parsed: parsedWith(
            durationSeconds: 2880,
            maxDepthMeters: 31.5,
            samples: const [],
          ),
          descriptorVendor: 'Mares',
          descriptorProduct: 'Smart',
          descriptorModel: 16,
          libdivecomputerVersion: '0.10.0',
        ),
        throwsA(isA<EmptyParseException>()),
      );
      await expectUntouched();
    });

    test('reparseAllForComputer counts it as failed', () async {
      final result = await service.reparseAllForComputer(
        'comp-1',
        parseFn: returning(emptyParse),
      );
      expect(result.succeeded, 0);
      expect(result.failed, 1);
      await expectUntouched();
    });

    test('reparseDive reports it as an error', () async {
      final result = await service.reparseDive(
        'dive-1',
        parseFn: returning(emptyParse),
      );
      expect(result.errors, hasLength(1));
      expect(result.errors.single, contains('no dive data'));
      await expectUntouched();
    });
  });
}
