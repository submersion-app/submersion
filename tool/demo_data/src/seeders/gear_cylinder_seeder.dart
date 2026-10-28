import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_configs/data/repositories/cylinder_config_repository.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/dive_computer/data/repositories/dive_computer_connection_repository.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/tank_presets/data/repositories/tank_preset_repository.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/weight_presets/data/repositories/weight_preset_repository.dart';

import '../story/story_plan.dart';
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
      (1, 'transmitter-right', 'Doubles', 'tech', 'twin', 24.0),
      (2, 'transmitter-cold', 'Lake single', 'ai', 'tank-12', 12.0),
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
          workingPressureBar: 232,
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
        id: 'demo-tank-preset-twin12',
        diverId: DemoSeedContext.diverId,
        name: 'twin12_steel',
        displayName: 'Twin 12 L steel',
        volumeLiters: 24,
        workingPressureBar: 232,
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
        (weightType: WeightType.belt, amountKg: 4, notes: '', label: 'Belt'),
      ],
    );
    await weights.createPreset(
      diverId: DemoSeedContext.diverId,
      displayName: 'Drysuit in the lake',
      entries: const [
        (weightType: WeightType.belt, amountKg: 6, notes: '', label: 'Belt'),
        (
          weightType: WeightType.trimWeights,
          amountKg: 2,
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
        volumeL: 24,
        workingPressureBar: 232,
        o2Percent: 21,
        hePercent: 35,
        createdAt: when,
        updatedAt: when,
      ),
      CylinderConfigItem(
        id: 'demo-config-item-2',
        configId: configId,
        tankRole: TankRole.deco,
        volumeL: 7,
        workingPressureBar: 207,
        o2Percent: 50,
        createdAt: when,
        updatedAt: when,
      ),
      CylinderConfigItem(
        id: 'demo-config-item-3',
        configId: configId,
        tankRole: TankRole.deco,
        volumeL: 7,
        workingPressureBar: 207,
        o2Percent: 100,
        createdAt: when,
        updatedAt: when,
      ),
    ]);

    final passports = CylinderPassportRepository();
    final fills = CylinderFillRepository();
    var n = 0;
    // Fills before home dives the cylinder was taken on, a few per year.
    for (final key in ['tank-12', 'twin', 'stage-1', 'stage-2']) {
      final passport = await passports.ensurePassportId(
        e[key]!,
        diverId: DemoSeedContext.diverId,
      );
      final doubles = key != 'tank-12';
      final dives = ctx.plan.dives
          .where(
            (d) =>
                d.destination.key == 'home' &&
                d.diveMode == 'oc' &&
                (d.tankCount > 1) == doubles &&
                (key != 'stage-2' || d.tankCount > 2) &&
                ctx.timeline.inUseOn(key, d.start),
          )
          .toList();
      for (var i = 0; i < dives.length; i += 4) {
        final d = dives[i];
        final at = ctx.timeline.homeDayOnOrBefore(
          d.start.subtract(const Duration(days: 1)),
        );
        await fills.create(
          CylinderFill(
            id: 'demo-fill-${n++}',
            passportId: passport,
            equipmentId: e[key],
            filledAt: at,
            o2Percent: switch (key) {
              'stage-1' => 50,
              'stage-2' => 100,
              'twin' => d.requiresCert == CertLevel.trimix ? 21 : 28,
              _ => 32,
            },
            hePercent: key == 'twin' && d.requiresCert == CertLevel.trimix
                ? 35
                : 0,
            pressureBar: key.startsWith('stage') ? 200 : 230,
            stationName: 'Club fill station',
            source: FillSource.manual,
            createdAt: at,
            updatedAt: at,
          ),
        );
      }
    }
  }
}
