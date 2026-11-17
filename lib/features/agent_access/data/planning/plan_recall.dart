import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/documents/plan_documents.dart';
import 'package:submersion/features/agent_access/data/planning/plan_request.dart';
import 'package:submersion/features/agent_access/data/planning/plan_result_document.dart';
import 'package:submersion/features/agent_access/data/planning/stored_plan_inputs.dart';
import 'package:submersion/features/agent_access/data/records/families/plan_record_loads.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_plan_fields.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/planner/data/services/plan_engine_settings.dart';
import 'package:submersion/features/planner/data/services/stored_series_results.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart'
    show AppSettings;

/// The keys that ask `compute_plan` to recall a saved plan.
const recallKeys = ['plan_id', 'series_id'];

/// What a recall says about how it was computed, for the agent to tell
/// the diver when a recalled schedule differs from the one they saved.
const recallNote =
    'Computed now from the saved inputs: a saved plan stores no results. '
    'Settings the plan leaves unset come from the diver\'s planner Settings '
    'as they are now, and a series that follows a logged dive starts from '
    'that dive as it is in the log now, so this can differ from the '
    'schedule shown when the plan was saved; effective_settings says which '
    'values came from Settings. A dive already dived keeps its planned '
    'schedule here, and the dives after it carry in what the log says it '
    'left.';

/// A saved plan, or a saved series, computed as the planner computes it on
/// opening (issue #4203): `compute_plan` given `plan_id` or `series_id`
/// rather than `dives`. Each dive also says where it stands in the log.
class PlanRecall {
  PlanRecall({
    required DiverContextLoader loader,
    required DiverSettingsRepository settings,
    required RecordRepositories records,
    required SeriesFollowReader followOf,
  }) : _loader = loader,
       _settings = settings,
       _r = records,
       _followOf = followOf;

  final DiverContextLoader _loader;
  final DiverSettingsRepository _settings;
  final RecordRepositories _r;
  final SeriesFollowReader _followOf;

  /// Whether [args] ask for a recall rather than describe dives: an id is
  /// given. A key sent as null asks for nothing, as a client that writes
  /// out every optional argument sends it.
  static bool asks(Map<String, Object?> args) =>
      recallKeys.any((key) => args[key] != null);

  /// A refusal of `overrides` given without an id to recall, which would
  /// otherwise be computed without them and say nothing; null when there is
  /// nothing to refuse.
  static AgentToolException? strayOverrides(Map<String, Object?> args) =>
      args['overrides'] == null
      ? null
      : _refuse(
          'overrides',
          'overrides apply to a recalled plan, with plan_id or series_id; '
              'give the dives\' own settings in dives instead.',
        );

  /// The recall [args] ask for, with [caveat] the planner's own.
  Future<Map<String, Object?>> call(
    Map<String, Object?> args, {
    required String caveat,
  }) async {
    for (final key in const ['dives', 'follow_dive_id']) {
      if (args[key] != null) {
        throw _refuse(
          key,
          'A recall computes the saved plan as it was saved; give $key to '
          'describe dives instead, without plan_id or series_id.',
        );
      }
    }
    final planId = optionalIdArg(args, 'plan_id');
    final seriesId = optionalIdArg(args, 'series_id');
    if (planId != null && seriesId != null) {
      throw _refuse('plan_id', 'Give plan_id or series_id, not both.');
    }
    final overrides = parsePlanOverrides(args['overrides']);

    final stored = seriesId != null
        ? await _series(seriesId)
        : await _plan(planId!);
    final diverId = await _diverFor(
      optionalIdArg(args, 'diver_id'),
      owner: seriesId == null ? null : stored.diverId,
    );
    final config = planEngineConfigFromSettings(
      await _settings.getSettingsForDiver(diverId) ?? const AppSettings(),
    );
    final recalled = stored.copyWith(
      dives: [
        for (final dive in stored.dives)
          overrides.isEmpty
              ? dive
              : dive.copyWith(plan: applyPlanValues(dive.plan, overrides)),
      ],
    );

    final ({PlanSeries series, List<SeriesDiveResult> results}) computed;
    final List<Map<String, Object?>> inputs;
    if (seriesId != null) {
      computed = await computeStoredSeries(
        recalled,
        config: config,
        dives: _r.dives,
        followOf: _followOf,
      );
      inputs = seriesInputsOf(recalled, follow: computed.series.follow);
    } else {
      final plan = recalled.dives.single.plan;
      computed = await computeStoredPlan(
        plan,
        config: config,
        dives: _r.dives,
        followOf: _followOf,
      );
      inputs = [planInputsOf(plan, withStart: true)];
    }
    final plans = [for (final dive in recalled.dives) dive.plan];
    final logged = await loggedEntryFlags(_r, linkedDiveIds(plans));

    final followedId = recalled.followedDiveId;
    return {
      'diver_id': diverId,
      'recalled': {
        'series_id': ?seriesId,
        'plan_id': ?planId,
        'name': recalled.name,
        'overrides': overrides.keys.toList()..sort(),
      },
      'followed_dive_id': followedId,
      if (followedId != null)
        'followed_dive_in_log': computed.series.follow != null,
      'dives': [
        for (final (i, result) in computed.results.indexed)
          {
            'index': i,
            'plan_id': plans[i].id,
            'name': recalled.dives[i].name ?? plans[i].name,
            ...planLogFields(plans[i], logged),
            ...planResultDocument(
              result,
              plan: plans[i],
              config: config,
              inputs: inputs[i],
            ),
          },
      ],
      'recall_note': recallNote,
      'caveat': caveat,
    };
  }

