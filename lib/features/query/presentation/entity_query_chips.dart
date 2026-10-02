import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_tree_edit.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/syntax/query_printer.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/query/app_query_registry.dart';

/// The chips of spec Unit 5 for any list rooted at [root]: one per
/// top-level AND child of the advanced query, labelled by the printer in
/// the diver's units. Printing from the tree the compiler consumes is what
/// guarantees a chip never claims a strictness the filter does not apply.
List<String> entityQueryChipLabels(
  QueryEntity root,
  QueryNode? query,
  UnitPrefs prefs,
) {
  final printer = QueryPrinter(appQueryRegistry, root, prefs);
  return [for (final part in topLevelConjuncts(query)) printer.print(part)];
}

/// [entityQueryChipLabels] paired with what each chip's delete leaves: the
/// query without that condition, or null when it was the last one. A list
/// writes `rest` back to its filter (clearing the query when null).
List<({String label, QueryNode? rest})> entityQueryChips(
  QueryEntity root,
  QueryNode? query,
  UnitPrefs prefs,
) => [
  for (final (i, label) in entityQueryChipLabels(root, query, prefs).indexed)
    (label: label, rest: removeTopLevelConjunct(query, i)),
];
