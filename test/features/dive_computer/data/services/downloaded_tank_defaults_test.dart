import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/features/dive_computer/data/services/downloaded_tank_defaults.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';

/// Dive computers report cylinder pressure but almost never cylinder size, so
/// a downloaded tank has no volume and volumetric (L/min) SAC is unreachable
/// (issue #386). When the diver has opted in, the default tank preset fills
/// the physical cylinder attributes on the way in.
void main() {
  final al80 = TankPresetEntity.fromBuiltIn(TankPresets.al80);

  test('fills volume, working pressure, material and preset name', () {
    const tank = TankData(
      index: 0,
      o2Percent: 21.0,
      startPressure: 200.0,
      endPressure: 50.0,
    );

    final result = applyDefaultPresetToTanks([tank], al80);

    expect(result, hasLength(1));
    expect(result.first.volumeLiters, al80.volumeLiters);
    expect(result.first.workingPressure, al80.workingPressureBar);
    expect(result.first.material, TankMaterial.aluminum.name);
    expect(result.first.presetName, 'al80');
  });

  test('keeps a volume the computer reported', () {
    const tank = TankData(index: 0, o2Percent: 21.0, volumeLiters: 12.0);

    final result = applyDefaultPresetToTanks([tank], al80);

    expect(result.first.volumeLiters, 12.0);
    // A computer-reported size is not the preset, so it is not labeled as one.
    expect(result.first.presetName, isNull);
  });

  test('treats a zero volume as missing', () {
    const tank = TankData(index: 0, o2Percent: 21.0, volumeLiters: 0.0);

    final result = applyDefaultPresetToTanks([tank], al80);

    expect(result.first.volumeLiters, al80.volumeLiters);
  });

  test('never fabricates a fill pressure', () {
    // Unlike file imports, a download's pressures come from the transmitter;
    // a non-AI dive must stay pressureless rather than show a 200 bar start.
    const tank = TankData(index: 0, o2Percent: 32.0);

    final result = applyDefaultPresetToTanks([tank], al80);

    expect(result.first.startPressure, isNull);
    expect(result.first.endPressure, isNull);
  });

  test('preserves the fields that identify the cylinder', () {
    const tank = TankData(
      index: 2,
      o2Percent: 32.0,
      hePercent: 10.0,
      startPressure: 180.0,
      endPressure: 120.0,
      role: 'backGas',
    );

    final result = applyDefaultPresetToTanks([tank], al80);

    expect(result.first.index, 2);
    expect(result.first.o2Percent, 32.0);
    expect(result.first.hePercent, 10.0);
    expect(result.first.startPressure, 180.0);
    expect(result.first.endPressure, 120.0);
    expect(result.first.role, 'backGas');
  });

  test('fills a cylinder whose role was not inferred', () {
    const tank = TankData(index: 0, o2Percent: 21.0);

    final result = applyDefaultPresetToTanks([tank], al80);

    expect(result.first.volumeLiters, al80.volumeLiters);
  });

  test('leaves stage, deco and rebreather bottles alone', () {
    // The default tank describes the diver's usual back gas. Stamping its
    // size and label on a deco bottle or a CCR diluent would fabricate a
    // cylinder record and misconvert that segment's SAC.
    const bottles = [
      TankData(index: 1, o2Percent: 50.0, role: 'deco'),
      TankData(index: 2, o2Percent: 21.0, role: 'stage'),
      TankData(index: 3, o2Percent: 21.0, role: 'diluent'),
      TankData(index: 4, o2Percent: 100.0, role: 'oxygenSupply'),
    ];

    final result = applyDefaultPresetToTanks(bottles, al80);

    for (final tank in result) {
      expect(tank.volumeLiters, isNull, reason: 'role ${tank.role}');
      expect(tank.presetName, isNull, reason: 'role ${tank.role}');
    }
  });

  test('does not mutate the input list', () {
    const tank = TankData(index: 0, o2Percent: 21.0);
    final input = [tank];

    applyDefaultPresetToTanks(input, al80);

    expect(input.first.volumeLiters, isNull);
  });
}
