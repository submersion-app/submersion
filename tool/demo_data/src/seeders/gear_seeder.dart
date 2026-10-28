import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/features/equipment/data/services/equipment_transfer_service.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';

import '../story/story_plan.dart';
import 'gear_assemblies.dart';
import 'gear_catalog.dart';
import 'seed_context.dart';

/// The kit sets: name, items, and whether the set is the default, applied
/// automatically, or drawn as a figure.
const demoSets = <String, (String, List<String>)>{
  'warm': (
    'Warm water single',
    [
      'mask',
      'fins',
      'wetsuit-3',
      'rash-guard',
      'boots',
      'bcd-jacket',
      'reg-warm',
      'computer-rec',
      'smb',
      'spool',
      'knife',
    ],
  ),
  'lake': (
    'Cold lake drysuit',
    [
      'mask',
      'fins',
      'drysuit',
      'undersuit',
      'baselayer',
      'socks',
      'dry-gloves',
      'hood',
      'reg-cold',
      'tank-12',
      'weights',
      'light-primary',
      'computer-ai',
      'smb',
      'spool',
      'knife',
    ],
  ),
  'tech': (
    'Tech doubles',
    [
      'mask-2',
      'fins-jet',
      'drysuit',
      'undersuit',
      'backplate',
      'harness',
      'wing',
      'tank-bands',
      'twin',
      'reg-right',
      'reg-left',
      'reg-stage-1',
      'stage-1',
      'computer-tech',
      'computer-ai',
      'light-canister',
      'light-backup-1',
      'light-backup-2',
      'reel',
      'wetnotes',
      'pocket',
      'smb',
      'knife',
    ],
  ),
  'ccr': (
    'Rebreather',
    [
      'mask-2',
      'fins-jet',
      'drysuit',
      'rebreather',
      'ccr-o2',
      'ccr-dil',
      'stage-1',
      'reg-stage-bailout',
      'computer-tech',
      'light-canister',
      'light-backup-1',
      'reel',
    ],
  ),
  'scooter': ('Scooter', ['dpv', 'reel', 'light-canister']),
  'camera': (
    'Camera',
    [
      'camera',
      'housing',
      'port',
      'tray',
      'arms',
      'float-arms',
      'strobe-left',
      'strobe-right',
      'video-light',
    ],
  ),
};

/// The demo diver's kit and what the app keeps about it: every item with
/// its attributes, the regulators' parts, what is fitted inside the
/// rebreather and the scooter, the kit sets, and where things are stored.
class GearSeeder implements DemoSeeder {
  @override
  String get name => 'gear';

  @override
  Future<void> seed(DemoSeedContext ctx) async {
    final repo = EquipmentRepository();
    for (final g in demoGear) {
      ctx.equipment[g.key] = 'demo-gear-${g.key}';
    }
    final installs = {for (final i in demoInstalls) i.childKey: i};
    for (final g in demoGear) {
      final id = ctx.equipment[g.key]!;
      final bought = ctx.timeline.boughtOn(g.key);
      final install = installs[g.key];
      var order = 0;
      EquipmentAttribute attr(String key, {String? text, double? number}) =>
          EquipmentAttribute(
            id: 'demo-attr-${g.key}-$key',
            equipmentId: id,
            key: key,
            isCustom: false,
            valueText: text,
            valueNum: number,
            sortOrder: order++,
          );
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
          status: g.currentStatus,
          purchaseDate: bought,
          purchasePrice: bought == null ? null : 40.0 + g.key.length * 35,
          serviceIntervalDays: g.serviceIntervalDays,
          parentEquipmentId: install == null
              ? null
              : ctx.equipment[install.parentKey],
          attributes: [
            if (g.size != null) attr(EquipmentAttrKeys.size, text: g.size),
            for (final MapEntry(:key, :value) in g.attributes.entries)
              value is num
                  ? attr(key, number: value.toDouble())
                  : attr(key, text: '$value'),
            if (install?.slot != null)
              attr(
                EquipmentAttrKeys.cellSlot,
                number: install!.slot!.toDouble(),
              ),
            if (install != null && bought != null)
              attr(
                EquipmentAttrKeys.installedDate,
                number: bought.millisecondsSinceEpoch.toDouble(),
              ),
          ],
        ),
        [if (g.travel) ctx.tags['Travel kit']!],
      );
    }

    final components = EquipmentComponentRepository();
    for (final a in demoAssemblies) {
      for (final (child, role) in a.parts) {
        await components.addComponent(
          parentId: ctx.equipment[a.parentKey]!,
          componentId: ctx.equipment[child]!,
          role: role,
        );
      }
    }

    await _sets(ctx);
    DateTime bought(int dive) {
      final d = ctx.plan.dives[dive - 1].start;
      return ctx.timeline.homeDayOnOrBefore(
        DateTime(d.year, d.month, d.day - 7),
      );
    }

    await _storageAndService(ctx, bought);
  }

  Future<void> _sets(DemoSeedContext ctx) async {
    final sets = EquipmentSetRepository();
    for (final MapEntry(key: key, value: (name, items)) in demoSets.entries) {
      final id = 'demo-set-$key';
      ctx.equipmentSets[key] = id;
      // A set is put together once all its items are owned.
      final created = items
          .map((k) => ctx.timeline.boughtOn(k)!)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      await sets.createSet(
        EquipmentSet(
          id: id,
          diverId: DemoSeedContext.diverId,
          name: name,
          equipmentIds: [for (final k in items) ctx.equipment[k]!],
          isDefault: key == 'warm',
          autoApplyOnComputerImport: key == 'lake',
          showFigure: key == 'tech',
          createdAt: created,
          updatedAt: created,
        ),
      );
    }
    await sets.setAsDefault(
      ctx.equipmentSets['warm']!,
      diverId: DemoSeedContext.diverId,
    );
    final home = ctx.plan.sites.firstWhere(
      (s) => ctx.plan.dives.any(
        (d) => d.siteId == s.id && d.destination.key == 'home',
      ),
    );
    final created = ctx.timeline.boughtOn('drysuit')!;
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
      movedAt: bought(ctx.plan.milestones[StoryMilestone.techStart]! + 10),
    );
    await moves.recordMoves(
      equipmentIds: [e['reg-cold']!],
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
      equipmentId: e['reg-cold']!,
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
      equipmentIds: [e['bcd-jacket']!],
      toDiverId: DemoSeedContext.partnerId,
      actingDiverId: DemoSeedContext.diverId,
    );
  }
}
