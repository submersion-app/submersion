import 'package:submersion/features/dive_log/domain/entities/dive.dart';

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
  final List<String> tagIds;

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
  final String? computerSerial;
  final String? customFieldKey;
  final String? customFieldValue;

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
    this.tagIds = const [],
    this.equipmentIds = const [],
    this.buddyNameFilter,
    this.buddyId,
    this.diveIds = const [],
    this.minO2Percent,
    this.maxO2Percent,
    this.minRating,
    this.minBottomTimeMinutes,
    this.maxBottomTimeMinutes,
    this.computerSerial,
    this.customFieldKey,
    this.customFieldValue,
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
      tagIds.isNotEmpty ||
      equipmentIds.isNotEmpty ||
      (buddyNameFilter != null && buddyNameFilter!.isNotEmpty) ||
      buddyId != null ||
      diveIds.isNotEmpty ||
      minO2Percent != null ||
      maxO2Percent != null ||
      minRating != null ||
      minBottomTimeMinutes != null ||
      maxBottomTimeMinutes != null ||
      computerSerial != null ||
      (customFieldKey != null && customFieldKey!.isNotEmpty);

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
    List<String>? tagIds,
    List<String>? equipmentIds,
    String? buddyNameFilter,
    String? buddyId,
    List<String>? diveIds,
    double? minO2Percent,
    double? maxO2Percent,
    int? minRating,
    int? minBottomTimeMinutes,
    int? maxBottomTimeMinutes,
    String? computerSerial,
    String? customFieldKey,
    String? customFieldValue,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearDiveType = false,
    bool clearSiteId = false,
    bool clearTripId = false,
    bool clearDiveCenterId = false,
    bool clearMinDepth = false,
    bool clearMaxDepth = false,
    bool clearFavoritesOnly = false,
    bool clearTagIds = false,
    bool clearEquipmentIds = false,
    bool clearBuddyNameFilter = false,
    bool clearBuddyId = false,
    bool clearDiveIds = false,
    bool clearMinO2Percent = false,
    bool clearMaxO2Percent = false,
    bool clearMinRating = false,
    bool clearMinBottomTimeMinutes = false,
    bool clearMaxBottomTimeMinutes = false,
    bool clearComputerSerial = false,
    bool clearCustomFieldKey = false,
    bool clearCustomFieldValue = false,
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
      tagIds: clearTagIds ? const [] : (tagIds ?? this.tagIds),
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
      computerSerial: clearComputerSerial
          ? null
          : (computerSerial ?? this.computerSerial),
      customFieldKey: clearCustomFieldKey
          ? null
          : (customFieldKey ?? this.customFieldKey),
      customFieldValue: clearCustomFieldValue
          ? null
          : (customFieldValue ?? this.customFieldValue),
    );
  }

  /// Filter a list of dives based on current filter state.
  /// Used as a fallback for non-paginated code paths (e.g., export).
  List<Dive> apply(List<Dive> dives) {
    return dives.where((dive) {
      if (startDate != null && dive.dateTime.isBefore(startDate!)) {
        return false;
      }
      if (endDate != null &&
          dive.dateTime.isAfter(endDate!.add(const Duration(days: 1)))) {
        return false;
      }
      if (diveTypeId != null && dive.diveTypeId != diveTypeId) {
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
      if (tagIds.isNotEmpty) {
        final diveTagIds = dive.tags.map((t) => t.id).toSet();
        if (!tagIds.any((tagId) => diveTagIds.contains(tagId))) {
          return false;
        }
      }
      if (buddyNameFilter != null && buddyNameFilter!.isNotEmpty) {
        final buddyLower = dive.buddy?.toLowerCase() ?? '';
        if (!buddyLower.contains(buddyNameFilter!.toLowerCase())) {
          return false;
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
        final durationMinutes = dive.bottomTime?.inMinutes;
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
      if (computerSerial != null) {
        if (dive.diveComputerSerial != computerSerial) return false;
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
      return true;
    }).toList();
  }
}
