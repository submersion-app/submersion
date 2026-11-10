import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart' show TankRole, WaterType;
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/core/utils/gas_percent.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/object_list_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';

/// What a dive plan is made of, as an agent writes it: shared by the
/// `dive_plans` write family, which saves a plan, and `compute_plan`, which
/// computes one, so whatever one takes the other takes the same way (issue
/// #4203).

/// The plan settings an agent sets, by document key, as plain numbers.
const planNumberFields = {
  'altitude_m': FieldCodec.number(min: -500, max: 6000, nullable: true),
  'salinity_ppt': FieldCodec.number(min: 0, max: 50, nullable: true),
  'descent_rate_m_min': FieldCodec.number(min: 1, max: 60, nullable: true),
  'ascent_rate_m_min': FieldCodec.number(min: 1, max: 30, nullable: true),
  'intermediate_ascent_rate_m_min': FieldCodec.number(
    min: 1,
    max: 30,
    nullable: true,
  ),
  'shallow_ascent_rate_m_min': FieldCodec.number(
    min: 1,
    max: 30,
    nullable: true,
  ),
  'final_ascent_rate_m_min': FieldCodec.number(min: 1, max: 30, nullable: true),
  'last_stop_depth_m': FieldCodec.number(min: 3, max: 9, nullable: true),
  'sac_bottom_l_min': FieldCodec.number(min: 1, max: 100, nullable: true),
  'sac_deco_l_min': FieldCodec.number(min: 1, max: 100, nullable: true),
  'sac_factor': FieldCodec.number(min: 1, max: 5, nullable: true),
  'reserve_pressure_bar': FieldCodec.number(min: 0, max: 300, nullable: true),
  'ppo2_bottom_bar': FieldCodec.number(min: 0.16, max: 2, nullable: true),
  'ppo2_deco_bar': FieldCodec.number(min: 0.16, max: 2, nullable: true),
};

/// The settings a plan can hold its own value for, by document key: an
/// unset one follows the diver's Settings.
final Map<String, FieldCodec> planSettingFields = {
  'water_type': FieldCodec.enumName(WaterType.values, nullable: true),
  'gf_low': const FieldCodec.integer(min: 1, max: 100, nullable: true),
  'gf_high': const FieldCodec.integer(min: 1, max: 100, nullable: true),
  ...planNumberFields,
  'gas_switch_stop_s': const FieldCodec.integer(
    min: 0,
    max: 600,
    nullable: true,
  ),
  'problem_solving_minutes': const FieldCodec.integer(
    min: 0,
    max: 60,
    nullable: true,
  ),
  'o2_narcotic': const FieldCodec.flag(nullable: true),
};

/// A plan's tanks, written whole and in order.
final planTanksField = ObjectListCodec(
  {
    'name': const FieldCodec.text(maxLength: 60, nullable: true, trim: true),
    'volume_l': const FieldCodec.number(min: 0.1, max: 100, nullable: true),
    'working_pressure_bar': const FieldCodec.number(
      min: 1,
      max: 400,
      nullable: true,
    ),
    'start_pressure_bar': const FieldCodec.number(
      min: 0,
      max: 400,
      nullable: true,
    ),
    'o2_fraction': const FieldCodec.number(min: 0.05, max: 1),
    'he_fraction': const FieldCodec.number(min: 0, max: 0.95),
    // A plan holds breathing gas only: a suit inflation bottle is refused
    // (issue #4243).
    'role': FieldCodec.enumName(TankRole.values.where((r) => r.isBreathingGas)),
    'deco_switch_depth_m': const FieldCodec.number(
      min: 0,
      max: 350,
      nullable: true,
    ),
  },
  defaults: {
    'o2_fraction': 0.21,
    'he_fraction': 0.0,
    'role': TankRole.backGas.name,
  },
  rule: _tankRule,
  maxItems: 12,
);

/// A plan's segments, written whole and in order. Each names its tank by
/// place in the plan's tanks.
const planSegmentsField = ObjectListCodec(
  {
    'target_depth_m': FieldCodec.number(min: 0, max: 350),
    'duration_s': FieldCodec.integer(min: 0, max: 86400),
    'tank': FieldCodec.integer(min: 0, max: 11),
    'setpoint_bar': FieldCodec.number(min: 0.2, max: 1.6, nullable: true),
    'split_at_configured_rate': FieldCodec.flag(),
  },
  defaults: {'split_at_configured_rate': false},
  maxItems: 100,
);

/// Everything of a plan an agent writes but its name, notes, site and
/// dive link: what computing it takes.
final Map<String, FieldCodec> planComputeFields = {
  'mode': FieldCodec.enumName(PlanMode.values),
  'start_date_time': const FieldCodec.wallClock(nullable: true),
  ...planSettingFields,
  'tanks': planTanksField,
  'segments': planSegmentsField,
};

String? _tankRule(Map<String, Object?> tank) =>
    (tank['o2_fraction']! as num) + (tank['he_fraction']! as num) > 1
    ? 'o2_fraction and he_fraction add to more than 1.'
    : null;

/// Why [segments], parsed by [planSegmentsField], cannot stand with
/// [tankCount] tanks, or null when every segment names a tank there is.
String? segmentTankProblem(List<Map<String, Object?>> segments, int tankCount) {
  for (final (i, s) in segments.indexed) {
    if ((s['tank']! as int) >= tankCount) {
      return 'segments: segment $i names tank ${s['tank']}, which tanks '
          'lacks.';
    }
  }
  return null;
}

