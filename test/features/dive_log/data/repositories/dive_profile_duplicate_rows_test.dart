import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// A repeated download or import can leave a dive with two identical copies of
/// every profile row. Both reads that feed the analysis pipeline have to
/// collapse them: a duplicated series halves every computed ascent rate,
/// because half the sample pairs share a timestamp and contribute a zero.
void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  /// Series twin of the retired `duplicateProfileRows`: `createDive` now
  /// writes series, so re-inserts every series of the dive as a second
  /// series under the SAME identity with a fresh id.
  Future<void> duplicateProfileSeries(String diveId) async {
    final series = ProfileSeriesRepository();
    for (final s in await series.getSeriesForDive(diveId)) {
      await series.insertSeries(
        diveId: diveId,
        computerId: s.computerId,
        sourceId: s.sourceId,
        isPrimary: s.isPrimary,
        samples: s.samples,
        now: 1000,
      );
    }
  }

  test('getMergedProfile collapses exact duplicate series', () async {
    await repository.createDive(
      domain.Dive(
        id: 'dup',
        dateTime: DateTime.utc(2026, 8, 1, 10),
        profile: [
          // Populated sample fields, so this proves whole-row equality rather
          // than only equality across a row of nulls.
          for (var t = 0; t <= 300; t += 10)
            domain.DiveProfilePoint(
              timestamp: t,
              depth: t / 10.0,
              temperature: 24.5,
              heartRate: 70 + t ~/ 100,
            ),
        ],
      ),
    );
    await duplicateProfileSeries('dup');

    // Two series under the same identity, proving the collapse runs and
    // is not merely the dedupe insertSeries already does inside one series.
    expect(
      await ProfileSeriesRepository().getSeriesForDive('dup'),
      hasLength(2),
    );

    final merged = await repository.getMergedProfile('dup');

    expect(merged, hasLength(31));
    expect(
      merged.map((p) => p.timestamp).toList(),
      equals([for (var t = 0; t <= 300; t += 10) t]),
    );
  });

  test(
    'identical samples from two different computers are both kept',
    () async {
      await repository.createDive(
        domain.Dive(
          id: 'dup3',
          dateTime: DateTime.utc(2026, 8, 1, 14),
          profile: [
            for (var t = 0; t <= 20; t += 10)
              domain.DiveProfilePoint(timestamp: t, depth: t / 10.0),
          ],
        ),
      );
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: 'comp-2',
              name: 'Second Computer',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      await ProfileSeriesRepository().insertSeries(
        diveId: 'dup3',
        computerId: 'comp-2',
        samples: [
          for (var t = 0; t <= 20; t += 10)
            ProfileSample(timestamp: t, depth: t / 10.0),
        ],
        now: 1000,
      );

      expect(await repository.getMergedProfile('dup3'), hasLength(6));
    },
  );

  test('getDiveById stays in step with getMergedProfile', () async {
    await repository.createDive(
      domain.Dive(
        id: 'dup2',
        dateTime: DateTime.utc(2026, 8, 1, 11),
        profile: [
          for (var t = 0; t <= 300; t += 10)
            domain.DiveProfilePoint(timestamp: t, depth: t / 10.0),
        ],
      ),
    );
    await duplicateProfileSeries('dup2');

    final full = await repository.getDiveById('dup2');
    final merged = await repository.getMergedProfile('dup2');

    // Analysis curves are index-aligned against the profile the detail page
    // holds, so these two lists must never differ in length.
    expect(
      full!.profile.map((p) => p.timestamp).toList(),
      equals(merged.map((p) => p.timestamp).toList()),
    );
  });

  test('samples matching on timestamp and depth but not on other recorded '
      'fields are kept', () async {
    // Two computers can agree on depth at the same second and still each
    // carry data the other does not. Keying only on (timestamp, depth) would
    // silently throw one computer's temperature or heart rate away.
    await repository.createDive(
      domain.Dive(
        id: 'meta',
        dateTime: DateTime.utc(2026, 8, 1, 13),
        profile: [
          for (var t = 0; t <= 100; t += 10)
            domain.DiveProfilePoint(timestamp: t, depth: t / 10.0),
        ],
      ),
    );
    // A second, unattributed series sharing every (timestamp, depth) pair
    // with the first but carrying its own heart rate.
    await ProfileSeriesRepository().insertSeries(
      diveId: 'meta',
      samples: [
        for (var t = 0; t <= 100; t += 10)
          ProfileSample(timestamp: t, depth: t / 10.0, heartRate: 72),
      ],
      now: 1000,
    );

    expect(await repository.getMergedProfile('meta'), hasLength(22));
  });

  test('samples that share a timestamp but differ in depth are kept', () async {
    // Two dive computers on one dive legitimately record different depths at
    // the same second. That is a source-attribution question, not a duplicate.
    await repository.createDive(
      domain.Dive(
        id: 'twosrc',
        dateTime: DateTime.utc(2026, 8, 1, 12),
        profile: [
          for (var t = 0; t <= 100; t += 10)
            domain.DiveProfilePoint(timestamp: t, depth: t / 10.0),
        ],
      ),
    );
    // A second, unattributed series recording a different depth at every
    // shared timestamp.
    await ProfileSeriesRepository().insertSeries(
      diveId: 'twosrc',
      samples: [
        for (var t = 0; t <= 100; t += 10)
          ProfileSample(timestamp: t, depth: t / 10.0 + 0.4),
      ],
      now: 1000,
    );

    expect(await repository.getMergedProfile('twosrc'), hasLength(22));
  });
}
