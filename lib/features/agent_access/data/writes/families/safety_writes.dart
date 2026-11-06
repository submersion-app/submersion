import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/equipment_observation_writes.dart'
    show ConditionFindingsRefresh;
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';

/// Incidents a diver logs, through the repository the incident page uses.
/// An incident can name the dive, the gear and the check-in that flagged
/// it; a check-in it names is an issue. The gear's condition findings are
/// worked out again for the items an incident leaves and joins.
class IncidentWrites extends WritableEntry {
  IncidentWrites(this._r, {ConditionFindingsRefresh? refreshFindings})
    : _refreshFindings = refreshFindings ?? scheduleConditionFindingsRefresh;

  final RecordRepositories _r;
  final ConditionFindingsRefresh _refreshFindings;

  /// Items whose findings the writes so far change, refreshed after apply.
  final _touchedItems = <String>{};

  @override
  String get name => 'incidents';

  @override
  String get table => 'incidents';

  @override
  late final Map<String, FieldCodec> fields = {
    'dive_id': const FieldCodec.reference('dives', nullable: true),
    'equipment_id': const FieldCodec.reference('equipment', nullable: true),
    'observation_id': const FieldCodec.reference(
      'equipment_observations',
      nullable: true,
    ),
    'occurred_time': const FieldCodec.wallClock(),
    'category': FieldCodec.enumName(IncidentCategory.values),
    'severity': FieldCodec.enumName(IncidentSeverity.values),
    'narrative': const FieldCodec.text(trim: true),
    'contributing_factors': const FieldCodec.text(nullable: true, trim: true),
    'lessons_learned': const FieldCodec.text(nullable: true, trim: true),
  };

  @override
  Set<String> get requiredOnCreate => const {'narrative', 'occurred_time'};

  @override
  String? titleOf(Map<String, Object?> document) =>
      document['narrative'] as String?;

  @override
  Future<Map<String, Object?>> createDefaults(
    String diverId,
    Map<String, Object?> values,
  ) async => {
    'category': IncidentCategory.other.name,
    'severity': IncidentSeverity.minor.name,
  };

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    final v = check.values;
    if (v['occurred_time'] case final DateTime at) {
      final now = DateTime.now();
      final today = DateTime.utc(now.year, now.month, now.day, 23, 59, 59);
      if (at.year < 1970 || at.isAfter(today)) {
        return const PlanBlock(
          BlockReason.invalidValue,
          'occurred_time: from 1970 to today.',
        );
      }
    }
    final observationId =
        (v.containsKey('observation_id')
                ? v['observation_id']
                : check.document?['observation_id'])
            as String?;
    if (observationId == null) return null;
    final observation = await _r.equipmentObservations.getById(observationId);
    if (observation == null) return null;
    if (observation.status != ObservationStatus.issue) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'observation_id: an incident names a check-in that found an issue.',
      );
    }
    final item =
        (v.containsKey('equipment_id')
                ? v['equipment_id']
                : check.document?['equipment_id'])
            as String?;
    if (item != observation.equipmentId) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'observation_id: the check-in is of another item than equipment_id.',
      );
    }
    return null;
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final incident = await _r.incidents.createIncident(
      occurredAt: values['occurred_time']! as DateTime,
      category: IncidentCategory.values.byName(values['category']! as String),
      severity: IncidentSeverity.values.byName(values['severity']! as String),
      narrative: values['narrative']! as String,
      contributingFactors: values['contributing_factors'] as String?,
      lessonsLearned: values['lessons_learned'] as String?,
      diveId: values['dive_id'] as String?,
      diverId: diverId,
      equipmentId: values['equipment_id'] as String?,
      observationId: values['observation_id'] as String?,
    );
    _touchedItems.addAll([?incident.equipmentId]);
    return incident.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current = await _incident(id);
    final v = update.values;
    T? kept<T>(String key, T? held) => v.containsKey(key) ? v[key] as T? : held;
    final next = Incident(
      id: id,
      diverId: current.diverId,
      diveId: kept('dive_id', current.diveId),
      equipmentId: kept('equipment_id', current.equipmentId),
      observationId: kept('observation_id', current.observationId),
      occurredAt: v['occurred_time'] as DateTime? ?? current.occurredAt,
      category: switch (v['category']) {
        final String c => IncidentCategory.values.byName(c),
        _ => current.category,
      },
      severity: switch (v['severity']) {
        final String s => IncidentSeverity.values.byName(s),
        _ => current.severity,
      },
      narrative: v['narrative'] as String? ?? current.narrative,
      contributingFactors: kept(
        'contributing_factors',
        current.contributingFactors,
      ),
      lessonsLearned: kept('lessons_learned', current.lessonsLearned),
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
    );
    await _r.incidents.updateIncident(next);
    _touchedItems.addAll([?current.equipmentId, ?next.equipmentId]);
  }

  @override
  Future<void> delete(String id, String? ownerId) async {
    final current = await _incident(id);
    await _r.incidents.deleteIncident(id);
    _touchedItems.addAll([?current.equipmentId]);
  }

  @override
  Future<void> afterApply(List<AppliedChange> changes, ApplyRun run) async {
    final items = {
      for (final id in _touchedItems)
        if (run.once(('findings', id))) id,
    };
    _touchedItems.clear();
    if (items.isNotEmpty) _refreshFindings(items);
  }

  Future<Incident> _incident(String id) async =>
      await _r.incidents.getIncidentById(id) ??
      (throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        'Incident $id no longer exists.',
        details: {'id': id},
      ));
}

