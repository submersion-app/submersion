import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';
import 'package:submersion/features/trips/domain/services/trip_gas_record_builder.dart';

void main() {
  final t0 = DateTime.utc(2026, 3, 9);
  DateTime at(int day, int hour, [int minute = 0]) =>
      DateTime.utc(2026, 3, day, hour, minute);

  TripCylinder slot(String id, String label, int order) => TripCylinder(
    id: id,
    tripId: 't1',
    label: label,
    volume: 11.1,
    workingPressure: 207,
    sortOrder: order,
    createdAt: t0,
    updatedAt: t0,
  );

  TripCylinderEvent fill(
    String id,
    String slotId,
    DateTime when, {
    String? bottle,
    double? pressure,
    double o2 = 32,
    double? analyzedO2,
    String? center,
    double? cost,
    String? currency,
    bool package = false,
  }) => TripCylinderEvent(
    id: id,
    tripCylinderId: slotId,
    kind: TripCylinderEventKind.fill,
    occurredAt: when,
    bottleLabel: bottle,
    pressure: pressure,
    o2Percent: o2,
    analyzedO2: analyzedO2,
    diveCenterId: center,
    cost: cost,
    currency: currency,
    isPackage: package,
    createdAt: when,
    updatedAt: when,
  );

  TripGasRecordTank tank(
    String id,
    String diveId,
    String slotId,
    DateTime when, {
    int order = 0,
    double? volume = 11.1,
    double? start,
    double? end,
    double o2 = 32,
    String? diver,
  }) => TripGasRecordTank(
    tankId: id,
    diveId: diveId,
    entryTime: when,
    diverId: diver,
    diverName: diver == null ? null : 'Diver $diver',
    siteName: 'Salt Pier',
    tankOrder: order,
    volume: volume,
    startPressure: start,
    endPressure: end,
    gasMix: GasMix(o2: o2),
    tripCylinderId: slotId,
  );

  final a = slot('a', 'Truck 1', 0);
  final b = slot('b', 'Truck 2', 1);
  // Truck 1: bottle 14 on Mar 9, swapped for bottle 22 on Mar 11 (a fill
  // with no reading, so the working pressure); a correction that evening.
  // Truck 2: one package fill, no bottle named.
  final events = {
    'a': [
      fill(
        'f1',
        'a',
        at(9, 7),
        bottle: '14',
        pressure: 200,
        analyzedO2: 31.8,
        center: 'c1',
        cost: 10,
        currency: 'USD',
      ),
      fill('f2', 'a', at(11, 7), bottle: '22', cost: 12),
      TripCylinderEvent(
        id: 'x1',
        tripCylinderId: 'a',
        kind: TripCylinderEventKind.adjustment,
        occurredAt: at(11, 18),
        pressure: 60,
        createdAt: at(11, 18),
        updatedAt: at(11, 18),
      ),
    ],
    'b': [
      fill(
        'g1',
        'b',
        at(9, 7, 30),
        pressure: 210,
        o2: 21,
        cost: 8,
        package: true,
      ),
    ],
  };

  TripGasRecord record({
    List<TripGasRecordTank>? tanks,
    GasModel model = GasModel.ideal,
    String currency = 'USD',
    List<TripUnlinkedTank> unlinked = const [],
  }) => buildTripGasRecord(
    cylinders: [a, b],
    eventsBySlot: events,
    tanks:
        tanks ??
        [
          tank('t2', 'd2', 'a', at(11, 9), volume: null, start: 207, end: 50),
          tank(
            't3',
            'd1',
            'b',
            at(9, 9),
            order: 1,
            start: 210,
            end: 100,
            o2: 21,
          ),
          tank('t1', 'd1', 'a', at(9, 9), start: 200, end: 60),
        ],
    unlinked: unlinked,
    gasModel: model,
    defaultCurrency: currency,
  );

  test('rows come in dive order, then tank order', () {
    expect(record().rows.map((r) => r.tank.tankId), ['t1', 't3', 't2']);
  });

  test('a swap credits each dive to its own bottle', () {
    final rows = {for (final r in record().rows) r.tank.tankId: r};
    // Mar 9 dive: bottle 14, filled to 200 at c1, analyzed 31.8.
    expect(rows['t1']!.bottleLabel, '14');
    expect(rows['t1']!.fill!.id, 'f1');
    expect(rows['t1']!.fillPressure, 200);
    expect(rows['t1']!.diveCenterId, 'c1');
    expect(rows['t1']!.analyzedMix!.o2, 31.8);
    expect(rows['t1']!.orderedMix!.o2, 32);
    // Mar 11 dive: bottle 22, a fill with no reading, so 207 (working).
    expect(rows['t2']!.bottleLabel, '22');
    expect(rows['t2']!.fill!.id, 'f2');
    expect(rows['t2']!.fillPressure, 207);
    expect(rows['t2']!.analyzedMix, isNull);
    // Truck 2 never named a bottle: the slot's own label.
    expect(rows['t3']!.bottleLabel, 'Truck 2');
  });

  test('a fill at the dive\'s minute counts for it', () {
    final r = record(
      tanks: [tank('t9', 'd9', 'a', at(11, 7), start: 207, end: 80)],
    );
    expect(r.rows.single.fill!.id, 'f2');
  });

  test('a dive before any fill has no fill and no fill pressure', () {
    final r = record(
      tanks: [tank('t0', 'd0', 'a', at(8, 9), start: 200, end: 50)],
    );
    expect(r.rows.single.fill, isNull);
    expect(r.rows.single.fillPressure, isNull);
    expect(r.rows.single.bottleLabel, 'Truck 1');
  });

  test('litres breathed, ideal gas', () {
    final rows = {for (final r in record().rows) r.tank.tankId: r};
    // 11.1 L x (200 - 60) bar = 1554 L.
    expect(rows['t1']!.litres, closeTo(1554, 0.001));
    // 11.1 L x (210 - 100) bar = 1221 L.
    expect(rows['t3']!.litres, closeTo(1221, 0.001));
    // No tank volume: no figure (decided 2026-09-30).
    expect(rows['t2']!.litres, isNull);
  });

  test('a real gas carries fewer litres than an ideal one at 200 bar', () {
    final rows = {
      for (final r in record(model: GasModel.real).rows) r.tank.tankId: r,
    };
    expect(rows['t1']!.litres, lessThan(1554));
    expect(rows['t1']!.litres, greaterThan(1400));
  });

  test('a missing pressure leaves the row out; end above start is 0 L', () {
    final r = record(
      tanks: [
        tank('u1', 'd5', 'a', at(9, 9), start: null, end: 60),
        tank('u2', 'd6', 'a', at(9, 11), start: 50, end: 60),
      ],
    );
    expect(r.rows.first.litres, isNull);
    expect(r.rows.last.litres, 0);
  });

  test('slot totals: dives, litres, and how many were left out', () {
    final totals = {for (final s in record().slots) s.cylinder.id: s};
    // Truck 1: two dives, 1554 L from t1, t2 left out (no size).
    expect(totals['a']!.dives, 2);
    expect(totals['a']!.litres, closeTo(1554, 0.001));
    expect(totals['a']!.leftOut, 1);
    // Truck 2: one dive, 1221 L.
    expect(totals['b']!.dives, 1);
    expect(totals['b']!.leftOut, 0);
    // Board order.
    expect(record().slots.map((s) => s.cylinder.id), ['a', 'b']);
  });

  test('a slot with no figure totals null, not 0 L', () {
    final r = record(
      tanks: [
        tank('u1', 'd5', 'a', at(9, 9), volume: null, start: 200, end: 60),
      ],
    );
    final totals = {for (final s in r.slots) s.cylinder.id: s};
    // Truck 1: one dive, no tank size, so no figure to total.
    expect(totals['a']!.dives, 1);
    expect(totals['a']!.leftOut, 1);
    expect(totals['a']!.litres, isNull);
    // Truck 2: no dives at all.
    expect(totals['b']!.dives, 0);
    expect(totals['b']!.litres, isNull);
  });

  test('left out counts dives, not tanks', () {
    // Two computers' rows for one cylinder on one dive, neither sized.
    final r = record(
      tanks: [
        tank('u1', 'd5', 'a', at(9, 9), volume: null, start: 200, end: 60),
        tank(
          'u2',
          'd5',
          'a',
          at(9, 9),
          order: 1,
          volume: null,
          start: 200,
          end: 60,
        ),
      ],
    );
    final truck1 = r.slots.firstWhere((s) => s.cylinder.id == 'a');
    expect(truck1.dives, 1);
    expect(truck1.leftOut, 1);
  });

  test('fills logged counts every fill on the trip', () {
    expect(record().fillsLogged, 3);
  });

  test('cost by currency, packages counted', () {
    // USD 10, and 12 with no currency, which is the diver's default (USD):
    // 22 USD. The package fill (8) is counted, not summed.
    final usd = record();
    expect(usd.costs, hasLength(1));
    expect(usd.costs.single.key, 'USD');
    expect(usd.costs.single.value, 22);
    expect(usd.packageFills, 1);
    // With a EUR default the 12 is EUR: EUR 12 then USD 10 (largest first).
    final eur = record(currency: 'EUR');
    expect(
      [for (final c in eur.costs) '${c.key} ${c.value}'],
      ['EUR 12.0', 'USD 10.0'],
    );
  });

  test('more than one diver', () {
    expect(record().multipleDivers, isFalse);
    final shared = record(
      tanks: [
        tank('t1', 'd1', 'a', at(9, 9), start: 200, end: 60, diver: 'x'),
        tank('t4', 'd4', 'a', at(9, 9), start: 200, end: 70, diver: 'y'),
      ],
    );
    expect(shared.multipleDivers, isTrue);
  });

  test('unlinked tanks pass through in dive order', () {
    final r = record(
      unlinked: [
        TripUnlinkedTank(
          tankId: 'n2',
          diveId: 'd8',
          entryTime: at(12, 9),
          tankOrder: 0,
        ),
        TripUnlinkedTank(
          tankId: 'n1',
          diveId: 'd7',
          entryTime: at(10, 9),
          tankOrder: 0,
        ),
      ],
    );
    expect(r.unlinked.map((u) => u.tankId), ['n1', 'n2']);
  });
}
