import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/presentation/navigation/open_dive_list.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

/// The dives behind one row of the Insights country card (#2623): the
/// Insights filter [scope] the row was counted under, narrowed to sites in
/// [country].
///
/// The row's count comes from `getCountriesVisited`, which groups the way
/// `site.country` compares (trimmed, case-insensitive), so the list it opens
/// holds the dives it counted. The list also shows any dives there that are
/// excluded from statistics, which Insights leaves out of its counts.
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
/// as `getCalendarDayMatrix`, so the list it opens holds the dives the cell
/// counted (plus any excluded from statistics, as for the place rows).
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

/// Opens the dive list showing [filter], replacing its current filter so a
/// leftover axis cannot hide some of the row's dives. The filter chips on
/// the dive list clear it again. The list is pushed over Insights, so its
/// back arrow returns there (#3292).
void openInsightsDives(
  BuildContext context,
  WidgetRef ref,
  DiveFilterState filter,
) {
  openDiveList(context, ref, filter);
}

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