/// A two-letter country code, upper-cased as the chamber form keeps it.
class _CountryCodec extends FieldCodec {
  const _CountryCodec();

  @override
  String get describe => 'a two-letter country code';

  @override
  Object parseValue(Object raw) {
    final code = raw is String ? raw.trim().toUpperCase() : null;
    if (code == null || !RegExp(r'^[A-Z]{2}$').hasMatch(code)) {
      throw const FieldRefusal('This field takes a two-letter country code.');
    }
    return code;
  }
}

/// The diver's own hyperbaric chambers, beside the built-in list, through
/// the repository the emergency page uses. A chamber is added or removed,
/// not edited; a built-in chamber is hidden in Settings, never deleted.
class EmergencyChamberWrites extends WritableEntry {
  EmergencyChamberWrites(this._r);

  final RecordRepositories _r;

  static const _blankable = FieldCodec.text(
    maxLength: 200,
    nullable: true,
    trim: true,
  );

  @override
  String get name => 'emergency_chambers';

  @override
  String get table => 'emergency_chambers';

  @override
  String get note =>
      'A chamber is added or deleted, not edited; to change one, delete it '
      'and add it again.';

  @override
  late final Map<String, FieldCodec> fields = {
    'name': const FieldCodec.text(maxLength: 200, trim: true),
    'country': const _CountryCodec(),
    'city': _blankable,
    'phone': const FieldCodec.text(maxLength: 50, trim: true),
    'latitude': const FieldCodec.number(min: -90, max: 90, nullable: true),
    'longitude': const FieldCodec.number(min: -180, max: 180, nullable: true),
    'notes': _blankable,
  };

  @override
  Set<String> get requiredOnCreate => const {'name', 'country', 'phone'};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async =>
      check.kind == ChangeKind.update
      ? const PlanBlock(
          BlockReason.notPermitted,
          'A chamber is not edited; delete it and add it again.',
        )
      : null;

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async =>
      (await _r.emergencyChambers.createChamber(
        name: values['name']! as String,
        country: values['country']! as String,
        phone: values['phone']! as String,
        city: values['city'] as String?,
        latitude: (values['latitude'] as num?)?.toDouble(),
        longitude: (values['longitude'] as num?)?.toDouble(),
        notes: values['notes'] as String?,
        diverId: diverId,
      )).id;

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) =>
      throw UnsupportedError('A chamber is not edited.');

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.emergencyChambers.deleteChamber(id);
}
