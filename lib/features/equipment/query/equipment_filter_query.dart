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
  /// Null only under [allStatuses] (#2590) with no other axis set: every
  /// other status choice narrows (the default view hides retired and sold
  /// gear, #636, and wishlist gear, #2025).
  QueryNode? toQuery() => _lower(defaultStatus: true);

  /// What Save stores (#2989): [toQuery] without the default status view,
  /// which every unfiltered list applies on its own, so a saved query names
  /// only what the diver chose. Null while nothing else is set.
  QueryNode? toSavedQuery() => _lower(defaultStatus: false);

  QueryNode? _lower({required bool defaultStatus}) {
    final parts = <QueryNode>[];
    QueryNode c(String key, QueryOp op, QueryValue? v) =>
        ConditionNode(FieldPath([key]), op, v);
    EnumValue e(String name) => EnumValue(name);
    final s = status;
    if (allStatuses) {
      // Every status (#2590): the axis adds no condition.
    } else if (s == null) {
      // getActiveEquipment: legacy rows can be retired with is_active still
      // set, sold gear has left the kit, and wanted gear has not joined it
      // (#2025). Not saved: the list applies it without being asked.
      if (defaultStatus) {
        parts
          ..add(c('active', QueryOp.eq, const BoolValue(true)))
          ..add(c('status', QueryOp.neq, e(EquipmentStatus.retired.name)))
          ..add(c('status', QueryOp.neq, e(EquipmentStatus.sold.name)))
          ..add(c('status', QueryOp.neq, e(EquipmentStatus.wanted.name)));
      }
    } else if (s == EquipmentStatus.retired) {
      // getEquipmentByStatus(retired): legacy rows that only flipped
      // is_active, but not sold or wanted gear.
      parts
        ..add(
          OrNode([
            c('status', QueryOp.eq, e(EquipmentStatus.retired.name)),
            c('active', QueryOp.eq, const BoolValue(false)),
          ]),
        )
        ..add(c('status', QueryOp.neq, e(EquipmentStatus.sold.name)))
        ..add(c('status', QueryOp.neq, e(EquipmentStatus.wanted.name)));
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
    if (locationNames.isNotEmpty || noLocation) {
      // Any of the chosen places, or none at all.
      final options = <QueryNode>[
        if (locationNames.isNotEmpty)
          c(
            'location',
            QueryOp.inList,
            ListValue([
              for (final name in locationNames.toList()..sort())
                StringValue(name),
            ]),
          ),
        if (noLocation) c('location', QueryOp.isEmpty, null),
      ];
      parts.add(options.length == 1 ? options.single : OrNode(options));
    }
    if (query != null) parts.add(query!);
    return switch (parts) {
      [] => null,
      [final only] => only,
      _ => AndNode(parts),
    };
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

/// Whether [node] constrains the gear's own status (`status` or `active`
/// at the root, not through a relation). A saved query that does takes
/// over the sheet's status axis on load (#2989): a picked status is saved
/// as conditions, and the default view ANDed back in would contradict it.
bool constrainsEquipmentStatus(QueryNode node) => switch (node) {
  AndNode(:final children) ||
  OrNode(:final children) => children.any(constrainsEquipmentStatus),
  NotNode(:final child) => constrainsEquipmentStatus(child),
  ConditionNode(:final path) =>
    path.segments.length == 1 &&
        (path.segments.single == 'status' || path.segments.single == 'active'),
  ScopedNode() || TextNode() => false,
};

/// The one compile call the equipment list shares. Root alias `r0`, which
/// [EquipmentFilterQuery.ownerScope] assumes. [diverId] reads shared gear's
/// dives as that diver's alone.
CompiledQuery compileEquipmentFilter(
  EquipmentFilterState filter, {
  String? diverId,
}) => compileQuery(
  filter.toQuery(),
  equipmentQueryEntity,
  appQueryRegistry,
  diverId: diverId,
);
