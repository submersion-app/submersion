import 'package:drift/drift.dart' show Variable;
import 'package:uuid/uuid.dart';

import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_plan_fields.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/object_list_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart'
    show PlanSummaryData;
import 'package:submersion/features/planner/data/services/plan_engine_settings.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart'
    show AppSettings;

/// Saved dive plans, through the repository the planner canvas saves with:
/// the whole plan, its tanks and its segments, and the depth and run time
/// the planner works out, which the saved plans list shows. A plan links
/// to one dive and a dive to one plan.
class DivePlanWrites extends WritableEntry {
  DivePlanWrites(this._r);

  final RecordRepositories _r;

  static const _copy = 'duplicate_of';
  static const _uuid = Uuid();

  @override
  String get name => 'dive_plans';

  @override
  String get table => 'dive_plans';

  @override
  String get note =>
      'tanks and segments are written whole, in order; a segment names its '
      'tank by place in tanks, as tank, and breathes that tank\'s gas. '
      '$_copy copies a plan. linked_dive_id moves the dive off any other '
      'plan. Gas and decompression are not checked, as in the planner.';

  @override
  late final Map<String, FieldCodec> fields = {
    'name': const FieldCodec.text(maxLength: 200, trim: true),
    'notes': const FieldCodec.text(allowBlank: true, trim: true),
    'site_id': const FieldCodec.reference('sites', nullable: true),
    'mode': FieldCodec.enumName(PlanMode.values),
    'start_date_time': const FieldCodec.wallClock(nullable: true),
    ...planSettingFields,
    'linked_dive_id': const FieldCodec.reference('dives', nullable: true),
    'tanks': planTanksField,
    'segments': planSegmentsField,
    _copy: const FieldCodec.reference('dive_plans'),
  };

  @override
  Set<String> get requiredOnCreate => const {};

  @override
  Set<String> get createOnly => const {_copy};

  /// The tanks and segments in the shape an agent writes them.
  @override
  Future<Map<String, Object?>> stored(
    String id,
    Map<String, Object?> document,
  ) async {
    final tanks = [
      for (final t in document['tanks'] as List? ?? const [])
        (t as Map).cast<String, Object?>(),
    ];
    final place = {for (final (i, t) in tanks.indexed) t['id']: i};
    return {
      ...document,
      'tanks': [
        for (final t in tanks) {for (final key in _tankKeys) key: t[key]},
      ],
      'segments': [
        for (final s in document['segments'] as List? ?? const [])
          {
            'target_depth_m': (s as Map)['target_depth_m'],
            'duration_s': s['duration_s'],
            'tank': place[s['tank_id']],
            'setpoint_bar': s['setpoint_bar'],
            'split_at_configured_rate': s['split_at_configured_rate'],
          },
      ],
    };
  }