const _uuid = Uuid();

/// [plan] with [values], parsed by the fields above, written over it. Tanks
/// keep the ids of the stored tanks at the same places, and segments those
/// of the segments; new ones take ids from [newId].
DivePlan applyPlanValues(
  DivePlan plan,
  Map<String, Object?> values, {
  String Function()? newId,
}) {
  final id = newId ?? _uuid.v4;
  bool clears(String key) => values.containsKey(key) && values[key] == null;
  double? number(String key) => (values[key] as num?)?.toDouble();
  final tanks = values.containsKey('tanks')
      ? [
          for (final (i, t) in ObjectListCodec.items(values['tanks']).indexed)
            DiveTank(
              id: i < plan.tanks.length ? plan.tanks[i].id : id(),
              name: t['name'] as String?,
              volume: (t['volume_l'] as num?)?.toDouble(),
              workingPressure: (t['working_pressure_bar'] as num?)?.toDouble(),
              startPressure: (t['start_pressure_bar'] as num?)?.toDouble(),
              // Without float noise, so 0.28 is the 28% a logged tank holds
              // and the planner carries a pressure between the two.
              gasMix: GasMix(
                o2: gasPercentOfFraction((t['o2_fraction']! as num).toDouble()),
                he: gasPercentOfFraction((t['he_fraction']! as num).toDouble()),
              ),
              role: TankRole.values.byName(t['role']! as String),
              order: i,
              decoSwitchDepth: (t['deco_switch_depth_m'] as num?)?.toDouble(),
            ),
        ]
      : plan.tanks;
  final segments = values.containsKey('segments')
      ? [
          for (final (i, s) in ObjectListCodec.items(
            values['segments'],
          ).indexed)
            PlanSegment(
              id: i < plan.segments.length ? plan.segments[i].id : id(),
              targetDepth: (s['target_depth_m']! as num).toDouble(),
              durationSeconds: s['duration_s']! as int,
              tankId: tanks[s['tank']! as int].id,
              gasMix: tanks[s['tank']! as int].gasMix,
              setpointBar: (s['setpoint_bar'] as num?)?.toDouble(),
              splitAtConfiguredRate:
                  s['split_at_configured_rate'] as bool? ?? false,
              order: i,
            ),
        ]
      : plan.segments;
  return plan.copyWith(
    name: values['name'] as String?,
    notes: values['notes'] as String?,
    siteId: values['site_id'] as String?,
    clearSiteId: clears('site_id'),
    mode: values.containsKey('mode')
        ? PlanMode.values.byName(values['mode']! as String)
        : null,
    startDateTime: switch (values['start_date_time']) {
      final DateTime at => fromWallClockUtc(at),
      _ => null,
    },
    clearStartDateTime: clears('start_date_time'),
    waterType: values.containsKey('water_type') && values['water_type'] != null
        ? WaterType.values.byName(values['water_type']! as String)
        : null,
    clearWaterType: clears('water_type'),
    gfLow: values['gf_low'] as int?,
    clearGfLow: clears('gf_low'),
    gfHigh: values['gf_high'] as int?,
    clearGfHigh: clears('gf_high'),
    altitude: number('altitude_m'),
    clearAltitude: clears('altitude_m'),
    salinityPpt: number('salinity_ppt'),
    clearSalinityPpt: clears('salinity_ppt'),
    descentRate: number('descent_rate_m_min'),
    clearDescentRate: clears('descent_rate_m_min'),
    ascentRate: number('ascent_rate_m_min'),
    clearAscentRate: clears('ascent_rate_m_min'),
    intermediateAscentRate: number('intermediate_ascent_rate_m_min'),
    clearIntermediateAscentRate: clears('intermediate_ascent_rate_m_min'),
    shallowAscentRate: number('shallow_ascent_rate_m_min'),
    clearShallowAscentRate: clears('shallow_ascent_rate_m_min'),
    finalAscentRate: number('final_ascent_rate_m_min'),
    clearFinalAscentRate: clears('final_ascent_rate_m_min'),
    lastStopDepth: number('last_stop_depth_m'),
    clearLastStopDepth: clears('last_stop_depth_m'),
    gasSwitchStopSeconds: values['gas_switch_stop_s'] as int?,
    clearGasSwitchStopSeconds: clears('gas_switch_stop_s'),
    sacBottom: number('sac_bottom_l_min'),
    clearSacBottom: clears('sac_bottom_l_min'),
    sacDeco: number('sac_deco_l_min'),
    clearSacDeco: clears('sac_deco_l_min'),
    sacFactor: number('sac_factor'),
    clearSacFactor: clears('sac_factor'),
    problemSolvingMinutes: values['problem_solving_minutes'] as int?,
    clearProblemSolvingMinutes: clears('problem_solving_minutes'),
    o2Narcotic: values['o2_narcotic'] as bool?,
    clearO2Narcotic: clears('o2_narcotic'),
    reservePressure: number('reserve_pressure_bar'),
    clearReservePressure: clears('reserve_pressure_bar'),
    ppO2Bottom: number('ppo2_bottom_bar'),
    clearPpO2Bottom: clears('ppo2_bottom_bar'),
    ppO2Deco: number('ppo2_deco_bar'),
    clearPpO2Deco: clears('ppo2_deco_bar'),
    tanks: tanks,
    segments: segments,
  );
}
