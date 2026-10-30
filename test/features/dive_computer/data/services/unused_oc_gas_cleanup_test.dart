import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/database/database.dart' show DiveTank;
import 'package:submersion/features/dive_computer/data/services/unused_oc_gas_cleanup.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';

/// Issue #3668: the writers drop the cylinders the resolver marked as unused
/// open-circuit gases, and a re-parse never drops one the diver edited.
void main() {
  TankData tank(int index, {bool unused = false, String role = 'bailout'}) =>
      TankData(index: index, o2Percent: 21.0, role: role, unusedOcGas: unused);

  group('dropUnusedOcGases', () {
    test('removes marked tanks and reports their indices', () {
      final drop = dropUnusedOcGases([
        tank(0, role: 'diluent'),
        tank(1, role: 'oxygenSupply'),
        tank(2, unused: true, role: 'deco'),
        tank(3, unused: true),
      ]);

      expect(drop.tanks.map((t) => t.index), [0, 1]);
      expect(drop.dropped, {2, 3});
    });

    test('keeps a marked tank named in keep', () {
      final drop = dropUnusedOcGases(
        [
          tank(0, role: 'diluent'),
          tank(2, unused: true),
          tank(3, unused: true),
        ],
        keep: {3},
      );

      expect(drop.tanks.map((t) => t.index), [0, 3]);
      expect(drop.dropped, {2});
    });

    test('keeps every unmarked tank', () {
      final tanks = [tank(0), tank(1)];
      final drop = dropUnusedOcGases(tanks);

      expect(drop.tanks.map((t) => t.index), [0, 1]);
      expect(drop.dropped, isEmpty);
    });

    test('never leaves a dive with no cylinder', () {
      final tanks = [tank(2, unused: true), tank(3, unused: true)];
      final drop = dropUnusedOcGases(tanks);

      expect(drop.tanks.map((t) => t.index), [2, 3]);
      expect(drop.dropped, isEmpty);
    });
  });

  group('unusedOcGasEditedByDiver', () {
    final al80 = TankPresetEntity.fromBuiltIn(TankPresets.al80);
    final parsedAirBailout = tank(3, unused: true);

    DiveTank row({
      String role = 'bailout',
      double o2 = 21.0,
      double he = 0.0,
      double? volume,
      double? workingPressure,
      String? material,
      String? presetName,
      String? tankName,
      String? equipmentId,
      double? startPressure,
      double? endPressure,
      String? regulatorEquipmentId,
      String? extraRegulatorIds,
      String? tripCylinderId,
      String? passportId,
    }) => DiveTank(
      id: 't3',
      diveId: 'd1',
      o2Percent: o2,
      hePercent: he,
      tankOrder: 3,
      tankRole: role,
      sourceTankIndex: 3,
      volume: volume,
      workingPressure: workingPressure,
      tankMaterial: material,
      presetName: presetName,
      tankName: tankName,
      equipmentId: equipmentId,
      startPressure: startPressure,
      endPressure: endPressure,
      regulatorEquipmentId: regulatorEquipmentId,
      extraRegulatorIds: extraRegulatorIds,
      tripCylinderId: tripCylinderId,
      passportId: passportId,
    );

    test('a row the importer wrote is not edited', () {
      expect(unusedOcGasEditedByDiver(row(), parsedAirBailout), isFalse);
    });

    final edits = <String, DiveTank>{
      'a name': row(tankName: 'Stage'),
      'gear': row(equipmentId: 'g1'),
      'a start pressure': row(startPressure: 200.0),
      'an end pressure': row(endPressure: 120.0),
      'a regulator': row(regulatorEquipmentId: 'r1'),
      'extra regulators': row(extraRegulatorIds: '["r2"]'),
      'a trip cylinder': row(tripCylinderId: 'c1'),
      'a passport': row(passportId: 'p1'),
      'a different mix': row(o2: 32.0),
      'helium': row(he: 10.0),
      'a role the importer never gives it': row(role: 'stage'),
      'a size alone': row(volume: 11.1),
    };
    for (final MapEntry(key: what, value: edited) in edits.entries) {
      test('$what makes it edited', () {
        expect(
          unusedOcGasEditedByDiver(
            edited,
            parsedAirBailout,
            defaultPreset: al80,
          ),
          isTrue,
        );
      });
    }

    test('an empty extra-regulator list is not an edit', () {
      expect(
        unusedOcGasEditedByDiver(
          row(extraRegulatorIds: '[]'),
          parsedAirBailout,
        ),
        isFalse,
      );
    });

    test(
      'the back-gas role the pre-v1.8.1 importer gave Air is not an edit',
      () {
        expect(
          unusedOcGasEditedByDiver(row(role: 'backGas'), parsedAirBailout),
          isFalse,
        );
      },
    );

    test('the deco role the pre-v1.8.1 importer gave O2 is not an edit', () {
      expect(
        unusedOcGasEditedByDiver(
          row(role: 'deco', o2: 100.0),
          const TankData(index: 2, o2Percent: 100.0, role: 'bailout'),
        ),
        isFalse,
      );
    });

    DiveTank presetFilled({String presetName = 'al80'}) => row(
      role: 'backGas',
      volume: al80.volumeLiters,
      workingPressure: al80.workingPressureBar,
      material: al80.material.name,
      presetName: presetName,
    );

    test('a back-gas row filled from the default preset is not edited', () {
      expect(
        unusedOcGasEditedByDiver(
          presetFilled(),
          parsedAirBailout,
          defaultPreset: al80,
        ),
        isFalse,
      );
    });

    test('three of the four preset values is an edit', () {
      expect(
        unusedOcGasEditedByDiver(
          presetFilled(presetName: 'hp100'),
          parsedAirBailout,
          defaultPreset: al80,
        ),
        isTrue,
      );
    });

    test('preset values with no default preset to compare are an edit', () {
      expect(
        unusedOcGasEditedByDiver(presetFilled(), parsedAirBailout),
        isTrue,
      );
    });

    test('preset values on a row that is not back gas are an edit', () {
      final bailout = row(
        volume: al80.volumeLiters,
        workingPressure: al80.workingPressureBar,
        material: al80.material.name,
        presetName: 'al80',
      );
      expect(
        unusedOcGasEditedByDiver(
          bailout,
          parsedAirBailout,
          defaultPreset: al80,
        ),
        isTrue,
      );
    });
  });

  group('sortUnusedOcGasRows', () {
    DiveTank stored(String id, int? sourceIndex, {String role = 'bailout'}) =>
        DiveTank(
          id: id,
          diveId: 'd1',
          o2Percent: 21.0,
          hePercent: 0.0,
          tankOrder: 3,
          tankRole: role,
          sourceTankIndex: sourceIndex,
        );

    test('splits own rows into edited and importer-written', () {
      final sorted = sortUnusedOcGasRows(
        [tank(2, unused: true), tank(3, unused: true)],
        {2: stored('a', 2), 3: stored('b', 3, role: 'stage')},
      );

      expect(sorted.importers, {2});
      expect(sorted.edited, {3});
    });

    test('ignores a row reached through the order fallback', () {
      final sorted = sortUnusedOcGasRows(
        [tank(3, unused: true)],
        {3: stored('by-hand', null)},
      );

      expect(sorted.importers, isEmpty);
      expect(sorted.edited, isEmpty);
    });

    test('ignores cylinders that are not unused gases', () {
      final sorted = sortUnusedOcGasRows([tank(3)], {3: stored('a', 3)});

      expect(sorted.importers, isEmpty);
      expect(sorted.edited, isEmpty);
    });
  });
}
