import 'package:submersion/core/constants/enums.dart';
import 'package:flutter/foundation.dart' show listEquals;

import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';

/// Filter state for the dive list.
///
/// A plain model the filter sheet edits. It evaluates nothing itself: every
/// consumer (the paginated list and its count, Statistics, the table, map
/// and export views) lowers it through `DiveFilterQuery.toQuery()` and
/// compiles that one tree to SQL (#2365).
class DiveFilterState {
  /// Inclusive first day of the range, treated as a CALENDAR DATE: only the
  /// year/month/day are read, and any time-of-day or timezone flag the value
  /// carries is discarded.
  ///
  /// Producers build these locally (the filter sheet's presets, and
  /// `showAppDatePicker` by construction) while `dives.dive_date_time` holds a
  /// wall clock flagged as UTC. Comparing the two frames raw shifted the day
  /// boundary by the device's UTC offset (issue #1368), so every comparison
  /// site goes through [startDateBoundMs] / [endDateBoundMs] instead.
  final DateTime? startDate;

  /// Inclusive last day of the range. See [startDate] for the calendar-date
  /// semantics; the whole of this day is kept.
  final DateTime? endDate;
  final String? diveTypeId;
  final String? siteId;
  final String? tripId;
  final String? diveCenterId;
  final double? minDepth;
  final double? maxDepth;
  final bool? favoritesOnly;

  /// When true, keep only dives the diver excluded from statistics, so
  /// they can find and review them (#526). Null means this axis is off.
  ///
  /// This is a view filter for *finding* excluded dives. It plays no part
  /// in enforcing the exclusion; that is DiveStatsScope's job and applies
  /// unconditionally, whether or not this axis is set.
  final bool? excludedFromStatsOnly;

  /// Decompression status, derived from the recorded profile signal: a
  /// deco-stop profile point, a `decoStopStart` event, or a positive ceiling
  /// on a profile carrying no deco-type data at all (mirroring
  /// `scanRecordedDecoSignals` in InsightsRepository). Null means no filter;
  /// true/false restrict to deco/no-deco dives. Dives whose status is
  /// unrecorded (no profile, or a profile needing the computed fallback)
  /// match neither.
  ///
  /// Lowered to the registry's `deco` field, whose SQL is
  /// `decoSignalCondition`, so every path evaluates it the same way.
  final bool? decoOnly;

  /// True to restrict the list to dives with no buddy assigned: neither the
  /// legacy free-text `buddy` field nor a linked buddy is set.
  final bool? noBuddyOnly;
  final List<String> tagIds;

  /// Restricts results to dives whose [Dive.dateTime] falls on one of these
  /// weekdays, using [DateTime.weekday] numbering (1 = Monday, 7 = Sunday).
  /// ANDs with [startDate]/[endDate] when both are set, like every other
  /// axis in this filter.
  final List<int> weekdays;

  // v1.5: Additional filter criteria
  final List<String> equipmentIds;
  final String? buddyNameFilter;

  /// Linked buddy to restrict to: a live check against the `dive_buddies`
  /// junction, never the legacy free-text `buddy` column. The buddy page's
  /// "View all" sets it beside [diveIds], so a dive that loses its link
  /// while the filter is active drops out (issue #1919).
  final String? buddyId;
  final List<String> diveIds;
  final double? minO2Percent;
  final double? maxO2Percent;
  final int? minRating;
  final int? minBottomTimeMinutes;
  final int? maxBottomTimeMinutes;

  /// Registered dive computer to restrict the list to, matched on
  /// `dives.computer_id`.
  ///
  /// Keyed on the computer id rather than its serial number: firmware often
  /// reports no serial, which used to leave those computers unfilterable
  /// (issue #1064).
  final String? computerId;
  final String? customFieldKey;
  final String? customFieldValue;

  /// Equipment-attribute conditions (curated keys only, issue #1805),
  /// combined with AND. A dive satisfies one when any item linked to it
  /// matches, directly or through a cylinder the transmitter registry
  /// matched. Suit thickness is one of them
  /// ([EquipmentAttrCondition.suitThickness]).
  final List<EquipmentAttrCondition> equipmentAttrConditions;

  /// Water temperature bounds in celsius against `dives.water_temp`. A dive
  /// with no recorded temperature never matches a set bound.
  final double? minWaterTemp;
  final double? maxWaterTemp;

