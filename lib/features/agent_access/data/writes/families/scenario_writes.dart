import 'dart:convert';

import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention_codec.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';

/// A dive's saved Dive Lab scenarios, through the repository the Dive Lab
/// uses. Interventions take the list documents carry, decoded with the Dive
/// Lab's own codec and held to its composition rules.
class ScenarioWrites extends WritableEntry {
  ScenarioWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'dive_scenarios';

  @override
  String get table => 'dive_scenarios';

  @override
  ChildOf get parent => const ChildOf(entity: 'dives', field: 'dive_id');

  @override
  late final Map<String, FieldCodec> fields = {
    'dive_id': const FieldCodec.reference('dives'),
    'name': const FieldCodec.text(maxLength: 100),
    'notes': const FieldCodec.text(allowBlank: true, nullable: true),
    'branch_s': const FieldCodec.integer(min: 0, max: 172800),
    'mode': FieldCodec.enumName(ScenarioMode.values),
    'interventions': const InterventionsCodec(),
  };

  @override
  Set<String> get requiredOnCreate => const {'name'};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    // The repository stores no notes as '' and reads them back as null, so
    // a blank would be listed as a change it never makes.
    if (check.values['notes'] case final String notes
        when notes.trim().isEmpty) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'notes: send null to clear a scenario\'s notes.',
      );
    }
    final encoded = check.values['interventions'];
    if (encoded is! String) return null;
    final interventions = decodeInterventionList(encoded);
    final errors = validateInterventions(interventions);
    if (errors.isNotEmpty) {
      return PlanBlock(
        BlockReason.invalidValue,
        'interventions: ${errors.map((e) => e.name).join(', ')}.',
      );
    }
    final diveId =
        (check.values['dive_id'] ?? check.document?['dive_id']) as String?;
    final cylinders = await _cylinders(diveId);
    final strangers = [
      for (final i in interventions)
        for (final ref in _tankRefs(interventionToJson(i)))
          if (!cylinders.contains(ref)) ref,
    ];
    if (strangers.isEmpty) return null;
    return PlanBlock(
      BlockReason.invalidValue,
      'interventions: ${strangers.join(', ')} is not a cylinder of dive '
      '$diveId.',
    );
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final now = DateTime.now();
    final saved = await _r.diveScenarios.saveScenario(
      DiveScenario(
        id: '',
        diveId: values['dive_id']! as String,
        name: values['name']! as String,
        notes: values['notes'] as String?,
        branchSeconds: values['branch_s'] as int? ?? 0,
        mode: _mode(values['mode']) ?? ScenarioMode.replay,
        interventions: switch (values['interventions']) {
          final String encoded => decodeInterventionList(encoded),
          _ => const [],
        },
        createdAt: now,
        updatedAt: now,
      ),
    );
    return saved.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current = await _r.diveScenarios.getScenario(id) ?? _gone(id);
    final v = update.values;
    await _r.diveScenarios.saveScenario(
      DiveScenario(
        id: id,
        diveId: current.diveId,
        name: v['name'] as String? ?? current.name,
        notes: v.containsKey('notes') ? v['notes'] as String? : current.notes,
        branchSeconds: v['branch_s'] as int? ?? current.branchSeconds,
        mode: _mode(v['mode']) ?? current.mode,
        interventions: switch (v['interventions']) {
          final String encoded => decodeInterventionList(encoded),
          _ => current.interventions,
        },
        createdAt: current.createdAt,
        updatedAt: current.updatedAt,
      ),
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) async {
    await _r.diveScenarios.getScenario(id) ?? _gone(id);
    await _r.diveScenarios.deleteScenario(id);
  }

  Never _gone(String id) => throw AgentToolException(
    AgentToolErrorCode.writeRefused,
    'Scenario $id no longer exists.',
    details: {'id': id},
  );

  ScenarioMode? _mode(Object? name) =>
      name is String ? ScenarioMode.values.byName(name) : null;

  Future<Set<String>> _cylinders(String? diveId) async {
    if (diveId == null) return const {};
    final rows = await DatabaseService.instance.database
        .customSelect(
          'SELECT id FROM dive_tanks WHERE dive_id = ?',
          variables: [Variable.withString(diveId)],
        )
        .get();
    return {for (final row in rows) row.read<String>('id')};
  }

  /// Every cylinder of the dive an intervention names, however deep: a
  /// switch's existing tank and a lost tank both carry a `tankId`, and a
  /// hypothetical one carries none.
  static Iterable<String> _tankRefs(Object? json) sync* {
    if (json is Map) {
      if (json['tankId'] case final String tankId) yield tankId;
      for (final value in json.values) {
        yield* _tankRefs(value);
      }
    } else if (json is List) {
      for (final value in json) {
        yield* _tankRefs(value);
      }
    }
  }
}

/// [encoded] as [InterventionsCodec] writes it.
List<ScenarioIntervention> decodeInterventionList(String encoded) => [
  for (final item in jsonDecode(encoded) as List)
    interventionFromJson(item as Map<String, Object?>),
];

/// A scenario's interventions, as the list documents carry. The parsed value
/// is that list's canonical JSON, so a list can be compared with the one
/// stored.
class InterventionsCodec extends FieldCodec {
  const InterventionsCodec();

  @override
  String get describe =>
      'a list of Dive Lab interventions, as documents '
      'carry them';

  @override
  Object parseValue(Object raw) {
    if (raw is! List) {
      throw const FieldRefusal('This field takes a list of interventions.');
    }
    try {
      return jsonEncode([
        for (final item in raw)
          interventionToJson(
            interventionFromJson(Map<String, Object?>.from(item as Map)),
          ),
      ]);
    } on FormatException catch (e) {
      throw FieldRefusal('An intervention is not valid: ${e.message}.');
    } on TypeError {
      throw const FieldRefusal('Each intervention is an object.');
    }
  }

  @override
  Object? canonical(Object? documentValue) =>
      documentValue is List ? jsonEncode(documentValue) : documentValue;

  @override
  Object? wire(Object? value) => value is String ? jsonDecode(value) : value;
}
