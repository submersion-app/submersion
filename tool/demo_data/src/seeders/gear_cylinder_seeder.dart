import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_configs/data/repositories/cylinder_config_repository.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/dive_computer/data/repositories/dive_computer_connection_repository.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/tank_presets/data/repositories/tank_preset_repository.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/weight_presets/data/repositories/weight_preset_repository.dart';

import 'seed_context.dart';

const _ble = DiveComputerConnectionKind.ble;
const _usb = DiveComputerConnectionKind.usb;

/// The serial each transmitter reports, by gear key: the dive tanks a
/// transmitter read carry the same serial.
const transmitterSerials = {
  'transmitter-right': '1A2B3C',
  'transmitter-cold': '4D5E6F',
};

/// The diver's dive computers and transmitters, cylinder set-ups, cylinder
/// passports with their fills, and tank and weight presets.
class GearCylinderSeeder implements DemoSeeder {
  @override
  String get name => 'computers, transmitters and cylinders';

  @override
  Future<void> seed(DemoSeedContext ctx) async {
    await _computers(ctx);
    await _cylinders(ctx);
  }

  Future<void> _computers(DemoSeedContext ctx) async {
    final computers = DiveComputerRepository();
    final connections = DiveComputerConnectionRepository();
    for (final (key, gearKey, model, serial, firmware, kind) in [
      ('rec', 'computer-rec', 'Peregrine', 'A1B2C3D4', '92', _ble),
      ('ai', 'computer-ai', 'Teric', 'C9D8E7F6', '88', _ble),
      ('tech', 'computer-tech', 'Perdix 2', 'E5F6A7B8', '84', _usb),
    ]) {
      final id = 'demo-computer-$key';
      ctx.computers[key] = id;
      final when = ctx.timeline.boughtOn(gearKey)!;
      await computers.createComputer(
        DiveComputer(
          id: id,
          diverId: DemoSeedContext.diverId,
          name: 'Shearwater $model',
          manufacturer: 'Shearwater',
          model: model,
          serialNumber: serial,
          firmwareVersion: firmware,
          equipmentId: ctx.equipment[gearKey],
          createdAt: when,
          updatedAt: when,
        ),
      );
      await connections.recordConnection(
        computerId: id,
        kind: kind,
        usedAt: ctx.anchor,
      );
    }
    // One transmitter on each regulator that has one: the doubles' right post
    // reports to the technical computer, the cold-water single to the
    // air-integrated wrist computer.
    final transmitters = TransmitterRepository();
    for (final (n, gearKey, label, computer, cylinder, volume) in [
      (1, 'transmitter-right', 'Doubles', 'tech', 'twin', 25.8),
      (2, 'transmitter-cold', 'Home single', 'ai', 'tank-12', 12.9),
    ]) {
      final when = ctx.timeline.boughtOn(gearKey)!;
      await transmitters.create(
        Transmitter(
          id: 'demo-transmitter-$n',
          diverId: DemoSeedContext.diverId,
          label: label,
          transmitterSerial: transmitterSerials[gearKey],
          diveComputerId: ctx.computers[computer],
          role: TankRole.backGas,
          volumeL: volume,
          workingPressureBar: 237.3,
          material: TankMaterial.steel,
          // The transmitter item, and the cylinder it lives on: the
          // registry links each tank the serial read to that cylinder.
          transmitterEquipmentId: ctx.equipment[gearKey],
          equipmentId: ctx.equipment[cylinder],
          isConfigured: true,
          createdAt: when,
          updatedAt: when,
        ),
      );
    }
    final when = ctx.timeline.boughtOn('twin')!;
    final presets = TankPresetRepository();
    await presets.createPreset(
      TankPresetEntity(
        id: 'demo-tank-preset-double-hp100',
        diverId: DemoSeedContext.diverId,
        name: 'double_hp100',
        displayName: 'Double HP100s',
        volumeLiters: 25.8,
        workingPressureBar: 237.3,
        material: TankMaterial.steel,
        createdAt: when,
        updatedAt: when,
      ),
    );
    final weights = WeightPresetRepository();
    await weights.createPreset(
      diverId: DemoSeedContext.diverId,
      displayName: 'Warm water',
      entries: const [
        (
          weightType: WeightType.belt,
          amountKg: 8 * _kgPerLb,
          notes: '',
          label: 'Belt',
        ),
      ],
    );
    await weights.createPreset(
      diverId: DemoSeedContext.diverId,
      displayName: 'Drysuit at home',
      entries: const [
        (
          weightType: WeightType.belt,
          amountKg: 14 * _kgPerLb,
          notes: '',
          label: 'Belt',
        ),
        (
          weightType: WeightType.trimWeights,
          amountKg: 4 * _kgPerLb,
          notes: 'Tank band',
          label: 'Trim',
        ),
      ],
    );
  }

  Future<void> _cylinders(DemoSeedContext ctx) async {
    final e = ctx.equipment;
    final configs = CylinderConfigRepository();
    final configId = await configs.createConfig(
      diverId: DemoSeedContext.diverId,
      equipmentId: e['twin'],
      name: 'Doubles with two stages',
      description: 'Trimix back gas, 50% and oxygen to decompress.',
    );
    final when = ctx.timeline.boughtOn('stage-2')!;
    await configs.saveItems(configId, [
      CylinderConfigItem(
        id: 'demo-config-item-1',
        configId: configId,
        tankRole: TankRole.backGas,
        volumeL: 25.8,
        workingPressureBar: 237.3,
        o2Percent: 21,
        hePercent: 35,
        createdAt: when,
        updatedAt: when,
      ),
      CylinderConfigItem(
        id: 'demo-config-item-2',
        configId: configId,
        tankRole: TankRole.deco,
        volumeL: 5.7,
        workingPressureBar: 207,
        o2Percent: 50,
        createdAt: when,
        updatedAt: when,
      ),
      CylinderConfigItem(
        id: 'demo-config-item-3',
        configId: configId,
        tankRole: TankRole.deco,
        volumeL: 5.7,
        workingPressureBar: 207,
        o2Percent: 100,
        createdAt: when,
        updatedAt: when,
      ),
    ]);

    final passports = CylinderPassportRepository();
    // Each owned cylinder carries a passport; its fills are written with the
    // dives they were filled for.
    for (final key in ['tank-12', 'twin', 'stage-1', 'stage-2']) {
      await passports.ensurePassportId(
        e[key]!,
        diverId: DemoSeedContext.diverId,
      );
    }
  }
}

/// Kilograms in a pound: the presets hold whole pounds of lead.
const _kgPerLb = 0.45359237;
