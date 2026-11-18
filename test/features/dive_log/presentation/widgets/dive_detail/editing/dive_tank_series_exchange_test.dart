import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_rules.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_series_exchange.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../../../helpers/test_database.dart';

/// A pressure series reassign made in a sitting: the cylinders show it at
/// once, and the readings move at Save (issue #4527, plan 5).
void main() {
  late DiveRepository dives;
  late TankPressureRepository pressures;
  late List<(String, String)> exchanged;

  setUp(() async {
    await setUpTestDatabase();
    dives = DiveRepository();
    pressures = TankPressureRepository();
    exchanged = [];
    await dives.createDive(
      Dive(
        id: 'd1',
        dateTime: DateTime.utc(2026, 7, 1, 10),
        tanks: const [
          DiveTank(
            id: 'tA',
            name: 'O2',
            order: 0,
            startPressure: 200,
            endPressure: 170,
            transmitterSerial: '111',
            sourceTankIndex: 0,
          ),
          DiveTank(
            id: 'tB',
            name: 'Dil',
            order: 1,
            startPressure: 210,
            transmitterSerial: '222',
            sourceTankIndex: 1,
          ),
        ],
      ),
    );
    await pressures.insertTankPressures('d1', {
      'tA': [
        (timestamp: 0, pressure: 200.0),
        (timestamp: 600, pressure: 170.0),
      ],
      'tB': [(timestamp: 0, pressure: 210.0)],
    });
  });
  tearDown(tearDownTestDatabase);

  Future<void> exchange(String a, String b) async {
    exchanged.add((a, b));
    await pressures.exchangeTankSources(
      diveId: 'd1',
      tankIdA: a,
      tankIdB: b,
      includePressures: false,
    );
  }

  /// The order the save service writes a sitting in: what must go before
  /// the dive, the dive, then the rest, in one transaction.
  Future<void> saveAsTheServiceDoes(EditSession<Dive> s) =>
      DatabaseService.instance.database.transaction(() async {
        await s.runHeldWrites(beforeRecord: true);
        await dives.updateDive(s.applyTo((await dives.getDiveById('d1'))!));
        await s.runHeldWrites();
      });

  Future<EditSession<Dive>> sitting() async =>
      EditSession((await dives.getDiveById('d1'))!);

  DiveTank tank(EditSession<Dive> s, String id) =>
      s.working.tanks.firstWhere((t) => t.id == id);

  test('an exchange swaps pressures and serials on the working cylinders '
      'and holds a change', () async {
    final s = await sitting();
    // As read back: a pressure the row lacks may be filled from readings.
    final b = tank(s, 'tB');
    exchangeTankSeries(s, 'tA', 'tB', exchange: exchange);

    expect(
      (tank(s, 'tA').startPressure, tank(s, 'tA').endPressure),
      (b.startPressure, b.endPressure),
    );
    expect(tank(s, 'tA').transmitterSerial, '222');
    expect(
      (tank(s, 'tB').startPressure, tank(s, 'tB').endPressure),
      (200.0, 170.0),
    );
    expect(tank(s, 'tB').sourceTankIndex, 0);
    expect(s.changedCardIds, {'tanks'});
    expect(heldTankSeriesExchanges(s), [('tA', 'tB')]);
  });

  test('the readings a reassign shows are moved by the held exchanges, '
      'in the order they were made', () async {
    final s = await sitting();
    const a = [TankPressurePoint(tankId: 'tA', timestamp: 0, pressure: 200)];
    const b = [TankPressurePoint(tankId: 'tB', timestamp: 0, pressure: 210)];
    final stored = {'tA': a, 'tB': b};

    expect(tankReadingsInSitting(s, stored), stored);
    exchangeTankSeries(s, 'tA', 'tB', exchange: exchange);
    expect(tankReadingsInSitting(s, stored), {'tA': b, 'tB': a});
    // Onto a cylinder with no readings: they move, and nothing is left.
    setTanks(s, [...s.working.tanks, const DiveTank(id: 'tC', order: 2)]);
    exchangeTankSeries(s, 'tA', 'tC', exchange: exchange);
    expect(tankReadingsInSitting(s, stored), {'tB': a, 'tC': b});
    expect(tankReadingsInSitting(s, null), isNull);
  });

  test('the same exchange again leaves the sitting clean', () async {
    final s = await sitting();
    exchangeTankSeries(s, 'tA', 'tB', exchange: exchange);
    exchangeTankSeries(s, 'tB', 'tA', exchange: exchange);

    expect(s.isDirty, isFalse);
    expect(heldTankSeriesExchanges(s), isEmpty);
  });

  test('at Save the readings move and the pressures are the swapped ones, '
      'once', () async {
    final s = await sitting();
    final before = tank(s, 'tB');
    exchangeTankSeries(s, 'tA', 'tB', exchange: exchange);

    await saveAsTheServiceDoes(s);

    final saved = (await dives.getDiveById('d1'))!;
    final a = saved.tanks.firstWhere((t) => t.id == 'tA');
    final b = saved.tanks.firstWhere((t) => t.id == 'tB');
    expect(
      (a.startPressure, a.endPressure, a.transmitterSerial),
      (before.startPressure, before.endPressure, '222'),
    );
    expect(
      (b.startPressure, b.endPressure, b.transmitterSerial),
      (200.0, 170.0, '111'),
    );
    final series = await pressures.getTankPressuresForDive('d1');
    expect(series['tA']!.map((p) => p.pressure), [210.0]);
    expect(series['tB']!.map((p) => p.pressure), [200.0, 170.0]);
  });

  test('a cylinder removed after an exchange: the one kept has the readings '
      'moved onto it, with their pressures', () async {
    final s = await sitting();
    final before = tank(s, 'tB');
    exchangeTankSeries(s, 'tA', 'tB', exchange: exchange);
    removeSittingTank(s, 'tB');

    await saveAsTheServiceDoes(s);

    final saved = (await dives.getDiveById('d1'))!;
    expect(saved.tanks.map((t) => t.id), ['tA']);
    final a = saved.tanks.single;
    expect(
      (a.startPressure, a.endPressure, a.transmitterSerial),
      (before.startPressure, before.endPressure, '222'),
    );
    final series = await pressures.getTankPressuresForDive('d1');
    expect(series['tA']!.map((p) => p.pressure), [210.0]);
    expect(series.containsKey('tB'), isFalse);
  });
}
