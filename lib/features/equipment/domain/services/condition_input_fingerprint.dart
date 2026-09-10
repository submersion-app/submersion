import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';

/// Hashes everything the condition engine reads for one item, so the
/// review marker can tell "nothing changed, serve the stored findings"
/// from "recompute": the exposure samples (count and newest stamp), the
/// observations and incidents (count and newest stamp), the children (ids
/// and install dates), the thresholds and both versions. Two devices with
/// the same data hash the same.
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
  final childKeys = [
    for (final c in children)
      '${c.id}@${c.installedDate?.millisecondsSinceEpoch}',
  ]..sort();
  final canonical = [
    'v$engineVersion',
    'sv$summaryVersion',
    's${samples.length}:$newestSample',
    'o${observations.length}:$newestObservation',
    'i${incidents.length}:$newestIncident',
    'c${childKeys.join(',')}',
    't${thresholds.coldWaterC}/${thresholds.deepDiveM}/${thresholds.highO2Fraction}',
  ].join('|');
  return sha1.convert(utf8.encode(canonical)).toString();
}
