import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart'
    show kNotRecordedDistributionKey;
import 'package:submersion/features/insights/domain/tank_configuration/tank_configuration.dart';

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
}) => _withConditions(scope, [_number('month', month), _number('day', day)]);

/// The dives behind one bar of the Day of Week chart (#3805). [dayOfWeek]
/// counts as the chart does, from 0 for Sunday.
DiveFilterState weekdayDivesFilter(DiveFilterState scope, int dayOfWeek) =>
    _withConditions(scope, [
      ConditionNode(
        FieldPath(const ['weekday']),
        QueryOp.eq,
        EnumValue(_weekdayNames[dayOfWeek]),
      ),
    ]);

/// The dives behind one bar of the Seasonal chart (#3805), in any year.
DiveFilterState monthDivesFilter(DiveFilterState scope, int month) =>
    _withConditions(scope, [_number('month', month)]);

/// The dives behind one bar of the Dives per Year chart (#3805).
DiveFilterState yearDivesFilter(DiveFilterState scope, int year) =>
    _withConditions(scope, [_number('year', year)]);

/// The dives behind one row of the dive types list (#3805). ANDed rather
/// than set on the scope's `diveTypeId`: a dive can carry several types, so
/// a scope already holding one type must keep it.
DiveFilterState diveTypeDivesFilter(DiveFilterState scope, String typeId) =>
    _withConditions(scope, [
      ConditionNode(
        FieldPath(const ['types']),
        QueryOp.eq,
        RefValue(typeId, typeId),
      ),
    ]);

/// The dives behind one water type segment (#3805). [key] is the chart's
/// key: a water type name or [kNotRecordedDistributionKey].
DiveFilterState waterTypeDivesFilter(DiveFilterState scope, String key) =>
    _withConditions(scope, [_recordedOrEmpty('waterType', key)]);

/// The dives behind one entry method bar (#3805). [key] is the chart's key:
/// an entry method name or [kNotRecordedDistributionKey].
DiveFilterState entryMethodDivesFilter(DiveFilterState scope, String key) =>
    _withConditions(scope, [_recordedOrEmpty('entryMethod', key)]);

/// The dives behind one configuration bar of the tank configuration card
/// (#3804): the Insights filter [scope], narrowed to [configuration].
///
/// A condition rather than the `tankConfigurations` axis, as for
/// [tankExtraDivesFilter].
DiveFilterState tankConfigDivesFilter(
  DiveFilterState scope,
  TankBaseConfiguration configuration,
) => _withConditions(scope, [
  ConditionNode(
    FieldPath(const ['tankConfig']),
    QueryOp.eq,
    EnumValue(configuration.name),
  ),
]);

/// The dives behind one extras bar of the tank configuration card. A
/// condition, not the `tankExtras` axis: that axis is OR, so tapping Deco
/// gas under a Stage(s) scope would list more dives than the bar counted.
DiveFilterState tankExtraDivesFilter(
  DiveFilterState scope,
  TankConfigurationExtra extra,
) => _withConditions(scope, [
  ConditionNode(FieldPath([extra.name]), QueryOp.eq, const BoolValue(true)),
]);

/// In the order the charts number days, from 0 for Sunday.
const _weekdayNames = [
  'sunday',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
];

ConditionNode _number(String field, int value) => ConditionNode(
  FieldPath([field]),
  QueryOp.eq,
  NumberValue(value.toDouble(), null),
);

ConditionNode _recordedOrEmpty(String field, String key) =>
    key == kNotRecordedDistributionKey
    ? ConditionNode(FieldPath([field]), QueryOp.isEmpty, null)
    : ConditionNode(FieldPath([field]), QueryOp.eq, EnumValue(key));

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
