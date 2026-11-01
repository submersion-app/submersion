import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/tank_usage_range.dart';

void main() {
  const back = DiveTank(id: 'back', volume: 12);
  const deco = DiveTank(
    id: 'deco',
    volume: 7,
    role: TankRole.deco,
    gasMix: GasMix(o2: 50),
  );

  GasSwitchWithTank switchTo(String tankId, int timestamp) {
    return GasSwitchWithTank(
      gasSwitch: GasSwitch(
        id: 'gs-$tankId-$timestamp',
        diveId: 'dive-1',
        timestamp: timestamp,
        tankId: tankId,
        createdAt: DateTime(2026),
      ),
      tankName: tankId,
      gasMix: 'mix',
      o2Fraction: 0.21,
    );
  }

  group('knownGasSwitches', () {
    test('keeps switches naming a current tank before the dive ends', () {
      final known = knownGasSwitches(
        const [back, deco],
        [
          switchTo('back', 0),
          switchTo('stale', 30),
          switchTo('deco', 2400),
          switchTo('deco', 3700),
        ],
        before: 3600,
      );

      expect(known.map((s) => s.gasSwitch.timestamp), [0, 2400]);
    });
  });

  group('startingTankOf', () {
    GasSwitch bare(String tankId, int timestamp) => GasSwitch(
      id: 'gs-$tankId-$timestamp',
      diveId: 'dive-1',
      timestamp: timestamp,
      tankId: tankId,
      createdAt: DateTime(2026),
    );

    test('a switch in the first minute names the start', () {
      final tank = startingTankOf(
        tanks: const [back, deco],
        switches: [bare('deco', 30)],
        diveStart: 0,
      );

      expect(tank?.id, 'deco');
    });

    test('a later switch leaves the back gas', () {
      final tank = startingTankOf(
        tanks: const [back, deco],
        switches: [bare('deco', 600)],
        diveStart: 0,
      );

      expect(tank?.id, 'back');
    });

    test('a switch to an unknown tank is ignored', () {
      final tank = startingTankOf(
        tanks: const [back, deco],
        switches: [bare('stale', 10)],
        diveStart: 0,
      );

      expect(tank?.id, 'back');
    });

    test('no tanks is null', () {
      expect(
        startingTankOf(tanks: const [], switches: const [], diveStart: 0),
        isNull,
      );
    });
  });

  group('activeTankAt', () {
    test('the back gas is breathed up to a switch late in the dive', () {
      // The grace for a starting gas runs from the dive's start, not from
      // the moment asked about: 50 s before the deco switch is back gas.
      final tank = activeTankAt(
        tanks: const [back, deco],
        gasSwitches: [switchTo('deco', 2400)],
        timestamp: 2350,
        diveStart: 0,
      );

      expect(tank?.id, 'back');
    });

    test('a switch in the first minute names the starting gas', () {
      final tank = activeTankAt(
        tanks: const [back, deco],
        gasSwitches: [switchTo('deco', 10), switchTo('back', 1200)],
        timestamp: 0,
        diveStart: 0,
      );

      expect(tank?.id, 'deco');
    });

    test('a stale switch is ignored', () {
      final tank = activeTankAt(
        tanks: const [deco, back],
        gasSwitches: [switchTo('stale', 10), switchTo('deco', 2400)],
        timestamp: 0,
        diveStart: 0,
      );

      expect(tank?.id, 'back');
    });

    test('with no switches the back gas is breathed', () {
      final tank = activeTankAt(
        tanks: const [deco, back],
        gasSwitches: null,
        timestamp: 600,
        diveStart: 0,
      );

      expect(tank?.id, 'back');
    });

    test('no tanks means no active tank', () {
      expect(
        activeTankAt(
          tanks: const [],
          gasSwitches: null,
          timestamp: 0,
          diveStart: 0,
        ),
        isNull,
      );
    });
  });

  group('tankUsageWindows', () {
    const left = DiveTank(id: 'left', role: TankRole.sidemountLeft);
    const right = DiveTank(id: 'right', role: TankRole.sidemountRight);
    const stage = DiveTank(id: 'stage', role: TankRole.stage);

    List<TankUsageWindow> windowsOf(
      DiveTank tank,
      List<GasSwitchWithTank> switches, {
      List<DiveTank> tanks = const [left, right],
      int diveEnd = 2400,
    }) {
      return tankUsageWindows(
        tank: tank,
        gasSwitches: switches,
        diveStart: 0,
        diveEnd: diveEnd,
        tanks: tanks,
      );
    }

    test('returns every period a cylinder was breathed (#3900)', () {
      final switches = [
        switchTo('left', 0),
        switchTo('right', 600),
        switchTo('left', 1200),
        switchTo('right', 1800),
      ];

      expect(windowsOf(left, switches), [
        (start: 0, end: 600),
        (start: 1200, end: 1800),
      ]);
      expect(windowsOf(right, switches), [
        (start: 600, end: 1200),
        (start: 1800, end: 2400),
      ]);
    });

    test(
      'a repeated switch onto the breathed cylinder continues the period',
      () {
        expect(
          windowsOf(
            back,
            [
              switchTo('back', 600),
              switchTo('back', 900),
              switchTo('deco', 1200),
            ],
            tanks: const [back, deco],
          ),
          [(start: 0, end: 1200)],
        );
      },
    );

    test('a cylinder switched off the moment it came on was not breathed', () {
      expect(
        windowsOf(
          deco,
          [switchTo('deco', 600), switchTo('back', 600)],
          tanks: const [back, deco],
        ),
        isEmpty,
      );
    });

    test('a stage no switch names has no windows', () {
      expect(windowsOf(stage, const [], tanks: const [back, stage]), isEmpty);
    });

    test('the primary gas spans a dive without switches', () {
      expect(windowsOf(back, const [], tanks: const [back, stage]), [
        (start: 0, end: 2400),
      ]);
    });

    test('a dive with no duration has no windows', () {
      expect(windowsOf(back, const [], diveEnd: 0), isEmpty);
    });

    test('a pair partner with no switch of its own shares every period', () {
      final switches = [
        switchTo('left', 0),
        switchTo('stage', 1200),
        switchTo('left', 1500),
      ];

      expect(windowsOf(right, switches, tanks: const [left, right, stage]), [
        (start: 0, end: 1200),
        (start: 1500, end: 2400),
      ]);
    });
  });

  group('TankUsageWindows', () {
    const List<TankUsageWindow> windows = [
      (start: 0, end: 600),
      (start: 1200, end: 1800),
    ];

    test('breathedSeconds sums the periods', () {
      expect(windows.breathedSeconds, 1200);
    });

    test('breathedBefore counts only time inside the periods', () {
      expect(windows.breathedBefore(0), 0);
      expect(windows.breathedBefore(300), 300);
      expect(windows.breathedBefore(900), 600);
      expect(windows.breathedBefore(1500), 900);
      expect(windows.breathedBefore(2400), 1200);
    });

    test('within clips the periods to a stretch of the dive', () {
      expect(windows.within(300, 1500), [
        (start: 300, end: 600),
        (start: 1200, end: 1500),
      ]);
      expect(windows.within(600, 1200), isEmpty);
    });
  });
}
