import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';

/// Filter state for dive list.
///
/// Used by both the provider layer (UI filter state) and the repository layer
/// (SQL WHERE clause generation for paginated queries).
class DiveFilterState {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? diveTypeId;
  final String? siteId;
  final String? tripId;
  final String? diveCenterId;
  final double? minDepth;
  final double? maxDepth;
  final bool? favoritesOnly;

  /// Decompression status, derived from the recorded profile signal: a
  /// deco-stop profile point, a `decoStopStart` event, or a positive ceiling
  /// on a profile carrying no deco-type data at all (mirroring
  /// `scanRecordedDecoSignals` in StatisticsRepository). Null means no filter;
  /// true/false restrict to deco/no-deco dives. Dives whose status is
  /// unrecorded (no profile, or a profile needing the computed fallback)
  /// match neither.
  ///
  /// This axis is SQL-only. It is applied by `decoSignalCondition` in the
  /// query paths and deliberately NOT by [apply]; see the note there.
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

  // Equipment-attribute axis (curated keys only). key selects the attribute;
  // choice matches value_text; min/max bound value_num (canonical metric).
  final String? equipmentAttrKey;
  final String? equipmentAttrChoice;
  final double? equipmentAttrMin;
  final double? equipmentAttrMax;

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
    this.equipmentAttrKey,
    this.equipmentAttrChoice,
    this.equipmentAttrMin,
    this.equipmentAttrMax,
  });

  bool get hasActiveFilters =>
      startDate != null ||
      endDate != null ||
      diveTypeId != null ||
      siteId != null ||
      tripId != null ||
      diveCenterId != null ||
      minDepth != null ||
      maxDepth != null ||
      favoritesOnly == true ||
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
      equipmentAttrKey != null;

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
    String? equipmentAttrKey,
    String? equipmentAttrChoice,
    double? equipmentAttrMin,
    double? equipmentAttrMax,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearDiveType = false,
    bool clearSiteId = false,
    bool clearTripId = false,
    bool clearDiveCenterId = false,
    bool clearMinDepth = false,
    bool clearMaxDepth = false,
    bool clearFavoritesOnly = false,
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
    bool clearEquipmentAttr = false,
  }) {
    return DiveFilterState(
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
      equipmentAttrKey: clearEquipmentAttr
          ? null
          : (equipmentAttrKey ?? this.equipmentAttrKey),
      equipmentAttrChoice: clearEquipmentAttr
          ? null
          : (equipmentAttrChoice ?? this.equipmentAttrChoice),
      equipmentAttrMin: clearEquipmentAttr
          ? null
          : (equipmentAttrMin ?? this.equipmentAttrMin),
      equipmentAttrMax: clearEquipmentAttr
          ? null
          : (equipmentAttrMax ?? this.equipmentAttrMax),
    );
  }

  /// Filter a list of dives based on current filter state.
  /// Used as a fallback for non-paginated code paths (e.g., export, table/map
  /// views).
  ///
  /// equipmentAttr* is applied in-memory here to mirror the SQL axis (see
  /// buildFilteredDiveIdSubquery), so non-paginated views stay consistent with
  /// the SQL-backed list. It relies on dive.equipment being hydrated with its
  /// curated attributes (getAllDives does this).
  ///
  /// [decoOnly] is the one axis this method does NOT apply. getAllDives skips
  /// profile hydration for list views and deco-stop events never reach the
  /// entity, so there is nothing here to classify a dive from; evaluating it
  /// anyway would silently match no dive at all. Callers that honour the deco
  /// axis intersect this result with `decoFilteredDiveIdsProvider`, which
  /// resolves it through the same SQL condition the paginated list uses.
  List<Dive> apply(List<Dive> dives) {
    return dives.where((dive) {
      if (startDate != null && dive.dateTime.isBefore(startDate!)) {
        return false;
      }
      if (endDate != null &&
          dive.dateTime.isAfter(endDate!.add(const Duration(days: 1)))) {
        return false;
      }
      if (diveTypeId != null && !dive.diveTypeIds.contains(diveTypeId)) {
        return false;
      }
      if (siteId != null && dive.site?.id != siteId) {
        return false;
      }
      if (tripId != null && dive.tripId != tripId) {
        return false;
      }
      if (diveCenterId != null && dive.diveCenter?.id != diveCenterId) {
        return false;
      }
      if (equipmentIds.isNotEmpty) {
        final diveEquipmentIds = dive.equipment.map((e) => e.id).toSet();
        if (!equipmentIds.any((eqId) => diveEquipmentIds.contains(eqId))) {
          return false;
        }
      }
      if (minDepth != null &&
          (dive.maxDepth == null || dive.maxDepth! < minDepth!)) {
        return false;
      }
      if (maxDepth != null &&
          (dive.maxDepth == null || dive.maxDepth! > maxDepth!)) {
        return false;
      }
      if (favoritesOnly == true && !dive.isFavorite) {
        return false;
      }
      if (noBuddyOnly == true) {
        final hasLegacyBuddy = dive.buddy != null && dive.buddy!.isNotEmpty;
        if (hasLegacyBuddy || dive.buddies.isNotEmpty) {
          return false;
        }
      }
      if (tagIds.isNotEmpty) {
        final diveTagIds = dive.tags.map((t) => t.id).toSet();
        if (!tagIds.any((tagId) => diveTagIds.contains(tagId))) {
          return false;
        }
      }
      if (weekdays.isNotEmpty && !weekdays.contains(dive.dateTime.weekday)) {
        return false;
      }
      if (buddyNameFilter != null && buddyNameFilter!.isNotEmpty) {
        final filters = buddyNameFilter!
            .split(',')
            .map((s) => s.trim().toLowerCase())
            .where((s) => s.isNotEmpty)
            .toList();

        for (final filterLower in filters) {
          final legacyBuddyText = dive.buddy?.toLowerCase() ?? '';
          final hasLegacyMatch = legacyBuddyText.contains(filterLower);
          final hasLinkedBuddyMatch = dive.buddies.any(
            (b) => b.buddy.name.toLowerCase().contains(filterLower),
          );
          if (!hasLegacyMatch && !hasLinkedBuddyMatch) {
            return false;
          }
        }
      }
      if (diveIds.isNotEmpty && !diveIds.contains(dive.id)) {
        return false;
      }
      if (minO2Percent != null || maxO2Percent != null) {
        if (dive.tanks.isEmpty) return false;
        final hasMatchingTank = dive.tanks.any((tank) {
          final o2 = tank.gasMix.o2;
          if (minO2Percent != null && o2 < minO2Percent!) return false;
          if (maxO2Percent != null && o2 > maxO2Percent!) return false;
          return true;
        });
        if (!hasMatchingTank) return false;
      }
      if (minRating != null) {
        if (dive.rating == null || dive.rating! < minRating!) return false;
      }
      if (minBottomTimeMinutes != null || maxBottomTimeMinutes != null) {
        final durationMinutes = (dive.bottomTime)?.inMinutes;
        if (durationMinutes == null) return false;
        if (minBottomTimeMinutes != null &&
            durationMinutes < minBottomTimeMinutes!) {
          return false;
        }
        if (maxBottomTimeMinutes != null &&
            durationMinutes > maxBottomTimeMinutes!) {
          return false;
        }
      }
      if (computerId != null) {
        if (dive.computerId != computerId) return false;
      }
      if (customFieldKey != null && customFieldKey!.isNotEmpty) {
        final hasMatch = dive.customFields.any((cf) {
          if (cf.key != customFieldKey) return false;
          if (customFieldValue != null && customFieldValue!.isNotEmpty) {
            return cf.value.toLowerCase().contains(
              customFieldValue!.toLowerCase(),
            );
          }
          return true;
        });
        if (!hasMatch) return false;
      }
      // Equipment-attribute axis: mirror the SQL subquery (curated rows only,
      // value_text exact-matches choice, value_num bounded by min/max).
      if (equipmentAttrKey != null) {
        // "Suit thickness" (thickness_mm) matches only exposure suits, mirroring
        // getDivesBySuitThickness() and the SQL axis; hoods/gloves/boots also
        // carry thickness_mm but are not suits.
        final suitOnly = equipmentAttrKey == EquipmentAttrKeys.thicknessMm;
        final matches = dive.equipment.any((item) {
          if (suitOnly &&
              item.type != EquipmentType.wetsuit &&
              item.type != EquipmentType.drysuit) {
            return false;
          }
          return item.attributes.any((attr) {
            if (attr.isCustom || attr.key != equipmentAttrKey) return false;
            if (equipmentAttrChoice != null &&
                attr.valueText != equipmentAttrChoice) {
              return false;
            }
            if (equipmentAttrMin != null &&
                (attr.valueNum == null || attr.valueNum! < equipmentAttrMin!)) {
              return false;
            }
            if (equipmentAttrMax != null &&
                (attr.valueNum == null || attr.valueNum! > equipmentAttrMax!)) {
              return false;
            }
            return true;
          });
        });
        if (!matches) return false;
      }
      return true;
    }).toList();
  }
}
