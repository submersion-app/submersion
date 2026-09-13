import 'package:submersion/core/services/export/models/export_service_record.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show Dive, TankPressurePoint;
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/services/profile_event_mapper.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// What a full UDDF export writes about each dive beyond the dive itself.
///
/// Every map is keyed by dive id and holds only the dives that have
/// something; a dive with no buddies, say, is absent from [diveBuddies].
/// [loadUddfDiveRelations] fills each map in dive order, which the
/// document depends on: the builder writes the participant role rows by
/// iterating [diveBuddies].
class UddfDiveRelations {
  final Map<String, List<BuddyWithRole>> diveBuddies;
  final Map<String, List<Tag>> diveTags;
  final Map<String, List<DiveWeight>> diveWeights;
  final Map<String, List<GasSwitchWithTank>> diveGasSwitches;
  final Map<String, List<ProfileEvent>> diveProfileEvents;
  final Map<String, Map<String, List<TankPressurePoint>>> diveTankPressures;

  const UddfDiveRelations({
    this.diveBuddies = const {},
    this.diveTags = const {},
    this.diveWeights = const {},
    this.diveGasSwitches = const {},
    this.diveProfileEvents = const {},
    this.diveTankPressures = const {},
  });
}

/// Loads the [UddfDiveRelations] for [dives] with one batched read per
/// relation, so the statement count does not grow with the logbook
/// (issue #1867; the export used to read every relation dive by dive).
///
/// The batched reads chunk their id lists, except buddies and tags, which
/// bind every id at once. [dives] come from `getAllDives`, which already
/// binds that same id list for its own buddy and tag reads, so those two
/// add no new bound-variable limit.
Future<UddfDiveRelations> loadUddfDiveRelations({
  required BuddyRepository buddyRepository,
  required TagRepository tagRepository,
  required DiveRepository diveRepository,
  required DiveComputerRepository diveComputerRepository,
  required TankPressureRepository tankPressureRepository,
  required List<Dive> dives,
}) async {
  final ids = [for (final dive in dives) dive.id];
  // A batch keys its map in row order; the per-dive loop keyed it in dive
  // order, and the document follows whichever order a map iterates in.
  Map<String, V> inDiveOrder<V extends Object>(Map<String, V> byDive) => {
    for (final id in ids) id: ?byDive[id],
  };

  final eventRows = await diveComputerRepository.getEventsForDives(ids);
  return UddfDiveRelations(
    // The certification-hydrating batch, because the per-dive read it
    // replaces hydrated each person's primary certification too.
    diveBuddies: inDiveOrder(
      await buddyRepository.getBuddiesForDivesWithCertifications(ids),
    ),
    diveTags: inDiveOrder(await tagRepository.getTagsForDives(ids)),
    // Already hydrated on the dives, so this costs no read.
    diveWeights: {
      for (final dive in dives)
        if (dive.weights.isNotEmpty) dive.id: dive.weights,
    },
    diveGasSwitches: inDiveOrder(
      await diveRepository.getGasSwitchesForDives(ids),
    ),
    diveProfileEvents: {
      for (final entry in inDiveOrder(eventRows).entries)
        entry.key: entry.value.map(mapDiveProfileEventToProfileEvent).toList(),
    },
    diveTankPressures: inDiveOrder(
      await tankPressureRepository.getTankPressuresForDives(ids),
    ),
  );
}

/// Every service record of [equipment] as the export DTO, item by item in
/// [equipment]'s order and newest service first within an item, read in
/// one batch rather than one read per item (issue #1867).
Future<List<ServiceRecord>> loadUddfServiceRecords(
  ServiceRecordRepository repository,
  List<EquipmentItem> equipment,
) async {
  final byItem = await repository.getRecordsForEquipmentIds([
    for (final item in equipment) item.id,
  ]);
  return [
    for (final item in equipment)
      for (final r in byItem[item.id] ?? const [])
        ServiceRecord(
          id: r.id,
          equipmentId: r.equipmentId,
          serviceCategory: r.serviceCategory,
          serviceDate: r.serviceDate,
          provider: r.provider,
          cost: r.cost,
          currency: r.currency,
          nextServiceDue: r.nextServiceDue,
          notes: r.notes,
        ),
  ];
}
