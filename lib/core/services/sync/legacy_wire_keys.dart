/// Wire spellings older peers still publish, and how this build reads them.
///
/// The apply path (`SyncDataSerializer`) and the conflict dialog share these
/// rules, so the dialog compares a remote row under the names "Keep remote"
/// will actually write (issue #3025).
library;

import 'package:submersion/core/database/trip_checklist_default.dart';

/// Wire keys this build renamed, as oldKey -> newKey per entity type.
///
/// Payloads published by peers below schema 160, and backups written by
/// them, spell the maintenance category 'serviceType'. The compatibility
/// floor stops those peers applying OUR payloads, but the gate is
/// one-directional (changeset_reader.dart compares the writer's floor to
/// the reader's schema), so their payloads still arrive here and would hit
/// a NOT NULL column with no key, throwing in the generated fromJson.
///
/// The serializer's schema-default fill cannot cover this: it only fills NOT
/// NULL columns carrying a constant SQL default, and service_category has
/// none.
///
/// Delete this once the floor moves past the last build that published the
/// old spelling.
const Map<String, Map<String, String>> renamedWireKeys = {
  'serviceRecords': {'serviceType': 'serviceCategory'},
  // v170: the SAC unit toggle became the gas-consumption display. The value
  // is remapped by [currentGasConsumptionLane].
  'diverSettings': {'sacUnit': 'gasConsumptionDisplay'},
};

/// The entities that named their trip directly until v336 (issue #3356).
const Set<String> _tripKeyedChecklistEntities = {
  'tripChecklistItems',
  'tripChecklistSections',
};

/// The trip a checklist row from a peer below v336 names, or null for any
/// other row. Such a row predates multiple checklists, so it belongs to its
/// trip's default checklist, the one the migration backfills. The floor only
/// stops OUR payloads reaching that peer: its own rows still arrive here, as
/// does every base published before the update.
String? legacyChecklistTripId(String entityType, Map<String, dynamic> data) {
  if (!_tripKeyedChecklistEntities.contains(entityType)) return null;
  if (data['checklistId'] != null) return null;
  final tripId = data['tripId'];
  return tripId is String ? tripId : null;
}

/// A pre-170 peer spells the gas-consumption display as a unit.
const Map<String, String> _legacyGasConsumptionLanes = {
  'litersPerMin': 'rmv',
  'pressurePerMin': 'sac',
};

/// [data] with every legacy key of [entityType] moved to its current name.
///
/// Returns [data] itself when nothing needed renaming; never mutates it.
Map<String, dynamic> withCurrentWireKeys(
  String entityType,
  Map<String, dynamic> data,
) {
  final legacyTripId = legacyChecklistTripId(entityType, data);
  if (legacyTripId != null) {
    return {...data, 'checklistId': defaultTripChecklistId(legacyTripId)}
      ..remove('tripId');
  }
  final renames = renamedWireKeys[entityType];
  if (renames == null) return data;
  Map<String, dynamic>? patched;
  for (final entry in renames.entries) {
    if (!data.containsKey(entry.key)) continue;
    // A payload carrying both keys came from a build that knows the new
    // name, so the new one wins and the stale alias is dropped.
    final map = patched ??= Map.of(data);
    final legacy = map.remove(entry.key);
    map.putIfAbsent(entry.value, () => legacy);
  }
  return patched ?? data;
}

/// The gas-consumption lane [value] means, mapping a legacy unit spelling.
Object? currentGasConsumptionLane(Object? value) =>
    _legacyGasConsumptionLanes[value] ?? value;

/// [data] as this build would store it: legacy keys renamed and legacy
/// values remapped. Returns [data] itself when nothing changed.
Map<String, dynamic> withCurrentWireSpelling(
  String entityType,
  Map<String, dynamic> data,
) {
  final renamed = withCurrentWireKeys(entityType, data);
  if (entityType != 'diverSettings') return renamed;
  const key = 'gasConsumptionDisplay';
  final display = renamed[key];
  final lane = currentGasConsumptionLane(display);
  if (lane == display) return renamed;
  return {...renamed, key: lane};
}
