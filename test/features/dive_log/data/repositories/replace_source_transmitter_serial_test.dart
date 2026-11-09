import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// Replace Source on a dive whose cylinders came in without transmitter
/// serials (a Shearwater Cloud UDDF import of the same computer): the
/// stored cylinder the download pairs with takes the download's serial,
/// once their start pressures agree (issue #4388).
void main() {
  late AppDatabase db;
  late DiveComputerRepository repo;

  final start = DateTime(2026, 6, 1, 9, 0);

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveComputerRepository();
    await db.customStatement(
      'INSERT INTO dive_computers (id, name, created_at, updated_at) '
      "VALUES ('perdix', 'Perdix', 1, 1)",
    );
  });
  tearDown(() => tearDownTestDatabase());

  Future<String> download(List<TankData> tanks, {bool isPrimary = true}) =>
      repo.importProfile(
        computerId: 'perdix',
        profileStartTime: start,
        points: const [
          ProfilePointData(timestamp: 0, depth: 0),
          ProfilePointData(timestamp: 600, depth: 20),
          ProfilePointData(timestamp: 1200, depth: 0),
        ],
        durationSeconds: 1200,
        maxDepth: 20,
        isPrimary: isPrimary,
        tanks: tanks,
        addMissingTanks: true,
      );

  Future<String> replaceWith(String diveId, List<TankData> tanks) async {
    final wasPrimary = await repo.clearSourceAndProfiles(
      diveId: diveId,
      computerId: 'perdix',
    );
    return download(tanks, isPrimary: wasPrimary);
  }

  Future<List<DiveTank>> tanksOf(String diveId) =>
      (db.select(db.diveTanks)
            ..where((t) => t.diveId.equals(diveId))
            ..orderBy([(t) => OrderingTerm.asc(t.tankOrder)]))
          .get();

  test('a stored cylinder with no serial takes the download\'s', () async {
    final diveId = await download(const [
      TankData(index: 0, o2Percent: 21, startPressure: 206.8),
      TankData(index: 1, o2Percent: 21, startPressure: 190.0),
    ]);

    await replaceWith(diveId, const [
      TankData(
        index: 0,
        o2Percent: 21,
        startPressure: 206.9,
        transmitterSerial: '76287',
      ),
      TankData(
        index: 1,
        o2Percent: 21,
        startPressure: 190.1,
        transmitterSerial: '76290',
      ),
    ]);

    final tanks = await tanksOf(diveId);
    expect(tanks, hasLength(2));
    expect(tanks.map((t) => t.transmitterSerial), ['76287', '76290']);
  });

  test('cylinders a file import wrote, with no computer or source index, '
      'take the serials too', () async {
    final diveId = await download(const [
      TankData(index: 0, o2Percent: 21, startPressure: 206.8),
      TankData(index: 1, o2Percent: 21, startPressure: 190.0),
    ]);
    // A Shearwater Cloud UDDF import knows only each cylinder's order.
    await (db.update(
      db.diveTanks,
    )..where((t) => t.diveId.equals(diveId))).write(
      const DiveTanksCompanion(
        computerId: Value(null),
        sourceTankIndex: Value(null),
      ),
    );

    await replaceWith(diveId, const [
      TankData(
        index: 0,
        o2Percent: 21,
        startPressure: 206.9,
        transmitterSerial: '76287',
      ),
      TankData(
        index: 1,
        o2Percent: 21,
        startPressure: 190.1,
        transmitterSerial: '76290',
      ),
    ]);

    final tanks = await tanksOf(diveId);
    expect(tanks, hasLength(2));
    expect(tanks.map((t) => t.transmitterSerial), ['76287', '76290']);
  });

  test('start pressures that disagree leave the serial empty', () async {
    final diveId = await download(const [
      TankData(index: 0, o2Percent: 21, startPressure: 206.8),
    ]);

    await replaceWith(diveId, const [
      TankData(
        index: 0,
        o2Percent: 21,
        startPressure: 150.0,
        transmitterSerial: '76287',
      ),
    ]);

    expect((await tanksOf(diveId)).single.transmitterSerial, isNull);
  });

  test('a serial the cylinder has is never replaced', () async {
    final diveId = await download(const [
      TankData(
        index: 0,
        o2Percent: 21,
        startPressure: 206.8,
        transmitterSerial: '11111',
      ),
    ]);

    await replaceWith(diveId, const [
      TankData(
        index: 0,
        o2Percent: 21,
        startPressure: 206.8,
        transmitterSerial: '76287',
      ),
    ]);

    expect((await tanksOf(diveId)).single.transmitterSerial, '11111');
  });
}
