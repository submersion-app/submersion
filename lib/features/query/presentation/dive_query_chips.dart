import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_tree_edit.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/query/presentation/entity_query_chips.dart';

export 'package:submersion/features/query/presentation/entity_query_chips.dart';

/// [entityQueryChipLabels] rooted at dives.
List<String> diveQueryChipLabels(QueryNode? query, UnitPrefs prefs) =>
    entityQueryChipLabels(diveQueryEntity, query, prefs);

/// [filter] with the chip at [index] removed; `query` is cleared when the
/// last one goes.
DiveFilterState removeDiveQueryChip(DiveFilterState filter, int index) {
  final next = removeTopLevelConjunct(filter.query, index);
  return next == null
      ? filter.copyWith(clearQuery: true)
      : filter.copyWith(query: next);
}
