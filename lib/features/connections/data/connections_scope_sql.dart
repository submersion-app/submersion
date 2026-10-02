import 'package:submersion/core/database/dive_stats_scope.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/data/dive_filter_sql.dart';

/// The WHERE terms every connections query shares, for a `dives` table
/// aliased `d`: the owning diver (when known), the always-on statistics
/// scope, and the diver's view filter when any axis is active.
///
/// Params are returned in clause order, so callers append their own clauses
/// and params after these.
({List<String> clauses, List<Object?> params}) diveScopeSql({
  required String? diverId,
  required DiveFilterState filter,
}) {
  final clauses = <String>[];
  final params = <Object?>[];
  if (diverId != null) {
    clauses.add('d.diver_id = ?');
    params.add(diverId);
  }
  clauses.add(DiveStatsScope.predicate(alias: 'd'));
  final f = buildFilteredDiveIdSubquery(filter);
  if (f.subquery.isNotEmpty) {
    clauses.add('d.id IN (${f.subquery})');
    params.addAll(f.params);
  }
  return (clauses: clauses, params: params);
}

String placeholders(int count) => List.filled(count, '?').join(', ');

/// Escapes `\`, `%` and `_` so user text matches literally inside a LIKE
/// pattern written with `ESCAPE '\'`.
String escapeLike(String text) =>
    text.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
