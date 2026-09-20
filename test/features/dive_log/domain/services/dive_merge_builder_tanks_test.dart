import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_merge_builder.dart';

/// Sequential combine keeps one row per physical cylinder (#2036): a dive
/// split in two by a surface interval breathed the same tanks throughout, so
/// each tank is carried once, from the first half's start pressure to the
/// last half's end pressure.
Dive _dive(String id, int hour, List<DiveTank> tanks) => Dive(
  id: id,
  diverId: 'diver1',
  dateTime: DateTime.utc(2026, 7, 1, hour),
  entryTime: DateTime.utc(2026, 7, 1, hour),
  runtime: const Duration(minutes: 30),
  tanks: tanks,
);

const _ean32 = GasMix(o2: 32);

void main() {
  const builder = DiveMergeBuilder();

  group('build - tanks shared across a surface interval (#2036)', () {
    test('matching transmitter serials merge into one tank per cylinder', () {
      final a = _dive('a', 9, const [
        DiveTank(
          id: 'a1',
          order: 0,
          transmitterSerial: 'TX-LEFT',
          startPressure: 210,
          endPressure: 150,
        ),
        DiveTank(
          id: 'a2',
          order: 1,
          transmitterSerial: 'TX-RIGHT',
          startPressure: 205,
          endPressure: 145,
        ),
      ]);
      final b = _dive('b', 10, const [
        DiveTank(
          id: 'b1',
          order: 0,
          transmitterSerial: 'TX-LEFT',
          startPressure: 150,
          endPressure: 90,
        ),
        DiveTank(
          id: 'b2',
          order: 1,
          transmitterSerial: 'TX-RIGHT',
          startPressure: 145,
          endPressure: 85,
        ),
      ]);

      final result = builder.build([a, b]);
      final tanks = result.mergedDive.tanks;

      expect(tanks, hasLength(2));
      expect(tanks[0].transmitterSerial, 'TX-LEFT');
      expect(tanks[0].startPressure, 210);
      expect(tanks[0].endPressure, 90);
      expect(tanks[1].transmitterSerial, 'TX-RIGHT');
      expect(tanks[1].startPressure, 205);
      expect(tanks[1].endPressure, 85);
      expect(tanks.map((t) => t.order), [0, 1]);
      // Both halves' rows point at the one merged tank, so their pressure
      // series, gas switches and events all land on it.
      expect(result.tankIdMap['a1'], tanks[0].id);
      expect(result.tankIdMap['b1'], tanks[0].id);
      expect(result.tankIdMap['a2'], tanks[1].id);
      expect(result.tankIdMap['b2'], tanks[1].id);
    });

    test('a serial match wins even when the programmed mix differs', () {
      final a = _dive('a', 9, const [
        DiveTank(id: 'a1', transmitterSerial: '123', gasMix: _ean32),
      ]);
      final b = _dive('b', 10, const [
        DiveTank(id: 'b1', transmitterSerial: '123', gasMix: GasMix(o2: 31)),
      ]);

      expect(builder.build([a, b]).mergedDive.tanks, hasLength(1));
    });

    test('a transmitter moved to a fresh cylinder is a different tank', () {
      // Same serial, but 50 bar at the end of the first half cannot read
      // 200 bar at the start of the second: the transmitter was moved onto a
      // full cylinder during the surface interval.
      final a = _dive('a', 9, const [
        DiveTank(
          id: 'a1',
          transmitterSerial: 'X',
          startPressure: 200,
          endPressure: 50,
        ),
      ]);
      final b = _dive('b', 10, const [
        DiveTank(
          id: 'b1',
          transmitterSerial: 'X',
          startPressure: 200,
          endPressure: 60,
        ),
      ]);

      expect(builder.build([a, b]).mergedDive.tanks, hasLength(2));
    });

    test('a "no transmitter" sentinel does not hide a later real serial', () {
      // libdivecomputer reports zero for "none": the fold must carry the
      // second half's real serial, or the next combine loses the identity.
      final a = _dive('a', 9, const [
        DiveTank(id: 'a1', transmitterSerial: '0'),
      ]);
      final b = _dive('b', 10, const [
        DiveTank(id: 'b1', transmitterSerial: '42'),
      ]);

      final tank = builder.build([a, b]).mergedDive.tanks.single;

      expect(tank.transmitterSerial, '42');
    });

    test('different serials stay two tanks even on the same mix', () {
      final a = _dive('a', 9, const [
        DiveTank(id: 'a1', transmitterSerial: '111', gasMix: _ean32),
      ]);
      final b = _dive('b', 10, const [
        DiveTank(id: 'b1', transmitterSerial: '222', gasMix: _ean32),
      ]);

      expect(builder.build([a, b]).mergedDive.tanks, hasLength(2));
    });

    test('without serials, same mix and continuous pressure merge', () {
      final a = _dive('a', 9, const [
        DiveTank(
          id: 'a1',
          gasMix: _ean32,
          startPressure: 200,
          endPressure: 120,
        ),
      ]);
      final b = _dive('b', 10, const [
        DiveTank(id: 'b1', gasMix: _ean32, startPressure: 118, endPressure: 60),
      ]);

      final tanks = builder.build([a, b]).mergedDive.tanks;

      expect(tanks, hasLength(1));
      expect(tanks.single.startPressure, 200);
      expect(tanks.single.endPressure, 60);
    });

    test('a cylinder that gained pressure over the gap is a different one', () {
      // Refilled or swapped during the surface interval: 120 bar at the end
      // of the first half cannot read 200 bar at the start of the second.
      final a = _dive('a', 9, const [
        DiveTank(id: 'a1', startPressure: 200, endPressure: 120),
      ]);
      final b = _dive('b', 10, const [
        DiveTank(id: 'b1', startPressure: 200, endPressure: 110),
      ]);

      expect(builder.build([a, b]).mergedDive.tanks, hasLength(2));
    });

    test('a small rise from the cylinder warming up still merges', () {
      final a = _dive('a', 9, const [
        DiveTank(id: 'a1', startPressure: 200, endPressure: 120),
      ]);
      final b = _dive('b', 10, const [
        DiveTank(id: 'b1', startPressure: 126, endPressure: 70),
      ]);

      expect(builder.build([a, b]).mergedDive.tanks, hasLength(1));
    });

    test('different mixes without serials stay two tanks', () {
      final a = _dive('a', 9, const [DiveTank(id: 'a1')]);
      final b = _dive('b', 10, const [DiveTank(id: 'b1', gasMix: _ean32)]);

      expect(builder.build([a, b]).mergedDive.tanks, hasLength(2));
    });

    test('one first-half tank is claimed by at most one tank per half', () {
      // A second half that adds a cylinder on the same mix keeps it: it has
      // nothing left in the first half to continue.
      final a = _dive('a', 9, const [DiveTank(id: 'a1')]);
      final b = _dive('b', 10, const [
        DiveTank(id: 'b1', order: 0),
        DiveTank(id: 'b2', order: 1),
      ]);

      final result = builder.build([a, b]);

      expect(result.mergedDive.tanks, hasLength(2));
      expect(result.tankIdMap['b1'], result.tankIdMap['a1']);
      expect(result.tankIdMap['b2'], isNot(result.tankIdMap['a1']));
    });

    test('twin cylinders on one mix pair by the closest pressure', () {
      final a = _dive('a', 9, const [
        DiveTank(id: 'a1', order: 0, startPressure: 200, endPressure: 110),
        DiveTank(id: 'a2', order: 1, startPressure: 200, endPressure: 150),
      ]);
      // Listed in the opposite order to the first half.
      final b = _dive('b', 10, const [
        DiveTank(id: 'b1', order: 0, startPressure: 150, endPressure: 100),
        DiveTank(id: 'b2', order: 1, startPressure: 110, endPressure: 60),
      ]);

      final result = builder.build([a, b]);

      expect(result.mergedDive.tanks, hasLength(2));
      expect(result.tankIdMap['b1'], result.tankIdMap['a2']);
      expect(result.tankIdMap['b2'], result.tankIdMap['a1']);
    });

    test(
      'a three-dive chain carries one tank from first start to last end',
      () {
        final a = _dive('a', 9, const [
          DiveTank(id: 'a1', startPressure: 200, endPressure: 160),
        ]);
        final b = _dive('b', 10, const [
          DiveTank(id: 'b1', startPressure: 160, endPressure: 120),
        ]);
        final c = _dive('c', 11, const [
          DiveTank(id: 'c1', startPressure: 120, endPressure: 70),
        ]);

        final tanks = builder.build([c, a, b]).mergedDive.tanks;

        expect(tanks, hasLength(1));
        expect(tanks.single.startPressure, 200);
        expect(tanks.single.endPressure, 70);
      },
    );

    test('merged fields take the earliest value any half reports', () {
      final a = _dive('a', 9, const [
        DiveTank(id: 'a1', volume: 11.1, startPressure: 200, endPressure: 120),
      ]);
      final b = _dive('b', 10, const [
        DiveTank(
          id: 'b1',
          name: 'Left sidemount',
          volume: 12.0,
          workingPressure: 232,
          presetName: 'al80',
          transmitterSerial: '42',
          startPressure: 120,
        ),
      ]);

      final tank = builder.build([a, b]).mergedDive.tanks.single;

      expect(tank.volume, 11.1);
      expect(tank.name, 'Left sidemount');
      expect(tank.workingPressure, 232);
      expect(tank.presetName, 'al80');
      expect(tank.transmitterSerial, '42');
      expect(tank.startPressure, 200);
      // The second half reported no end pressure: the latest one reported
      // is the first half's.
      expect(tank.endPressure, 120);
    });
  });
}
