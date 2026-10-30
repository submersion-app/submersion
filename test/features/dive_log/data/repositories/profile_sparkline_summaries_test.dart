import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_sparkline_summaries.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProfileSeriesRepository series;
  const now = 1750000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    series = ProfileSeriesRepository();
    for (final id in ['dive-1', 'dive-2']) {
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
  });

  tearDown(tearDownTestDatabase);

  group('summarizeSparklinesInBackground (#3506)', () {
    test(
      'summarises a page the same way off the UI isolate as on it',
      () async {
        await series.insertSeries(
          diveId: 'dive-1',
          samples: [
            for (var i = 0; i < 600; i++)
              ProfileSample(timestamp: i * 2, depth: (i % 40).toDouble()),
          ],
          now: now,
        );
        // A demoted copy the sparkline must leave out (#543).
        await series.insertSeries(
          diveId: 'dive-1',
          isPrimary: false,
          samples: const [
            ProfileSample(timestamp: 1, depth: 50.0),
            ProfileSample(timestamp: 3, depth: 50.0),
          ],
          now: now,
        );
        await series.insertSeries(
          diveId: 'dive-2',
          samples: const [
            ProfileSample(timestamp: 0, depth: 0.0),
            ProfileSample(timestamp: 30, depth: 12.0),
          ],
          now: now,
        );
        final rows = await series.getRowsForDives(['dive-1', 'dive-2']);

        final inline = summarizeSparklines(rows, maxSamples: 120);
        final background = await summarizeSparklinesInBackground(
          rows,
          maxSamples: 120,
        );

        expect(background.byDive, inline.byDive);
        expect(background.byDive['dive-1'], hasLength(120));
        expect(
          background.byDive['dive-1']!.map((p) => p.depth),
          everyElement(lessThan(50.0)),
        );
        expect(background.byDive['dive-2']!.map((p) => p.timestamp), [0, 30]);
        expect(background.unreadableSeriesIds, isEmpty);
      },
    );

    test('reports an unreadable blob instead of failing the page', () async {
      final badId = await series.insertSeries(
        diveId: 'dive-1',
        samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
        now: now,
      );
      await series.insertSeries(
        diveId: 'dive-2',
        samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
        now: now,
      );
      await (db.update(
        db.diveProfileSeries,
      )..where((t) => t.id.equals(badId))).write(
        DiveProfileSeriesCompanion(
          samples: Value(Uint8List.fromList(const [1, 2, 3, 4])),
        ),
      );
      final rows = await series.getRowsForDives(['dive-1', 'dive-2']);

      final summaries = await summarizeSparklinesInBackground(
        rows,
        maxSamples: 120,
      );

      expect(summaries.byDive.keys, ['dive-2']);
      expect(summaries.unreadableSeriesIds, [badId]);
    });
  });
}
