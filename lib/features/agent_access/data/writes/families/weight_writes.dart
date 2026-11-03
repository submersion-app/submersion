import 'package:drift/drift.dart' show Value;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    show DiveWeightsCompanion;
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_child_row_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/weight_label.dart';

/// A dive's weights, one row at a time.
class WeightWrites extends WritableEntry {
  WeightWrites({DiveChildRowRepository? rows})
    : _rows = rows ?? DiveChildRowRepository();

  final DiveChildRowRepository _rows;

  @override
  String get name => 'dive_weights';

  @override
  String get table => 'dive_weights';

  @override
  ChildOf get parent => const ChildOf(entity: 'dives', field: 'dive_id');

  @override
  late final Map<String, FieldCodec> fields = {
    'dive_id': const FieldCodec.reference('dives'),
    'type': FieldCodec.enumName(WeightType.values),
    'amount_kg': const FieldCodec.number(min: 0, max: 60),
    'label': const FieldCodec.text(
      maxLength: weightLabelMaxLength,
      allowBlank: true,
    ),
    'notes': const FieldCodec.text(allowBlank: true),
  };

  @override
  Set<String> get requiredOnCreate => const {'amount_kg'};

  /// Every weight write stores its label trimmed, so a label that is not
  /// would be written differently from what the plan shows.
  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    final label = check.values['label'];
    if (label is! String || label == label.trim()) return null;
    return const PlanBlock(
      BlockReason.invalidValue,
      'label: a weight stores its label trimmed, so send it without spaces '
      'at either end.',
    );
  }

  /// Its label, or none. A title is shown as it is, so neither its type,
  /// an untranslated name, nor its amount, which belongs in the diver's
  /// units, can stand in; the dialog names an untitled record by its kind.
  @override
  String? titleOf(Map<String, Object?> document) {
    final label = document['label'] as String?;
    return label == null || label.isEmpty ? null : label;
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) =>
      _rows.addWeight(
        values['dive_id']! as String,
        _companion({'type': WeightType.belt.name, ...values}),
      );

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    if (!await _rows.updateWeight(id, _companion(update.values))) _gone(id);
  }

  @override
  Future<void> delete(String id, String? ownerId) async {
    if (!await _rows.deleteWeight(id)) _gone(id);
  }

  Never _gone(String id) => throw AgentToolException(
    AgentToolErrorCode.writeRefused,
    'Weight $id no longer exists.',
    details: {'id': id},
  );

  DiveWeightsCompanion _companion(Map<String, Object?> v) {
    Value<T> field<T>(String key) =>
        v.containsKey(key) ? Value(v[key] as T) : const Value.absent();
    return DiveWeightsCompanion(
      weightType: field('type'),
      amountKg: field('amount_kg'),
      label: field('label'),
      notes: field('notes'),
    );
  }
}
