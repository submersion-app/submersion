import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

/// [ProfileSeriesRepository.promoteWinnerOwnedBy] replaced SQL that picked a
/// winner per timestamp (`ROW_NUMBER() OVER (PARTITION BY p.timestamp ...)`)
/// with a whole-series range overlap test. The two agree on every shape a
/// current writer produces, and these pin which is which so a future writer
/// that produces a partial overlap is noticed here rather than in a dive
/// that quietly lost half its profile.
void main() {
  late AppDatabase db;
  late ProfileSeriesRepository repo;
  const now = 1750000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = ProfileSeriesRepository();
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-1',
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'comp-1',
            name: 'Comp 1',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-1',
            diveId: 'dive-1',
            computerId: const Value('comp-1'),
            importedAt: DateTime.fromMillisecondsSinceEpoch(now),
            createdAt: DateTime.fromMillisecondsSinceEpoch(now),
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  Future<void> segment(String id, int from, int to) => repo.insertSeries(
    diveId: 'dive-1',
    computerId: 'comp-1',
    sourceId: 'src-1',
    isPrimary: false,
    id: id,
    now: now,
    samples: [
      for (var t = from; t <= to; t += 60)
        ProfileSample(timestamp: t, depth: 5),
    ],
  );

  Future<List<String>> promote() => repo.promoteWinnerOwnedBy(
    'dive-1',
    sourceId: 'src-1',
    computerId: 'comp-1',
    now: now,
  );

  test('two disjoint segments of one source are both promoted', () async {
    // What a merge of one computer's split dive writes: the source owns two
    // ranges that share no timestamp, so neither supersedes the other and
    // promoting only one would hand back half the dive.
    await segment('early', 0, 600);
    await segment('late', 1800, 2400);

    expect(await promote(), unorderedEquals(['early', 'late']));
  });

  test('a superseding generation over the same range promotes one', () async {
    // An edited profile and the original it replaces share a range, which is
    // exactly what the overlap test is for.
    await segment('original', 0, 1200);
    await segment('edited', 0, 1200);

    expect(await promote(), hasLength(1));
  });

  test('a partial overlap promotes only one, keeping its own range', () async {
    // The documented narrowing: the retired SQL picked a winner per
    // timestamp, so the non-colliding part of the loser survived; the range
    // test drops the loser whole. No current writer produces a partial
    // same-source overlap, so this pins the behaviour rather than blessing
    // it. If a writer ever does, the 1200..1800 replacement below is the
    // half that silently disappears.
    await segment('full', 0, 3600);
    await segment('partial', 1200, 1800);

    final promoted = await promote();
    expect(promoted, hasLength(1));
    final kept = (await repo.getRowsForDives([
      'dive-1',
    ])).where((r) => r.isPrimary).single;
    expect(promoted.single, kept.id);
  });

  test('a source with nothing of its own promotes nothing', () async {
    expect(await promote(), isEmpty);
  });
}