  Future<StoredSeries> _series(String id) async {
    final series = await _r.divePlanSeries.getSeries(id);
    if (series == null) {
      throw AgentToolException(
        AgentToolErrorCode.notFound,
        'No saved series has id "$id".',
        details: {'series_id': id},
      );
    }
    if (series.dives.isEmpty) {
      throw _refuse('series_id', 'The saved series "$id" has no dives.');
    }
    return series;
  }

  /// A plan in no series, as a series of one, which is how the planner
  /// opens it.
  Future<StoredSeries> _plan(String id) async {
    final plan = await _r.divePlans.getPlan(id);
    if (plan == null) {
      throw AgentToolException(
        AgentToolErrorCode.notFound,
        'No saved plan has id "$id".',
        details: {'plan_id': id},
      );
    }
    final seriesId = await _r.divePlanSeries.seriesIdForPlan(id);
    if (seriesId != null) {
      throw AgentToolException(
        AgentToolErrorCode.invalidArgument,
        'The plan "$id" is a dive of the saved series "$seriesId", which '
        'carries tissue loading from one dive to the next; recall it with '
        'series_id "$seriesId".',
        details: {'field': 'plan_id', 'series_id': seriesId},
      );
    }
    return StoredSeries(
      id: id,
      name: plan.name,
      dives: [StoredSeriesDive(plan: plan)],
    );
  }

  /// Whose Settings compute it: [requested], else [owner], a series' own
  /// diver while that profile is still on the device, else the active one,
  /// as the planned dives action does.
  Future<String> _diverFor(String? requested, {required String? owner}) async {
    if (requested != null || owner == null) {
      return _loader.resolveDiverId(requested);
    }
    try {
      return await _loader.resolveDiverId(owner);
    } on AgentToolException catch (e) {
      if (e.code != AgentToolErrorCode.unknownDiver) rethrow;
      return _loader.resolveDiverId(null);
    }
  }
}

/// `overrides` as the `dive_plans` write family parses settings: values
/// written over every dive of the recalled plan, a null clearing the
/// plan's own so the diver's Settings decide. Only settings: the dives
/// themselves are recalled as saved.
Map<String, Object?> parsePlanOverrides(Object? raw) {
  if (raw == null) return const {};
  if (raw is! Map) {
    throw _refuse('overrides', 'overrides takes an object of settings.');
  }
  return {
    for (final MapEntry(:key, :value) in raw.cast<String, Object?>().entries)
      key: _override(key, value),
  };
}

Object? _override(String key, Object? value) {
  final codec = planSettingFields[key];
  if (codec == null) {
    throw _refuse(
      'overrides.$key',
      'overrides takes the plan settings only (${planSettingFields.keys.join(', ')}); '
          'it has no $key.',
    );
  }
  try {
    return codec.parse(value);
  } on FieldRefusal catch (refusal) {
    throw _refuse('overrides.$key', '$key: ${refusal.reason}');
  }
}

const _refuse = planArgumentRefusal;
