import 'package:submersion/core/constants/enums.dart' show TankRole;
import 'package:submersion/features/agent_access/data/writes/families/dive_plan_fields.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/object_list_codec.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// The most dives one `compute_plan` call computes.
const maxPlanRequestDives = 10;

/// One dive of a [PlanRequest].
class PlanRequestDive {
  const PlanRequestDive({
    required this.values,
    required this.inputs,
    required this.tanksGiven,
    this.surfaceInterval,
    this.fixedStart = false,
    this.carriesFromTank,
  });

  /// Its plan fields as the `dive_plans` write family parses them, for
  /// [applyPlanValues]: what it gave, and what it took from the dive before.
  final Map<String, Object?> values;

  /// [values] as JSON, with the `bottom` shorthand written out as segments:
  /// what the dive was computed from. Its plan fields are in the shape a
  /// `dive_plans` save takes; `surface_interval_s` and `carries_from_tank`
  /// are `compute_plan`'s own.
  final Map<String, Object?> inputs;

  /// Whether it gave its own tanks rather than taking the dive before's.
  final bool tanksGiven;

  /// The gap since the dive before, or since the followed dive for a
  /// first dive; null when [fixedStart], or for a first dive following
  /// nothing, or one following a dive that left the interval to the
  /// planner's default.
  final Duration? surfaceInterval;

  /// Whether it starts at its own `start_date_time`, its surface interval
  /// then following from it.
  final bool fixedStart;

  /// For each of its tanks, the place of the tank it carries from in the
  /// dive before (or the followed dive), or null for none. Null when it
  /// did not say, so tanks are matched as the planner matches them.
  final List<int?>? carriesFromTank;
}

/// What `compute_plan` was asked to compute (issue #4203): one dive, or a
/// series, and the logged dive it follows.
class PlanRequest {
  const PlanRequest({required this.dives, this.followDiveId});

  final List<PlanRequestDive> dives;
  final String? followDiveId;
}

const _bottom = 'bottom';
const _interval = 'surface_interval_s';
const _carries = 'carries_from_tank';
const _start = 'start_date_time';

/// The longest surface interval a dive takes. Following a logged dive
/// defaults to the time since it ended, however old, and writes that into
/// the dive's inputs, so this must hold any dive a log can have.
const _maxIntervalSeconds = 100 * 365 * 86400;

/// The keys a dive takes from the dive before when it leaves them out, as a
/// dive the planner adds copies its settings.
final _inherited = ['mode', ...planSettingFields.keys];

/// Reads `compute_plan`'s arguments. [settings] are the diver's, for the
/// descent the `bottom` shorthand writes out when the plan sets no rate of
/// its own. Throws an [AgentToolException] naming the field at fault.
PlanRequest parsePlanRequest(
  Map<String, Object?> args, {
  required PlanEngineConfig settings,
}) {
  final follow = args['follow_dive_id'];
  if (follow != null && follow is! String) {
    throw _refuse('follow_dive_id', 'follow_dive_id takes a dive id.');
  }
  final raw = args['dives'];
  if (raw is! List || raw.isEmpty || raw.length > maxPlanRequestDives) {
    throw _refuse(
      'dives',
      'dives takes a list of 1 to $maxPlanRequestDives dives.',
    );
  }
  final dives = <PlanRequestDive>[];
  for (final (index, dive) in raw.indexed) {
    if (dive is! Map) throw _refuse('dives[$index]', 'Each dive is an object.');
    dives.add(
      _dive(
        dive.cast<String, Object?>(),
        index: index,
        previous: dives.lastOrNull,
        follows: follow != null,
        // A series has a clock only when its first dive has a start or it
        // follows a logged dive: every later start is measured from that.
        timed: follow != null || (dives.firstOrNull?.fixedStart ?? false),
        settings: settings,
      ),
    );
  }
  return PlanRequest(dives: dives, followDiveId: follow as String?);
}

