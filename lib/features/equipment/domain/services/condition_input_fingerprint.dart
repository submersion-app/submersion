import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';

/// Hashes everything the condition engine reads for one item, so the
/// review marker can tell "nothing changed, serve the stored findings"
/// from "recompute": the exposure samples, observations and incidents
/// (count, newest stamp and a digest of their ids with their own stamps),
/// the children (ids and install dates), the thresholds and both
/// versions. Two devices with the same data hash the same, in any order.
///
/// The id digest is what makes it identity rather than shape. Deleting
/// one dive and importing another of the same vintage leaves the count
/// and the newest stamp exactly where they were, and without the digest
/// the item would read as unchanged while its findings still cited a dive
/// that had left the logbook.
///
/// The configuration counts as much as the data. [item] contributes its
/// type, its parent link and its own cell slot and install date, [parent]
/// its type (which decides the rebreather rules), each child its type,
/// slot and install date, and [transmitterSerials] the registry serials
/// the dropout rules match gaps against. Any of them changing re-points
/// the rules at other readings without a single dive changing.
///
/// [summaryStamps] carries each stored sensor summary as
/// `engineVersion/sourceUpdatedAt`, keyed by dive. A summary can arrive
/// after the item was first reviewed (the background sweep writes it
/// later) or be recomputed, and neither touches the dive; without the
/// stamps the old marker still matched and served findings built without
/// those readings. [summaryVersion] is the summary algorithm's version.
String conditionInputFingerprint({
  required EquipmentItem item,
  required EquipmentItem? parent,
  required Map<String, String> summaryStamps,
  required Set<String> transmitterSerials,
  required List<EquipmentExposureSample> samples,
  required List<EquipmentObservation> observations,
  required List<Incident> incidents,
  required List<EquipmentItem> children,
  required ExposureThresholds thresholds,
  required int engineVersion,
  required int summaryVersion,
}) {
  var newestSample = 0;
  for (final s in samples) {
    if (s.updatedAt > newestSample) newestSample = s.updatedAt;
  }
  var newestObservation = 0;
  for (final o in observations) {
    final ms = o.updatedAt.millisecondsSinceEpoch;
    if (ms > newestObservation) newestObservation = ms;
  }
  var newestIncident = 0;
  for (final i in incidents) {
    final ms = i.updatedAt.millisecondsSinceEpoch;
    if (ms > newestIncident) newestIncident = ms;
  }
  // Every field the engine reads, not only the dive's stamp: a link change
  // (the transmitter registry rewriting dive_tanks.equipment_id) can move
  // the gas the item breathed or which readings reach it without touching
  // dives.updated_at.
  final sampleKeys = [
    for (final s in samples)
      '${s.diveId}@${s.updatedAt}/${s.date.millisecondsSinceEpoch}/'
          '${s.durationSeconds}/${s.diveMode.name}/${s.maxDepth}/'
          '${s.minTemperature}/${s.waterType?.name}/${s.contactO2Fraction}',
  ];
  final observationKeys = [
    for (final o in observations)
      '${o.id}@${o.updatedAt.millisecondsSinceEpoch}',
  ];
  final incidentKeys = [
    for (final i in incidents) '${i.id}@${i.updatedAt.millisecondsSinceEpoch}',
  ];
  final childKeys = [for (final c in children) '${c.id}@${_configOf(c)}']
    ..sort();
  final summaryKeys = [
    for (final e in summaryStamps.entries) '${e.key}@${e.value}',
  ];
  final canonical = [
    'v$engineVersion',
    'sv$summaryVersion',
    'm${_configOf(item)}:${item.parentEquipmentId}:${parent?.type.name}',
    'x${_digest(summaryKeys)}',
    'r${_digest(transmitterSerials.toList())}',
    's${samples.length}:$newestSample:${_digest(sampleKeys)}',
    'o${observations.length}:$newestObservation:${_digest(observationKeys)}',
    'i${incidents.length}:$newestIncident:${_digest(incidentKeys)}',
    'c${childKeys.join(',')}',
    't${thresholds.coldWaterC}/${thresholds.deepDiveM}/${thresholds.highO2Fraction}',
  ].join('|');
  return sha1.convert(utf8.encode(canonical)).toString();
}

/// What the engine reads off an item beyond its id: the type, whether it
/// is still fitted (a retired cell's slot ends at its successor), the
/// cell slot, and the install date with the creation date it falls back
/// to.
String _configOf(EquipmentItem e) => [
  e.type.name,
  e.isActive,
  e.status.name,
  e.attrNum(EquipmentAttrKeys.cellSlot),
  e.installedDate?.millisecondsSinceEpoch,
  e.createdAt?.millisecondsSinceEpoch,
].join('/');

/// A short, order-independent digest of a set of "id@stamp" keys. Sorted
/// so two devices holding the same rows in a different order agree, and
/// truncated because the canonical string is only ever compared with
/// itself: it needs to change when the set changes, not to be a proof.
String _digest(List<String> keys) {
  if (keys.isEmpty) return '0';
  final sorted = [...keys]..sort();
  return sha1
      .convert(utf8.encode(sorted.join(',')))
      .toString()
      .substring(0, 12);
}
