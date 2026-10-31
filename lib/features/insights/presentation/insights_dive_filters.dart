import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// The dives behind one row of the Insights country card (#2623): the
/// Insights filter [scope] the row was counted under, narrowed to sites in
/// [country].
///
/// The row's count comes from `getCountriesVisited`, which groups the way
/// `site.country` compares (trimmed, case-insensitive), so the list it opens
/// holds the dives it counted once `getCountedDiveIds` applies the statistics
/// scope.
DiveFilterState countryDivesFilter(DiveFilterState scope, String country) =>
    _withConditions(scope, [_site('country', StringValue(country))]);

/// The dives behind one row of the Insights region card (#2623). Regions are
/// counted per country, so the row's [country] is pinned too, and a row
/// with no country keeps only sites that have none.
DiveFilterState regionDivesFilter(
  DiveFilterState scope, {
  required String region,
  required String? country,
}) => _withConditions(scope, [
  _site('region', StringValue(region)),
  if (country == null)
    ConditionNode(FieldPath(const ['site', 'country']), QueryOp.isEmpty, null)
  else
    _site('country', StringValue(country)),
]);

/// The dives behind one cell of the Time patterns calendar-days card
/// (#3127): the Insights filter [scope], narrowed to dives logged on
/// [month] / [day] in any year.
///
/// The `month` and `day` query fields read the same wall-clock date parts
/// as `getCalendarDayMatrix`, so this picks out the dives the cell counted.
DiveFilterState calendarDayDivesFilter(
  DiveFilterState scope, {
  required int month,
  required int day,
}) => _withConditions(scope, [
  ConditionNode(
    FieldPath(const ['month']),
    QueryOp.eq,
    NumberValue(month.toDouble(), null),
  ),
  ConditionNode(
    FieldPath(const ['day']),
    QueryOp.eq,
    NumberValue(day.toDouble(), null),
  ),
]);

ConditionNode _site(String column, StringValue value) =>
    ConditionNode(FieldPath(['site', column]), QueryOp.eq, value);

/// ANDs [conditions] (a place, a calendar date) onto the scope's own
/// advanced query, keeping every other axis of the scope as it is.
DiveFilterState _withConditions(
  DiveFilterState scope,
  List<QueryNode> conditions,
) {
  final parts = [?scope.query, ...conditions];
  return scope.copyWith(
    query: parts.length == 1 ? parts.single : AndNode(parts),
  );
}
