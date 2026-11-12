import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_plan_series_create.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/planner/data/services/plan_engine_settings.dart';
import 'package:submersion/features/planner/data/services/stored_series_results.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart'
    show AppSettings;

/// Repetitive dive series, through the repository the planner saves them
/// with. A series is created from its dives, as `compute_plan` takes them,
/// or as a copy of another; here it is renamed, its dives kept, reordered
/// or dropped (a dropped dive's plan goes with it), dissolved into one
/// plan, or deleted with its plans.
class DivePlanSeriesWrites extends WritableEntry {
  /// [followOf] reads the logged dive a new series follows, as
  /// `compute_plan` reads it; without it a series cannot follow one.
  DivePlanSeriesWrites(this._r, {SeriesFollowReader? followOf})
    : _followOf = followOf;

  final RecordRepositories _r;
  final SeriesFollowReader? _followOf;

  static const _copy = 'duplicate_of';
  static const _dissolve = 'dissolve_keeping_plan_id';
  static const _dives = 'dives';
  static const _follow = 'followed_dive_id';

  @override
  String get name => 'dive_plan_series';

  @override
  String get table => 'dive_plan_series';

  @override
  String get note =>
      'plan_ids are the series\' dives in order, a selection of the ones it '
      'holds; a plan left out is deleted. $_dissolve turns the series back '
      'into that one plan, deleting the rest. A new series takes a name and '
      '$_dives, as compute_plan takes them (a dive\'s resolved_inputs save '
      'unchanged), and $_follow for the logged dive it follows; or it is a '
      'copy, $_copy. A single dive is a dive_plans record.';

  @override
  late final Map<String, FieldCodec> fields = {
    'name': const FieldCodec.text(maxLength: 200, trim: true),
    'plan_ids': const FieldCodec.textList(maxItems: 20),
    _dissolve: const FieldCodec.reference('dive_plans'),
    _copy: const FieldCodec.reference('dive_plan_series'),
    _dives: const PlanSeriesDivesCodec(),
    _follow: const FieldCodec.reference('dives'),
  };

  @override
  Set<String> get requiredOnCreate => const {};

  @override
  Set<String> get createOnly => const {_copy, _dives, _follow};

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
    if (check.kind == ChangeKind.create) return _refuseCreate(check);
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

  Future<PlanBlock?> _refuseCreate(WriteCheck check) async {
    final v = check.values;
    final dives = v[_dives];
    if (v[_copy] != null) {
      return dives != null || v[_follow] != null
          ? const PlanBlock(
              BlockReason.notPermitted,
              'A copy takes its dives, and the dive it follows, from '
              '$_copy.',
            )
          : null;
    }
    if (dives == null) {
      return const PlanBlock(
        BlockReason.missingField,
        'A new dive_plan_series record needs $_dives, or $_copy.',
      );
    }
    if (v['name'] == null) {
      return const PlanBlock(
        BlockReason.missingField,
        'A new dive_plan_series record needs a name.',
      );
    }
    if (seriesDiveCountProblem(dives) case final problem?) {
      return PlanBlock(BlockReason.invalidValue, problem);
    }
    try {
      await _built(v, check.ownerId!);
    } on AgentToolException catch (e) {
      final field = e.details?['field'];
      return PlanBlock(
        BlockReason.invalidValue,
        field == null ? e.message : '$field: ${e.message}',
      );
    }
    return null;
  }

  @override
  Future<Map<String, int>> alsoCreates(
    String diverId,
    Map<String, Object?> values,
  ) async => {
    if (values[_dives] case final Object dives)
      'dive_plans': PlanSeriesDivesCodec.dives(dives).length,
  };

  /// The series [values] create from their dives, computed with [diverId]'s
  /// planner settings, as the planner computes a series it saves for them.
  Future<StoredSeries> _built(
    Map<String, Object?> values,
    String diverId,
  ) async {
    final settings = await _r.diverSettings.getSettingsForDiver(diverId);
    return seriesFromDives(
      dives: values[_dives],
      name: values['name']! as String,
      diverId: diverId,
      followedDiveId: values[_follow] as String?,
      config: planEngineConfigFromSettings(settings ?? const AppSettings()),
      followOf: _followOf,
    );
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
    if (values[_copy] == null) {
      final saved = await _r.divePlanSeries.saveSeries(
        await _built(values, diverId),
      );
      return saved.id;
    }
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
