import 'dart:isolate';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_reduction.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/services/profile_series_merge.dart';

import '../../../../helpers/test_database.dart';

String? _isolateName(Object? _) => Isolate.current.debugName;

int _failToReduce(Object? _) => throw StateError('reduction failed');

void main() {
  late AppDatabase db;
  late ProfileSeriesRepository series;
  const now = 1750000000000;

  List<ProfileSample> samples(int count, {int offset = 0, double depth = 5}) =>
      [
        for (var i = 0; i < count; i++)
          ProfileSample(
            timestamp: offset + i * 2,
            depth: depth + (i % 11),
            temperature: 20.25,
            heartRate: 70 + (i % 5),
          ),
      ];

  setUp(() async {
    db = await setUpTestDatabase();
    series = ProfileSeriesRepository();
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

  tearDown(tearDownTestDatabase);

  Future<void> corrupt(String seriesId) =>
      (db.update(
        db.diveProfileSeries,
      )..where((t) => t.id.equals(seriesId))).write(
        DiveProfileSeriesCompanion(
          samples: Value(Uint8List.fromList(const [1, 2, 3, 4])),
        ),
      );

  group('reduceSeriesRowsInBackground (#3820)', () {
    test('runs a full-resolution dive on another isolate', () async {
      await series.insertSeries(
        diveId: 'dive-1',
        samples: samples(kInlineSeriesSampleLimit),
        now: now,
      );
      final rows = await series.getRowsForDives(['dive-1']);

      final reduction = await reduceSeriesRowsInBackground(rows, _isolateName);

      expect(reduction.result, isNot(Isolate.current.debugName));
    });

    test('stays on this isolate below the limit', () async {
      await series.insertSeries(
        diveId: 'dive-1',
        samples: samples(kInlineSeriesSampleLimit - 1),
        now: now,
      );
      final rows = await series.getRowsForDives(['dive-1']);

      final reduction = await reduceSeriesRowsInBackground(rows, _isolateName);

      expect(reduction.result, Isolate.current.debugName);
    });

    test('counts the samples of every series toward the limit', () async {
      for (final offset in [0, 10000]) {
        await series.insertSeries(
          diveId: 'dive-1',
          samples: samples(kInlineSeriesSampleLimit - 1, offset: offset),
          now: now,
        );
      }
      final rows = await series.getRowsForDives(['dive-1']);

      final reduction = await reduceSeriesRowsInBackground(rows, _isolateName);

      expect(reduction.result, isNot(Isolate.current.debugName));
    });

    test('merges the same points off this isolate as on it', () async {
      await series.insertSeries(
        diveId: 'dive-1',
        samples: samples(600),
        now: now,
      );
      await series.insertSeries(
        diveId: 'dive-1',
        isPrimary: false,
        samples: samples(600, offset: 1, depth: 30),
        now: now,
      );
      final rows = await series.getRowsForDives(['dive-1']);
      final reduce = mergedPointsReduction(
        hasSources: true,
        primaryComputerId: null,
      );

      final inline = reduceSeriesRows(rows, reduce);
      final background = await reduceSeriesRowsInBackground(rows, reduce);

      expect(background.result, inline.result);
      // A primary with no computer reads as a saved edit, and the demoted
      // series in its family as the original it replaced.
      expect(background.result, hasLength(600));
      expect(background.result.map((p) => p.depth), everyElement(lessThan(30)));
      expect(background.unreadable, isEmpty);
    });

    test('reports an unreadable blob instead of failing the read', () async {
      final badId = await series.insertSeries(
        diveId: 'dive-1',
        samples: samples(600),
        now: now,
      );
      await series.insertSeries(
        diveId: 'dive-1',
        samples: samples(600, offset: 5000),
        now: now,
      );
      await corrupt(badId);
      final rows = await series.getRowsForDives(['dive-1']);

      final reduction = await reduceSeriesRowsInBackground(
        rows,
        mergeSeriesPoints,
      );

      expect(reduction.result, hasLength(600));
      expect(reduction.unreadable.keys, [badId]);
      expect(
        reduction.unreadable[badId],
        contains('ProfileSeriesCodecException'),
      );
    });

    test('reads as empty when no blob is readable', () async {
      final badId = await series.insertSeries(
        diveId: 'dive-1',
        samples: samples(600),
        now: now,
      );
      await corrupt(badId);
      final rows = await series.getRowsForDives(['dive-1']);

      final reduction = await reduceSeriesRowsInBackground(
        rows,
        mergeSeriesPoints,
      );

      expect(reduction.result, isEmpty);
      expect(reduction.unreadable.keys, [badId]);
    });

    test('fails the read when the reduction throws', () async {
      await series.insertSeries(
        diveId: 'dive-1',
        samples: samples(600),
        now: now,
      );
      final rows = await series.getRowsForDives(['dive-1']);

      await expectLater(
        reduceSeriesRowsInBackground(rows, _failToReduce),
        throwsStateError,
      );
    });
  });
}