  /// Visibility bounds in metres against `dives.visibility_meters` only; the
  /// legacy `visibility` bucket column is read-only and ignored.
  final double? minVisibility;
  final double? maxVisibility;

  /// Water types to keep (OR within the axis), matched on `dives.water_type`.
  final List<WaterType> waterTypes;

  /// Species ids: keep dives with a sighting of ANY listed species.
  final List<String> speciesIds;

  /// Site ids (OR within the axis), the set form of [siteId]; both apply when
  /// both are set. Explore lowers a place mention ("Bonaire") to this.
  final List<String> siteIds;

  /// The advanced part of the filter: a query tree the typed field or the
  /// rule builder edits (#2365). ANDed with every other axis by
  /// `toQuery()`. Null means no advanced conditions.
  final QueryNode? query;

  const DiveFilterState({
    this.startDate,
    this.endDate,
    this.diveTypeId,
    this.siteId,
    this.tripId,
    this.diveCenterId,
    this.minDepth,
    this.maxDepth,
    this.favoritesOnly,
    this.excludedFromStatsOnly,
    this.decoOnly,
    this.noBuddyOnly,
    this.tagIds = const [],
    this.weekdays = const [],
    this.equipmentIds = const [],
    this.buddyNameFilter,
    this.buddyId,
    this.diveIds = const [],
    this.minO2Percent,
    this.maxO2Percent,
    this.minRating,
    this.minBottomTimeMinutes,
    this.maxBottomTimeMinutes,
    this.computerId,
    this.customFieldKey,
    this.customFieldValue,
    this.equipmentAttrConditions = const [],
    this.minWaterTemp,
    this.maxWaterTemp,
    this.minVisibility,
    this.maxVisibility,
    this.waterTypes = const [],
    this.speciesIds = const [],
    this.siteIds = const [],
    this.query,
  });

  /// Inclusive lower bound for `dives.dive_date_time`, in the wall-clock-as-UTC
  /// epoch milliseconds that column stores. Null when [startDate] is unset.
  ///
  /// Every date comparison, in SQL and in [apply], binds this value, so the
  /// three implementations of the axis cannot drift apart.
  int? get startDateBoundMs {
    final date = startDate;
    if (date == null) return null;
    return wallClockUtcDayStart(date).millisecondsSinceEpoch;
  }

  /// EXCLUSIVE upper bound for `dives.dive_date_time`: the start of the day
  /// after [endDate], so the whole of the end day is inside the range. Null
  /// when [endDate] is unset.
  int? get endDateBoundMs {
    final date = endDate;
    if (date == null) return null;
    // UTC has no DST, so adding a day here is exact.
    return wallClockUtcDayStart(
      date,
    ).add(const Duration(days: 1)).millisecondsSinceEpoch;
  }

  bool get hasActiveFilters =>
      minWaterTemp != null ||
      maxWaterTemp != null ||
      minVisibility != null ||
      maxVisibility != null ||
      waterTypes.isNotEmpty ||
      speciesIds.isNotEmpty ||
      siteIds.isNotEmpty ||
      startDate != null ||
      endDate != null ||
      diveTypeId != null ||
      siteId != null ||
      tripId != null ||
      diveCenterId != null ||
      minDepth != null ||
      maxDepth != null ||
      favoritesOnly == true ||
      excludedFromStatsOnly == true ||
      decoOnly != null ||
      noBuddyOnly == true ||
      tagIds.isNotEmpty ||
      weekdays.isNotEmpty ||
      equipmentIds.isNotEmpty ||
      (buddyNameFilter != null && buddyNameFilter!.isNotEmpty) ||
      buddyId != null ||
      diveIds.isNotEmpty ||
      minO2Percent != null ||
      maxO2Percent != null ||
      minRating != null ||
      minBottomTimeMinutes != null ||
      maxBottomTimeMinutes != null ||
      computerId != null ||
      (customFieldKey != null && customFieldKey!.isNotEmpty) ||
      equipmentAttrConditions.isNotEmpty ||
      query != null;

