import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';

import '../../../../helpers/test_database.dart';

/// Whether [read] let the event loop turn before it finished.
///
/// Everything else a read does here finishes in microtasks, because the test
/// database is in-memory on this isolate, so only a hand-off to another
/// isolate lets a timer in. On the app's UI isolate that turn is what a frame
/// needs (issue #3820).
Future<bool> yieldsToEventLoop(Future<void> Function() read) async {
  var turned = false;
  Timer.run(() => turned = true);
  await read();
  return turned;
}

void main() {
  late DiveRepository repository;
  late AppDatabase db;

  const now = 1750000000000;

  List<ProfileSample> samples(int count, {double depth = 10, int offset = 0}) =>
      [
        for (var i = 0; i < count; i++)
          ProfileSample(
            timestamp: offset + i * 2,
            depth: depth + (i % 7),
            temperature: 21.5,
            ndl: 900 - i,
          ),
      ];

  Future<void> insertDataSource({
    required String id,
    required bool isPrimary,
    String? computerId,
  }) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion(
          id: Value(id),
          diveId: const Value('dive-1'),
          computerId: Value(computerId),
          isPrimary: Value(isPrimary),
          importedAt: Value(DateTime(2026, 1, 1)),
          createdAt: Value(DateTime(2026, 1, 1)),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
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

  group('a full-resolution dive leaves the UI isolate (#3820)', () {
    setUp(() async {
      await ProfileSeriesRepository().insertSeries(
        diveId: 'dive-1',
        samples: samples(2000),
        now: now,
      );
    });

    test('getDiveById decodes and merges off the UI isolate', () async {
      domain.Dive? dive;
      final yielded = await yieldsToEventLoop(() async {
        dive = await repository.getDiveById('dive-1');
      });

      expect(yielded, isTrue);
      expect(dive!.profile, hasLength(2000));
    });

    test('getDiveForAnalysis decodes and merges off the UI isolate', () async {
      domain.Dive? dive;
      final yielded = await yieldsToEventLoop(() async {
        dive = await repository.getDiveForAnalysis('dive-1');
      });

      expect(yielded, isTrue);
      expect(dive!.profile, hasLength(2000));
    });

    test('getDiveProfile decodes and merges off the UI isolate', () async {
      var points = const <domain.DiveProfilePoint>[];
      final yielded = await yieldsToEventLoop(() async {
        points = await repository.getDiveProfile('dive-1');
      });

      expect(yielded, isTrue);
      expect(points, hasLength(2000));
    });

    test('getProfilesByDataSource groups off the UI isolate', () async {
      await insertDataSource(id: 'source-1', isPrimary: true);

      var profiles = const <String, SourceProfile>{};
      final yielded = await yieldsToEventLoop(() async {
        profiles = await repository.getProfilesByDataSource('dive-1');
      });

      expect(yielded, isTrue);
      expect(profiles['source-1']!.points, hasLength(2000));
    });
  });

  group('reads agree with what a bulk read of the same dive returns', () {
    const editedId = 'dive-1';

    /// Two computers, the primary one edited: every branch the merge and the
    /// source grouping take, at a size that leaves the UI isolate.
    setUp(() async {
      for (final id in ['computer-a', 'computer-b']) {
        await db
            .into(db.diveComputers)
            .insert(
              DiveComputersCompanion(
                id: Value(id),
                name: Value(id),
                createdAt: const Value(now),
                updatedAt: const Value(now),
              ),
            );
      }
      await insertDataSource(
        id: 'source-a',
        isPrimary: true,
        computerId: 'computer-a',
      );
      await insertDataSource(
        id: 'source-b',
        isPrimary: false,
        computerId: 'computer-b',
      );
      final series = ProfileSeriesRepository();
      await series.insertSeries(
        diveId: editedId,
        computerId: 'computer-a',
        sourceId: 'source-a',
        samples: samples(800),
        now: now,
      );
      await series.insertSeries(
        diveId: editedId,
        computerId: 'computer-b',
        sourceId: 'source-b',
        isPrimary: false,
        samples: samples(800, depth: 11, offset: 1),
        now: now,
      );
      await repository.saveEditedProfile(editedId, [
        for (var i = 0; i < 700; i++)
          domain.DiveProfilePoint(timestamp: i * 2, depth: 12.5),
      ]);
    });

    test('the merged read drops the original the edit replaced', () async {
      final bulk = (await repository.getDivesByIds([editedId])).single;
      final diveById = await repository.getDiveById(editedId);
      final analysis = await repository.getDiveForAnalysis(editedId);
      final merged = await repository.getMergedProfilesForDives([editedId]);

      expect(diveById!.profile, hasLength(1500));
      expect(diveById.profile.where((p) => p.depth == 12.5), hasLength(700));
      expect(analysis!.profile, diveById.profile);
      expect(merged[editedId], diveById.profile);
      expect(bulk.profile, diveById.profile);
    });

    test('the primary read returns the edit alone', () async {
      final points = await repository.getDiveProfile(editedId);

      expect(points, hasLength(700));
      expect(points.map((p) => p.depth).toSet(), {12.5});
    });

    test('the source read files each series under its own source', () async {
      final profiles = await repository.getProfilesByDataSource(editedId);

      expect(profiles.keys, ['source-a', 'source-b']);
      expect(profiles['source-a']!.isEdited, isTrue);
      expect(profiles['source-a']!.points, hasLength(700));
      expect(profiles['source-b']!.computerId, 'computer-b');
      expect(profiles['source-b']!.isEdited, isFalse);
      expect(profiles['source-b']!.points, hasLength(800));
    });
  });

  test('a dive with no source row gets a synthetic one', () async {
    await ProfileSeriesRepository().insertSeries(
      diveId: 'dive-1',
      samples: samples(600),
      now: now,
    );

    final profiles = await repository.getProfilesByDataSource('dive-1');

    expect(profiles.keys, [legacyDataSourceId('dive-1')]);
    expect(profiles.values.single.points, hasLength(600));
  });

  test('a bulk read stays on the calling isolate', () async {
    await ProfileSeriesRepository().insertSeries(
      diveId: 'dive-1',
      samples: samples(2000),
      now: now,
    );

    expect(
      await yieldsToEventLoop(() async {
        await repository.getDivesByIds(['dive-1']);
      }),
      isFalse,
    );
  });

  test('a short dive stays on the calling isolate', () async {
    await ProfileSeriesRepository().insertSeries(
      diveId: 'dive-1',
      samples: samples(20),
      now: now,
    );

    expect(
      await yieldsToEventLoop(() async {
        await repository.getDiveForAnalysis('dive-1');
      }),
      isFalse,
    );
  });
}
