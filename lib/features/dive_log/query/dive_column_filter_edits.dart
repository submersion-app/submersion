import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/column_rules.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_column_filters.dart';

/// [filter] with [rule] ANDed as a new top-level child (#2984), so it shows
/// as its own removable chip; unchanged when an equal child is there.
DiveFilterState addDiveTableRule(DiveFilterState filter, QueryNode rule) {
  final query = addColumnRule(filter.query, rule);
  if (identical(query, filter.query)) return filter;
  return filter.copyWith(query: query);
}

/// [filter] without [field]'s column filter: every top-level rule on its
/// key (plain or negated) and its Refine axis. Rules inside groups stay.
DiveFilterState resetDiveColumnFilter(DiveFilterState filter, DiveField field) {
  final key = kDiveColumnFilters[field]?.key;
  if (key == null) return filter;
  final query = resetColumnRules(filter.query, key);
  final withoutRules = identical(query, filter.query)
      ? filter
      : filter.copyWith(query: query, clearQuery: query == null);
  return _clearAxis(withoutRules, field);
}

/// Whether [field]'s column has a top-level rule or its axis set. An axis
/// "All dives" suspends is not filtering anything, so it does not count.
bool isDiveColumnFiltered(DiveFilterState filter, DiveField field) {
  final key = kDiveColumnFilters[field]?.key;
  if (key == null) return false;
  return isColumnFiltered(filter.query, key) ||
      (!filter.axesSuspended && _hasAxis(filter, field));
}

bool _hasAxis(DiveFilterState f, DiveField field) => switch (field) {
  DiveField.siteName => f.siteId != null || f.siteIds.isNotEmpty,
  DiveField.tripName => f.tripId != null,
  DiveField.diveCenterName => f.diveCenterId != null,
  DiveField.diveTypeName => f.diveTypeId != null,
  DiveField.diveComputerModel => f.computerId != null,
  DiveField.buddy =>
    f.buddyId != null || f.buddyNameFilter != null || f.noBuddyOnly == true,
  DiveField.tags => f.tagIds.isNotEmpty,
  DiveField.dateTime => f.startDate != null || f.endDate != null,
  DiveField.maxDepth => f.minDepth != null || f.maxDepth != null,
  DiveField.bottomTime =>
    f.minBottomTimeMinutes != null || f.maxBottomTimeMinutes != null,
  DiveField.waterTemp => f.minWaterTemp != null || f.maxWaterTemp != null,
  DiveField.visibility => f.minVisibility != null || f.maxVisibility != null,
  DiveField.ratingStars => f.minRating != null,
  DiveField.isFavorite => f.favoritesOnly == true,
  DiveField.waterType => f.waterTypes.isNotEmpty || f.noWaterType == true,
  DiveField.entryMethod => f.noEntryMethodOnly == true,
  _ => false,
};

DiveFilterState _clearAxis(
  DiveFilterState f,
  DiveField field,
) => switch (field) {
  DiveField.siteName => f.copyWith(clearSiteId: true, clearSiteIds: true),
  DiveField.tripName => f.copyWith(clearTripId: true),
  DiveField.diveCenterName => f.copyWith(clearDiveCenterId: true),
  DiveField.diveTypeName => f.copyWith(clearDiveType: true),
  DiveField.diveComputerModel => f.copyWith(clearComputerId: true),
  DiveField.buddy => f.copyWith(
    clearBuddyId: true,
    clearBuddyNameFilter: true,
    clearNoBuddyOnly: true,
  ),
  DiveField.tags => f.copyWith(clearTagIds: true),
  DiveField.dateTime => f.copyWith(clearStartDate: true, clearEndDate: true),
  DiveField.maxDepth => f.copyWith(clearMinDepth: true, clearMaxDepth: true),
  DiveField.bottomTime => f.copyWith(
    clearMinBottomTimeMinutes: true,
    clearMaxBottomTimeMinutes: true,
  ),
  DiveField.waterTemp => f.copyWith(
    clearMinWaterTemp: true,
    clearMaxWaterTemp: true,
  ),
  DiveField.visibility => f.copyWith(
    clearMinVisibility: true,
    clearMaxVisibility: true,
  ),
  DiveField.ratingStars => f.copyWith(clearMinRating: true),
  DiveField.isFavorite => f.copyWith(clearFavoritesOnly: true),
  DiveField.waterType => f.copyWith(
    clearWaterTypes: true,
    clearNoWaterType: true,
  ),
  DiveField.entryMethod => f.copyWith(clearNoEntryMethodOnly: true),
  _ => f,
};