  static const _tankKeys = [
    'name',
    'volume_l',
    'working_pressure_bar',
    'start_pressure_bar',
    'o2_fraction',
    'he_fraction',
    'role',
    'deco_switch_depth_m',
  ];

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    final v = check.values;
    if (check.kind == ChangeKind.delete) {
      final series = await _seriesOf(check.id!);
      return series == null
          ? null
          : PlanBlock(
              BlockReason.notPermitted,
              'This plan is a dive of series $series; take it out of the '
              'series first.',
            );
    }
    if (check.kind == ChangeKind.create &&
        v[_copy] == null &&
        v['name'] == null) {
      return const PlanBlock(
        BlockReason.missingField,
        'A new dive_plans record needs name, or $_copy.',
      );
    }
    if (v[_copy] != null &&
        (v.containsKey('tanks') || v.containsKey('segments'))) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'A copy takes its tanks and segments; edit them once it exists.',
      );
    }
    final tanks = v.containsKey('tanks')
        ? ObjectListCodec.items(v['tanks']).length
        : (check.document?['tanks'] as List?)?.length ?? 0;
    final segments = v.containsKey('segments')
        ? ObjectListCodec.items(v['segments'])
        : const <Map<String, Object?>>[];
    if (segmentTankProblem(segments, tanks) case final problem?) {
      return PlanBlock(BlockReason.invalidValue, problem);
    }
    return null;
  }

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async {
    final diveId = update.values['linked_dive_id'];
    if (diveId is! String) return const SideEffects();
    final others = await _r.db
        .customSelect(
          'SELECT COUNT(*) AS n FROM dive_plans WHERE linked_dive_id = ? '
          'AND id != ?',
          variables: [Variable.withString(diveId), Variable.withString(id)],
        )
        .getSingle();
    final n = others.read<int>('n');
    return SideEffects(touched: {if (n > 0) 'dive_plans': n});
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    if (values[_copy] case final String from) {
      final copy =
          await _r.divePlans.duplicatePlan(from) ??
          (throw AgentToolException(
            AgentToolErrorCode.writeRefused,
            'Dive plan $from no longer exists.',
            details: {'id': from},
          ));
      final rest = {...values}..remove(_copy);
      // Saved again even with nothing else to set: the copy keeps the
      // summary its source was saved with, which may be another diver's.
      await _save(copy, rest, ownerId: diverId, summarize: true);
      return copy.id;
    }
    final now = DateTime.now();
    final saved = await _save(
      DivePlan(
        id: _uuid.v4(),
        name: values['name']! as String,
        createdAt: now,
        updatedAt: now,
      ),
      values,
      ownerId: diverId,
    );
    return saved.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current =
        await _r.divePlans.getPlan(id) ??
        (throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Dive plan $id no longer exists.',
          details: {'id': id},
        ));
    await _save(
      current,
      update.values,
      // A plan in a series belongs to the series' diver, whose settings it
      // is computed with. A plan on its own has no owner, so the planner
      // computes it with the active diver's settings, and so does this.
      ownerId: ownerId ?? await _r.activeDiverId?.call(),
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.divePlans.deletePlan(id);

  /// Saves [plan] with [values] over it, with the summary the planner works
  /// out for [ownerId] from their planner settings, then moves its dive
  /// link, which the save leaves as stored. A change to the link alone
  /// leaves the summary as it is, unless [summarize] asks for it anyway.
  Future<DivePlan> _save(
    DivePlan plan,
    Map<String, Object?> values, {
    required String? ownerId,
    bool summarize = false,
  }) async {
    final link = values.containsKey('linked_dive_id');
    final next = applyPlanValues(plan, values);
    final changesPlan =
        summarize || values.keys.any((k) => k != 'linked_dive_id');
    var saved = plan;
    if (changesPlan) {
      final outcome = PlanEngine(
        config: await _configFor(ownerId),
      ).compute(next);
      saved = await _r.divePlans.savePlan(
        next,
        summary: PlanSummaryData(
          maxDepth: outcome.maxDepth,
          runtimeSeconds: outcome.runtimeSeconds,
          ttsSeconds: outcome.ttsAtBottom,
        ),
      );
    }
    if (link) {
      final diveId = values['linked_dive_id'] as String?;
      if (diveId == null) {
        await _r.divePlans.unlinkPlan(saved.id);
      } else {
        await _r.divePlans.linkPlanToDive(saved.id, diveId);
      }
    }
    return saved;
  }

  /// The planner settings of [ownerId], or the defaults for a plan with no
  /// owner or an owner with no settings of their own.
  Future<PlanEngineConfig> _configFor(String? ownerId) async {
    final settings = ownerId == null
        ? null
        : await _r.diverSettings.getSettingsForDiver(ownerId);
    return planEngineConfigFromSettings(settings ?? const AppSettings());
  }

  Future<String?> _seriesOf(String id) async {
    final row = await _r.db
        .customSelect(
          'SELECT series_id FROM dive_plans WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    return row?.readNullable<String>('series_id');
  }
}
