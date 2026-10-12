import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/equipment/domain/models/equipment_default_view.dart';
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
  /// other status choice narrows. With no status chosen, [defaultStatuses]
  /// decides what shows: the diver's default view (#2628), by default
  /// everything but retired, sold (#636) and wishlist (#2025) gear.
  QueryNode? toQuery({
    Set<EquipmentStatus> defaultStatuses = factoryDefaultEquipmentStatuses,
  }) => _lower(defaultStatuses: defaultStatuses);

  /// What Save stores (#2989): [toQuery] without the default status view,
  /// which every unfiltered list applies on its own, so a saved query names
  /// only what the diver chose. Null while nothing else is set.
  QueryNode? toSavedQuery() => _lower(defaultStatuses: null);

  QueryNode? _lower({required Set<EquipmentStatus>? defaultStatuses}) {
    final parts = <QueryNode>[];
    EnumValue e(String name) => EnumValue(name);
    final s = status;
    if (allStatuses) {
      // Every status (#2590): the axis adds no condition.
    } else if (s == null) {
      // Not saved: the list applies it without being asked. A service-due
      // view keeps the factory kit: the home strip counts clocks over it,
      // so the rows must match the count and never hide gear due for
      // service behind the diver's narrower default (#2628).
      if (defaultStatuses != null) {
        parts.addAll(
          _defaultViewParts(
            serviceDue == null
                ? defaultStatuses
                : factoryDefaultEquipmentStatuses,
          ),
        );
      }
    } else if (s == EquipmentStatus.retired) {
      parts.addAll(_retiredView());
    } else {
      parts.add(_c('status', QueryOp.eq, e(s.name)));
    }
    final due = serviceDue;
    if (due != null) {
      parts.add(switch (due) {
        ServiceDueFilter.any => _c(
          'serviceDue',
          QueryOp.inList,
          ListValue([e('dueSoon'), e('overdue')]),
        ),
        ServiceDueFilter.overdue => _c('serviceDue', QueryOp.eq, e('overdue')),
        ServiceDueFilter.dueSoon => _c('serviceDue', QueryOp.eq, e('dueSoon')),
      });
    }
    if (type != null) parts.add(_c('type', QueryOp.eq, e(type!.name)));
    for (final cond in attrConditions) {
      parts.add(equipmentAttrConditionNode(cond));
    }
    if (tagIds.isNotEmpty) {
      parts.add(
        _c(
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
          _c(
            'location',
            QueryOp.inList,
            ListValue([
              for (final name in locationNames.toList()..sort())
                StringValue(name),
            ]),
          ),
        if (noLocation) _c('location', QueryOp.isEmpty, null),
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

QueryNode _c(String key, QueryOp op, QueryValue? v) =>
    ConditionNode(FieldPath([key]), op, v);

/// getEquipmentByStatus(retired): legacy rows that only flipped
/// is_active, but not sold or wanted gear (stored inactive too).
List<QueryNode> _retiredView() => [
  OrNode([
    _c('status', QueryOp.eq, EnumValue(EquipmentStatus.retired.name)),
    _c('active', QueryOp.eq, const BoolValue(false)),
  ]),
  _c('status', QueryOp.neq, EnumValue(EquipmentStatus.sold.name)),
  _c('status', QueryOp.neq, EnumValue(EquipmentStatus.wanted.name)),
];

/// Statuses whose rows are stored inactive by design, so their view reads
/// the status alone.
const _inactiveByDesign = {EquipmentStatus.sold, EquipmentStatus.wanted};

/// The default view for [statuses] (#2628). The factory set (and an empty
/// one, which the setting never stores) keeps getActiveEquipment's exact
/// conditions: legacy rows can be retired with is_active still set, sold
/// gear has left the kit, and wanted gear has not joined it. A custom set
/// ORs each status's own view, so the legacy retired rule still holds.
List<QueryNode> _defaultViewParts(Set<EquipmentStatus> statuses) {
  if (statuses.isEmpty || isFactoryDefaultEquipmentStatuses(statuses)) {
    return [
      _c('active', QueryOp.eq, const BoolValue(true)),
      _c('status', QueryOp.neq, EnumValue(EquipmentStatus.retired.name)),
      _c('status', QueryOp.neq, EnumValue(EquipmentStatus.sold.name)),
      _c('status', QueryOp.neq, EnumValue(EquipmentStatus.wanted.name)),
    ];
  }
  final owned = [
    for (final s in EquipmentStatus.values)
      if (statuses.contains(s) &&
          s != EquipmentStatus.retired &&
          !_inactiveByDesign.contains(s))
        s,
  ];
  final options = <QueryNode>[
    if (owned.isNotEmpty)
      AndNode([
        _c('active', QueryOp.eq, const BoolValue(true)),
        owned.length == 1
            ? _c('status', QueryOp.eq, EnumValue(owned.single.name))
            : _c(
                'status',
                QueryOp.inList,
                ListValue([for (final s in owned) EnumValue(s.name)]),
              ),
      ]),
    for (final s in EquipmentStatus.values)
      if (statuses.contains(s) && _inactiveByDesign.contains(s))
        _c('status', QueryOp.eq, EnumValue(s.name)),
    if (statuses.contains(EquipmentStatus.retired)) AndNode(_retiredView()),
  ];
  return [options.length == 1 ? options.single : OrNode(options)];
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
/// dives as that diver's alone; [defaultStatuses] is the diver's default
/// view (#2628).
CompiledQuery compileEquipmentFilter(
  EquipmentFilterState filter, {
  String? diverId,
  required Set<EquipmentStatus> defaultStatuses,
}) => compileQuery(
  filter.toQuery(defaultStatuses: defaultStatuses),
  equipmentQueryEntity,
  appQueryRegistry,
  diverId: diverId,
);
