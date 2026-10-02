import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
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
    _withPlace(scope, [_site('country', StringValue(country))]);

/// The dives behind one row of the Insights region card (#2623). Regions are
/// counted per country, so the row's [country] is pinned too, and a row
/// with no country keeps only sites that have none.
DiveFilterState regionDivesFilter(
  DiveFilterState scope, {
  required String region,
  required String? country,
}) => _withPlace(scope, [
  _site('region', StringValue(region)),
  if (country == null)
    ConditionNode(FieldPath(const ['site', 'country']), QueryOp.isEmpty, null)
  else
    _site('country', StringValue(country)),
]);

/// Opens the dive list showing [filter], replacing its current filter so a
/// leftover axis cannot hide some of the row's dives. The filter chips on
/// the dive list clear it again.
void openInsightsDives(
  BuildContext context,
  WidgetRef ref,
  DiveFilterState filter,
) {
  ref.read(diveFilterProvider.notifier).state = filter;
  // go, not push: the dive list is a shell tab.
  context.go('/dives');
}

ConditionNode _site(String column, StringValue value) =>
    ConditionNode(FieldPath(['site', column]), QueryOp.eq, value);

/// ANDs [place] onto the scope's own advanced query, keeping every other
/// axis of the scope as it is.
DiveFilterState _withPlace(DiveFilterState scope, List<QueryNode> place) {
  final parts = [?scope.query, ...place];
  return scope.copyWith(
    query: parts.length == 1 ? parts.single : AndNode(parts),
  );
}
