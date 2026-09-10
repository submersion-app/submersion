import 'dart:convert';

import 'package:crypto/crypto.dart';

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
/// [summaryVersion] is the sensor summary algorithm's own version. The
/// summaries are not hashed row by row (they are derived from the same
/// dives the samples carry), but they ARE recomputed when that version
/// rises without any dive changing, and the engine reads them. Leaving it
/// out froze every finding against readings that had since moved.
String conditionInputFingerprint({
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
  final sampleKeys = [for (final s in samples) '${s.diveId}@${s.updatedAt}'];
  final observationKeys = [
    for (final o in observations)
      '${o.id}@${o.updatedAt.millisecondsSinceEpoch}',
  ];
  final incidentKeys = [
    for (final i in incidents) '${i.id}@${i.updatedAt.millisecondsSinceEpoch}',
  ];
  final childKeys = [
    for (final c in children)
      '${c.id}@${c.installedDate?.millisecondsSinceEpoch}',
  ]..sort();
  final canonical = [
    'v$engineVersion',
    'sv$summaryVersion',
    's${samples.length}:$newestSample:${_digest(sampleKeys)}',
    'o${observations.length}:$newestObservation:${_digest(observationKeys)}',
    'i${incidents.length}:$newestIncident:${_digest(incidentKeys)}',
    'c${childKeys.join(',')}',
    't${thresholds.coldWaterC}/${thresholds.deepDiveM}/${thresholds.highO2Fraction}',
  ].join('|');
  return sha1.convert(utf8.encode(canonical)).toString();
}

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
