import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/agent_access/data/records/record_reader.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/records/record_scope.dart';

/// A trip's packed bags, each to the packed items riding in it, as the gear
/// tab groups them (issue #4945), counting only what [diverId] sees: gear
/// another profile keeps hidden is neither listed nor moved. Packed gear in
/// no bag is loose and not listed; a bag with nothing in it is not listed
/// either.
Future<Map<String, List<String>>> bagContentsOf(
  RecordRepositories r,
  String tripId,
  String? diverId,
) async {
  final byBag = <String, List<String>>{};
  for (final MapEntry(key: itemId, value: bagId)
      in (await visibleBagAssignments(r, tripId, diverId)).entries) {
    byBag.update(bagId, (ids) => [...ids, itemId], ifAbsent: () => [itemId]);
  }
  return {
    for (final MapEntry(:key, :value) in byBag.entries) key: [...value]..sort(),
  };
}

/// The trip's gear in a bag, item to bag, where [diverId] sees both.
Future<Map<String, String>> visibleBagAssignments(
  RecordRepositories r,
  String tripId,
  String? diverId,
) async {
  final assigned = await r.tripEquipment.bagAssignmentsForTrip(tripId);
  final seen = await visibleEquipment(r, {
    ...assigned.keys,
    ...assigned.values,
  }, diverId);
  return {
    for (final MapEntry(key: item, value: bag) in assigned.entries)
      if (seen.contains(item) && seen.contains(bag)) item: bag,
  };
}

/// The ids of [ids] that [diverId] sees; all of them with no profile.
Future<Set<String>> visibleEquipment(
  RecordRepositories r,
  Set<String> ids,
  String? diverId,
) async {
  if (ids.isEmpty || diverId == null) return ids;
  return (await RecordReader(r.db).visibleRows(
    'equipment',
    rootScope(QuerySubject.equipment),
    ids.toList(),
    diverId,
  )).toSet();
}
