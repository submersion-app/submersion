import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_batch_service.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ReparseBatchService batch;

  setUp(() async {
    db = createTestDatabase();
    batch = ReparseBatchService(ReparseService(db: db));
    await insertDiver(db, 'diver-1');
    await insertDiver(db, 'diver-2');
  });

  tearDown(() => db.close());

  final now = DateTime.utc(2026, 1, 15, 10);

  Future<void> addComputer(String id, {String? name}) => db
      .into(db.diveComputers)
      .insert(
        DiveComputersCompanion(
          id: Value(id),
          name: Value(name ?? 'Computer $id'),
          createdAt: Value(now.millisecondsSinceEpoch),
          updatedAt: Value(now.millisecondsSinceEpoch),
        ),
      );

  Future<void> addDive(String id, {String diverId = 'diver-1'}) =>
      insertDive(db, id, diverId: diverId);

  Future<void> addSource({
    required String id,
    required String diveId,
    String? computerId,
    bool withRawData = true,
    String? vendor = 'Shearwater',
    String? product = 'Perdix',
    int? model = 42,
  }) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion(
          id: Value(id),
          diveId: Value(diveId),
          computerId: Value(computerId),
          isPrimary: const Value(true),
          sourceFormat: const Value('dive_computer'),
          rawData: Value(withRawData ? Uint8List.fromList([1, 2, 3]) : null),
          descriptorVendor: Value(vendor),
          descriptorProduct: Value(product),
          descriptorModel: Value(model),
          importedAt: Value(now),
          createdAt: Value(now),
        ),
      );

  Future<DateTime?> lastParsedAt(String sourceId) async {
    final row = await (db.select(
      db.diveDataSources,
    )..where((t) => t.id.equals(sourceId))).getSingle();
    return row.lastParsedAt;
  }

  pigeon.ParsedDive parsedDive() => pigeon.ParsedDive(
    fingerprint: 'fp',
    dateTimeYear: 2026,
    dateTimeMonth: 1,
    dateTimeDay: 15,
    dateTimeHour: 10,
    dateTimeMinute: 0,
    dateTimeSecond: 0,
    maxDepthMeters: 25,
    avgDepthMeters: 14,
    durationSeconds: 3000,
    minTemperatureCelsius: 18,
    samples: [
      pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0),
      pigeon.ProfileSample(timeSeconds: 60, depthMeters: 10),
      pigeon.ProfileSample(timeSeconds: 120, depthMeters: 25),
      pigeon.ProfileSample(timeSeconds: 180, depthMeters: 5),
    ],
    tanks: [],
    gasMixes: [],
    events: [],
  );

  Future<pigeon.ParsedDive> okParse(
    String vendor,
    String product,
    int model,
    Uint8List rawData,
  ) async => parsedDive();

  group('run', () {
    test('re-parses every dive and reports succeeded', () async {
      await addDive('d1');
      await addDive('d2');
      await addSource(id: 's1', diveId: 'd1');
      await addSource(id: 's2', diveId: 'd2');

      final result = await batch.run(['d1', 'd2'], parseFn: okParse);

      expect(result.total, 2);
      expect(result.succeeded, 2);
      expect(result.failed, 0);
      expect(result.notProcessed, 0);
      expect(result.cancelled, isFalse);
      expect(await lastParsedAt('s1'), isNotNull);
      expect(await lastParsedAt('s2'), isNotNull);
    });

    test('skips dives with no raw data', () async {
      await addDive('d1');
      await addSource(id: 's1', diveId: 'd1', withRawData: false);
      await addDive('d2');

      final result = await batch.run(['d1', 'd2'], parseFn: okParse);

      expect(result.skipped, 2);
      expect(result.succeeded, 0);
      expect(result.failed, 0);
    });

    test(
      'applies nothing on a dive when one of its sources fails to parse',
      () async {
        await addDive('d1');
        await addSource(id: 'src-a', diveId: 'd1');
        await addSource(id: 'src-b', diveId: 'd1', vendor: 'Suunto');

        final result = await batch.run(
          ['d1'],
          parseFn: (vendor, product, model, raw) async {
            if (vendor == 'Suunto') throw Exception('bad bytes');
            return parsedDive();
          },
        );

        expect(result.succeeded, 0);
        expect(result.failures.single.diveId, 'd1');
        expect(result.failures.single.error, contains('bad bytes'));
        expect(await lastParsedAt('src-a'), isNull);
        expect(await lastParsedAt('src-b'), isNull);
      },
    );

    test('counts missing descriptors as a failure', () async {
      await addDive('d1');
      await addSource(
        id: 's1',
        diveId: 'd1',
        vendor: null,
        product: null,
        model: null,
      );

      final result = await batch.run(['d1'], parseFn: okParse);

      expect(result.failures.single.error, missingDescriptorsError);
      expect(await lastParsedAt('s1'), isNull);
    });

    test('counts an empty parse as a failure', () async {
      await addDive('d1');
      await addSource(id: 's1', diveId: 'd1');

      final result = await batch.run(
        ['d1'],
        parseFn: (vendor, product, model, raw) async => pigeon.ParsedDive(
          fingerprint: '',
          dateTimeYear: 0,
          dateTimeMonth: 0,
          dateTimeDay: 0,
          dateTimeHour: 0,
          dateTimeMinute: 0,
          dateTimeSecond: 0,
          maxDepthMeters: 0,
          avgDepthMeters: 0,
          durationSeconds: 0,
          samples: [],
          tanks: [],
          gasMixes: [],
          events: [],
        ),
      );

      expect(result.failed, 1);
      expect(await lastParsedAt('s1'), isNull);
    });

    test('with computerId leaves other computers\' sources alone', () async {
      await addComputer('comp-A');
      await addComputer('comp-B');
      await addDive('d1');
      await addSource(id: 'src-a', diveId: 'd1', computerId: 'comp-A');
      await addSource(id: 'src-b', diveId: 'd1', computerId: 'comp-B');

      final result = await batch.run(
        ['d1'],
        parseFn: okParse,
        computerId: 'comp-A',
      );

      expect(result.succeeded, 1);
      expect(await lastParsedAt('src-a'), isNotNull);
      expect(await lastParsedAt('src-b'), isNull);
    });

    test(
      'stops when cancelled and reports the rest as not processed',
      () async {
        for (final id in ['d1', 'd2', 'd3']) {
          await addDive(id);
          await addSource(id: 's-$id', diveId: id);
        }
        var cancelled = false;

        final result = await batch.run(
          ['d1', 'd2', 'd3'],
          parseFn: okParse,
          onProgress: (done, total) => cancelled = true,
          isCancelled: () => cancelled,
        );

        expect(result.succeeded, 1);
        expect(result.notProcessed, 2);
        expect(result.cancelled, isTrue);
        expect(await lastParsedAt('s-d2'), isNull);
      },
    );

    test('reports progress after every dive', () async {
      await addDive('d1');
      await addSource(id: 's1', diveId: 'd1');
      await addDive('d2');
      await addDive('d3');
      await addSource(id: 's3', diveId: 'd3', vendor: null);
      final calls = <(int, int)>[];

      await batch.run(
        ['d1', 'd2', 'd3'],
        parseFn: okParse,
        onProgress: (done, total) => calls.add((done, total)),
      );

      expect(calls, [(1, 3), (2, 3), (3, 3)]);
    });

    test('records one change-log operation for the whole run', () async {
      await addDive('d1');
      await addDive('d2');
      await addSource(id: 's1', diveId: 'd1');
      await addSource(id: 's2', diveId: 'd2');
      await db.delete(db.changeLogOperations).go();

      await batch.run(['d1', 'd2'], parseFn: okParse);

      final operations = await db.select(db.changeLogOperations).get();
      expect(operations, hasLength(1));
      expect(operations.single.label, ChangeLogLabels.reparse);
    });
  });

  group('candidate queries', () {
    test('diveIdsWithRawData filters by diver', () async {
      await addDive('d1');
      await addDive('d2', diverId: 'diver-2');
      await addDive('d3');
      await addSource(id: 's1', diveId: 'd1');
      await addSource(id: 's2', diveId: 'd2');
      await addSource(id: 's3', diveId: 'd3', withRawData: false);

      expect(await batch.diveIdsWithRawData(diverId: 'diver-1'), ['d1']);
      expect((await batch.diveIdsWithRawData(diverId: null)).toSet(), {
        'd1',
        'd2',
      });
    });

    test('diveIdsWithRawData lists a multi-source dive once', () async {
      await addDive('d1');
      await addSource(id: 's1', diveId: 'd1');
      await addSource(id: 's2', diveId: 'd1');

      expect(await batch.diveIdsWithRawData(diverId: 'diver-1'), ['d1']);
    });

    test('diveIdsForComputer returns only that computer\'s dives', () async {
      await addComputer('comp-A');
      await addComputer('comp-B');
      await addDive('d1');
      await addDive('d2');
      await addSource(id: 's1', diveId: 'd1', computerId: 'comp-A');
      await addSource(id: 's2', diveId: 'd2', computerId: 'comp-B');

      expect(await batch.diveIdsForComputer('comp-A'), ['d1']);
    });

    test('withRawData keeps input order and drops dives without', () async {
      await addDive('d1');
      await addDive('d2');
      await addDive('d3');
      await addSource(id: 's1', diveId: 'd1');
      await addSource(id: 's3', diveId: 'd3');

      expect(await batch.withRawData(['d3', 'd2', 'd1']), ['d3', 'd1']);
    });

    test('rawDataCountsByComputer groups by computer', () async {
      await addComputer('comp-A', name: 'Perdix');
      await addComputer('comp-B', name: 'Teric');
      for (final id in ['d1', 'd2', 'd3']) {
        await addDive(id);
      }
      await addSource(id: 's1', diveId: 'd1', computerId: 'comp-A');
      await addSource(id: 's2', diveId: 'd2', computerId: 'comp-A');
      await addSource(id: 's3', diveId: 'd3', computerId: 'comp-B');

      final counts = await batch.rawDataCountsByComputer(diverId: 'diver-1');

      expect(
        {for (final c in counts) c.computerName: c.dives},
        {'Perdix': 2, 'Teric': 1},
      );
    });

    test('diveCountWithoutRawData counts dives with no raw data', () async {
      await addDive('d1');
      await addDive('d2');
      await addDive('d3', diverId: 'diver-2');
      await addSource(id: 's1', diveId: 'd1');

      expect(await batch.diveCountWithoutRawData(diverId: 'diver-1'), 1);
    });
  });
}
