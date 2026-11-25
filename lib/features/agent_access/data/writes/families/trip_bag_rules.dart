import 'dart:convert';

import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/constants/enums.dart' show EquipmentType;
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

/// A trip's packed bags, each to the packed items riding in it, as the gear
/// tab groups them (issue #4945). Packed gear in no bag is loose and not
/// listed; a bag with nothing in it is not listed either.
Future<Map<String, List<String>>> bagContentsOf(
  RecordRepositories r,
  String tripId,
) async {
  final byBag = <String, List<String>>{};
  for (final MapEntry(key: itemId, value: bagId)
      in (await r.tripEquipment.bagAssignmentsForTrip(tripId)).entries) {
    (byBag[bagId] ??= []).add(itemId);
  }
  return {for (final e in byBag.entries) e.key: e.value..sort()};
}

/// Why [check]'s `bag_contents` cannot be the trip's bags, or null: each
/// key a bag packed on the trip, each item packed on it and not a bag, and
/// no item in two bags. The trip's `equipment_ids` in the same change count.
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
  final gear = check.relations['equipment_ids'];
  final packed = {
    ...await r.tripEquipment.equipmentIdsForTrip(tripId),
    ...?gear?.add,
  }.difference(gear?.remove ?? const <String>{});
  final named = {...byBag.keys, for (final ids in byBag.values) ...ids};
  final unpacked = named.difference(packed);
  if (unpacked.isNotEmpty) {
    return PlanBlock(
      BlockReason.invalidValue,
      'bag_contents: ${(unpacked.toList()..sort()).join(', ')} is not packed '
      'on this trip; add it to equipment_ids first.',
    );
  }
  final bags = await _bagIds(r, named);
  final notBags = byBag.keys.toSet().difference(bags);
  if (notBags.isNotEmpty) {
    return PlanBlock(
      BlockReason.invalidValue,
      'bag_contents: ${(notBags.toList()..sort()).join(', ')} is not a bag.',
    );
  }
  final seen = <String>{};
  for (final ids in byBag.values) {
    for (final id in ids) {
      if (bags.contains(id)) {
        return PlanBlock(
          BlockReason.invalidValue,
          'bag_contents: $id is a bag and cannot go in another bag.',
        );
      }
      if (!seen.add(id)) {
        return PlanBlock(
          BlockReason.invalidValue,
          'bag_contents: $id is in more than one bag.',
        );
      }
    }
  }
  return null;
}

/// Puts each packed item of [tripId] in the bag [parsed] names for it, and
/// the rest loose, through the repository the gear tab moves gear with.
Future<void> setBagContents(
  RecordRepositories r,
  String tripId,
  Object? parsed,
) async {
  final bagOf = {
    for (final MapEntry(key: bagId, value: ids) in decodedBagContents(
      parsed,
    ).entries)
      for (final id in ids) id: bagId,
  };
  final current = await r.tripEquipment.bagAssignmentsForTrip(tripId);
  final items = {...current.keys, ...bagOf.keys}.toList()..sort();
  for (final itemId in items) {
    if (current[itemId] != bagOf[itemId]) {
      await r.tripEquipment.assignBag(tripId, itemId, bagOf[itemId]);
    }
  }
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
