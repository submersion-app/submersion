import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_split_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_uncombine_service.dart';

import '../../../../helpers/test_database.dart';

/// Every reader of `dive_data_sources.duration` (field attribution, split,
/// uncombine) takes it as the source's bottom time, and every other writer
/// stores one there. A libdivecomputer download reports no bottom time, so
/// the download path has to store the one it derives from the profile, not
/// the dive's runtime; otherwise splitting or uncombining the dive replaces
/// its bottom time with the runtime.
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
  }) => computers.importProfile(
    computerId: computerId,
    profileStartTime: start ?? DateTime.utc(2026, 3, 1, 10),
    points: points,
    durationSeconds: runtimeSeconds,
    maxDepth: 30.0,
    forceNew: forceNew,
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

  group('importProfile source row', () {
    test(
      'a new dive stores the derived bottom time, not the runtime',
      () async {
        final diveId = await download('comp-1');

        final source = await getSource(diveId, 'comp-1');
        expect(source.duration, derivedBottomTimeSeconds);
        // The provenance window still spans the whole runtime.
        expect(
          source.exitTime!.difference(source.entryTime!).inSeconds,
          runtimeSeconds,
        );
      },
    );

    test('a download attached to an existing dive stores its own derived '
        'bottom time', () async {
      final diveId = await download('comp-1');
      final attachedTo = await download('comp-2');
      expect(attachedTo, diveId);

      final source = await getSource(diveId, 'comp-2');
      expect(source.duration, derivedBottomTimeSeconds);
    });

    test('a profile too short to yield a bottom time stores none', () async {
      final diveId = await computers.importProfile(
        computerId: 'comp-1',
        profileStartTime: DateTime.utc(2026, 3, 1, 10),
        points: const [
          ProfilePointData(timestamp: 0, depth: 0.0),
          ProfilePointData(timestamp: 60, depth: 10.0),
        ],
        durationSeconds: 600,
        maxDepth: 10.0,
      );

      final source = await getSource(diveId, 'comp-1');
      expect(source.duration, isNull);
    });
  });

  test('splitting a downloaded computer out keeps its bottom time', () async {
    final diveId = await download('comp-1');
    await download('comp-2');
    final secondary = await getSource(diveId, 'comp-2');

    final newDiveId = await DiveSplitService(
      diveRepo,
    ).split(diveId: diveId, sourceId: secondary.id);

    final newDive = await getDive(newDiveId);
    expect(newDive.bottomTime, derivedBottomTimeSeconds);
    final kept = await getDive(diveId);
    expect(kept.bottomTime, derivedBottomTimeSeconds);
  });

  test('splitting the primary out keeps the promoted bottom time', () async {
    final diveId = await download('comp-1');
    await download('comp-2');
    final primary = await getSource(diveId, 'comp-1');

    await DiveSplitService(
      diveRepo,
    ).split(diveId: diveId, sourceId: primary.id);

    final kept = await getDive(diveId);
    expect(kept.bottomTime, derivedBottomTimeSeconds);
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
    final kept = await getDive(merged.mergedDive.id);
    final restored = await getDive(newIds.single);
    expect(kept.bottomTime, derivedBottomTimeSeconds);
    expect(restored.bottomTime, derivedBottomTimeSeconds);
  });
}
