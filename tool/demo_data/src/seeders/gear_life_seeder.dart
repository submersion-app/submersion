import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/features/equipment/data/services/equipment_transfer_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';

import '../story/story_plan.dart';
import 'dive_kit.dart';
import 'gear_catalog.dart';
import 'seed_context.dart';

/// Kit kept at home rather than travelling.
const _homeKit = [
  'drysuit',
  'undersuit',
  'tank-12',
  'twin',
  'stage-1',
  'stage-2',
  'weights',
  'rebreather',
  'dpv',
];

/// Where the kit lives and moves, who has it, and what the diver noticed
/// about it: stored at home, packed for the last trip, the cold-water
/// regulator in for service, the travel regulator lent to a buddy, the jacket
/// BCD sold to the partner, fins shared with them, and routine checks.
class GearLifeSeeder implements DemoSeeder {
  @override
  String get name => 'gear locations, loans and checks';

  @override
  Future<void> seed(DemoSeedContext ctx) async {
    final e = ctx.equipment;
    final t = ctx.timeline;
    final locations = EquipmentLocationRepository();
    Future<EquipmentLocation> place(String name, EquipmentLocationKind kind) =>
        locations.createLocation(
          diverId: DemoSeedContext.diverId,
          name: name,
          kind: kind,
        );
    final garage = await place('Garage shelf', EquipmentLocationKind.storage);
    final bag = await place('Travel bag', EquipmentLocationKind.storage);
    final shop = await place(
      'Regulator service shop',
      EquipmentLocationKind.serviceShop,
    );
    final borrower = ctx.plan.people.firstWhere(
      (p) => p.role == PersonRole.regular && p.id != 'p-mara',
    );
    final lent = await place(borrower.name, EquipmentLocationKind.person);

    final moves = EquipmentLocationMoveRepository();
    Future<void> move(
      List<String> keys,
      String locationId,
      DateTime at, [
      String note = '',
    ]) => moves.recordMoves(
      equipmentIds: [for (final k in keys) e[k]!],
      locationId: locationId,
      movedAt: at,
      note: note,
    );

    // Home kit goes on the shelf when it arrives.
    for (final key in _homeKit) {
      await move([key], garage.id, t.boughtOn(key)!);
    }
    // Packed for the last trip, unpacked after it.
    final trip = ctx.plan.trips.last;
    final packed = [
      for (final g in demoGear)
        if (g.travel && t.inUseOn(g.key, trip.start)) g.key,
    ];
    await move(
      packed,
      bag.id,
      DateTime(trip.start.year, trip.start.month, trip.start.day - 2),
      'Packed for ${trip.destination.label}',
    );
    await move(
      packed,
      garage.id,
      DateTime(trip.end.year, trip.end.month, trip.end.day + 1),
      'Unpacked',
    );
    // The travel regulator lent out; the cold-water one in for its service.
    await move(['reg-warm'], lent.id, t.leftOn('reg-warm')!, 'Lent for a trip');
    await move(
      ['reg-cold'],
      shop.id,
      t.homeDayOnOrBefore(ctx.anchor.subtract(const Duration(days: 6))),
      'In for its annual service',
    );

    final observations = EquipmentObservationRepository();
    // The drysuit leaks at the wrist, which is why it needs its seals.
    final lastDry = ctx.plan.dives.lastWhere(
      (d) => kitFor(d, t, photo: false).gearKeys.contains('drysuit'),
    );
    await observations.create(
      equipmentId: e['drysuit']!,
      diveId: ctx.diveId(lastDry.number),
      diverId: DemoSeedContext.diverId,
      observedAt: lastDry.start.add(lastDry.plannedDuration),
      status: ObservationStatus.issue,
      issueTags: const [ObservationTag.leakWrist],
      note: 'Damp left wrist after the dive.',
      now: lastDry.start.add(lastDry.plannedDuration),
    );
    // Routine checks after every tenth dive on the diver's own regulator.
    for (final d in ctx.plan.dives) {
      if (d.number % 10 != 0) continue;
      final regulator = kitFor(
        d,
        t,
        photo: false,
      ).gearKeys.where((k) => k == 'reg-cold' || k == 'reg-warm').firstOrNull;
      if (regulator == null || ctx.faults.freeFlowDives.contains(d.number)) {
        continue;
      }
      final at = d.start.add(d.plannedDuration);
      await observations.create(
        equipmentId: e[regulator]!,
        diveId: ctx.diveId(d.number),
        diverId: DemoSeedContext.diverId,
        observedAt: at,
        status: ObservationStatus.ok,
        now: at,
      );
    }

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

    // The share, the sale and the places are stamped with the build clock by
    // their repositories; they belong in the story.
    final bcdSold = t.leftOn('bcd-jacket')!.millisecondsSinceEpoch;
    final finsShared = t.boughtOn('fins')!.millisecondsSinceEpoch;
    for (final (key, at) in [('bcd-jacket', bcdSold), ('fins', finsShared)]) {
      await ctx.db.customStatement(
        'UPDATE equipment_ownership_events SET occurred_at = ? '
        'WHERE equipment_id = ?',
        [at, e[key]!],
      );
    }
    await ctx.db.customStatement('UPDATE equipment_shares SET created_at = ?', [
      finsShared,
    ]);
    await ctx.db.customStatement(
      'UPDATE equipment_locations SET created_at = (SELECT MIN(moved_at) '
      'FROM equipment_location_moves m WHERE m.location_id = '
      'equipment_locations.id), updated_at = (SELECT MIN(moved_at) FROM '
      'equipment_location_moves m WHERE m.location_id = equipment_locations.id)',
    );
  }
}
