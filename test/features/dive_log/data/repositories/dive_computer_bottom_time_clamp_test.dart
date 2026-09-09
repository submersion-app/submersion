import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// Issue #1642: the live-download path must never store a bottom time longer
/// than the computer's own reported duration, even when the sample stream
/// keeps logging at the surface after the dive ended.
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
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  // 13 s dive to 1.77 m. Threshold = min(max(6, 0.58), 0.85 * 1.77) = 1.50 m,
  // so the 1.55 m surface-noise sample at t=368 would otherwise mark the
  // ascent start and yield a 368 s bottom time.
  const shallowWithSurfaceTail = [
    ProfilePointData(timestamp: 0, depth: 0.0),
    ProfilePointData(timestamp: 5, depth: 1.77),
    ProfilePointData(timestamp: 10, depth: 1.6),
    ProfilePointData(timestamp: 13, depth: 0.3),
    ProfilePointData(timestamp: 60, depth: 0.2),
    ProfilePointData(timestamp: 120, depth: 0.4),
    ProfilePointData(timestamp: 240, depth: 0.9),
    ProfilePointData(timestamp: 368, depth: 1.55),
    ProfilePointData(timestamp: 400, depth: 0.0),
  ];

  test('imported bottom time never exceeds durationSeconds', () async {
    final diveId = await computers.importProfile(
      computerId: 'comp-1',
      profileStartTime: DateTime(2026, 1, 1, 10),
      points: shallowWithSurfaceTail,
      durationSeconds: 13,
      maxDepth: 1.77,
    );

    final dive = await getDive(diveId);
    expect(dive.runtime, 13);
    expect(dive.bottomTime, 13);
  });

  test('a bottom time already within the duration is left alone', () async {
    final diveId = await computers.importProfile(
      computerId: 'comp-1',
      profileStartTime: DateTime(2026, 1, 1, 10),
      points: const [
        ProfilePointData(timestamp: 0, depth: 0.0),
        ProfilePointData(timestamp: 60, depth: 30.0),
        ProfilePointData(timestamp: 1200, depth: 30.0),
        ProfilePointData(timestamp: 1260, depth: 5.0),
        ProfilePointData(timestamp: 1320, depth: 0.0),
      ],
      durationSeconds: 1320,
      maxDepth: 30.0,
    );

    final dive = await getDive(diveId);
    expect(dive.bottomTime, 1200);
  });
}
