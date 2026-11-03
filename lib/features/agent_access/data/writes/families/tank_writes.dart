import 'package:drift/drift.dart' show Value;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show DiveTanksCompanion;
import 'package:submersion/core/utils/gas_percent.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_child_row_repository.dart';

/// A dive's tanks, one at a time, so a change to one leaves the others, and
/// every tank's pressure series and gas switches, as they were. The fields are
/// the ones a diver edits: the computer's attribution, the recorded usage and
/// the planning-only settings stay as they are.
class TankWrites extends WritableEntry {
  TankWrites({DiveChildRowRepository? rows})
    : _rows = rows ?? DiveChildRowRepository();

  final DiveChildRowRepository _rows;

  @override
  String get name => 'dive_tanks';

  @override
  String get table => 'dive_tanks';

  @override
  ChildOf get parent => const ChildOf(entity: 'dives', field: 'dive_id');

  static const _pressure = FieldCodec.number(min: 0, max: 450, nullable: true);

  @override
  late final Map<String, FieldCodec> fields = {
    'dive_id': const FieldCodec.reference('dives'),
    'name': const FieldCodec.text(maxLength: 100, nullable: true),
    'volume_l': const FieldCodec.number(min: 0, max: 60, nullable: true),
    'working_pressure_bar': _pressure,
    'start_pressure_bar': _pressure,
    'end_pressure_bar': _pressure,
    'o2_fraction': const FieldCodec.number(min: 0.05, max: 1),
    'he_fraction': const FieldCodec.number(min: 0, max: 0.95),
    'role': FieldCodec.enumName(TankRole.values),
    'material': FieldCodec.enumName(TankMaterial.values, nullable: true),
    'order': const FieldCodec.integer(min: 0, max: 99),
    'preset_name': const FieldCodec.text(maxLength: 60, nullable: true),
  };

  @override
  Set<String> get requiredOnCreate => const {};

  /// A mix a diver could breathe: oxygen and helium never make up more than
  /// the whole, judged on the tank as it would be after the change.
  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    double fraction(String key, double fallback) =>
        ((check.values[key] ?? check.document?[key] ?? fallback) as num)
            .toDouble();
    final o2 = fraction('o2_fraction', 0.21);
    final he = fraction('he_fraction', 0);
    if (o2 + he <= 1 + 1e-9) return null;
    return PlanBlock(
      BlockReason.invalidValue,
      'o2_fraction ($o2) and he_fraction ($he) add up to more than 1.',
    );
  }

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async {
    // A profile event names its tank with no foreign key, which
    // countUnlinked cannot see; the delete clears it.
    final events = await countRows('dive_profile_events', 'tank_id = ?1', id);
    return DeleteReach(
      parts: await countCascaded('dive_tanks', id),
      unlinked: {
        ...await countUnlinked('dive_tanks', id),
        if (events > 0) 'dive_profile_events': events,
      },
    );
  }

  /// Its name, else its preset, else its mix.
  @override
  String? titleOf(Map<String, Object?> document) {
    for (final key in const ['name', 'preset_name']) {
      if (document[key] case final String text when text.trim().isNotEmpty) {
        return text;
      }
    }
    if (document['o2_fraction'] case final num o2) {
      final he = document['he_fraction'] as num? ?? 0;
      String percent(num fraction) =>
          formatGasPercentValue(gasPercentOfFraction(fraction.toDouble()));
      return '${percent(o2)}/${percent(he)}';
    }
    return null;
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) =>
      _rows.addTank(
        values['dive_id']! as String,
        _companion({
          'o2_fraction': 0.21,
          'he_fraction': 0.0,
          'role': TankRole.backGas.name,
          ...values,
        }),
      );

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    if (!await _rows.updateTank(id, _companion(update.values))) _gone(id);
  }

  @override
  Future<void> delete(String id, String? ownerId) async {
    if (!await _rows.deleteTank(id)) _gone(id);
  }

  Never _gone(String id) => throw AgentToolException(
    AgentToolErrorCode.writeRefused,
    'Tank $id no longer exists.',
    details: {'id': id},
  );

  /// The columns [v] names. Documents carry a gas as a fraction, the table as
  /// a percentage.
  DiveTanksCompanion _companion(Map<String, Object?> v) {
    Value<T> field<T>(String key) =>
        v.containsKey(key) ? Value(v[key] as T) : const Value.absent();
    Value<double> percent(String key) => v.containsKey(key)
        ? Value(gasPercentOfFraction(v[key]! as double))
        : const Value.absent();
    return DiveTanksCompanion(
      tankName: field('name'),
      volume: field('volume_l'),
      workingPressure: field('working_pressure_bar'),
      startPressure: field('start_pressure_bar'),
      endPressure: field('end_pressure_bar'),
      o2Percent: percent('o2_fraction'),
      hePercent: percent('he_fraction'),
      tankRole: field('role'),
      tankMaterial: field('material'),
      tankOrder: field('order'),
      presetName: field('preset_name'),
    );
  }
}
