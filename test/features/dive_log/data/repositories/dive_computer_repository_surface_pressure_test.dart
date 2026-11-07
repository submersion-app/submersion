import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// Issue #4208: the surface pressure a computer measured lands on the dive.
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

  setUp(() async {
    db = await setUpTestDatabase();
    computers = DiveComputerRepository();
    await insertComputer('comp-1');
    await insertComputer('comp-2');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  const points = [
    ProfilePointData(timestamp: 0, depth: 0.0),
    ProfilePointData(timestamp: 60, depth: 18.0),
    ProfilePointData(timestamp: 1800, depth: 0.0),
  ];
  final start = DateTime(2026, 1, 1, 10);

  Future<String> download(String computerId, {double? surfacePressure}) =>
      computers.importProfile(
        computerId: computerId,
        profileStartTime: start,
        points: points,
        durationSeconds: 1800,
        maxDepth: 18.0,
        surfacePressure: surfacePressure,
      );

  test('a new dive takes the measured surface pressure', () async {
    final diveId = await download('comp-1', surfacePressure: 0.961);

    expect((await getDive(diveId)).surfacePressure, 0.961);
  });

  test('a new dive without a reading has none', () async {
    final diveId = await download('comp-1');

    expect((await getDive(diveId)).surfacePressure, isNull);
  });

  test('a matched dive without one takes the reading', () async {
    final diveId = await download('comp-1');
    final matchedId = await download('comp-2', surfacePressure: 0.961);

    expect(matchedId, diveId);
    expect((await getDive(diveId)).surfacePressure, 0.961);
  });

  test('a matched dive keeps the surface pressure it already has', () async {
    final diveId = await download('comp-1');
    await (db.update(db.dives)..where((t) => t.id.equals(diveId))).write(
      const DivesCompanion(surfacePressure: Value(1.002)),
    );

    await download('comp-2', surfacePressure: 0.961);

    expect((await getDive(diveId)).surfacePressure, 1.002);
  });

  test('a download taking the primary role from a file import replaces the '
      'imported surface pressure', () async {
    final now = DateTime.now();
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('uddf-dive'),
            diveDateTime: Value(start.millisecondsSinceEpoch),
            entryTime: Value(start.millisecondsSinceEpoch),
            surfacePressure: const Value(1.013),
            createdAt: Value(now.millisecondsSinceEpoch),
            updatedAt: Value(now.millisecondsSinceEpoch),
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'uddf-source',
            diveId: 'uddf-dive',
            isPrimary: const Value(true),
            sourceFileFormat: const Value('uddf'),
            importedAt: now,
            createdAt: now,
          ),
        );

    final diveId = await download('comp-1', surfacePressure: 0.961);

    expect(diveId, 'uddf-dive');
    expect((await getDive(diveId)).surfacePressure, 0.961);
  });

  test('a secondary computer leaves the primary reading alone', () async {
    final diveId = await download('comp-1', surfacePressure: 1.01);

    await download('comp-2', surfacePressure: 0.961);

    expect((await getDive(diveId)).surfacePressure, 1.01);
  });
}
