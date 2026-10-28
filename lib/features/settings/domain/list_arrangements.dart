import 'package:flutter/foundation.dart';

/// How the diver left each list: its sort, its grouping and Equipment's gear
/// arrangement (issue #3748). Stored per diver and synced under its own
/// clock, so a sort tap never republishes the diver's other settings.
///
/// Every value is the raw stored form, null when the diver never changed
/// that list. Raw on purpose: a value a newer build wrote (a sort field this
/// build lacks) is carried untouched, so this device reading it as the
/// starting order never erases the other device's choice. The list
/// providers decode it, falling back to their starting value.
///
/// Sorts are `field:direction` (see `encodeSortState`), groupings are enum
/// names, and [equipmentArrangement] is `EquipmentArrangement.toJson`
/// encoded as JSON.
@immutable
class ListArrangements {
  final String? diveSort;
  final String? divePlanSort;
  final String? tripSort;
  final String? courseSort;
  final String? buddySort;
  final String? diveCenterSort;
  final String? siteSort;
  final String? certificationSort;
  final String? equipmentSort;
  final String? siteGroupBy;
  final String? certificationGroupBy;
  final String? equipmentArrangement;
  final bool? equipmentGroupByLocation;

  const ListArrangements({
    this.diveSort,
    this.divePlanSort,
    this.tripSort,
    this.courseSort,
    this.buddySort,
    this.diveCenterSort,
    this.siteSort,
    this.certificationSort,
    this.equipmentSort,
    this.siteGroupBy,
    this.certificationGroupBy,
    this.equipmentArrangement,
    this.equipmentGroupByLocation,
  });

  /// No list changed yet: every list opens on its starting order.
  static const ListArrangements none = ListArrangements();

  /// A value is never cleared back to null: a list the diver changed stays
  /// changed.
  ListArrangements copyWith({
    String? diveSort,
    String? divePlanSort,
    String? tripSort,
    String? courseSort,
    String? buddySort,
    String? diveCenterSort,
    String? siteSort,
    String? certificationSort,
    String? equipmentSort,
    String? siteGroupBy,
    String? certificationGroupBy,
    String? equipmentArrangement,
    bool? equipmentGroupByLocation,
  }) {
    return ListArrangements(
      diveSort: diveSort ?? this.diveSort,
      divePlanSort: divePlanSort ?? this.divePlanSort,
      tripSort: tripSort ?? this.tripSort,
      courseSort: courseSort ?? this.courseSort,
      buddySort: buddySort ?? this.buddySort,
      diveCenterSort: diveCenterSort ?? this.diveCenterSort,
      siteSort: siteSort ?? this.siteSort,
      certificationSort: certificationSort ?? this.certificationSort,
      equipmentSort: equipmentSort ?? this.equipmentSort,
      siteGroupBy: siteGroupBy ?? this.siteGroupBy,
      certificationGroupBy: certificationGroupBy ?? this.certificationGroupBy,
      equipmentArrangement: equipmentArrangement ?? this.equipmentArrangement,
      equipmentGroupByLocation:
          equipmentGroupByLocation ?? this.equipmentGroupByLocation,
    );
  }

  List<Object?> get _props => [
    diveSort,
    divePlanSort,
    tripSort,
    courseSort,
    buddySort,
    diveCenterSort,
    siteSort,
    certificationSort,
    equipmentSort,
    siteGroupBy,
    certificationGroupBy,
    equipmentArrangement,
    equipmentGroupByLocation,
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListArrangements && listEquals(other._props, _props);

  @override
  int get hashCode => Object.hashAll(_props);
}
