import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_split_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_uncombine_service.dart';

import '../../../../helpers/test_database.dart';

/// `dive_data_sources.duration` holds what the computer measured: the dive's
/// runtime. Bottom time is not measured; it is derived from a profile with a
/// depth threshold, so it never replaces a runtime in storage. Operations that
/// rebuild a dive from one of its sources (split, uncombine, a primary swap)
/// derive that dive's bottom time from the profile they carry, and must never
/// copy the source's runtime into it (issue #2421).
void main() {
  late AppDatabase db;
  late DiveComputerRepository computers;
  late DiveRepository diveRepo;

  // Down to 30 m, 19 minutes on the bottom, then a long stop at 5 m. The
  // bottom time the profile yields (1200 s) is well short of the runtime.
  const runtimeSeconds = 1500;
  const derivedBottomTimeSeconds = 1200;
  const points = [
    ProfilePointData(timestamp: 0, depth: 0.0),
    ProfilePointData(timestamp: 60, depth: 30.0),
    ProfilePointData(timestamp: 1200, depth: 30.0),
    ProfilePointData(timestamp: 1260, depth: 5.0),
    ProfilePointData(timestamp: 1440, depth: 5.0),
    ProfilePointData(timestamp: 1500, depth: 0.0),
  ];

  Future<void> insertComputer(String id) async {
    final now = DateTime.utc(2026, 3, 1).millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value('Computer $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<Dive> getDive(String id) =>
      (db.select(db.dives)..where((t) => t.id.equals(id))).getSingle();

  Future<DiveDataSourcesData> getSource(String diveId, String computerId) =>
      (db.select(db.diveDataSources)..where(
            (t) => t.diveId.equals(diveId) & t.computerId.equals(computerId),
          ))
          .getSingle();

  Future<String> download(
    String computerId, {
    DateTime? start,
    bool forceNew = false,
    int? reportedBottomTimeSeconds,
  }) => computers.importProfile(
    computerId: computerId,
    profileStartTime: start ?? DateTime.utc(2026, 3, 1, 10),
    points: points,
    durationSeconds: runtimeSeconds,
    maxDepth: 30.0,
    forceNew: forceNew,
    bottomTimeSeconds: reportedBottomTimeSeconds,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    computers = DiveComputerRepository();
    diveRepo = DiveRepository();
    await insertComputer('comp-1');
    await insertComputer('comp-2');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test(
    'the profile really yields a bottom time short of the runtime',
    () async {
      final diveId = await download('comp-1');

      final dive = await getDive(diveId);
      expect(dive.runtime, runtimeSeconds);
      expect(dive.bottomTime, derivedBottomTimeSeconds);
    },
  );

  group('importProfile source row stores the runtime', () {
    test('on a new dive', () async {
      final diveId = await download('comp-1');

      expect((await getSource(diveId, 'comp-1')).duration, runtimeSeconds);
    });

    test('on a download attached to an existing dive', () async {
      final diveId = await download('comp-1');
      expect(await download('comp-2'), diveId);

      expect((await getSource(diveId, 'comp-2')).duration, runtimeSeconds);
    });

    test('even when the source reports a bottom time of its own', () async {
      final diveId = await download('comp-1', reportedBottomTimeSeconds: 900);

      // The reported bottom time lands on the dive, never in place of the
      // runtime the source measured.
      expect((await getDive(diveId)).bottomTime, 900);
      expect((await getSource(diveId, 'comp-1')).duration, runtimeSeconds);
    });
  });

  test('splitting a downloaded computer out keeps its bottom time', () async {
    final diveId = await download('comp-1');
    await download('comp-2');
    final secondary = await getSource(diveId, 'comp-2');

    final newDiveId = await DiveSplitService(
      diveRepo,
    ).split(diveId: diveId, sourceId: secondary.id);

    expect((await getDive(newDiveId)).bottomTime, derivedBottomTimeSeconds);
    expect((await getDive(diveId)).bottomTime, derivedBottomTimeSeconds);
  });

  test('splitting the primary out keeps the promoted bottom time', () async {
    final diveId = await download('comp-1');
    await download('comp-2');
    final primary = await getSource(diveId, 'comp-1');

    await DiveSplitService(
      diveRepo,
    ).split(diveId: diveId, sourceId: primary.id);

    expect((await getDive(diveId)).bottomTime, derivedBottomTimeSeconds);
  });

  test('making the other computer primary keeps the bottom time', () async {
    final diveId = await download('comp-1');
    await download('comp-2');
    final secondary = await getSource(diveId, 'comp-2');

    await diveRepo.setPrimaryDataSource(
      diveId: diveId,
      computerReadingId: secondary.id,
    );

    expect((await getDive(diveId)).bottomTime, derivedBottomTimeSeconds);
  });

  test('uncombining two downloaded dives keeps each bottom time', () async {
    final first = await download('comp-1');
    final second = await download(
      'comp-1',
      start: DateTime.utc(2026, 3, 1, 11),
      forceNew: true,
    );

    final merged = await DiveMergeService(diveRepo).apply([first, second]);
    final newIds = await DiveUncombineService(
      diveRepo,
    ).separate(diveId: merged.mergedDive.id);

    expect(newIds, hasLength(1));
    expect(
      (await getDive(merged.mergedDive.id)).bottomTime,
      derivedBottomTimeSeconds,
    );
    expect((await getDive(newIds.single)).bottomTime, derivedBottomTimeSeconds);
  });
}
