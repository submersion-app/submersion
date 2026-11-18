import 'package:drift/drift.dart' show Variable;
import 'package:uuid/uuid.dart';

import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_plan_fields.dart';
import 'package:submersion/features/agent_access/data/writes/families/planned_dives_effect.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/object_list_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart'
    show PlanSummaryData;
import 'package:submersion/features/planner/data/services/stored_series_results.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart'
    show SeriesDiveResult;

/// Saved dive plans, through the repository the planner canvas saves with:
/// the whole plan, its tanks and its segments, and the depth and run time
/// the planner works out, which the saved plans list shows. A plan links
/// to one dive and a dive to one plan. A plan in no series can also be
/// written to the log as a planned dive.
class DivePlanWrites extends WritableEntry {
  /// [followOf] reads a dived dive as the planner does, which a plan is
  /// computed with before its planned dive is written; without it, a plan
  /// cannot be.
  DivePlanWrites(this._r, {SeriesFollowReader? followOf})
    : _planned = PlannedDivesEffect(_r, followOf: followOf);

  final RecordRepositories _r;
  final PlannedDivesEffect _planned;

  static const _plannedField = PlannedDivesEffect.field;

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
      'plan. Gas and decompression are not checked, as in the planner. '
      '${PlannedDivesEffect.note} Only a plan in no series; a series writes '
      'all its dives. ${PlannedDivesEffect.moveDivedLink} lets a plan linked '
      'to a dived dive take a new entry.';

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
    _plannedField: PlannedDivesEffect.codec,
  };

  @override
  Set<String> get requiredOnCreate => const {};

  @override
  Set<String> get createOnly => const {_copy};

  @override
  Set<String> get effectFields => const {_plannedField};

  /// The tanks and segments in the shape an agent writes them, and the link
  /// the row holds. The document names no link to a dive no longer in the
  /// log, so a change compares against the stored one: clearing such a link
  /// is a change, not a plan already unlinked.
  @override
  Future<Map<String, Object?>> stored(
    String id,
    Map<String, Object?> document,
  ) async {
    final row = await _r.db
        .customSelect(
          'SELECT linked_dive_id FROM dive_plans WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    return {
      ...document,
      ...planPartsAsWritten(document),
      'linked_dive_id': row == null
          ? document['linked_dive_id']
          : row.readNullable<String>('linked_dive_id'),
    };
  }

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
    if (PlannedDivesRequest.of(v[_plannedField]) case final ask?) {
      return _refusePlanned(check, ask);
    }
    return null;
  }

  Future<PlanBlock?> _refusePlanned(
    WriteCheck check,
    PlannedDivesRequest ask,
  ) async {
    final v = check.values;
    if (v[_copy] != null) {
      return const PlanBlock(
        BlockReason.notPermitted,
        '$_plannedField: write a copy\'s planned dive once it exists.',
      );
    }
    if (v.containsKey('linked_dive_id')) {
      return const PlanBlock(
        BlockReason.notPermitted,
        '$_plannedField: link a plan in a change of its own; writing its '
        'planned dive links it.',
      );
    }
    final id = check.id;
    if (id != null) {
      if (await _seriesOf(id) case final series?) {
        return PlanBlock(
          BlockReason.notPermitted,
          '$_plannedField: this plan is a dive of series $series; write the '
          'series\' planned dives.',
        );
      }
    }
    // An earlier change to the log refuses a new plan as well as a stored
    // one, as it refuses a new series, so the rule has no exception.
    if (PlannedDivesEffect.changedEarlier(
      check.soFar,
      (entity, record) => id != null && entity == name && record == id,
    )) {
      return const PlanBlock(
        BlockReason.notPermitted,
        '$_plannedField: write a planned dive in a change set after the one '
        'that changes this plan, a plan\'s link or the log.',
      );
    }
    return PlannedDivesEffect.blockOf(
      await _outlookOf(check.id, v, check.ownerId, ask, check.pass),
    );
  }

  /// What writing the planned dive of the plan [values] save does, for
  /// [ownerId] as [_plannedOwner] works it out. Computed once per preview in
  /// [pass]: the refusal and the side effects of one change ask with the
  /// same values.
  Future<PlannedDivesOutlook> _outlookOf(
    String? id,
    Map<String, Object?> values,
    String? ownerId,
    PlannedDivesRequest ask,
    PlanningPass? pass,
  ) {
    Future<PlannedDivesOutlook> read() async => _outlook(
      await _plannedPlan(id, values),
      await _plannedOwner(ownerId),
      ask,
    );
    return pass?.once((this, id, values), read) ?? read();
  }

  /// The plan [values] save, over the stored one for an update of [id] or a
  /// new one for a create.
  Future<DivePlan> _plannedPlan(String? id, Map<String, Object?> values) async {
    final now = DateTime.now();
    final base = id == null
        ? DivePlan(
            id: _uuid.v4(),
            name: values['name'] as String? ?? '',
            createdAt: now,
            updatedAt: now,
          )
        : await _storedPlan(id);
    return applyPlanValues(base, values);
  }

  /// Whose plan this is, for its summary and its planned dive: [ownerId],
  /// which a create and a plan in a series have, else the active diver, as
  /// the planner computes a plan on its own.
  Future<String?> _plannedOwner(String? ownerId) async =>
      ownerId ?? await _r.activeDiverId?.call();

  /// What writing [plan]'s planned dive for [owner] does.
  Future<PlannedDivesOutlook> _outlook(
    DivePlan plan,
    String? owner,
    PlannedDivesRequest ask,
  ) async => _planned.outlook(
    await _computedPlan(plan, owner),
    ownerId: owner,
    request: ask,
  );

  /// [plan] computed as the planner opens it, with [owner]'s settings.
  Future<({PlanSeries series, List<SeriesDiveResult> results})> _computedPlan(
    DivePlan plan,
    String? owner,
  ) async => computeStoredPlan(
    plan,
    config: await _planned.configFor(owner),
    dives: _r.dives,
    followOf: _planned.followOf,
  );

  /// Writes the planned dive of the saved plan [id] for [owner].
  Future<void> _writePlanned(
    String id,
    String? owner,
    PlannedDivesRequest ask,
  ) async => _planned.write(
    await _computedPlan(await _storedPlan(id), owner),
    ownerId: owner,
    request: ask,
  );

  /// The stored plan [id], or a refusal when it has gone.
  Future<DivePlan> _storedPlan(String id) async =>
      await _r.divePlans.getPlan(id) ??
      (throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        'Dive plan $id no longer exists.',
        details: {'id': id},
      ));

  @override
  Future<Map<String, int>> alsoCreates(
    String diverId,
    Map<String, Object?> values,
  ) async => {
    // A new plan has no entry in the log, so it gets one.
    if (values[_plannedField] != null) 'dives': 1,
  };

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async {
    final ask = PlannedDivesRequest.of(update.values[_plannedField]);
    final planned = ask == null
        ? const SideEffects()
        : PlannedDivesEffect.effectsOf(
            await _outlookOf(id, update.values, ownerId, ask, update.pass),
          );
    final diveId = update.values['linked_dive_id'];
    if (diveId is! String) return planned;
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
    if (PlannedDivesRequest.of(values[_plannedField]) case final ask?) {
      await _writePlanned(saved.id, diverId, ask);
    }
    return saved.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current = await _storedPlan(id);
    final owner = await _plannedOwner(ownerId);
    await _save(
      current,
      update.values,
      // A plan in a series belongs to the series' diver, whose settings it
      // is computed with. A plan on its own has no owner, so the planner
      // computes it with the active diver's settings, and so does this.
      ownerId: owner,
    );
    if (PlannedDivesRequest.of(update.values[_plannedField]) case final ask?) {
      await _writePlanned(id, owner, ask);
    }
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
        summarize ||
        values.keys.any((k) => k != 'linked_dive_id' && k != _plannedField);
    var saved = plan;
    if (changesPlan) {
      final outcome = PlanEngine(
        config: await _planned.configFor(ownerId),
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
