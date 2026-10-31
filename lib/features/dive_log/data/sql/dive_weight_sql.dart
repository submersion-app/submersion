/// SQL spelling of the lead a dive's detail page shows, for queries that read
/// weight without hydrating `Dive` object graphs.
///
/// The `dive_weights` rows win whenever the dive has any, and the retired
/// `dives.weight_amount` scalar is never added to them. An older or restored
/// log can still hold the scalar alone: nothing backfills it into rows, the
/// editor only converts a dive when it is opened and saved. A scalar of zero
/// or less is no recorded weight, the same test the detail page and the
/// editor's conversion apply.
///
/// The fragment lives here so Insights, its observations and the query
/// language cannot give two answers for one dive (issue #3914), and
/// `Dive.recordedWeightKg` is its Dart twin, held to it by
/// `dive_weight_sql_parity_test.dart`. Callers pass the table alias their
/// statement uses for `dives`.
library;

/// The dive's total lead in kilograms, or NULL when it has none recorded.
String recordedWeightKgSql(String alias) =>
    'COALESCE((SELECT SUM(w.amount_kg) FROM dive_weights w '
    'WHERE w.dive_id = $alias.id), '
    'CASE WHEN $alias.weight_amount > 0 THEN $alias.weight_amount END)';
