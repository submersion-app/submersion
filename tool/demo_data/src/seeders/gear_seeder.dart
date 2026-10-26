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
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/data/services/equipment_transfer_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/tank_presets/data/repositories/tank_preset_repository.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/weight_presets/data/repositories/weight_preset_repository.dart';

import 'gear_catalog.dart';
import 'seed_context.dart';

/// The demo diver's kit and everything the app keeps about it: sets, where
/// it is stored, service history, computers and transmitters, cylinders with
/// passports and fills, presets.
class GearSeeder implements DemoSeeder {
  @override
  String get name => 'gear';

  @override
  Future<void> seed(DemoSeedContext ctx) async {
    final repo = EquipmentRepository();
    DateTime bought(int dive) {
      final d = ctx.plan.dives[dive - 1].start;
      return DateTime(d.year, d.month, d.day - 7);
    }

    for (final g in demoGear) {
      final id = 'demo-gear-${g.key}';
      ctx.equipment[g.key] = id;
      await repo.createEquipmentWithTags(
        EquipmentItem(
          id: id,
          diverId: DemoSeedContext.diverId,
          name: g.name,
          type: g.type,
          brand: g.brand,
          model: g.model,
          serialNumber:
              'DEMO-${g.key.toUpperCase()}-${1000 + g.key.length * 37}',
          status: g.status,
          purchaseDate: bought(g.boughtAtDive),
          purchasePrice: 80.0 + g.key.length * 45,
          serviceIntervalDays: g.serviceIntervalDays,
          attributes: [
            if (g.size != null)
              EquipmentAttribute(
                id: 'demo-attr-${g.key}-size',
                equipmentId: id,
                key: 'Size',
                isCustom: true,
                valueText: g.size,
              ),
          ],
        ),
        [if (g.travel) ctx.tags['Travel kit']!],
      );
    }

    final components = EquipmentComponentRepository();
    for (final (child, role) in [
      ('first-stage', 'first stage'),
      ('second-primary', 'primary'),
      ('second-octo', 'octopus'),
    ]) {
      await components.addComponent(
        parentId: ctx.equipment['reg']!,
        componentId: ctx.equipment[child]!,
        role: role,
      );
    }
    for (final cell in ['o2-cell-1', 'o2-cell-2', 'o2-cell-3']) {
      await components.addComponent(
        parentId: ctx.equipment['rebreather']!,
        componentId: ctx.equipment[cell]!,
        role: 'cell',
      );
    }

    await _sets(ctx);
    await _computers(ctx, bought);
    await _storageAndService(ctx, bought);
    await _cylinders(ctx, bought);
  }

  Future<void> _sets(DemoSeedContext ctx) async {
    final sets = EquipmentSetRepository();
    final created = ctx.plan.dives.first.start;
    final e = ctx.equipment;
    final defs = <String, (String, List<String>)>{
      'warm': (
        'Warm water',
        ['mask', 'fins', 'wetsuit', 'reg', 'bcd', 'computer-rec', 'smb'],
      ),
      'lake': (
        'Lake, drysuit',
        [
          'mask',
          'fins',
          'drysuit',
          'undersuit',
          'hood',
          'gloves',
          'reg',
          'tank-12',
          'weights',
          'light',
          'computer-rec',
        ],
      ),
      'tech': (
        'Technical doubles',
        [
          'mask',
          'fins',
          'drysuit',
          'wing',
          'backplate',
          'twin',
          'stage-1',
          'stage-2',
          'computer-tech',
          'light',
          'reel',
          'smb',
        ],
      ),
      'ccr': (
        'Rebreather',
        [
          'mask',
          'fins',
          'drysuit',
          'rebreather',
          'ccr-o2',
          'ccr-dil',
          'stage-1',
          'computer-tech',
          'light',
        ],
      ),
    };
    for (final MapEntry(key: key, value: (name, items)) in defs.entries) {
      final id = 'demo-set-$key';
      ctx.equipmentSets[key] = id;
      await sets.createSet(
        EquipmentSet(
          id: id,
          diverId: DemoSeedContext.diverId,
          name: name,
          equipmentIds: [for (final k in items) e[k]!],
          isDefault: key == 'warm',
          createdAt: created,
          updatedAt: created,
        ),
      );
    }
    final home = ctx.plan.sites.firstWhere(
      (s) => ctx.plan.dives.any(
        (d) => d.siteId == s.id && d.destination.key == 'home',
      ),
    );
    await sets.addGeofence(
      EquipmentSetGeofence(
        id: 'demo-geofence-lake',
        setId: ctx.equipmentSets['lake']!,
        latitude: home.latitude,
        longitude: home.longitude,
        radiusMeters: 30000,
        label: 'Home lakes',
        createdAt: created,
        updatedAt: created,
      ),
    );
  }

