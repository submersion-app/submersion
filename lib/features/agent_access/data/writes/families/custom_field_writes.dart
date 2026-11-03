import 'package:drift/drift.dart' show Value;

import 'package:submersion/core/database/database.dart'
    show DiveCustomFieldsCompanion;
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_child_row_repository.dart';

/// A dive's custom fields, one row at a time. A key may not be blank: the
/// dive editor drops a field with no key when it saves.
class CustomFieldWrites extends WritableEntry {
  CustomFieldWrites({DiveChildRowRepository? rows})
    : _rows = rows ?? DiveChildRowRepository();

  final DiveChildRowRepository _rows;

  @override
  String get name => 'dive_custom_fields';

  @override
  String get table => 'dive_custom_fields';

  @override
  ChildOf get parent => const ChildOf(entity: 'dives', field: 'dive_id');

  @override
  final Map<String, FieldCodec> fields = const {
    'dive_id': FieldCodec.reference('dives'),
    'key': FieldCodec.text(maxLength: 100),
    'value': FieldCodec.text(maxLength: 2000, allowBlank: true),
    'sort_order': FieldCodec.integer(min: 0, max: 999),
  };

  @override
  Set<String> get requiredOnCreate => const {'key'};

  @override
  String? titleOf(Map<String, Object?> document) => document['key'] as String?;

  @override
  Future<String> create(String diverId, Map<String, Object?> values) =>
      _rows.addCustomField(values['dive_id']! as String, _companion(values));

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    if (!await _rows.updateCustomField(id, _companion(update.values))) {
      _gone(id);
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) async {
    if (!await _rows.deleteCustomField(id)) _gone(id);
  }

  Never _gone(String id) => throw AgentToolException(
    AgentToolErrorCode.writeRefused,
    'Custom field $id no longer exists.',
    details: {'id': id},
  );

  DiveCustomFieldsCompanion _companion(Map<String, Object?> v) {
    Value<T> field<T>(String key) =>
        v.containsKey(key) ? Value(v[key] as T) : const Value.absent();
    return DiveCustomFieldsCompanion(
      fieldKey: field('key'),
      fieldValue: field('value'),
      sortOrder: field('sort_order'),
    );
  }
}
