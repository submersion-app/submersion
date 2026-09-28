import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/query/equipment_attr_condition_query.dart';
import 'package:submersion/features/equipment/query/equipment_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';

/// Lowers the equipment filter panel to the query tree (#2365). The ONLY
/// evaluator of an EquipmentFilterState: a field added to it and not named
/// here fails `equipment_filter_query_census_test`.
extension EquipmentFilterQuery on EquipmentFilterState {
  /// Never null: the status axis always narrows (the default view hides
  /// retired and sold gear, #636).
  QueryNode toQuery() {
    final parts = <QueryNode>[];
    QueryNode c(String key, QueryOp op, QueryValue? v) =>
        ConditionNode(FieldPath([key]), op, v);
    EnumValue e(String name) => EnumValue(name);
    final s = status;
    if (s == null) {
      // getActiveEquipment: legacy rows can be retired with is_active still
      // set, and sold gear has left the kit.
      parts
        ..add(c('active', QueryOp.eq, const BoolValue(true)))
        ..add(c('status', QueryOp.neq, e(EquipmentStatus.retired.name)))
        ..add(c('status', QueryOp.neq, e(EquipmentStatus.sold.name)));
    } else if (s == EquipmentStatus.retired) {
      // getEquipmentByStatus(retired): legacy rows that only flipped
      // is_active, but not sold gear.
      parts
        ..add(
          OrNode([
            c('status', QueryOp.eq, e(EquipmentStatus.retired.name)),
            c('active', QueryOp.eq, const BoolValue(false)),
          ]),
        )
        ..add(c('status', QueryOp.neq, e(EquipmentStatus.sold.name)));
    } else {
      parts.add(c('status', QueryOp.eq, e(s.name)));
    }
    final due = serviceDue;
    if (due != null) {
      parts.add(switch (due) {
        ServiceDueFilter.any => c(
          'serviceDue',
          QueryOp.inList,
          ListValue([e('dueSoon'), e('overdue')]),
        ),
        ServiceDueFilter.overdue => c('serviceDue', QueryOp.eq, e('overdue')),
        ServiceDueFilter.dueSoon => c('serviceDue', QueryOp.eq, e('dueSoon')),
      });
    }
    if (type != null) parts.add(c('type', QueryOp.eq, e(type!.name)));
    for (final cond in attrConditions) {
      parts.add(equipmentAttrConditionNode(cond));
    }
    if (tagIds.isNotEmpty) {
      parts.add(
        c(
          'tags',
          QueryOp.inList,
          ListValue([
            for (final id in tagIds.toList()..sort()) RefValue(id, id),
          ]),
        ),
      );
    }
    if (query != null) parts.add(query!);
    return parts.length == 1 ? parts.first : AndNode(parts);
  }

  /// The owner axis (issue #2046) as a caller-applied scope over `r0`. It
  /// compares rows with the active diver, which a saved query must not
  /// name, so it is not a query field. Null narrows nothing, as apply()
  /// did with no active diver.
  QueryScope? ownerScope(String? activeDiverId) {
    if (activeDiverId == null) return null;
    return switch (owner) {
      EquipmentOwnerFilter.all => null,
      EquipmentOwnerFilter.mine => (
        sql: '(r0.diver_id IS NULL OR r0.diver_id = ?)',
        params: [activeDiverId],
      ),
      EquipmentOwnerFilter.sharedWithMe => (
        sql: '(r0.diver_id IS NOT NULL AND r0.diver_id != ?)',
        params: [activeDiverId],
      ),
    };
  }
}

/// The one compile call the equipment list shares. Root alias `r0`, which
/// [EquipmentFilterQuery.ownerScope] assumes.
CompiledQuery compileEquipmentFilter(EquipmentFilterState filter) =>
    compileQuery(filter.toQuery(), equipmentQueryEntity, appQueryRegistry);
