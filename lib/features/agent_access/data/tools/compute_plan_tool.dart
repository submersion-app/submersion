import 'package:clock/clock.dart';

import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/agent_access/data/planning/plan_recall.dart';
import 'package:submersion/features/agent_access/data/planning/plan_request.dart';
import 'package:submersion/features/agent_access/data/planning/plan_request_series.dart';
import 'package:submersion/features/agent_access/data/planning/plan_result_document.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_plan_fields.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/planner/data/services/plan_engine_settings.dart';
import 'package:submersion/features/planner/data/services/stored_series_results.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart'
    show AppSettings;

/// Computes a dive, or a repetitive series, as the planner computes it, with
/// a diver's own planner settings (issue #4203). Writes nothing.
class ComputePlanTool implements AgentTool {
  ComputePlanTool({
    required DiverContextLoader loader,
    required DiverSettingsRepository settings,
    required SeriesFollowReader followOf,
    required RecordRepositories records,
    required String Function() caveat,
    DateTime Function()? now,
  }) : _loader = loader,
       _settings = settings,
       _followOf = followOf,
       _recall = PlanRecall(
         loader: loader,
         settings: settings,
         records: records,
         followOf: followOf,
       ),
       _caveat = caveat,
       _now = now ?? clock.now;

  final DiverContextLoader _loader;
  final DiverSettingsRepository _settings;
  final SeriesFollowReader _followOf;
  final PlanRecall _recall;
  final String Function() _caveat;
  final DateTime Function() _now;

  @override
  String get name => 'compute_plan';

  @override
  String get description =>
      'Compute a dive plan, or a repetitive series of up to '
      '$maxPlanRequestDives dives, with Submersion\'s own planner '
      '(Buhlmann ZH-L16C with gradient factors) and the diver\'s planner '
      'Settings for whatever the plan leaves out. Writes nothing. Returns, '
      'per dive: the schedule (with the whole-minute duration and runtime '
      'columns the printed slate shows; travel between stops has no row of '
      'its own, so a stop row lists it in folded_travel and its '
      'duration_min covers that travel as well as duration_s at the stop; '
      'an ascent row is labelled with the depth it reaches, but its '
      'ppo2_bar and end_m are taken at its deeper end, the leg\'s worst), '
      'stops, runtime, NDL and TTS at the bottom (ndl_at_bottom_s is null '
      'and in_deco_at_bottom true once the bottom is in deco), gas use per '
      'tank (litres_used is the dive itself; problem_solving_litres is the '
      'allowance of problem_solving_minutes at the deepest point on bottom '
      'SAC x sac_factor, held back and not part of litres_used; minimum gas '
      'is checked against bottom_end_pressure_bar, the cylinder as the '
      'diver leaves the deepest point: under min_gas_ascent_bar is '
      'critical, under min_gas_bar a warning; '
      'a tank with no volume_l is priced as 11 litres, so give every '
      'tank\'s volume_l for its pressures to mean anything), '
      'CNS and OTU, what it carried in from the '
      'dives before (carried_in.tissue_loading is the tissues as the dive '
      'starts, after the surface interval: the leading compartment, its '
      'percent of the surface M-value, surface_gf_percent, and each '
      'compartment\'s N2 and He in bar), issues (every warning the planner raises), effective_settings '
      '(each value used and whether it came from the plan, Settings or the '
      'default), and resolved_inputs (what was computed, the bottom '
      'shorthand written out; all of it but surface_interval_s and '
      'carries_from_tank, which only this tool takes, saves unchanged '
      'through the dive_plans write family). $kDocumentDateRule Inputs and results are '
      'metric; present them '
      'in the diver\'s units (see the units resource). To recall a saved '
      'plan, give its plan_id (a dive_plans record in no series) or '
      'series_id (a dive_plan_series record) instead of dives, with '
      'overrides for any setting to try on top: it is computed now with '
      'the diver\'s current Settings and, for a series following a logged '
      'dive, with that dive as it is now, so say so when the schedule may '
      'differ from the one saved (see recall_note). Each recalled dive '
      'also gives its log_state (planned, logged_as_planned or dived) and '
      'linked_dive_id; a dived dive keeps its planned schedule, and the '
      'dives after it carry in what the log says it left. A recalled '
      'dive\'s resolved_inputs compute it again as dives, with '
      'follow_dive_id set to followed_dive_id when followed_dive_in_log; '
      'once a dive is dived, the dives after it compute again only as '
      'planned. A saved plan\'s settings this tool does not take (stop '
      'minimums, deco ppO2 bands, max O2 depth, setpoints, a segment\'s '
      'mode override) still compute '
      'the recall but are not in resolved_inputs; read them from the '
      'dive_plans record. Always pass on every '
      'issue and the caveat, state the parameters the schedule depends on, '
      'and never present a schedule as safe, verified or guaranteed: it is '
      'a plan for a trained diver to check, not a dive computer.';

