import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_tree_edit.dart';
import 'package:submersion/core/query/syntax/query_printer.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';

/// The chips of spec Unit 5: one per top-level AND child of the advanced
/// query, labelled by the printer in the diver's units. Printing from the
/// tree the compiler consumes is what guarantees a chip never claims a
/// strictness the filter does not apply.
List<String> diveQueryChipLabels(QueryNode? query, UnitPrefs prefs) {
  final printer = QueryPrinter(appQueryRegistry, diveQueryEntity, prefs);
  return [for (final part in topLevelConjuncts(query)) printer.print(part)];
}

/// [filter] with the chip at [index] removed; `query` is cleared when the
/// last one goes.
DiveFilterState removeDiveQueryChip(DiveFilterState filter, int index) {
  final next = removeTopLevelConjunct(filter.query, index);
  return next == null
      ? filter.copyWith(clearQuery: true)
      : filter.copyWith(query: next);
}