  /// Value equality over every axis, so an unchanged filter set again is
  /// no change to a listener, and the id-set family keyed on the filter
  /// reuses its instance for an equal filter.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiveFilterState &&
          other.startDate == startDate &&
          other.endDate == endDate &&
          other.diveTypeId == diveTypeId &&
          other.siteId == siteId &&
          other.tripId == tripId &&
          other.diveCenterId == diveCenterId &&
          other.minDepth == minDepth &&
          other.maxDepth == maxDepth &&
          other.favoritesOnly == favoritesOnly &&
          other.excludedFromStatsOnly == excludedFromStatsOnly &&
          other.decoOnly == decoOnly &&
          other.noBuddyOnly == noBuddyOnly &&
          listEquals(other.tagIds, tagIds) &&
          listEquals(other.weekdays, weekdays) &&
          listEquals(other.equipmentIds, equipmentIds) &&
          other.buddyNameFilter == buddyNameFilter &&
          other.buddyId == buddyId &&
          listEquals(other.diveIds, diveIds) &&
          other.minO2Percent == minO2Percent &&
          other.maxO2Percent == maxO2Percent &&
          other.minRating == minRating &&
          other.minBottomTimeMinutes == minBottomTimeMinutes &&
          other.maxBottomTimeMinutes == maxBottomTimeMinutes &&
          other.computerId == computerId &&
          other.customFieldKey == customFieldKey &&
          other.customFieldValue == customFieldValue &&
          listEquals(other.equipmentAttrConditions, equipmentAttrConditions) &&
          other.minWaterTemp == minWaterTemp &&
          other.maxWaterTemp == maxWaterTemp &&
          other.minVisibility == minVisibility &&
          other.maxVisibility == maxVisibility &&
          listEquals(other.waterTypes, waterTypes) &&
          listEquals(other.speciesIds, speciesIds) &&
          listEquals(other.siteIds, siteIds) &&
          other.query == query;

  @override
  int get hashCode => Object.hashAll([
    startDate,
    endDate,
    diveTypeId,
    siteId,
    tripId,
    diveCenterId,
    minDepth,
    maxDepth,
    favoritesOnly,
    excludedFromStatsOnly,
    decoOnly,
    noBuddyOnly,
    Object.hashAll(tagIds),
    Object.hashAll(weekdays),
    Object.hashAll(equipmentIds),
    buddyNameFilter,
    buddyId,
    Object.hashAll(diveIds),
    minO2Percent,
    maxO2Percent,
    minRating,
    minBottomTimeMinutes,
    maxBottomTimeMinutes,
    computerId,
    customFieldKey,
    customFieldValue,
    Object.hashAll(equipmentAttrConditions),
    minWaterTemp,
    maxWaterTemp,
    minVisibility,
    maxVisibility,
    Object.hashAll(waterTypes),
    Object.hashAll(speciesIds),
    Object.hashAll(siteIds),
    query,
  ]);