PlanRequestDive _dive(
  Map<String, Object?> raw, {
  required int index,
  required PlanRequestDive? previous,
  required bool follows,
  required bool timed,
  required PlanEngineConfig settings,
}) {
  final at = 'dives[$index]';
  for (final key in raw.keys) {
    if (!planComputeFields.containsKey(key) &&
        key != _bottom &&
        key != _interval &&
        key != _carries) {
      throw _refuse('$at.$key', 'A dive has no $key.');
    }
  }

  // [field] names what the agent sent, when it is not [key] itself.
  Object? parse(String key, Object? value, {String? field}) {
    try {
      return planComputeFields[key]!.parse(value);
    } on FieldRefusal catch (refusal) {
      throw _refuse('$at.${field ?? key}', '$key: ${refusal.reason}');
    }
  }

  final values = <String, Object?>{
    if (previous != null)
      for (final key in _inherited)
        if (previous.values.containsKey(key)) key: previous.values[key],
  };
  for (final entry in raw.entries) {
    if (planComputeFields.containsKey(entry.key) && entry.key != 'segments') {
      values[entry.key] = parse(entry.key, entry.value);
    }
  }
  values['mode'] ??= PlanMode.oc.name;

  final tanksGiven = raw.containsKey('tanks');
  if (!tanksGiven) {
    if (previous == null) {
      throw _refuse('$at.tanks', 'The first dive needs tanks.');
    }
    values['tanks'] = previous.values['tanks'];
  }
  final tanks = ObjectListCodec.items(values['tanks']);
  final tankCount = tanks.length;
  if (tankCount == 0) throw _refuse('$at.tanks', 'A dive needs a tank.');

  final hasSegments = raw.containsKey('segments');
  final hasBottom = raw.containsKey(_bottom);
  if (hasSegments && hasBottom) {
    throw _refuse('$at.$_bottom', 'Give segments or bottom, not both.');
  }
  if (!hasSegments && !hasBottom) {
    throw _refuse('$at.segments', 'A dive needs segments, or bottom.');
  }
  // A refusal names what the agent sent: bottom, when it wrote no segments.
  final segmentsField = hasSegments ? 'segments' : _bottom;
  values['segments'] = hasSegments
      ? parse('segments', raw['segments'])
      : parse(
          'segments',
          _bottomSegments(
            raw[_bottom],
            at: '$at.$_bottom',
            descentRate:
                (values['descent_rate_m_min'] as num?)?.toDouble() ??
                settings.descentRate,
            defaultTank: _simplePlanTank(tanks, mode: values['mode']),
          ),
          field: segmentsField,
        );
  final segments = ObjectListCodec.items(values['segments']);
  if (segments.isEmpty) {
    throw _refuse('$at.$segmentsField', 'A dive needs a segment.');
  }
  if (segmentTankProblem(segments, tankCount) case final problem?) {
    throw _refuse('$at.$segmentsField', problem);
  }

  final carriesIn = previous != null || follows;
  final hasStart = values[_start] != null;
  final interval = raw[_interval];
  if (interval != null) {
    if (!carriesIn) {
      throw _refuse(
        '$at.$_interval',
        'The first dive has no surface interval unless it follows a logged '
            'dive (follow_dive_id).',
      );
    }
    if (interval is! int || interval < 0 || interval > _maxIntervalSeconds) {
      throw _refuse(
        '$at.$_interval',
        '$_interval takes whole seconds from 0 to $_maxIntervalSeconds.',
      );
    }
    if (hasStart) {
      throw _refuse('$at.$_start', 'Give $_interval or $_start, not both.');
    }
  } else if (previous != null && !hasStart) {
    throw _refuse(
      '$at.$_interval',
      'A dive after the first needs $_interval or $_start.',
    );
  }
  // With no clock to measure from, the planner drops a later dive's start
  // and computes it after its default interval instead.
  if (previous != null && hasStart && !timed) {
    throw _refuse(
      '$at.$_start',
      'A later dive starts at its own $_start only when the first dive has '
          'one or the series follows a logged dive; give $_interval instead.',
    );
  }

  final carries = _carriesFrom(
    raw[_carries],
    at: '$at.$_carries',
    tankCount: tankCount,
    previousTankCount: previous == null
        ? null
        : ObjectListCodec.items(previous.values['tanks']).length,
    carriesIn: carriesIn,
  );

  return PlanRequestDive(
    values: values,
    inputs: {
      for (final MapEntry(:key, :value) in values.entries)
        key: planComputeFields[key]!.wire(value),
      _interval: ?(interval as int?),
      _carries: ?carries,
    },
    tanksGiven: tanksGiven,
    surfaceInterval: interval == null ? null : Duration(seconds: interval),
    fixedStart: hasStart,
    carriesFromTank: carries,
  );
}

