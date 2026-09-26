import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// Issue #1798: a source that reports its own dive summary (Garmin's FIT
/// dive_summary and dive_settings) must land those values on the new dive
/// rather than having them derived from the profile or dropped.
void main() {
  late AppDatabase db;
  late DiveComputerRepository computers;

  Future<void> insertComputer(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
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

  Future<DiveDataSourcesData> getSource(String diveId) => (db.select(
    db.diveDataSources,
  )..where((t) => t.diveId.equals(diveId))).getSingle();

  setUp(() async {
    db = await setUpTestDatabase();
    computers = DiveComputerRepository();
    await insertComputer('comp-1');
    await insertComputer('comp-2');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  // A slow ascent: the profile calculator ends the bottom phase at the first
  // sample shallower than its depth threshold (t=3000, 50 min), while the
  // computer itself counts 60 min of bottom time.
  const slowAscent = [
    ProfilePointData(timestamp: 0, depth: 0.0),
    ProfilePointData(timestamp: 60, depth: 20.0, cns: 3.0),
    ProfilePointData(timestamp: 2760, depth: 20.0, cns: 9.0),
    ProfilePointData(timestamp: 3000, depth: 12.0, cns: 10.0),
    ProfilePointData(timestamp: 3300, depth: 6.0, cns: 11.0),
    ProfilePointData(timestamp: 3600, depth: 0.0, cns: 11.0),
  ];

  test('a reported bottom time wins over the profile-derived one', () async {
    final derivedId = await computers.importProfile(
      computerId: 'comp-1',
      profileStartTime: DateTime(2026, 1, 1, 10),
      points: slowAscent,
      durationSeconds: 3600,
      maxDepth: 20.0,
    );
    final reportedId = await computers.importProfile(
      computerId: 'comp-1',
      profileStartTime: DateTime(2026, 1, 2, 10),
      points: slowAscent,
      durationSeconds: 3600,
      maxDepth: 20.0,
      bottomTimeSeconds: 3600,
    );

    expect((await getDive(derivedId)).bottomTime, 3000);
    expect((await getDive(reportedId)).bottomTime, 3600);
  });

  test('a reported bottom time is still bounded by the duration', () async {
    final diveId = await computers.importProfile(
      computerId: 'comp-1',
      profileStartTime: DateTime(2026, 1, 1, 10),
      points: slowAscent,
      durationSeconds: 3600,
      maxDepth: 20.0,
      bottomTimeSeconds: 4000,
    );

    expect((await getDive(diveId)).bottomTime, 3600);
  });

  test('stores the reported surface interval and water type', () async {
    final diveId = await computers.importProfile(
      computerId: 'comp-1',
      profileStartTime: DateTime(2026, 1, 1, 10),
      points: slowAscent,
      durationSeconds: 3600,
      maxDepth: 20.0,
      surfaceIntervalSeconds: 5400,
      waterType: WaterType.salt,
    );

    final dive = await getDive(diveId);
    expect(dive.surfaceIntervalSeconds, 5400);
    expect(dive.waterType, 'salt');
    expect((await getSource(diveId)).surfaceInterval, 5400);
  });

  test('reported end CNS and OTU land on the dive and its source', () async {
    final diveId = await computers.importProfile(
      computerId: 'comp-1',
      profileStartTime: DateTime(2026, 1, 1, 10),
      points: slowAscent,
      durationSeconds: 3600,
      maxDepth: 20.0,
      cnsEnd: 14.0,
      otu: 38.0,
    );

    final dive = await getDive(diveId);
    expect(dive.cnsEnd, 14.0);
    expect(dive.otu, 38.0);
    final source = await getSource(diveId);
    expect(source.cns, 14.0);
    expect(source.otu, 38.0);
  });

  test('a download attached to an existing dive records its summary on its '
      'own source row and leaves the dive row alone', () async {
    final start = DateTime(2026, 1, 1, 10);
    final diveId = await computers.importProfile(
      computerId: 'comp-1',
      profileStartTime: start,
      points: slowAscent,
      durationSeconds: 3600,
      maxDepth: 20.0,
    );
    final matchedId = await computers.importProfile(
      computerId: 'comp-2',
      profileStartTime: start,
      points: slowAscent,
      durationSeconds: 3600,
      maxDepth: 20.0,
      bottomTimeSeconds: 3600,
      surfaceIntervalSeconds: 5400,
      waterType: WaterType.salt,
      cnsEnd: 14.0,
      otu: 38.0,
    );
    expect(matchedId, diveId);

    final dive = await getDive(diveId);
    expect(dive.bottomTime, 3000);
    expect(dive.cnsEnd, 11.0);
    expect(dive.otu, isNull);
    expect(dive.surfaceIntervalSeconds, isNull);
    expect(dive.waterType, isNull);

    final source =
        await (db.select(db.diveDataSources)..where(
              (t) => t.diveId.equals(diveId) & t.computerId.equals('comp-2'),
            ))
            .getSingle();
    expect(source.cns, 14.0);
    expect(source.otu, 38.0);
    expect(source.surfaceInterval, 5400);
  });

  test('a download attached to an existing dive without a summary takes its '
      'source CNS from the samples', () async {
    final start = DateTime(2026, 1, 1, 10);
    final diveId = await computers.importProfile(
      computerId: 'comp-1',
      profileStartTime: start,
      points: slowAscent,
      durationSeconds: 3600,
      maxDepth: 20.0,
    );
    await computers.importProfile(
      computerId: 'comp-2',
      profileStartTime: start,
      points: slowAscent,
      durationSeconds: 3600,
      maxDepth: 20.0,
    );

    final source =
        await (db.select(db.diveDataSources)..where(
              (t) => t.diveId.equals(diveId) & t.computerId.equals('comp-2'),
            ))
            .getSingle();
    expect(source.cns, 11.0);
    expect(source.otu, isNull);
    expect(source.surfaceInterval, isNull);
  });

  test('without a summary, CNS falls back to the samples and the rest stay '
      'unset', () async {
    final diveId = await computers.importProfile(
      computerId: 'comp-1',
      profileStartTime: DateTime(2026, 1, 1, 10),
      points: slowAscent,
      durationSeconds: 3600,
      maxDepth: 20.0,
    );

    final dive = await getDive(diveId);
    expect(dive.cnsEnd, 11.0);
    expect(dive.otu, isNull);
    expect(dive.surfaceIntervalSeconds, isNull);
    expect(dive.waterType, isNull);
    final source = await getSource(diveId);
    expect(source.cns, 11.0);
    expect(source.otu, isNull);
    expect(source.surfaceInterval, isNull);
  });
}