  DiveFilterState copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? diveTypeId,
    String? siteId,
    String? tripId,
    String? diveCenterId,
    double? minDepth,
    double? maxDepth,
    bool? favoritesOnly,
    bool? excludedFromStatsOnly,
    bool? decoOnly,
    bool? noBuddyOnly,
    List<String>? tagIds,
    List<int>? weekdays,
    List<String>? equipmentIds,
    String? buddyNameFilter,
    String? buddyId,
    List<String>? diveIds,
    double? minO2Percent,
    double? maxO2Percent,
    int? minRating,
    int? minBottomTimeMinutes,
    int? maxBottomTimeMinutes,
    String? computerId,
    String? customFieldKey,
    String? customFieldValue,
    List<EquipmentAttrCondition>? equipmentAttrConditions,
    double? minWaterTemp,
    double? maxWaterTemp,
    double? minVisibility,
    double? maxVisibility,
    List<WaterType>? waterTypes,
    List<String>? speciesIds,
    List<String>? siteIds,
    QueryNode? query,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearDiveType = false,
    bool clearSiteId = false,
    bool clearTripId = false,
    bool clearDiveCenterId = false,
    bool clearMinDepth = false,
    bool clearMaxDepth = false,
    bool clearFavoritesOnly = false,
    bool clearExcludedFromStatsOnly = false,
    bool clearDecoOnly = false,
    bool clearNoBuddyOnly = false,
    bool clearTagIds = false,
    bool clearWeekdays = false,
    bool clearEquipmentIds = false,
    bool clearBuddyNameFilter = false,
    bool clearBuddyId = false,
    bool clearDiveIds = false,
    bool clearMinO2Percent = false,
    bool clearMaxO2Percent = false,
    bool clearMinRating = false,
    bool clearMinBottomTimeMinutes = false,
    bool clearMaxBottomTimeMinutes = false,
    bool clearComputerId = false,
    bool clearCustomFieldKey = false,
    bool clearCustomFieldValue = false,
    bool clearEquipmentAttrConditions = false,
    bool clearMinWaterTemp = false,
    bool clearMaxWaterTemp = false,
    bool clearMinVisibility = false,
    bool clearMaxVisibility = false,
    bool clearWaterTypes = false,
    bool clearSpeciesIds = false,
    bool clearSiteIds = false,
    bool clearQuery = false,
  }) {
    return DiveFilterState(
      minWaterTemp: clearMinWaterTemp
          ? null
          : (minWaterTemp ?? this.minWaterTemp),
      maxWaterTemp: clearMaxWaterTemp
          ? null
          : (maxWaterTemp ?? this.maxWaterTemp),
      minVisibility: clearMinVisibility
          ? null
          : (minVisibility ?? this.minVisibility),
      maxVisibility: clearMaxVisibility
          ? null
          : (maxVisibility ?? this.maxVisibility),
      waterTypes: clearWaterTypes ? const [] : (waterTypes ?? this.waterTypes),
      speciesIds: clearSpeciesIds ? const [] : (speciesIds ?? this.speciesIds),
      siteIds: clearSiteIds ? const [] : (siteIds ?? this.siteIds),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      diveTypeId: clearDiveType ? null : (diveTypeId ?? this.diveTypeId),
      siteId: clearSiteId ? null : (siteId ?? this.siteId),
      tripId: clearTripId ? null : (tripId ?? this.tripId),
      diveCenterId: clearDiveCenterId
          ? null
          : (diveCenterId ?? this.diveCenterId),
      minDepth: clearMinDepth ? null : (minDepth ?? this.minDepth),
      maxDepth: clearMaxDepth ? null : (maxDepth ?? this.maxDepth),
      favoritesOnly: clearFavoritesOnly
          ? null
          : (favoritesOnly ?? this.favoritesOnly),
      excludedFromStatsOnly: clearExcludedFromStatsOnly
          ? null
          : (excludedFromStatsOnly ?? this.excludedFromStatsOnly),
      decoOnly: clearDecoOnly ? null : (decoOnly ?? this.decoOnly),
      noBuddyOnly: clearNoBuddyOnly ? null : (noBuddyOnly ?? this.noBuddyOnly),
      tagIds: clearTagIds ? const [] : (tagIds ?? this.tagIds),
      weekdays: clearWeekdays ? const [] : (weekdays ?? this.weekdays),
      equipmentIds: clearEquipmentIds
          ? const []
          : (equipmentIds ?? this.equipmentIds),
      buddyNameFilter: clearBuddyNameFilter
          ? null
          : (buddyNameFilter ?? this.buddyNameFilter),
      buddyId: clearBuddyId ? null : (buddyId ?? this.buddyId),
      diveIds: clearDiveIds ? const [] : (diveIds ?? this.diveIds),
      minO2Percent: clearMinO2Percent
          ? null
          : (minO2Percent ?? this.minO2Percent),
      maxO2Percent: clearMaxO2Percent
          ? null
          : (maxO2Percent ?? this.maxO2Percent),
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      minBottomTimeMinutes: clearMinBottomTimeMinutes
          ? null
          : (minBottomTimeMinutes ?? this.minBottomTimeMinutes),
      maxBottomTimeMinutes: clearMaxBottomTimeMinutes
          ? null
          : (maxBottomTimeMinutes ?? this.maxBottomTimeMinutes),
      computerId: clearComputerId ? null : (computerId ?? this.computerId),
      customFieldKey: clearCustomFieldKey
          ? null
          : (customFieldKey ?? this.customFieldKey),
      customFieldValue: clearCustomFieldValue
          ? null
          : (customFieldValue ?? this.customFieldValue),
      equipmentAttrConditions: clearEquipmentAttrConditions
          ? const []
          : (equipmentAttrConditions ?? this.equipmentAttrConditions),
      query: clearQuery ? null : (query ?? this.query),
    );
  }
}