  @override
  Map<String, Object?> get inputSchema => {
    'type': 'object',
    'properties': {
      'diver_id': {
        'type': 'string',
        'description':
            'Whose planner Settings to compute with; omitted means the '
            'active profile, or for a recalled series its own diver.',
      },
      'plan_id': {
        'type': 'string',
        'description':
            'Recall this saved plan (a dive_plans id) instead of giving '
            'dives. A plan in a series is recalled by its series_id.',
      },
      'series_id': {
        'type': 'string',
        'description':
            'Recall this saved series (a dive_plan_series id) instead of '
            'giving dives.',
      },
      'overrides': {
        'type': 'object',
        'additionalProperties': false,
        'description':
            'With plan_id or series_id: settings written over every dive '
            'of the recalled plan for this computation only, saving '
            'nothing; null clears the plan\'s own value so Settings decide.',
        'properties': {
          for (final MapEntry(:key, value: codec) in planSettingFields.entries)
            key: {'description': codec.describe},
        },
      },
      'follow_dive_id': {
        'type': 'string',
        'description':
            'A logged dive the first dive follows: it starts with the '
            'tissue loading, CNS and OTU that dive and those before it '
            'left, and its tanks can carry that dive\'s end pressures.',
      },
      'dives': {
        'type': 'array',
        'minItems': 1,
        'maxItems': maxPlanRequestDives,
        'description':
            'The dives in order. A dive after the first takes the dive '
            'before\'s mode, settings and tanks for any it leaves out; '
            'segments or bottom are always its own.',
        'items': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            for (final MapEntry(:key, value: codec)
                in planComputeFields.entries)
              key: {'description': codec.describe},
            // The lists by their item shape, as the parser reads them.
            'tanks': {
              'type': 'array',
              'maxItems': planTanksField.maxItems,
              'description':
                  'The cylinders, in order; a segment names one by its '
                  'place here. ${planTanksField.describe}.',
              'items': planTanksField.itemSchema,
            },
            'segments': {
              'type': 'array',
              'maxItems': planSegmentsField.maxItems,
              'description':
                  'The profile: each segment goes to target_depth_m over '
                  'duration_s on the tank at place tank in tanks, with '
                  'setpoint_bar for a loop; split_at_configured_rate '
                  'travels at the configured rate then holds. The planner '
                  'adds the ascent and stops. '
                  '${planSegmentsField.describe}.',
              'items': planSegmentsField.itemSchema,
            },
            'bottom': {
              'type': 'object',
              'description':
                  'Shorthand for segments: descend to depth_m at the '
                  'descent rate, then stay time_s seconds (time at depth, '
                  'not counting the descent) on tank (default 0, or the '
                  'first diluent for a ccr dive).',
              'properties': {
                'depth_m': {'type': 'number'},
                'time_s': {'type': 'integer'},
                'tank': {'type': 'integer'},
              },
              'required': ['depth_m', 'time_s'],
              // As the parser reads it: any other key is refused.
              'additionalProperties': false,
            },
            'surface_interval_s': {
              'type': 'integer',
              'description':
                  'Seconds since the dive before ended; for the first dive, '
                  'since the followed dive (default: the time since it '
                  'ended, at least an hour). A dive after the first needs '
                  'this or start_date_time, and takes start_date_time only '
                  'when the first dive has one or follow_dive_id is given.',
            },
            'carries_from_tank': {
              'type': 'array',
              'items': {
                'type': ['integer', 'null'],
              },
              'description':
                  'One entry per tank: the place of the tank in the dive '
                  'before (or the followed dive) it continues, or null to '
                  'start at its own start_pressure_bar. A tank continues '
                  'only the same cylinder, the same volume_l, '
                  'working_pressure_bar and gas, and starts at that tank\'s '
                  'end pressure; linked to a different one it starts full, '
                  'and a followed tank whose log has no end pressure starts '
                  'at what that logged tank started with. Omitted: tanks '
                  'taken from the dive before continue their own; tanks of '
                  'its own continue the same cylinder, if there is one.',
            },
          },
        },
      },
    },
    'additionalProperties': false,
  };

  @override
  Future<Map<String, Object?>> call(
    Map<String, Object?> args,
    AgentToolContext context,
  ) async {
    if (PlanRecall.asks(args)) return _recall(args, caveat: _caveat());
    if (PlanRecall.strayOverrides(args) case final refusal?) throw refusal;
    final diverId = await _loader.resolveDiverId(
      optionalIdArg(args, 'diver_id'),
    );
    final config = planEngineConfigFromSettings(
      await _settings.getSettingsForDiver(diverId) ?? const AppSettings(),
    );
    final request = parsePlanRequest(args, settings: config);
    final followedId = request.followDiveId;
    final follow = followedId == null ? null : await _followOf(followedId);
    if (followedId != null && follow == null) {
      throw AgentToolException(
        AgentToolErrorCode.notFound,
        'No logged dive has id "$followedId".',
        details: {'follow_dive_id': followedId},
      );
    }
    final built = storedSeriesFor(request, follow: follow, now: _now());
    final computed = computeSeriesFromStored(
      built.stored,
      follow: follow,
      config: config,
    );
    return {
      'diver_id': diverId,
      'followed_dive_id': followedId,
      'dives': [
        for (final (i, result) in computed.results.indexed)
          {
            'index': i,
            ...planResultDocument(
              result,
              plan: built.stored.dives[i].plan,
              config: config,
              inputs: built.inputs[i],
            ),
          },
      ],
      'caveat': _caveat(),
    };
  }
}
