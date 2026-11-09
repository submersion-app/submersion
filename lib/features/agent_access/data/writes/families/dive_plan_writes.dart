import 'package:drift/drift.dart' show Variable;
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart' show TankRole, WaterType;
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/object_list_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart'
    show PlanSummaryData;
import 'package:submersion/features/planner/data/services/plan_engine_settings.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart'
    show AppSettings;

/// The plan settings an agent writes, by document key, as plain numbers.
const _numbers = {
  'altitude_m': FieldCodec.number(min: -500, max: 6000, nullable: true),
  'salinity_ppt': FieldCodec.number(min: 0, max: 50, nullable: true),
  'descent_rate_m_min': FieldCodec.number(min: 1, max: 60, nullable: true),
  'ascent_rate_m_min': FieldCodec.number(min: 1, max: 30, nullable: true),
  'last_stop_depth_m': FieldCodec.number(min: 3, max: 9, nullable: true),
  'sac_bottom_l_min': FieldCodec.number(min: 1, max: 100, nullable: true),
  'sac_deco_l_min': FieldCodec.number(min: 1, max: 100, nullable: true),
  'reserve_pressure_bar': FieldCodec.number(min: 0, max: 300, nullable: true),
  'ppo2_bottom_bar': FieldCodec.number(min: 0.16, max: 2, nullable: true),
  'ppo2_deco_bar': FieldCodec.number(min: 0.16, max: 2, nullable: true),
};

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
    'water_type': FieldCodec.enumName(WaterType.values, nullable: true),
    'gf_low': const FieldCodec.integer(min: 1, max: 100, nullable: true),
    'gf_high': const FieldCodec.integer(min: 1, max: 100, nullable: true),
    ..._numbers,
    'linked_dive_id': const FieldCodec.reference('dives', nullable: true),
    'tanks': ObjectListCodec(
      {
        'name': const FieldCodec.text(
          maxLength: 60,
          nullable: true,
          trim: true,
        ),
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
        // A plan holds breathing gas only: a suit inflation bottle is
        // refused (issue #4243).
        'role': FieldCodec.enumName(
          TankRole.values.where((r) => r.isBreathingGas),
        ),
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
    ),
    'segments': const ObjectListCodec(
      {
        'target_depth_m': FieldCodec.number(min: 0, max: 350),
        'duration_s': FieldCodec.integer(min: 0, max: 86400),
        'tank': FieldCodec.integer(min: 0, max: 11),
        'setpoint_bar': FieldCodec.number(min: 0.2, max: 1.6, nullable: true),
        'split_at_configured_rate': FieldCodec.flag(),
      },
      defaults: {'split_at_configured_rate': false},
      maxItems: 100,
    ),
    _copy: const FieldCodec.reference('dive_plans'),
  };

  static String? _tankRule(Map<String, Object?> tank) =>
      (tank['o2_fraction']! as num) + (tank['he_fraction']! as num) > 1
      ? 'o2_fraction and he_fraction add to more than 1.'
      : null;

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
    for (final (i, s) in segments.indexed) {
      if ((s['tank']! as int) >= tanks) {
        return PlanBlock(
          BlockReason.invalidValue,
          'segments: segment $i names tank ${s['tank']}, which tanks lacks.',
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
      if (rest.isNotEmpty) await _save(copy, rest, ownerId: diverId);
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
      // No diver owns a saved plan, so the planner computes it with the
      // active diver's settings, and so does this.
      ownerId: ownerId ?? await _r.activeDiverId?.call(),
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.divePlans.deletePlan(id);

  /// Saves [plan] with [values] over it, with the summary the planner works
  /// out for [ownerId] from their planner settings, then moves its dive
  /// link, which the save leaves as stored.
  Future<DivePlan> _save(
    DivePlan plan,
    Map<String, Object?> values, {
    required String? ownerId,
  }) async {
    final link = values.containsKey('linked_dive_id');
    final next = _applied(plan, values);
    final changesPlan = values.keys.any((k) => k != 'linked_dive_id');
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

  /// [plan] with [values] written over it. Tanks keep the ids of the
  /// stored tanks at the same places, and segments those of the segments.
  static DivePlan _applied(DivePlan plan, Map<String, Object?> values) {
    bool clears(String key) => values.containsKey(key) && values[key] == null;
    double? number(String key) => (values[key] as num?)?.toDouble();
    final tanks = values.containsKey('tanks')
        ? [
            for (final (i, t) in ObjectListCodec.items(values['tanks']).indexed)
              DiveTank(
                id: i < plan.tanks.length ? plan.tanks[i].id : _uuid.v4(),
                name: t['name'] as String?,
                volume: (t['volume_l'] as num?)?.toDouble(),
                workingPressure: (t['working_pressure_bar'] as num?)
                    ?.toDouble(),
                startPressure: (t['start_pressure_bar'] as num?)?.toDouble(),
                gasMix: GasMix(
                  o2: (t['o2_fraction']! as num) * 100,
                  he: (t['he_fraction']! as num) * 100,
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
                id: i < plan.segments.length ? plan.segments[i].id : _uuid.v4(),
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
      waterType:
          values.containsKey('water_type') && values['water_type'] != null
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
      lastStopDepth: number('last_stop_depth_m'),
      clearLastStopDepth: clears('last_stop_depth_m'),
      sacBottom: number('sac_bottom_l_min'),
      clearSacBottom: clears('sac_bottom_l_min'),
      sacDeco: number('sac_deco_l_min'),
      clearSacDeco: clears('sac_deco_l_min'),
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
}
