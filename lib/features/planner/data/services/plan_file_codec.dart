import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;

/// The `.subplan` file format: versioned JSON around the plan aggregate.
/// Version 1 carries every engine-relevant input; schedules are never
/// exported — the importing install recomputes them.
const subplanFormat = 'submersion-plan';
const subplanVersion = 1;
const subplanExtension = 'subplan';

const _uuid = Uuid();

/// Serializes [plan] into a shareable `.subplan` JSON string.
String planToSubplanJson(domain.DivePlan plan) {
  final map = {
    'format': subplanFormat,
    'version': subplanVersion,
    'plan': {
      'name': plan.name,
      'notes': plan.notes,
      'mode': plan.mode.name,
      'altitude': plan.altitude,
      'waterType': plan.waterType?.name,
      'gfLow': plan.gfLow,
      'gfHigh': plan.gfHigh,
      'descentRate': plan.descentRate,
      'ascentRate': plan.ascentRate,
      'lastStopDepth': plan.lastStopDepth,
      'gasSwitchStopSeconds': plan.gasSwitchStopSeconds,
      'airBreaks': plan.airBreaks == null
          ? null
          : {
              'o2Seconds': plan.airBreaks!.o2Seconds,
              'breakSeconds': plan.airBreaks!.breakSeconds,
            },
      'sacBottom': plan.sacBottom,
      'sacDeco': plan.sacDeco,
      'sacStressed': plan.sacStressed,
      'reservePressure': plan.reservePressure,
      'setpointLow': plan.setpointLow,
      'setpointHigh': plan.setpointHigh,
      'setpointSwitchDepth': plan.setpointSwitchDepth,
      'deviationDepthDelta': plan.deviationDepthDelta,
      'deviationTimeMinutes': plan.deviationTimeMinutes,
      'turnPressureRule': plan.turnPressureRule?.name,
      'turnPressureFraction': plan.turnPressureFraction,
      'tanks': [
        for (final tank in plan.tanks)
          {
            'key': tank.id,
            'name': tank.name,
            'volume': tank.volume,
            'workingPressure': tank.workingPressure,
            'startPressure': tank.startPressure,
            'o2': tank.gasMix.o2,
            'he': tank.gasMix.he,
            'role': tank.role.name,
            'order': tank.order,
          },
      ],
      'segments': [
        for (final segment in plan.segments)
          {
            'type': segment.type.name,
            'startDepth': segment.startDepth,
            'endDepth': segment.endDepth,
            'durationSeconds': segment.durationSeconds,
            'tankKey': segment.tankId,
            'o2': segment.gasMix.o2,
            'he': segment.gasMix.he,
            'rate': segment.rate,
            'order': segment.order,
          },
      ],
    },
  };
  return const JsonEncoder.withIndent('  ').convert(map);
}

