import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// Issue #4333. A download stored the water temperature it measured on its
/// source row only, so the dive's own column stayed empty, and the query
/// field, the dive table and the agent's documents showed none. The dive now
/// takes it too, filling an empty column on a dive the download matched.
void main() {
  late DiveComputerRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveComputerRepository();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'teric',
            name: 'Shearwater Teric',
            manufacturer: const Value('Shearwater'),
            model: const Value('Teric'),
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  final start = DateTime.utc(2026, 5, 1, 9);

  const sampled = [
    ProfilePointData(timestamp: 0, depth: 1.0, temperature: 24.0),
    ProfilePointData(timestamp: 600, depth: 18.0, temperature: 14.5),
    ProfilePointData(timestamp: 1200, depth: 6.0, temperature: 19.0),
  ];

  Future<double?> diveWaterTemp(String diveId) async => (await (db.select(
    db.dives,
  )..where((t) => t.id.equals(diveId))).getSingle()).waterTemp;

  Future<void> loggedDive(String id, {double? waterTemp}) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: start.millisecondsSinceEpoch,
          entryTime: Value(start.millisecondsSinceEpoch),
          runtime: const Value(1800),
          waterTemp: Value(waterTemp),
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  Future<String> download({
    List<ProfilePointData> points = sampled,
    double? minTemperature,
    String? targetDiveId,
  }) => repository.importProfile(
    computerId: 'teric',
    profileStartTime: start,
    points: points,
    durationSeconds: 1800,
    maxDepth: 18.0,
    minTemperature: minTemperature,
    targetDiveId: targetDiveId,
    forceNew: targetDiveId == null,
  );

  test('a new dive takes the coldest sample', () async {
    expect(await diveWaterTemp(await download()), 14.5);
  });

  test('a new dive takes the header value where there is one', () async {
    expect(await diveWaterTemp(await download(minTemperature: 12)), 12);
  });

  test('a new dive with no temperature anywhere stays empty', () async {
    final diveId = await download(
      points: const [
        ProfilePointData(timestamp: 0, depth: 1.0),
        ProfilePointData(timestamp: 600, depth: 18.0),
      ],
    );

    expect(await diveWaterTemp(diveId), isNull);
  });

  test('a matched dive with no temperature is filled', () async {
    await loggedDive('logged');

    final diveId = await download(targetDiveId: 'logged');

    expect(diveId, 'logged');
    expect(await diveWaterTemp('logged'), 14.5);
  });

  test('a matched dive keeps the temperature it holds', () async {
    await loggedDive('logged', waterTemp: 20);

    await download(targetDiveId: 'logged');

    expect(await diveWaterTemp('logged'), 20);
  });
}
