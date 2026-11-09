import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository dives;
  late ProfileSeriesRepository series;
  const now = 1750000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    dives = DiveRepository();
    series = ProfileSeriesRepository();
    for (final id in ['dive-1', 'dive-2', 'dive-3']) {
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

  // #4112: a dive with no series maps to an empty list, so the dive list can
  // tell "has no samples" (estimate an outline) from "not fetched yet".
  test(
    'a series-backed dive is summarised, a dive without one maps to empty',
    () async {
      await series.insertSeries(
        diveId: 'dive-1',
        samples: [
          for (var i = 0; i < 300; i++)
            ProfileSample(timestamp: i, depth: i.toDouble()),
        ],
        now: now,
      );
      final summaries = await dives.getBatchProfileSummaries([
        'dive-1',
        'dive-2',
        'dive-3',
      ], maxSamples: 120);
      expect(summaries.keys.toSet(), {'dive-1', 'dive-2', 'dive-3'});
      expect(summaries['dive-2'], isEmpty);
      expect(summaries['dive-3'], isEmpty);
      expect(summaries['dive-1'], hasLength(120));
      expect(summaries['dive-1']!.first.timestamp, 0);
      expect(summaries['dive-1']!.last.timestamp, 299);
    },
  );

  // #543: a consolidated dive carries the secondary computer's series
  // demoted next to the primary's; the sparkline must not interleave them.
  test('a demoted series is left out when the dive has a primary', () async {
    await series.insertSeries(
      diveId: 'dive-1',
      samples: const [
        ProfileSample(timestamp: 0, depth: 1.0),
        ProfileSample(timestamp: 10, depth: 3.0),
      ],
      now: now,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      isPrimary: false,
      samples: const [
        ProfileSample(timestamp: 5, depth: 20.0),
        ProfileSample(timestamp: 15, depth: 20.0),
      ],
      now: now,
    );
    final summaries = await dives.getBatchProfileSummaries(['dive-1']);
    expect(summaries['dive-1']!.map((p) => p.timestamp), [0, 10]);
    expect(summaries['dive-1']!.map((p) => p.depth), [1.0, 3.0]);
  });

  // #1451: a sequential Combine keeps each half's own series primary, so
  // "primary only" is still the WHOLE stitched dive here. Pinned because the
  // #543 rule above reads like "one series wins" and a future tightening to a
  // single primary would silently halve every combined dive's sparkline.
  test('the primary halves of a combined dive all contribute', () async {
    await series.insertSeries(
      diveId: 'dive-1',
      samples: const [
        ProfileSample(timestamp: 0, depth: 0.0),
        ProfileSample(timestamp: 600, depth: 20.0),
      ],
      now: now,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: null,
      samples: const [
        ProfileSample(timestamp: 600, depth: 20.0),
        ProfileSample(timestamp: 1200, depth: 0.0),
      ],
      now: now,
    );
    final summaries = await dives.getBatchProfileSummaries(['dive-1']);
    expect(
      summaries['dive-1']!.last.timestamp,
      1200,
      reason: 'the second half must not be dropped as a demoted series',
    );
  });

  test('with no primary series every series contributes', () async {
    await series.insertSeries(
      diveId: 'dive-1',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: now,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      isPrimary: false,
      computerId: null,
      samples: const [ProfileSample(timestamp: 10, depth: 2.0)],
      now: now,
    );
    final summaries = await dives.getBatchProfileSummaries(['dive-1']);
    expect(summaries['dive-1']!.map((p) => p.timestamp), [0, 10]);
  });

  test('a dive summary comes from its series', () async {
    await series.insertSeries(
      diveId: 'dive-1',
      samples: const [ProfileSample(timestamp: 0, depth: 7.0)],
      now: now,
    );
    final summaries = await dives.getBatchProfileSummaries(['dive-1']);
    expect(summaries['dive-1']!.map((p) => p.depth), [7.0]);
  });

  test('an empty id list returns an empty map', () async {
    expect(await dives.getBatchProfileSummaries(const []), isEmpty);
  });

  group('an unreadable blob', () {
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

    test('blanks only its own dive, not every sparkline', () async {
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
      await corrupt(badId);

      final summaries = await dives.getBatchProfileSummaries([
        'dive-1',
        'dive-2',
      ], maxSamples: 120);
      expect(summaries.keys.toSet(), {'dive-2'});
    });

    test('still lets getDiveById return the dive', () async {
      final badId = await series.insertSeries(
        diveId: 'dive-1',
        samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
        now: now,
      );
      await corrupt(badId);

      final dive = await dives.getDiveById('dive-1');
      expect(dive, isNotNull);
      expect(dive!.profile, isEmpty);
    });
  });
}
