import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';

/// Narrows one equipment item's service history.
///
/// Filtering happens in the presentation layer over the already loaded
/// per-item record list: the repository already scopes by equipment and these
/// lists are small, so a query-level filter would add a code path without
/// buying anything.
class MaintenanceHistoryFilter extends Equatable {
  /// Selects records whose [ServiceRecord.serviceKindId] is null. A real kind
  /// id can never collide with it: kind ids are uuids or the built-in slugs.
  static const untaggedSentinel = '__untagged__';

  final String? serviceKindId;
  final ServiceCategory? serviceCategory;
  final int? year;

  const MaintenanceHistoryFilter({
    this.serviceKindId,
    this.serviceCategory,
    this.year,
  });

  bool get isActive =>
      serviceKindId != null || serviceCategory != null || year != null;

  bool matches(ServiceRecord record) {
    if (serviceKindId == untaggedSentinel) {
      if (record.serviceKindId != null) return false;
    } else if (serviceKindId != null && record.serviceKindId != serviceKindId) {
      return false;
    }
    if (serviceCategory != null && record.serviceCategory != serviceCategory) {
      return false;
    }
    if (year != null && record.serviceDate.year != year) return false;
    return true;
  }

  /// Every field is nullable and clearable, so each parameter takes the plain
  /// value and passing null means "clear this dimension", which is what the
  /// "All" option in each dropdown does. This deliberately differs from
  /// [ServiceKind.copyWith] and friends, whose `_undefined` sentinel exists so
  /// a nullable field can be cleared *or* left alone; here clearing is the
  /// only thing any caller ever wants, so callers pass every field they keep.
  MaintenanceHistoryFilter copyWith({
    String? serviceKindId,
    ServiceCategory? serviceCategory,
    int? year,
  }) => MaintenanceHistoryFilter(
    serviceKindId: serviceKindId,
    serviceCategory: serviceCategory,
    year: year,
  );

  @override
  List<Object?> get props => [serviceKindId, serviceCategory, year];
}
