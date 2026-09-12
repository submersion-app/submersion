import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/dive_sensor_summary_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_findings_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
import 'package:submersion/features/equipment/domain/services/condition_input_fingerprint.dart';
import 'package:submersion/features/equipment/domain/services/dive_sensor_summary_service.dart';
import 'package:submersion/features/equipment/domain/services/equipment_condition_engine.dart';
import 'package:submersion/features/safety/data/repositories/incident_repository.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';

/// Compute-through-cache for one item's condition findings, without
/// Riverpod so the provider, the sweep and the scheduler share it.
///
/// Reads the engine's inputs, fingerprints them, and returns the stored
/// findings when the review marker matches (an unchanged item never runs
/// the engine and never writes). Otherwise it loads the sensor summaries,
/// runs the engine and saves. With the master toggle off the stored
/// findings are served untouched.
class EquipmentConditionRefresher {
  final EquipmentRepository _equipment;
  final EquipmentObservationRepository _observations;
  final IncidentRepository _incidents;
  final TransmitterRepository _transmitters;
  final DiveSensorSummaryRepository _summaries;
  final EquipmentFindingsRepository _findings;
  final EquipmentConditionEngine _engine;
  final void Function(Set<String> diveIds)? _requestSummaries;

  EquipmentConditionRefresher({
    required EquipmentRepository equipment,
    required EquipmentObservationRepository observations,
    required IncidentRepository incidents,
    required TransmitterRepository transmitters,
    required DiveSensorSummaryRepository summaries,
    required EquipmentFindingsRepository findings,
    EquipmentConditionEngine engine = const EquipmentConditionEngine(),
    void Function(Set<String> diveIds)? requestSummaries,
  }) : _equipment = equipment,
       _observations = observations,
       _incidents = incidents,
       _transmitters = transmitters,
       _summaries = summaries,
       _findings = findings,
       _engine = engine,
       _requestSummaries = requestSummaries;

  /// Null when [equipmentId] does not exist.
  Future<List<EquipmentFinding>?> ensureCurrent(
    String equipmentId, {
    required ExposureThresholds thresholds,
    required bool engineEnabled,
    DateTime? now,
  }) async {
    final item = await _equipment.getEquipmentById(equipmentId);
    if (item == null) return null;
    return ensureCurrentItem(
      item,
      thresholds: thresholds,
      engineEnabled: engineEnabled,
      now: now,
    );
  }

