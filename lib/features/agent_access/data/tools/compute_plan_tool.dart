import 'package:clock/clock.dart';

import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/agent_access/data/planning/plan_request.dart';
import 'package:submersion/features/agent_access/data/planning/plan_request_series.dart';
import 'package:submersion/features/agent_access/data/planning/plan_result_document.dart';
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
    required String Function() caveat,
    DateTime Function()? now,
  }) : _loader = loader,
       _settings = settings,
       _followOf = followOf,
       _caveat = caveat,
       _now = now ?? clock.now;

  final DiverContextLoader _loader;
  final DiverSettingsRepository _settings;
  final SeriesFollowReader _followOf;
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
      'tank (litres_used includes a problem-solving '
      'allowance of problem_solving_minutes at the deepest point on bottom '
      'SAC x sac_factor; set problem_solving_minutes to 0 to leave it out; '
      'a tank with no volume_l is priced as 11 litres, so give every '
      'tank\'s volume_l for its pressures to mean anything), '
      'CNS and OTU, what it carried in from the '
      'dives before, issues (every warning the planner raises), effective_settings '
      '(each value used and whether it came from the plan, Settings or the '
      'default), and resolved_inputs (what was computed, the bottom '
      'shorthand written out; all of it but surface_interval_s and '
      'carries_from_tank, which only this tool takes, saves unchanged '
      'through the dive_plans write family). $kDocumentDateRule Inputs and results are '
      'metric; present them '
      'in the diver\'s units (see the units resource). Always pass on every '
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
            'active profile.',
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
    'required': ['dives'],
    'additionalProperties': false,
  };

  @override
  Future<Map<String, Object?>> call(
    Map<String, Object?> args,
    AgentToolContext context,
  ) async {
    final diverId = await _loader.resolveDiverId(args['diver_id'] as String?);
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
