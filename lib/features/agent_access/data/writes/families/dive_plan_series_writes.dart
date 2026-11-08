import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';

/// Repetitive dive series, through the repository the planner saves them
/// with. A series is made in the planner, or as a copy of another; here it
/// is renamed, its dives kept, reordered or dropped (a dropped dive's plan
/// goes with it), dissolved into one plan, or deleted with its plans.
class DivePlanSeriesWrites extends WritableEntry {
  DivePlanSeriesWrites(this._r);

  final RecordRepositories _r;

  static const _copy = 'duplicate_of';
  static const _dissolve = 'dissolve_keeping_plan_id';

  @override
  String get name => 'dive_plan_series';

  @override
  String get table => 'dive_plan_series';

  @override
  String get note =>
      'plan_ids are the series\' dives in order, a selection of the ones it '
      'holds; a plan left out is deleted. $_dissolve turns the series back '
      'into that one plan, deleting the rest. A new series is a copy, '
      '$_copy.';

  @override
  late final Map<String, FieldCodec> fields = {
    'name': const FieldCodec.text(maxLength: 200, trim: true),
    'plan_ids': const FieldCodec.textList(maxItems: 20),
    _dissolve: const FieldCodec.reference('dive_plans'),
    _copy: const FieldCodec.reference('dive_plan_series'),
  };

  @override
  Set<String> get requiredOnCreate => const {_copy};

  @override
  Set<String> get createOnly => const {_copy};

  @override
  Set<String> get effectFields => const {_dissolve};

  @override
  Future<Map<String, Object?>> stored(
    String id,
    Map<String, Object?> document,
  ) async => {
    ...document,
    'plan_ids': [
      for (final d in document['dives'] as List? ?? const [])
        (d as Map)['plan_id'],
    ],
  };

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind != ChangeKind.update) return null;
    final held = [
      for (final d in check.document?['dives'] as List? ?? const [])
        (d as Map)['plan_id'] as String,
    ];
    final v = check.values;
    if (v.containsKey(_dissolve) && v.containsKey('plan_ids')) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'Dissolve a series in a change of its own.',
      );
    }
    if (v[_dissolve] case final String keep when !held.contains(keep)) {
      return PlanBlock(
        BlockReason.invalidValue,
        '$_dissolve: $keep is not a dive of this series.',
      );
    }
    if (v['plan_ids'] case final Object raw) {
      final ids = _texts(raw);
      if (ids.isEmpty || ids.any((id) => !held.contains(id))) {
        return const PlanBlock(
          BlockReason.invalidValue,
          'plan_ids: one or more of the series\' own dives.',
        );
      }
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
    final held = (document['plan_ids'] as List? ?? const []).length;
    final v = update.values;
    final kept = v.containsKey(_dissolve)
        ? 1
        : v['plan_ids'] == null
        ? held
        : _texts(v['plan_ids']!).length;
    final dropped = held - kept;
    return SideEffects(parts: {if (dropped > 0) 'dive_plans': dropped});
  }

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async {
    final series = await _r.divePlanSeries.getSeries(id);
    final n = series?.dives.length ?? 0;
    return DeleteReach(records: {if (n > 0) 'dive_plans': n});
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final from = values[_copy]! as String;
    final copy =
        await _r.divePlanSeries.duplicateSeries(from) ??
        (throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Series $from no longer exists.',
          details: {'id': from},
        ));
    if (values['name'] case final String name) {
      await _r.divePlanSeries.renameSeries(copy.id, name);
    }
    return copy.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final v = update.values;
    final repo = _r.divePlanSeries;
    if (v[_dissolve] case final String keep) {
      await repo.dissolveSeries(id, keepPlanId: keep);
      return;
    }
    if (v['plan_ids'] case final Object raw) {
      final series = await _series(id);
      final byPlan = {for (final d in series.dives) d.plan.id: d};
      await repo.saveSeries(
        StoredSeries(
          id: series.id,
          name: v['name'] as String? ?? series.name,
          diverId: series.diverId,
          followedDiveId: series.followedDiveId,
          dives: [for (final planId in _texts(raw)) byPlan[planId]!],
        ),
      );
      return;
    }
    if (v['name'] case final String name) {
      await repo.renameSeries(id, name);
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.divePlanSeries.deleteSeries(id);

  Future<StoredSeries> _series(String id) async =>
      await _r.divePlanSeries.getSeries(id) ??
      (throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        'Series $id no longer exists.',
        details: {'id': id},
      ));

  static List<String> _texts(Object raw) => raw is String
      ? [
          for (final t
              in (const FieldCodec.textList().wire(raw) as List? ?? const []))
            '$t',
        ]
      : [for (final t in raw as List) '$t'];
}
