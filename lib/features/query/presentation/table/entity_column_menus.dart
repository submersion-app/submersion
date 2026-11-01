import 'package:flutter/foundation.dart';

import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/column_rules.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_menu.dart';

/// Header and cell filter menus for an entity that has none of its own
/// (#3422): sites and dive centers in the table editor. Smaller than the
/// dive list's menus: only empty, only with a value, reset, only this value
/// and exclude this value. Labels are resolved by the caller, so the shared
/// table never reads l10n in build.

List<EntityTableMenuAction> entityColumnHeaderMenuItems({
  required AppLocalizations l10n,
  required QueryEntity root,
  required String fieldKey,
  required String columnLabel,
  required QueryNode? query,
  required ValueChanged<QueryNode?> onChanged,
}) {
  final field = root.field(fieldKey);
  if (field == null) return const [];
  final path = FieldPath([field.key]);
  return [
    if (field.ops.contains(QueryOp.isEmpty))
      EntityTableMenuAction(
        label: l10n.tableMode_cell_noValue(columnLabel),
        onSelected: () => onChanged(
          addColumnRule(query, ConditionNode(path, QueryOp.isEmpty, null)),
        ),
      ),
    if (field.ops.contains(QueryOp.isSet))
      EntityTableMenuAction(
        label: l10n.tableMode_cell_anyValue(columnLabel),
        onSelected: () => onChanged(
          addColumnRule(query, ConditionNode(path, QueryOp.isSet, null)),
        ),
      ),
    EntityTableMenuAction(
      label: l10n.tableMode_menu_resetFilter,
      enabled: isColumnFiltered(query, field.key),
      onSelected: () => onChanged(resetColumnRules(query, field.key)),
    ),
  ];
}

List<EntityTableMenuAction> entityColumnCellMenuItems({
  required AppLocalizations l10n,
  required QueryEntity root,
  required String fieldKey,
  required Object? value,
  required String valueLabel,
  required QueryNode? query,
  required ValueChanged<QueryNode?> onChanged,
}) {
  final field = root.field(fieldKey);
  if (field == null || value == null) return const [];
  final queryValue = _valueFor(field, value);
  if (queryValue == null) return const [];
  final path = FieldPath([field.key]);
  return [
    if (field.ops.contains(QueryOp.eq))
      EntityTableMenuAction(
        label: l10n.tableMode_cell_only(valueLabel),
        onSelected: () => onChanged(
          addColumnRule(query, ConditionNode(path, QueryOp.eq, queryValue)),
        ),
      ),
    if (field.ops.contains(QueryOp.neq))
      EntityTableMenuAction(
        label: l10n.tableMode_cell_exclude(valueLabel),
        onSelected: () => onChanged(
          addColumnRule(query, ConditionNode(path, QueryOp.neq, queryValue)),
        ),
      ),
  ];
}

/// The query value for a cell's stored value, by the field's type; null
/// when the two do not fit (a list, a value of another kind).
QueryValue? _valueFor(QueryField field, Object value) => switch (field.type) {
  FieldType.text when value is String => StringValue(value),
  FieldType.number when value is num => NumberValue(value.toDouble(), null),
  FieldType.bool when value is bool => BoolValue(value),
  FieldType.enumName when value is String => EnumValue(value),
  FieldType.id when value is String => RefValue(value, value),
  _ => null,
};
