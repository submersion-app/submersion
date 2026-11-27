import 'dart:convert';

import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/constants/enums.dart' show EquipmentType;
import 'package:submersion/features/agent_access/data/records/families/trip_bag_contents.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

/// Why [check]'s `bag_contents` cannot be the trip's bags, or null: each
/// key a bag packed on the trip, each item packed on it and not a bag, and
/// no item in two bags. The trip's `equipment_ids` in the same change count,
/// and so do the changes before it in the set: gear they delete, take off
/// this trip, or turn into or out of a bag.
Future<PlanBlock?> bagContentsProblem(
  RecordRepositories r,
  WriteCheck check,
) async {
  if (!check.values.containsKey('bag_contents')) return null;
  final tripId = check.id;
  if (tripId == null) {
    return const PlanBlock(
      BlockReason.notPermitted,
      'bag_contents: pack the gear first, then set its bags in an update.',
    );
  }
  final byBag = decodedBagContents(check.values['bag_contents']);
  final named = {...byBag.keys, for (final ids in byBag.values) ...ids};
  final gear = check.relations['equipment_ids'];
  final soFar = check.soFar;
  final gone = soFar.deleted['equipment'] ?? const <String>{};
  final packed =
      {...await r.tripEquipment.equipmentIdsForTrip(tripId), ...?gear?.add}
          .where(
            (id) =>
                !gone.contains(id) &&
                !(gear?.remove.contains(id) ?? false) &&
                !(soFar.unlinked[('equipment', id)]?['trips']?.contains(
                      tripId,
                    ) ??
                    false),
          )
          .toSet();
  final seen = await visibleEquipment(r, named, check.ownerId);
  final unpacked = named.difference(packed.intersection(seen));
  if (unpacked.isNotEmpty) {
    return PlanBlock(
      BlockReason.invalidValue,
      'bag_contents: ${(unpacked.toList()..sort()).join(', ')} is not packed '
      'on this trip; add it to equipment_ids first.',
    );
  }
  final stored = await _bagIds(r, named);
  final bags = {
    for (final id in named)
      if (switch (soFar.values[('equipment', id)]?['type']) {
        final String type => type == EquipmentType.bag.name,
        _ => stored.contains(id),
      })
        id,
  };
  final notBags = byBag.keys.toSet().difference(bags);
  if (notBags.isNotEmpty) {
    return PlanBlock(
      BlockReason.invalidValue,
      'bag_contents: ${(notBags.toList()..sort()).join(', ')} is not a bag.',
    );
  }
  final placed = <String>{};
  for (final id in [for (final ids in byBag.values) ...ids]) {
    if (bags.contains(id)) {
      return PlanBlock(
        BlockReason.invalidValue,
        'bag_contents: $id is a bag and cannot go in another bag.',
      );
    }
    if (placed.contains(id)) {
      return PlanBlock(
        BlockReason.invalidValue,
        'bag_contents: $id is in more than one bag.',
      );
    }
    placed.add(id);
  }
  return null;
}

/// Puts each packed item of [tripId] that [diverId] sees in the bag [parsed]
/// names for it, and the rest loose, in one repository batch checked as the
/// gear tab's moves are. Gear [diverId] does not see stays where it is.
Future<void> setBagContents(
  RecordRepositories r,
  String tripId,
  String? diverId,
  Object? parsed,
) async {
  final bagOf = {
    for (final MapEntry(key: bagId, value: ids) in decodedBagContents(
      parsed,
    ).entries)
      for (final id in ids) id: bagId,
  };
  final current = await visibleBagAssignments(r, tripId, diverId);
  await r.tripEquipment.assignBags(tripId, {
    for (final itemId in {...current.keys, ...bagOf.keys})
      if (current[itemId] != bagOf[itemId]) itemId: bagOf[itemId],
  });
}

/// The parsed `bag_contents` back to a map, empty for anything else.
Map<String, List<String>> decodedBagContents(Object? parsed) => parsed is String
    ? {
        for (final MapEntry(:key, :value)
            in (jsonDecode(parsed) as Map<String, Object?>).entries)
          key: [for (final id in value! as List) '$id'],
      }
    : const {};

Future<Set<String>> _bagIds(RecordRepositories r, Set<String> ids) async {
  if (ids.isEmpty) return const {};
  final list = ids.toList();
  final rows = await r.db
      .customSelect(
        'SELECT id FROM equipment WHERE type = ? AND id IN '
        '(${List.filled(list.length, '?').join(', ')})',
        variables: [
          Variable.withString(EquipmentType.bag.name),
          for (final id in list) Variable.withString(id),
        ],
      )
      .get();
  return {for (final row in rows) row.read<String>('id')};
}