/// The tank the planner's simple plan breathes: a loop's first diluent,
/// else the first tank.
int _simplePlanTank(List<Map<String, Object?>> tanks, {required Object? mode}) {
  if (mode != PlanMode.ccr.name) return 0;
  final diluent = tanks.indexWhere((t) => t['role'] == TankRole.diluent.name);
  return diluent < 0 ? 0 : diluent;
}

/// The `bottom` shorthand as the planner's simple plan writes it: down to
/// its depth at [descentRate], then held there for its time, on
/// [defaultTank] unless it names one.
List<Map<String, Object?>> _bottomSegments(
  Object? raw, {
  required String at,
  required double descentRate,
  required int defaultTank,
}) {
  if (raw is! Map) {
    throw _refuse(at, 'bottom takes {depth_m, time_s, tank}.');
  }
  final unknown = raw.keys.where(
    (k) => !const {'depth_m', 'time_s', 'tank'}.contains(k),
  );
  if (unknown.isNotEmpty) {
    throw _refuse(at, 'bottom has no ${unknown.join(', ')}.');
  }
  final depth = raw['depth_m'];
  final time = raw['time_s'];
  final tank = raw['tank'] ?? defaultTank;
  if (depth is! num || depth <= 0 || depth > 350) {
    throw _refuse(at, 'bottom.depth_m takes metres above 0, to 350.');
  }
  if (time is! int || time <= 0 || time > 86400) {
    throw _refuse(at, 'bottom.time_s takes whole seconds above 0.');
  }
  if (tank is! int) throw _refuse(at, 'bottom.tank takes a tank\'s place.');
  return [
    {
      'target_depth_m': depth,
      'duration_s': PlanSegment.travelSeconds(
        metres: depth.toDouble(),
        ratePerMinute: descentRate,
      ),
      'tank': tank,
    },
    {'target_depth_m': depth, 'duration_s': time, 'tank': tank},
  ];
}

List<int?>? _carriesFrom(
  Object? raw, {
  required String at,
  required int tankCount,
  required int? previousTankCount,
  required bool carriesIn,
}) {
  if (raw == null) return null;
  if (!carriesIn) {
    throw _refuse(
      at,
      'The first dive carries from no tank unless it follows a logged dive.',
    );
  }
  if (raw is! List || raw.length != tankCount) {
    throw _refuse(
      at,
      '$_carries takes one entry per tank: a tank\'s place in the dive '
      'before, or null.',
    );
  }
  final seen = <int>{};
  for (final entry in raw) {
    if (entry == null) continue;
    final inRange =
        entry is int &&
        entry >= 0 &&
        (previousTankCount == null || entry < previousTankCount);
    if (!inRange || !seen.add(entry)) {
      throw _refuse(
        at,
        '$_carries: $entry is not a tank of the dive before, or is named '
        'twice.',
      );
    }
  }
  return raw.cast<int?>();
}

AgentToolException _refuse(String field, String message) => AgentToolException(
  AgentToolErrorCode.invalidArgument,
  message,
  details: {'field': field},
);
