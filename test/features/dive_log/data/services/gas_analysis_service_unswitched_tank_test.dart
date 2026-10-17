import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';

/// Per-cylinder SAC for a breathed cylinder that no gas switch names
/// (issue #3373): the second cylinder of a sidemount pair, a single cylinder
/// whose recorded switches carry stale tank ids, and the back gas before the
/// only recorded switch.
void main() {
  const service = GasAnalysisService();

  Dive makeDive(List<DiveTank> tanks, {int minutes = 60}) {
    return Dive(
      id: 'dive-1',
      dateTime: DateTime(2026, 10, 1, 10),
      runtime: Duration(minutes: minutes),
      avgDepth: 20,
      tanks: tanks,
      profile: [
        for (var t = 0; t <= minutes * 60; t += 60)
          DiveProfilePoint(timestamp: t, depth: 20),
      ],
      gear: looseGear(const []),
      notes: '',
      photoIds: const [],
      sightings: const [],
      weights: const [],
      tags: const [],
    );
  }

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

  const left = DiveTank(
    id: 'left',
    volume: 10,
    startPressure: 170,
    endPressure: 70,
    role: TankRole.sidemountLeft,
  );
  const right = DiveTank(
    id: 'right',
    volume: 10,
    startPressure: 166,
    endPressure: 65,
    role: TankRole.sidemountRight,
  );

  Map<String, CylinderSac> byId(List<CylinderSac> results) => {
    for (final r in results) r.tankId: r,
  };

  test('both cylinders of a sidemount pair get a SAC when the computer '
      'recorded one switch onto the first', () {
    // Both cylinders hold air, so the computer's one gas switch resolves to
    // the first of them. The second was breathed all dive just the same.
    final dive = makeDive([left, right]);
    final results = byId(
      service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
        gasSwitches: [switchTo('left', 0)],
      ),
    );

    expect(results.keys, containsAll(['left', 'right']));
    expect(results['left']!.sacRate, isNotNull);
    expect(results['right']!.sacRate, isNotNull);
    expect(results['right']!.usageDuration?.inMinutes, 60);
    // Nearly equal drops over the same window give nearly equal rates.
    expect(results['right']!.sacRate, closeTo(results['left']!.sacRate!, 0.05));
  });

  test('a sidemount pair whose switches name each cylinder keeps separate '
      'windows', () {
    final dive = makeDive([left, right]);
    final results = byId(
      service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
        gasSwitches: [switchTo('left', 0), switchTo('right', 1800)],
      ),
    );

    expect(results['left']!.usageDuration?.inMinutes, 30);
    expect(results['right']!.usageDuration?.inMinutes, 30);
  });

  test('a back gas pair shares the window before a switch to deco', () {
    const a = DiveTank(
      id: 'a',
      volume: 12,
      startPressure: 200,
      endPressure: 100,
    );
    const b = DiveTank(
      id: 'b',
      volume: 12,
      startPressure: 200,
      endPressure: 110,
    );
    const deco = DiveTank(
      id: 'deco',
      volume: 7,
      startPressure: 200,
      endPressure: 150,
      role: TankRole.deco,
      gasMix: GasMix(o2: 50),
    );
    final dive = makeDive([a, b, deco]);
    final results = byId(
      service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
        gasSwitches: [switchTo('a', 0), switchTo('deco', 45 * 60)],
      ),
    );

    expect(results['a']!.usageDuration?.inMinutes, 45);
    expect(results['b']!.usageDuration?.inMinutes, 45);
    expect(results['deco']!.usageDuration?.inMinutes, 15);
  });

  test('a sidemount pair with no switches gets a SAC for both', () {
    final dive = makeDive([left, right]);
    final results = byId(
      service.calculateCylinderSac(dive: dive, profile: dive.profile),
    );

    expect(results['left']!.sacRate, isNotNull);
    expect(results['right']!.sacRate, isNotNull);
  });

  test('doubles logged as independents both get a SAC', () {
    const a = DiveTank(
      id: 'a',
      volume: 12,
      startPressure: 200,
      endPressure: 100,
    );
    const b = DiveTank(
      id: 'b',
      volume: 12,
      startPressure: 200,
      endPressure: 110,
    );
    final dive = makeDive([a, b]);
    final results = byId(
      service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
        gasSwitches: [switchTo('a', 0)],
      ),
    );

    expect(results['a']!.sacRate, isNotNull);
    expect(results['b']!.sacRate, isNotNull);
  });

  test(
    'a single cylinder gets a SAC when the switches name stale tank ids',
    () {
      const tank = DiveTank(
        id: 'current',
        volume: 15,
        startPressure: 197,
        endPressure: 82,
        gasMix: GasMix(o2: 31),
      );
      final dive = makeDive([tank]);
      final results = byId(
        service.calculateCylinderSac(
          dive: dive,
          profile: dive.profile,
          gasSwitches: [switchTo('stale-id', 0)],
        ),
      );

      expect(results['current']!.sacRate, isNotNull);
      expect(results['current']!.usageDuration?.inMinutes, 60);
    },
  );

  test('the back gas is breathed until the only recorded switch', () {
    const back = DiveTank(
      id: 'back',
      volume: 12,
      startPressure: 200,
      endPressure: 80,
    );
    const deco = DiveTank(
      id: 'deco',
      volume: 7,
      startPressure: 200,
      endPressure: 150,
      role: TankRole.deco,
      gasMix: GasMix(o2: 50),
    );
    final dive = makeDive([back, deco]);
    final results = byId(
      service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
        gasSwitches: [switchTo('deco', 40 * 60)],
      ),
    );

    expect(results['back']!.sacRate, isNotNull);
    expect(results['back']!.usageDuration?.inMinutes, 40);
    expect(results['deco']!.usageDuration?.inMinutes, 20);
  });

  test('a starting gas logged at the first sample is the starting gas', () {
    // The computer logs the travel stage it starts on at the first sample,
    // a few seconds in, and the switch to back gas later. The back gas was
    // not breathed in those first seconds.
    const back = DiveTank(
      id: 'back',
      volume: 12,
      startPressure: 200,
      endPressure: 100,
    );
    const travel = DiveTank(
      id: 'travel',
      volume: 7,
      startPressure: 200,
      endPressure: 150,
      role: TankRole.stage,
      gasMix: GasMix(o2: 32),
    );
    final dive = makeDive([back, travel]);
    final results = byId(
      service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
        gasSwitches: [switchTo('travel', 10), switchTo('back', 20 * 60)],
      ),
    );

    expect(results['back']!.usageDuration?.inMinutes, 40);
    expect(results['travel']!.usageDuration?.inMinutes, 20);
  });

  test('phase segments start on a starting gas logged at the first '
      'sample', () {
    const back = DiveTank(
      id: 'back',
      volume: 12,
      startPressure: 200,
      endPressure: 100,
    );
    const travel = DiveTank(
      id: 'travel',
      volume: 7,
      startPressure: 200,
      endPressure: 150,
      role: TankRole.stage,
      gasMix: GasMix(o2: 32),
    );
    final profile = [
      for (var t = 0; t <= 3600; t += 10)
        DiveProfilePoint(
          timestamp: t,
          depth: t < 300
              ? t / 10
              : t > 3300
              ? (3600 - t) / 10
              : 30,
        ),
    ];
    final segments = service.calculatePhaseSegments(
      profile: profile,
      tanks: const [back, travel],
      gasSwitches: [switchTo('travel', 10), switchTo('back', 20 * 60)],
    );

    expect(segments, isNotNull);
    expect(segments!.first.startTimestamp, 0);
    expect(segments.first.tankId, 'travel');
  });

  test('switches naming only stale tanks leave a recorded duration in '
      'force', () {
    const a = DiveTank(
      id: 'a',
      volume: 12,
      startPressure: 200,
      endPressure: 100,
      usageDuration: Duration(minutes: 20),
    );
    const b = DiveTank(
      id: 'b',
      volume: 12,
      startPressure: 200,
      endPressure: 100,
      role: TankRole.stage,
      usageDuration: Duration(minutes: 40),
    );
    final dive = makeDive([a, b]);
    final results = byId(
      service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
        gasSwitches: [switchTo('stale-id', 0)],
      ),
    );

    expect(results['a']!.usageDuration?.inMinutes, 20);
    expect(results['b']!.usageDuration?.inMinutes, 40);
  });

  test('a switch after the dive ends opens no window', () {
    const back = DiveTank(
      id: 'back',
      volume: 12,
      startPressure: 200,
      endPressure: 100,
    );
    const deco = DiveTank(
      id: 'deco',
      volume: 7,
      startPressure: 200,
      endPressure: 190,
      role: TankRole.deco,
      gasMix: GasMix(o2: 50),
    );
    final dive = makeDive([back, deco]);
    final results = byId(
      service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
        gasSwitches: [switchTo('back', 0), switchTo('deco', 61 * 60)],
      ),
    );

    expect(results['back']!.usageDuration?.inMinutes, 60);
    expect(results.containsKey('deco'), isFalse);
  });

  test('phase segments start on the back gas before a later first '
      'switch', () {
    const back = DiveTank(
      id: 'back',
      volume: 12,
      startPressure: 200,
      endPressure: 100,
    );
    const deco = DiveTank(
      id: 'deco',
      volume: 7,
      startPressure: 200,
      endPressure: 150,
      role: TankRole.deco,
      gasMix: GasMix(o2: 50),
    );
    final profile = [
      for (var t = 0; t <= 3600; t += 10)
        DiveProfilePoint(
          timestamp: t,
          depth: t < 300
              ? t / 10
              : t > 3300
              ? (3600 - t) / 10
              : 30,
        ),
    ];
    final segments = service.calculatePhaseSegments(
      profile: profile,
      tanks: const [back, deco],
      gasSwitches: [switchTo('deco', 40 * 60)],
    );

    expect(segments, isNotNull);
    expect(segments!.first.startTimestamp, 0);
    expect(segments.first.tankId, 'back');

    // With no switches at all, every phase is charged to the back gas.
    final unswitched = service.calculatePhaseSegments(
      profile: profile,
      tanks: const [deco, back],
    );
    expect(unswitched, isNotNull);
    expect(unswitched!.map((s) => s.tankId).toSet(), {'back'});
  });

  test('a switch after the dive ends leaves a recorded duration in '
      'force', () {
    const a = DiveTank(
      id: 'a',
      volume: 12,
      startPressure: 200,
      endPressure: 100,
      usageDuration: Duration(minutes: 20),
    );
    const b = DiveTank(
      id: 'b',
      volume: 12,
      startPressure: 200,
      endPressure: 100,
      role: TankRole.stage,
      usageDuration: Duration(minutes: 40),
    );
    final dive = makeDive([a, b]);
    final results = byId(
      service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
        gasSwitches: [switchTo('b', 61 * 60)],
      ),
    );

    expect(results['a']!.usageDuration?.inMinutes, 20);
    expect(results['b']!.usageDuration?.inMinutes, 40);
  });

  test('a stage with no recorded switch still has no SAC', () {
    // Without a switch nothing says how long the stage was breathed, and
    // spreading its drop over the whole dive would understate its rate.
    const back = DiveTank(
      id: 'back',
      volume: 12,
      startPressure: 200,
      endPressure: 80,
    );
    const stage = DiveTank(
      id: 'stage',
      volume: 7,
      startPressure: 200,
      endPressure: 150,
      role: TankRole.stage,
      gasMix: GasMix(o2: 50),
    );
    final dive = makeDive([back, stage]);
    final results = byId(
      service.calculateCylinderSac(dive: dive, profile: dive.profile),
    );

    expect(results['back']!.sacRate, isNotNull);
    expect(results.containsKey('stage'), isFalse);
  });

  test('a flat pressure series falls back to the logged start and end '
      'pressures', () {
    const tank = DiveTank(
      id: 'current',
      volume: 15,
      startPressure: 197,
      endPressure: 82,
    );
    final dive = makeDive([tank]);
    final results = byId(
      service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
        tankPressures: {
          'current': [
            for (var t = 0; t <= 3600; t += 600)
              TankPressurePoint(tankId: 'current', timestamp: t, pressure: 197),
          ],
        },
      ),
    );

    expect(results['current']!.sacRate, isNotNull);
  });
}