  Future<List<EquipmentFinding>> ensureCurrentItem(
    EquipmentItem item, {
    required ExposureThresholds thresholds,
    required bool engineEnabled,
    DateTime? now,
  }) async {
    final parentId = item.parentEquipmentId;
    final parent = parentId == null
        ? null
        : await _equipment.getEquipmentById(parentId);
    // Retired parts too: a retired cell tells the engine who occupied its
    // slot until its successor went in.
    final children = await _equipment.getChildEquipment(
      item.id,
      includeRetired: true,
    );
    // Same link semantics the service clocks use (equipment_providers).
    final isRebreather =
        item.type == EquipmentType.rebreather ||
        parent?.type == EquipmentType.rebreather;
    final samples = await _equipment.getExposureSamplesForEquipment(
      item.id,
      parentEquipmentId: parentId,
      installedSince: item.parentDivesFrom,
      rebreatherContact: isRebreather,
    );
    final observations = await _observations.getForEquipment(item.id);
    final incidents = await _incidents.getIncidentsForEquipment(item.id);
    // Both read before the marker check: the fingerprint has to see the
    // serials the dropout rules match against and which dives have a
    // summary, or a change to either would leave the marker matching.
    final serials = item.type == EquipmentType.transmitter
        ? await _transmitters.getSerialsForEquipment(item.id)
        : const <String>{};
    final diveIds = [for (final s in samples) s.diveId];
    final stamps = await _summaries.getSummaryStamps(diveIds);
    final fingerprint = conditionInputFingerprint(
      item: item,
      parent: parent,
      summaryStamps: {
        for (final e in stamps.entries)
          // computedAt too: a forced rebuild (a repair that rewrote the
          // profile or pressures without touching the dive) keeps the
          // source stamp but can change what the rules read.
          e.key:
              '${e.value.engineVersion}/${e.value.sourceUpdatedAt}/'
              '${e.value.computedAt}',
      },
      transmitterSerials: serials,
      samples: samples,
      observations: observations,
      incidents: incidents,
      children: children,
      thresholds: thresholds,
      engineVersion: EquipmentConditionEngine.engineVersion,
      summaryVersion: DiveSensorSummaryService.version,
    );
    final review = await _findings.getReview(item.id);
    final current =
        review != null &&
        review.engineVersion >= EquipmentConditionEngine.engineVersion &&
        review.inputFingerprint == fingerprint;
    if (current || !engineEnabled) return _findings.getFindings(item.id);

    // Summaries are device-local: a dive that arrived by sync, or changed
    // since, has none yet (or a stale one). The sensor rules cannot say
    // whether they still fire without them, so a finding they made
    // (perhaps on another device) is kept rather than tombstoned, no
    // marker is saved, and the missing summaries are asked for; their
    // arrival changes the fingerprint and the item recomputes in full.
    bool summarised(EquipmentExposureSample s) {
      final stamp = stamps[s.diveId];
      return stamp != null &&
          stamp.engineVersion >= DiveSensorSummaryService.version &&
          stamp.sourceUpdatedAt == s.updatedAt;
    }

    // Only for an item a summary rule can read: any other would wait on
    // summaries that change nothing, record no marker, and keep a sensor
    // finding a former type left behind.
    final readsSummaries = EquipmentConditionEngine.readsSummaries(item.type);
    final missing = readsSummaries
        ? {
            for (final s in samples)
              if (!summarised(s)) s.diveId,
          }
        : const <String>{};
    if (missing.isNotEmpty) _requestSummaries?.call(missing);
    // Only current summaries reach the engine: a stale one describes an
    // older version of the dive, and its rebuild is already requested.
    final summaries = readsSummaries
        ? {
            for (final e in (await _summaries.getSummaries(diveIds)).entries)
              if (!missing.contains(e.key)) e.key: e.value,
          }
        : const <String, DiveSensorSummary>{};
    final stamp = now ?? DateTime.now().toUtc();
    final evaluated = _engine.evaluate(
      ConditionEngineInput(
        item: item,
        children: children,
        samples: samples,
        summariesByDive: summaries,
        observations: observations,
        incidents: incidents,
        transmitterSerials: serials,
        thresholds: thresholds,
        now: stamp,
      ),
    );
    // With any summary missing, the summary rules can say nothing either
    // way: their findings are neither written nor deleted until every
    // summary is current (keepIfNotEmitted below).
    final findings = missing.isEmpty
        ? evaluated
        : [
            for (final f in evaluated)
              if (!EquipmentConditionEngine.summaryRules.contains(f.ruleId)) f,
          ];
    await _findings.saveReview(
      equipmentId: item.id,
      inputFingerprint: fingerprint,
      findings: findings,
      engineVersion: EquipmentConditionEngine.engineVersion,
      // Dates for the dismissal carry-over: only a dive that happened
      // after the dismissal counts towards re-raising a finding. Incident
      // dives too, which the item may never have been linked to: the
      // incident rule names them, so a dismissed incident finding would
      // otherwise never clear. A linked dive's own date wins.
      diveDates: {
        for (final i in incidents) ?i.diveId: i.occurredAt,
        for (final s in samples) s.diveId: s.date,
      },
      keepIfNotEmitted: missing.isEmpty
          ? const {}
          : EquipmentConditionEngine.summaryRules,
      recordMarker: missing.isEmpty,
      now: stamp,
    );
    return _findings.getFindings(item.id);
  }
}
