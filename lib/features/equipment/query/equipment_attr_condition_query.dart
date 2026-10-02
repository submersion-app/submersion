import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';

/// One curated attribute condition at equipment level: an item of one of
/// [EquipmentAttrCondition.types] carrying a curated row for the key whose
/// text is one of the choices and whose number is in range. The ONE
/// lowering of [EquipmentAttrCondition.matches]: the dive filter wraps it
/// in `gear[...]`, the equipment filter uses it at the root.
QueryNode equipmentAttrConditionNode(EquipmentAttrCondition cond) {
  QueryNode c(String key, QueryOp op, QueryValue v) =>
      ConditionNode(FieldPath([key]), op, v);
  final types = cond.types.map((t) => t.name).toList()..sort();
  final choices = cond.choices.toList()..sort();
  return AndNode([
    if (types.isNotEmpty)
      c(
        'type',
        QueryOp.inList,
        ListValue([for (final t in types) EnumValue(t)]),
      ),
    ScopedNode(
      FieldPath(['attributes']),
      AndNode([
        c('key', QueryOp.eq, StringValue(cond.key)),
        c('custom', QueryOp.eq, const BoolValue(false)),
        if (choices.isNotEmpty)
          c(
            'valueText',
            QueryOp.inList,
            ListValue([for (final ch in choices) StringValue(ch)]),
          ),
        if (cond.min != null)
          c('valueNum', QueryOp.gte, NumberValue(cond.min!, null)),
        if (cond.max != null)
          c('valueNum', QueryOp.lte, NumberValue(cond.max!, null)),
      ]),
    ),
  ]);
}