  Future<void> _computers(
    DemoSeedContext ctx,
    DateTime Function(int) bought,
  ) async {
    final computers = DiveComputerRepository();
    final connections = DiveComputerConnectionRepository();
    for (final (key, gearKey, model, at, kind) in [
      ('rec', 'computer-rec', 'Peregrine', 1, DiveComputerConnectionKind.ble),
      (
        'tech',
        'computer-tech',
        'Perdix 2',
        130,
        DiveComputerConnectionKind.usb,
      ),
    ]) {
      final id = 'demo-computer-$key';
      ctx.computers[key] = id;
      final when = bought(at);
      await computers.createComputer(
        DiveComputer(
          id: id,
          diverId: DemoSeedContext.diverId,
          name: 'Shearwater $model',
          manufacturer: 'Shearwater',
          model: model,
          serialNumber: key == 'rec' ? 'A1B2C3D4' : 'E5F6A7B8',
          firmwareVersion: key == 'rec' ? '92' : '84',
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
    final transmitters = TransmitterRepository();
    final when = bought(130);
    for (final (n, role) in [(1, TankRole.backGas), (2, TankRole.deco)]) {
      await transmitters.create(
        Transmitter(
          id: 'demo-transmitter-$n',
          label: n == 1 ? 'Back gas' : 'Stage',
          transmitterSerial: n == 1 ? '1A2B3C' : '4D5E6F',
          diveComputerId: ctx.computers['tech'],
          role: role,
          volumeL: n == 1 ? 24 : 7,
          workingPressureBar: n == 1 ? 232 : 207,
          equipmentId: ctx.equipment['transmitter-$n'],
          createdAt: when,
          updatedAt: when,
        ),
      );
    }
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

  Future<void> _storageAndService(
    DemoSeedContext ctx,
    DateTime Function(int) bought,
  ) async {
    final e = ctx.equipment;
    final locations = EquipmentLocationRepository();
    final garage = await locations.createLocation(
      diverId: DemoSeedContext.diverId,
      name: 'Garage shelf',
      kind: EquipmentLocationKind.storage,
    );
    final shop = await locations.createLocation(
      diverId: DemoSeedContext.diverId,
      name: 'Regulator service shop',
      kind: EquipmentLocationKind.serviceShop,
    );
    final moves = EquipmentLocationMoveRepository();
    await moves.recordMoves(
      equipmentIds: [
        for (final k in ['drysuit', 'tank-12', 'twin', 'weights']) e[k]!,
      ],
      locationId: garage.id,
      movedAt: bought(140),
    );
    await moves.recordMoves(
      equipmentIds: [e['reg']!],
      locationId: shop.id,
      movedAt: DateTime(ctx.anchor.year, ctx.anchor.month, ctx.anchor.day - 20),
      note: 'Annual service',
    );

    final observations = EquipmentObservationRepository();
    final lastLake = ctx.plan.dives.lastWhere(
      (d) => d.destination.key == 'home',
    );
    await observations.create(
      equipmentId: e['drysuit']!,
      diverId: DemoSeedContext.diverId,
      observedAt: lastLake.start,
      status: ObservationStatus.issue,
      issueTags: const [ObservationTag.leak],
      note: 'Damp left wrist after the dive.',
    );
    await observations.create(
      equipmentId: e['reg']!,
      diverId: DemoSeedContext.diverId,
      observedAt: lastLake.start,
      status: ObservationStatus.ok,
    );

    await EquipmentShareRepository().setShares(
      equipmentId: e['fins']!,
      diverIds: {DemoSeedContext.partnerId},
      actingDiverId: DemoSeedContext.diverId,
    );
    await EquipmentTransferService().transfer(
      equipmentIds: [e['old-bcd']!],
      toDiverId: DemoSeedContext.partnerId,
      actingDiverId: DemoSeedContext.diverId,
    );

    final records = ServiceRecordRepository();
    final first = ctx.plan.dives.first.start;
    for (var year = 1; year < 6; year++) {
      final at = DateTime(first.year + year, first.month, 15);
      if (at.isAfter(ctx.anchor)) break;
      await records.createRecord(
        ServiceRecord(
          id: 'demo-service-reg-$year',
          equipmentId: e['reg']!,
          serviceCategory: ServiceCategory.annual,
          serviceKindId: 'regulator-service',
          serviceDate: at,
          provider: 'Regulator service shop',
          cost: 95,
          currency: 'EUR',
          nextServiceDue: DateTime(at.year + 1, at.month, at.day),
          notes: 'Annual service, new seats and O-rings.',
          createdAt: at,
          updatedAt: at,
        ),
      );
    }
    final seals = DateTime(ctx.anchor.year, ctx.anchor.month - 10, 4);
    await records.createRecord(
      ServiceRecord(
        id: 'demo-service-drysuit',
        equipmentId: e['drysuit']!,
        serviceCategory: ServiceCategory.repair,
        serviceKindId: 'drysuit-seals',
        serviceDate: seals,
        provider: 'Drysuit repair',
        cost: 140,
        currency: 'EUR',
        notes: 'New latex wrist seals.',
        createdAt: seals,
        updatedAt: seals,
      ),
    );
    final schedules = ServiceScheduleRepository();
    await schedules.createSchedule(
      ServiceSchedule(
        id: 'demo-schedule-reg',
        equipmentId: e['reg']!,
        serviceKindId: 'regulator-service',
        intervalDays: 365,
        enabled: true,
        createdAt: first,
        updatedAt: first,
      ),
    );
    final ccrAt = bought(285);
    await schedules.createSchedule(
      ServiceSchedule(
        id: 'demo-schedule-ccr',
        equipmentId: e['rebreather']!,
        serviceKindId: 'o2-cell-replacement',
        intervalDays: 365,
        anchorDate: ccrAt,
        enabled: true,
        createdAt: ccrAt,
        updatedAt: ccrAt,
      ),
    );
  }

  Future<void> _cylinders(
    DemoSeedContext ctx,
    DateTime Function(int) bought,
  ) async {
    final e = ctx.equipment;
    final configs = CylinderConfigRepository();
    final configId = await configs.createConfig(
      diverId: DemoSeedContext.diverId,
      equipmentId: e['twin'],
      name: 'Doubles with two stages',
      description: 'Trimix back gas, 50% and oxygen to decompress.',
    );
    final when = bought(200);
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
    for (final key in ['tank-12', 'twin', 'stage-1']) {
      final passport = await passports.ensurePassportId(
        e[key]!,
        diverId: DemoSeedContext.diverId,
      );
      final dives = ctx.plan.dives
          .where(
            (d) =>
                d.destination.key == 'home' && ctx.plan.dives.indexOf(d) >= 30,
          )
          .toList();
      for (final d
          in dives.where((d) => dives.indexOf(d) % 6 == n % 6).take(8)) {
        final at = d.start.subtract(const Duration(days: 1));
        await fills.create(
          CylinderFill(
            id: 'demo-fill-${n++}',
            passportId: passport,
            equipmentId: e[key],
            filledAt: at,
            o2Percent: key == 'stage-1' ? 50 : (key == 'twin' ? 21 : 32),
            hePercent: key == 'twin' && d.number > 203 ? 35 : 0,
            pressureBar: key == 'stage-1' ? 200 : 230,
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
