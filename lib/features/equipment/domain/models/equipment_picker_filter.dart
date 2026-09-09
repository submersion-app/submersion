import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Narrows the Add Equipment picker, requested in #1576 for divers with large
/// inventories.
///
/// Deliberately NOT [EquipmentFilterState], the Equipment page's filter, for
/// two reasons:
///
/// - That filter's status axis decides which provider the list reads (active,
///   service-due, or one status). The picker reads exactly one provider,
///   `activeEquipmentProvider`, so both axes here are pure client-side
///   narrowing over that single result.
/// - Sharing state would mean filtering the Equipment page silently filtered
///   the dive picker, which is not what either surface's control implies.
///
/// There is no service-due axis: it needs the service-clock providers the
/// picker never loads, and "needs service" is not how a diver picks the gear
/// they actually dived.
///
/// [EquipmentStatus.retired] is absent from the picker by construction
/// (`getActiveEquipment` excludes it, per #636), so it is never offered.
@immutable
class EquipmentPickerFilter {
  /// One status, or null for every status the picker can show.
  final EquipmentStatus? status;

  /// One gear category, or null for every category.
  final EquipmentType? type;

  const EquipmentPickerFilter({this.status, this.type});

  static const EquipmentPickerFilter none = EquipmentPickerFilter();

  /// Whether the control should carry its badge.
  bool get hasActiveFilters => status != null || type != null;

  /// Narrow [equipment]. Both axes compose with AND semantics.
  List<EquipmentItem> apply(List<EquipmentItem> equipment) {
    if (!hasActiveFilters) return equipment;
    return [
      for (final item in equipment)
        if ((status == null || item.status == status) &&
            (type == null || item.type == type))
          item,
    ];
  }

  EquipmentPickerFilter copyWith({
    EquipmentStatus? status,
    EquipmentType? type,
    bool clearStatus = false,
    bool clearType = false,
  }) {
    return EquipmentPickerFilter(
      status: clearStatus ? null : (status ?? this.status),
      type: clearType ? null : (type ?? this.type),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EquipmentPickerFilter &&
          other.status == status &&
          other.type == type;

  @override
  int get hashCode => Object.hash(status, type);

  @override
  String toString() => 'EquipmentPickerFilter(status: $status, type: $type)';
}
