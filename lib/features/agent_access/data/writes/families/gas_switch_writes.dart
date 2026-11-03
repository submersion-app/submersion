import 'package:drift/drift.dart' show Variable;
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart' show DiveMode;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_time_limit.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/dive_log/data/services/diver_gas_switch_writer.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/gas_switch_editing.dart';
import 'package:submersion/features/dive_log/domain/services/profile_depth_at.dart';

/// A dive's gas switches, as the dive editor shows them: the primary
/// computer's and untagged ones, on a dive with two or more cylinders that
/// is neither gauge nor planned. Every write goes through the editor's own
/// writer, so it also marks the dive's switches as the diver's, which a
/// re-parse leaves alone, and drops the stored safety review.
class GasSwitchWrites extends WritableEntry {
  GasSwitchWrites(this._r);

  final RecordRepositories _r;
  static const _uuid = Uuid();

  @override
  String get name => 'gas_switches';

  @override
  String get table => 'gas_switches';

  @override
  ChildOf get parent => const ChildOf(entity: 'dives', field: 'dive_id');

  @override
  final Map<String, FieldCodec> fields = const {
    'dive_id': FieldCodec.reference('dives'),
    't_s': FieldCodec.integer(min: 0, max: 172800),
    'tank_id': FieldCodec.reference('dive_tanks'),
    'depth_m': FieldCodec.number(min: 0, max: 350, nullable: true),
  };

  @override
  Set<String> get requiredOnCreate => const {'t_s', 'tank_id'};

  @override
  String get note =>
      'The switches the dive editor shows: the primary computer\'s and '
      'untagged ones, on a dive with two or more cylinders; a moved switch '
      'takes the profile\'s depth unless depth_m is given';

