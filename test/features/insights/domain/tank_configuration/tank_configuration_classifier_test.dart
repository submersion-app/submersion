import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/insights/domain/tank_configuration/tank_configuration.dart';
import 'package:submersion/features/insights/domain/tank_configuration/tank_configuration_classifier.dart';

/// Issue #3421: every dive sorts into one base configuration, read only from
/// its existing tanks, and counts under each extra that applies.
void main() {
  var nextId = 0;
  DiveTank tank(
    TankRole role, {
    double o2 = 21.0,
    double he = 0.0,
    double? volume,
    String? name,
    String? presetName,
    double? start,
    double? end,
  }) => DiveTank(
    id: 't${nextId++}',
    role: role,
    gasMix: GasMix(o2: o2, he: he),
    volume: volume,
    name: name,
    presetName: presetName,
    startPressure: start,
    endPressure: end,
  );

  TankConfigurationResult classify(
    List<DiveTank> tanks, {
    DiveMode mode = DiveMode.oc,
    List<({String tankId, int timestamp})> switches = const [],
    bool hasProfile = true,
  }) => classifyTankConfiguration(
    TankConfigurationDive(
      diveMode: mode,
      tanks: tanks,
      gasSwitches: switches,
      hasProfile: hasProfile,
    ),
  );

  group('base configuration', () {
    test('no tanks', () {
      final r = classify(const []);
      expect(r.base, TankBaseConfiguration.noTanks);
      expect(r.extras, isEmpty);
    });

    test('ccr mode with untagged tanks is a rebreather', () {
      final r = classify([tank(TankRole.backGas)], mode: DiveMode.ccr);
      expect(r.base, TankBaseConfiguration.rebreather);
    });

    test('oc mode with a diluent tank is a rebreather', () {
      final r = classify([tank(TankRole.diluent)]);
      expect(r.base, TankBaseConfiguration.rebreather);
    });

    test('diluent plus sidemountLeft is a rebreather (precedence)', () {
      final r = classify([
        tank(TankRole.diluent),
        tank(TankRole.sidemountLeft),
      ]);
      expect(r.base, TankBaseConfiguration.rebreather);
    });

    test('one sidemountLeft tank is sidemount', () {
      final r = classify([tank(TankRole.sidemountLeft)]);
      expect(r.base, TankBaseConfiguration.sidemount);
    });

    test('sidemount pair plus a stage is sidemount with stages', () {
      final r = classify([
        tank(TankRole.sidemountLeft),
        tank(TankRole.sidemountRight),
        tank(TankRole.stage, o2: 50),
      ]);
      expect(r.base, TankBaseConfiguration.sidemount);
      expect(r.extras, {TankConfigurationExtra.stages});
    });

    test('two backGas at 21 and 21.3 are twin backmount', () {
      final r = classify([
        tank(TankRole.backGas),
        tank(TankRole.backGas, o2: 21.3),
      ]);
      expect(r.base, TankBaseConfiguration.twinBackmount);
    });

    test('two backGas on air and EAN32 are single backmount', () {
      final r = classify([
        tank(TankRole.backGas),
        tank(TankRole.backGas, o2: 32),
      ]);
      expect(r.base, TankBaseConfiguration.singleBackmount);
    });

    test('one backGas of 24 L is twin backmount', () {
      final r = classify([tank(TankRole.backGas, volume: 24)]);
      expect(r.base, TankBaseConfiguration.twinBackmount);
    });

    test('one backGas of 18 L is single backmount', () {
      final r = classify([tank(TankRole.backGas, volume: 18)]);
      expect(r.base, TankBaseConfiguration.singleBackmount);
    });

    test('one backGas with no volume is single backmount', () {
      final r = classify([tank(TankRole.backGas)]);
      expect(r.base, TankBaseConfiguration.singleBackmount);
    });

    test('only a stage tank is other with stages', () {
      final r = classify([tank(TankRole.stage)]);
      expect(r.base, TankBaseConfiguration.other);
      expect(r.extras, {TankConfigurationExtra.stages});
    });

    test('only a pony is other with no extras', () {
      final r = classify([tank(TankRole.pony)]);
      expect(r.base, TankBaseConfiguration.other);
      expect(r.extras, isEmpty);
    });
  });

  group('looksLikeTwinSet', () {
    for (final name in [
      'Twin 12',
      'D12',
      'd7',
      'Doppel 10',
      'Doubles 12',
      '2x12',
      '2 x 7',
      '2×8.5',
      'Manifold 12',
    ]) {
      test('name "$name" is a twin set', () {
        expect(looksLikeTwinSet(tank(TankRole.backGas, name: name)), isTrue);
      });
    }

    for (final preset in ['twin_12', 'd12']) {
      test('preset "$preset" with no name is a twin set', () {
        expect(
          looksLikeTwinSet(tank(TankRole.backGas, presetName: preset)),
          isTrue,
        );
      });
    }

    for (final name in [
      'AL80',
      'HP100',
      'Steel 12',
      'Dive 12',
      'D',
      'D123',
      'ED12',
      // Volume by pressure, the usual European single label.
      'Steel 12x232',
      'Faber 12x300',
      '12 x 300',
      '232x12',
    ]) {
      test('name "$name" is not a twin set', () {
        expect(looksLikeTwinSet(tank(TankRole.backGas, name: name)), isFalse);
      });
    }

    test('no name and no preset is not a twin set', () {
      expect(looksLikeTwinSet(tank(TankRole.backGas)), isFalse);
    });
  });

  group('extras', () {
    test('a deco tank adds deco gas', () {
      final r = classify([tank(TankRole.backGas), tank(TankRole.deco, o2: 50)]);
      expect(r.extras, contains(TankConfigurationExtra.decoGas));
    });

    test('a deco gas switched to is multi-gas', () {
      final back = tank(TankRole.backGas, start: 200, end: 60);
      final deco = tank(TankRole.deco, o2: 50);
      final r = classify(
        [back, deco],
        switches: [(tankId: deco.id, timestamp: 1800)],
      );
      expect(r.extras, contains(TankConfigurationExtra.multiGas));
    });

    test('an untouched air and EAN32 download is not multi-gas', () {
      final r = classify([
        tank(TankRole.backGas),
        tank(TankRole.backGas, o2: 32),
      ]);
      expect(r.extras, isNot(contains(TankConfigurationExtra.multiGas)));
    });

    test('a hand-logged dive with two gases is multi-gas', () {
      final r = classify([
        tank(TankRole.backGas),
        tank(TankRole.backGas, o2: 32),
      ], hasProfile: false);
      expect(r.extras, contains(TankConfigurationExtra.multiGas));
    });

    test('a sidemount pair on one gas is not multi-gas', () {
      final r = classify([
        tank(TankRole.sidemountLeft, o2: 32, start: 200, end: 100),
        tank(TankRole.sidemountRight, o2: 32, start: 200, end: 110),
      ]);
      expect(r.extras, isNot(contains(TankConfigurationExtra.multiGas)));
    });

    test('a ccr diluent and oxygen supply are not multi-gas', () {
      final r = classify([
        tank(TankRole.diluent, start: 200, end: 150),
        tank(TankRole.oxygenSupply, o2: 100, start: 200, end: 120),
      ], mode: DiveMode.ccr);
      expect(r.extras, isNot(contains(TankConfigurationExtra.multiGas)));
    });

    test('EAN32 and 32.4 both breathed are one gas', () {
      final r = classify([
        tank(TankRole.backGas, o2: 32, start: 200, end: 100),
        tank(TankRole.stage, o2: 32.4, start: 200, end: 120),
      ]);
      expect(r.extras, isNot(contains(TankConfigurationExtra.multiGas)));
    });

    test('EAN32 and EAN33 both breathed are multi-gas', () {
      final r = classify([
        tank(TankRole.backGas, o2: 32, start: 200, end: 100),
        tank(TankRole.stage, o2: 33, start: 200, end: 120),
      ]);
      expect(r.extras, contains(TankConfigurationExtra.multiGas));
    });
  });

  test('fromDives counts base configurations and extras', () {
    TankConfigurationDive d(List<DiveTank> tanks) => TankConfigurationDive(
      diveMode: DiveMode.oc,
      tanks: tanks,
      hasProfile: true,
    );
    final stats = TankConfigurationStats.fromDives([
      d([tank(TankRole.sidemountLeft), tank(TankRole.sidemountRight)]),
      d([tank(TankRole.sidemountLeft), tank(TankRole.stage, o2: 50)]),
      d([tank(TankRole.backGas)]),
      d(const []),
    ]);
    expect(stats.totalDives, 4);
    expect(stats.baseCounts, {
      TankBaseConfiguration.sidemount: 2,
      TankBaseConfiguration.singleBackmount: 1,
      TankBaseConfiguration.noTanks: 1,
    });
    expect(stats.extraCounts, {TankConfigurationExtra.stages: 1});
  });
}
