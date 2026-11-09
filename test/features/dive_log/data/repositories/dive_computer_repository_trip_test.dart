import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// Issue #3022: a downloaded dive joins the trip the caller resolved for it,
/// but only when the download creates the dive.
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
    await seedTrip(db, 'maldives');
    await seedTrip(db, 'red-sea');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  const points = [
    ProfilePointData(timestamp: 0, depth: 0.0),
    ProfilePointData(timestamp: 60, depth: 18.0),
    ProfilePointData(timestamp: 1800, depth: 0.0),
  ];
  final start = DateTime.utc(2026, 11, 8, 10);

  Future<String> download(String computerId, {String? tripId}) =>
      computers.importProfile(
        computerId: computerId,
        profileStartTime: start,
        points: points,
        durationSeconds: 1800,
        maxDepth: 18.0,
        tripId: tripId,
      );

  test('a new dive joins the trip it was given', () async {
    final diveId = await download('comp-1', tripId: 'maldives');

    expect((await getDive(diveId)).tripId, 'maldives');
  });

  test('a new dive given no trip has none', () async {
    final diveId = await download('comp-1');

    expect((await getDive(diveId)).tripId, isNull);
  });

  test('a matched dive keeps the trip it already has', () async {
    final diveId = await download('comp-1', tripId: 'red-sea');

    final matchedId = await download('comp-2', tripId: 'maldives');

    expect(matchedId, diveId);
    expect((await getDive(diveId)).tripId, 'red-sea');
  });

  test('a matched dive the diver left out of every trip stays out', () async {
    final diveId = await download('comp-1');

    await download('comp-2', tripId: 'maldives');

    expect((await getDive(diveId)).tripId, isNull);
  });
}