/// Parses a `.subplan` JSON string into a fresh [domain.DivePlan].
///
/// All ids are regenerated (tank references are remapped through the
/// exported keys) so importing can never collide with existing rows.
/// Throws [FormatException] on a foreign format or a newer version.
domain.DivePlan subplanFromJson(String source, {DateTime? now}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException {
    throw const FormatException('Not a valid .subplan file');
  }
  if (decoded is! Map<String, dynamic> || decoded['format'] != subplanFormat) {
    throw const FormatException('Not a Submersion plan file');
  }
  final version = decoded['version'];
  if (version is! int || version > subplanVersion) {
    throw FormatException(
      'Plan file version $version is newer than this app supports',
    );
  }
  final plan = decoded['plan'];
  if (plan is! Map<String, dynamic>) {
    throw const FormatException('Plan file carries no plan');
  }

  final timestamp = now ?? DateTime.now();

  // Fresh tank ids, remembering the export keys for segment references.
  final tankIdByKey = <String, String>{};
  final tanks = <DiveTank>[];
  for (final (index, raw) in (plan['tanks'] as List? ?? const []).indexed) {
    final tank = raw as Map<String, dynamic>;
    final id = _uuid.v4();
    tankIdByKey[tank['key'] as String] = id;
    tanks.add(
      DiveTank(
        id: id,
        name: tank['name'] as String?,
        volume: (tank['volume'] as num?)?.toDouble(),
        workingPressure: (tank['workingPressure'] as num?)?.toDouble(),
        startPressure: (tank['startPressure'] as num?)?.toDouble(),
        gasMix: GasMix(
          o2: (tank['o2'] as num).toDouble(),
          he: (tank['he'] as num?)?.toDouble() ?? 0.0,
        ),
        role: TankRole.values.asNameMap()[tank['role']] ?? TankRole.backGas,
        order: (tank['order'] as num?)?.toInt() ?? index,
      ),
    );
  }

  final segments = <PlanSegment>[];
  for (final (index, raw) in (plan['segments'] as List? ?? const []).indexed) {
    final segment = raw as Map<String, dynamic>;
    segments.add(
      PlanSegment(
        id: _uuid.v4(),
        type:
            SegmentType.values.asNameMap()[segment['type']] ??
            SegmentType.bottom,
        startDepth: (segment['startDepth'] as num).toDouble(),
        endDepth: (segment['endDepth'] as num).toDouble(),
        durationSeconds: (segment['durationSeconds'] as num).toInt(),
        tankId: tankIdByKey[segment['tankKey']] ?? '',
        gasMix: GasMix(
          o2: (segment['o2'] as num).toDouble(),
          he: (segment['he'] as num?)?.toDouble() ?? 0.0,
        ),
        rate: (segment['rate'] as num?)?.toDouble(),
        order: (segment['order'] as num?)?.toInt() ?? index,
      ),
    );
  }

  final airBreaks = plan['airBreaks'];

  return domain.DivePlan(
    id: _uuid.v4(),
    name: plan['name'] as String? ?? 'Imported plan',
    notes: plan['notes'] as String? ?? '',
    createdAt: timestamp,
    updatedAt: timestamp,
    mode:
        domain.PlanMode.values.asNameMap()[plan['mode']] ?? domain.PlanMode.oc,
    altitude: (plan['altitude'] as num?)?.toDouble(),
    waterType: WaterType.values.asNameMap()[plan['waterType']],
    gfLow: (plan['gfLow'] as num).toInt(),
    gfHigh: (plan['gfHigh'] as num).toInt(),
    descentRate: (plan['descentRate'] as num?)?.toDouble() ?? 18.0,
    ascentRate: (plan['ascentRate'] as num?)?.toDouble() ?? 9.0,
    lastStopDepth: (plan['lastStopDepth'] as num?)?.toDouble() ?? 3.0,
    gasSwitchStopSeconds: (plan['gasSwitchStopSeconds'] as num?)?.toInt() ?? 0,
    airBreaks: airBreaks is Map<String, dynamic>
        ? AirBreakPolicy(
            o2Seconds: (airBreaks['o2Seconds'] as num).toInt(),
            breakSeconds: (airBreaks['breakSeconds'] as num).toInt(),
          )
        : null,
    sacBottom: (plan['sacBottom'] as num?)?.toDouble() ?? 15.0,
    sacDeco: (plan['sacDeco'] as num?)?.toDouble(),
    sacStressed: (plan['sacStressed'] as num?)?.toDouble(),
    reservePressure: (plan['reservePressure'] as num?)?.toDouble() ?? 50.0,
    setpointLow: (plan['setpointLow'] as num?)?.toDouble(),
    setpointHigh: (plan['setpointHigh'] as num?)?.toDouble(),
    setpointSwitchDepth: (plan['setpointSwitchDepth'] as num?)?.toDouble(),
    deviationDepthDelta:
        (plan['deviationDepthDelta'] as num?)?.toDouble() ?? 5.0,
    deviationTimeMinutes: (plan['deviationTimeMinutes'] as num?)?.toInt() ?? 5,
    turnPressureRule: domain.TurnPressureRule.values
        .asNameMap()[plan['turnPressureRule']],
    turnPressureFraction: (plan['turnPressureFraction'] as num?)?.toDouble(),
    tanks: tanks,
    segments: segments,
  );
}