  @override
  String? titleOf(Map<String, Object?> document) =>
      document['tank_name'] as String?;

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    final diveId =
        (check.values['dive_id'] ?? check.document?['dive_id']) as String?;
    if (diveId == null) return null;
    final dive = await _dive(diveId);
    if (dive == null) return null;
    if (!gasSwitchesEditable(
      tankCount: dive.tanks,
      // As every dive read parses it: a mode the app does not know is open
      // circuit, and the dive editor shows that dive's switches.
      mode: DiveMode.fromCode(dive.mode),
      isPlanned: dive.planned,
    )) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'A dive has gas switches to change only with two or more cylinders, '
        'and not on a gauge or planned dive, as the dive editor shows them.',
      );
    }
    if (check.id case final id?) {
      if (!GasSwitch.shownFor(await _switchComputer(id), dive.computer)) {
        return const PlanBlock(
          BlockReason.notPermitted,
          'This switch is another dive computer\'s, which the dive editor '
          'does not show or change.',
        );
      }
    }
    if (await beyondDive(_r, diveId, check.values) case final block?) {
      return block;
    }
    if (check.values['tank_id'] case final String tankId) {
      final tankDive = await _tankDive(tankId);
      if (tankDive != diveId) {
        return PlanBlock(
          BlockReason.invalidValue,
          'tank_id: $tankId is not a cylinder of dive $diveId.',
        );
      }
    }
    return null;
  }

  /// A switch moved in time takes the profile's depth there, as the editor
  /// fills it, unless the change names a depth.
  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async {
    final fill = await _filledDepth(
      document['dive_id']! as String,
      update.values,
    );
    if (fill == null || fill.depth == document['depth_m']) {
      return const SideEffects();
    }
    return SideEffects(fields: {'depth_m': fill.depth});
  }

  /// The depth the editor fills for a switch [values] moves without naming
  /// one: the profile's at the new time. Null when nothing is filled, as
  /// for a dive with no profile.
  Future<({double? depth})?> _filledDepth(
    String diveId,
    Map<String, Object?> values,
  ) async {
    final moved = values['t_s'];
    if (moved is! int || values.containsKey('depth_m')) return null;
    final profile = await _r.dives.getDiveProfile(diveId);
    if (profile.isEmpty) return null;
    return (depth: profileDepthAt(profile, moved));
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final diveId = values['dive_id']! as String;
    final id = _uuid.v4();
    final shown = await _shown(diveId);
    await _save(diveId, shown, [
      ...shown,
      GasSwitch(
        id: id,
        diveId: diveId,
        timestamp: values['t_s']! as int,
        tankId: values['tank_id']! as String,
        depth: values['depth_m'] as double?,
        createdAt: DateTime.now(),
      ),
    ]);
    return id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final v = update.values;
    final diveId = await _diveOf(id);
    final shown = await _shown(diveId);
    final current = shown.where((s) => s.id == id).firstOrNull ?? _gone(id);
    // The planner's side effect is not in [v], so the depth is filled again
    // here by the same rule.
    final fill = await _filledDepth(diveId, v);
    final depth = fill != null
        ? fill.depth
        : v.containsKey('depth_m')
        ? v['depth_m'] as double?
        : current.depth;
    final next = GasSwitch(
      id: id,
      diveId: diveId,
      timestamp: v['t_s'] as int? ?? current.timestamp,
      tankId: v['tank_id'] as String? ?? current.tankId,
      depth: depth,
      createdAt: current.createdAt,
      computerId: current.computerId,
    );
    await _save(diveId, shown, [for (final s in shown) s.id == id ? next : s]);
  }

  @override
  Future<void> delete(String id, String? ownerId) async {
    final diveId = await _diveOf(id);
    final shown = await _shown(diveId);
    if (!shown.any((s) => s.id == id)) _gone(id);
    await _save(diveId, shown, [
      for (final s in shown)
        if (s.id != id) s,
    ]);
  }

  Future<void> _save(
    String diveId,
    List<GasSwitch> shown,
    List<GasSwitch> next,
  ) => DiverGasSwitchWriter().save(
    diveId: diveId,
    switches: next,
    loadedIds: {for (final s in shown) s.id},
  );

  /// The switches the dive editor shows for [diveId].
  Future<List<GasSwitch>> _shown(String diveId) async {
    final computer = (await _dive(diveId))?.computer;
    return [
      for (final s in await _r.dives.getGasSwitchesForDive(diveId))
        if (s.gasSwitch.shownInEditor(computer)) s.gasSwitch,
    ];
  }

  Future<({int tanks, String mode, bool planned, String? computer})?> _dive(
    String diveId,
  ) async {
    final row = await DatabaseService.instance.database
        .customSelect(
          'SELECT d.dive_mode, d.is_planned, d.computer_id, '
          '(SELECT COUNT(*) FROM dive_tanks t WHERE t.dive_id = d.id) AS tanks '
          'FROM dives d WHERE d.id = ?',
          variables: [Variable.withString(diveId)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return (
      tanks: row.read<int>('tanks'),
      mode: row.read<String>('dive_mode'),
      planned: row.read<bool>('is_planned'),
      computer: row.readNullable<String>('computer_id'),
    );
  }

  Future<String?> _switchComputer(String id) async {
    final row = await DatabaseService.instance.database
        .customSelect(
          'SELECT computer_id FROM gas_switches WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    return row?.readNullable<String>('computer_id');
  }

  Future<String?> _tankDive(String tankId) async {
    final row = await DatabaseService.instance.database
        .customSelect(
          'SELECT dive_id FROM dive_tanks WHERE id = ?',
          variables: [Variable.withString(tankId)],
        )
        .getSingleOrNull();
    return row?.read<String>('dive_id');
  }

  Future<String> _diveOf(String id) async {
    final row = await DatabaseService.instance.database
        .customSelect(
          'SELECT dive_id FROM gas_switches WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    return row?.read<String>('dive_id') ?? _gone(id);
  }

  Never _gone(String id) => throw AgentToolException(
    AgentToolErrorCode.writeRefused,
    'Gas switch $id no longer exists.',
    details: {'id': id},
  );
}
