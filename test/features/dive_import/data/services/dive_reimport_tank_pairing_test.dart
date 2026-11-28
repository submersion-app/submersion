import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_import/data/services/dive_reimport_service.dart';

import '../../../../helpers/test_database.dart';

/// A file whose tanks carry no order (Shearwater Cloud, Subsurface) pairs
/// them with the stored cylinders it can tell apart, by transmitter serial
/// or start pressure, never by position alone (issue #4665): a diver who
/// removed or reordered a cylinder must not see another cylinder's readings
/// written onto it.
void main() {
  late AppDatabase db;
  late DiveReimportService service;
  const diveId = 'dive-1';

  setUp(() async {
    db = await setUpTestDatabase();
    service = DiveReimportService(db: db);
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: diveId,
            diveDateTime: 1000,
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  Future<void> seed(
    String id,
    int order, {
    double? start,
    double? end,
    double o2 = 21,
    String? serial,
  }) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion.insert(
          id: id,
          diveId: diveId,
          tankOrder: Value(order),
          startPressure: Value(start),
          endPressure: Value(end),
          o2Percent: Value(o2),
          transmitterSerial: Value(serial),
        ),
      );

  Future<void> resync(List<Map<String, dynamic>> tanks) =>
      service.applyReimport(
        diveId: diveId,
        diveData: {'tanks': tanks},
        now: DateTime(2026, 11, 28),
      );

  Future<DiveTank> row(String id) =>
      (db.select(db.diveTanks)..where((t) => t.id.equals(id))).getSingle();

  Future<List<DiveTank>> rows() =>
      (db.select(db.diveTanks)..where((t) => t.diveId.equals(diveId))).get();

  test('a removed cylinder does not hand its readings to the next', () async {
    // The diver removed the first cylinder, so the pony sits where it was.
    await seed('pony', 1, start: 150, end: 100);

    await resync([
      {'startPressure': 200.0, 'endPressure': 50.0},
      {'startPressure': 150.0, 'endPressure': 110.0},
    ]);

    final pony = await row('pony');
    expect(pony.startPressure, 150.0);
    expect(pony.endPressure, 110.0);
  });

  test('a file tank that names no stored cylinder is left out while one '
      'is unplaced', () async {
    // The diver corrected the start pressure by hand: nothing says the
    // file's tank is this cylinder, so neither is changed or duplicated.
    await seed('tank-a', 0, start: 180, end: 60);

    await resync([
      {'startPressure': 200.0, 'endPressure': 50.0},
    ]);

    final all = await rows();
    expect(all, hasLength(1));
    expect(all.single.startPressure, 180.0);
    expect(all.single.endPressure, 60.0);
  });

  test('a serial pairs the cylinder whatever its pressure', () async {
    await seed('tank-a', 0, start: 100, serial: '111');

    await resync([
      {'startPressure': 200.0, 'endPressure': 50.0, 'transmitterSerial': '111'},
    ]);

    expect((await row('tank-a')).endPressure, 50.0);
  });

  test('a serial pairs its cylinder before the rest line up', () async {
    // The diver reordered the cylinders; only one has a stored serial, and
    // it names the file's first tank.
    await seed('pony', 0, start: 200);
    await seed('main', 1, start: 200, serial: '222');

    await resync([
      {
        'startPressure': 200.0,
        'endPressure': 150.0,
        'transmitterSerial': '222',
      },
      {'startPressure': 200.0, 'endPressure': 120.0},
    ]);

    expect((await row('main')).endPressure, 150.0);
    expect((await row('pony')).endPressure, 120.0);
  });

  test('a cylinder left as it was keeps its gas switches', () async {
    // The diver corrected the deco cylinder's start pressure, so nothing
    // says the file's second tank is it: it is left as it was, switches too.
    await seed('back', 0, start: 200);
    await seed('deco', 1, start: 180);
    for (final (id, tankId, t) in [
      ('gs-back', 'back', 0),
      ('gs-deco', 'deco', 600),
    ]) {
      await db
          .into(db.gasSwitches)
          .insert(
            GasSwitchesCompanion.insert(
              id: id,
              diveId: diveId,
              tankId: tankId,
              timestamp: t,
              createdAt: 1000,
            ),
          );
    }

    await service.applyReimport(
      diveId: diveId,
      diveData: {
        'tanks': [
          {'startPressure': 200.0, 'endPressure': 60.0},
          {'startPressure': 210.0, 'endPressure': 150.0},
        ],
        'gasSwitches': [
          {'timestamp': 0, 'tankIndex': 0},
          {'timestamp': 600, 'tankIndex': 1},
        ],
      },
      now: DateTime(2026, 11, 28),
    );

    final switches = await (db.select(
      db.gasSwitches,
    )..where((t) => t.diveId.equals(diveId))).get();
    expect(
      {for (final s in switches) (s.tankId, s.timestamp)},
      {('back', 0), ('deco', 600)},
    );
    expect((await row('deco')).startPressure, 180.0);
  });

  test('cylinders that line up in order pair by position', () async {
    await seed('a', 0, start: 200);
    await seed('b', 1, start: 200);

    await resync([
      {'startPressure': 200.0, 'endPressure': 60.0},
      {'startPressure': 200.0, 'endPressure': 90.0},
    ]);

    expect((await row('a')).endPressure, 60.0);
    expect((await row('b')).endPressure, 90.0);
  });

  test('a stored cylinder with no start pressure takes the file\'s when '
      'all line up', () async {
    await seed('tank-a', 0);

    await resync([
      {'startPressure': 200.0, 'endPressure': 50.0},
    ]);

    expect((await row('tank-a')).startPressure, 200.0);
  });

  test('a file tank with no stored cylinder left is added', () async {
    await seed('tank-a', 0, start: 200);

    await resync([
      {'startPressure': 200.0, 'endPressure': 50.0},
      {'startPressure': 150.0, 'endPressure': 100.0},
    ]);

    final all = await rows();
    expect(all, hasLength(2));
    expect((await row('tank-a')).endPressure, 50.0);
  });
}
