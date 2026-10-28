import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/models/sort_state_codec.dart';
import 'package:submersion/features/certifications/presentation/utils/certification_grouping.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_grouping.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Saves how the diver left each list (issue #3748), for the active diver.
///
/// Each waits for the diver's settings to load, through
/// [SettingsNotifier.updateListArrangements], so a sort tapped at launch is
/// not overwritten when the load lands. The list providers watch the saved
/// value, so the list follows as soon as the setter updates the state.
extension ListArrangementWrites on SettingsNotifier {
  Future<void> setDiveSort(SortState<DiveSortField> sort) =>
      updateListArrangements(
        (a) => a.copyWith(diveSort: encodeSortState(sort)),
      );

  Future<void> setDivePlanSort(SortState<DivePlanSortField> sort) =>
      updateListArrangements(
        (a) => a.copyWith(divePlanSort: encodeSortState(sort)),
      );

  Future<void> setTripSort(SortState<TripSortField> sort) =>
      updateListArrangements(
        (a) => a.copyWith(tripSort: encodeSortState(sort)),
      );

  Future<void> setCourseSort(SortState<CourseSortField> sort) =>
      updateListArrangements(
        (a) => a.copyWith(courseSort: encodeSortState(sort)),
      );

  Future<void> setBuddySort(SortState<BuddySortField> sort) =>
      updateListArrangements(
        (a) => a.copyWith(buddySort: encodeSortState(sort)),
      );

  Future<void> setDiveCenterSort(SortState<DiveCenterSortField> sort) =>
      updateListArrangements(
        (a) => a.copyWith(diveCenterSort: encodeSortState(sort)),
      );

  Future<void> setSiteSort(SortState<SiteSortField> sort) =>
      updateListArrangements(
        (a) => a.copyWith(siteSort: encodeSortState(sort)),
      );

  Future<void> setCertificationSort(SortState<CertificationSortField> sort) =>
      updateListArrangements(
        (a) => a.copyWith(certificationSort: encodeSortState(sort)),
      );

  Future<void> setEquipmentSort(SortState<EquipmentSortField> sort) =>
      updateListArrangements(
        (a) => a.copyWith(equipmentSort: encodeSortState(sort)),
      );

  Future<void> setSiteGroupBy(SiteGroupBy groupBy) =>
      updateListArrangements((a) => a.copyWith(siteGroupBy: groupBy.name));

  Future<void> setCertificationGroupBy(CertificationGroupBy groupBy) =>
      updateListArrangements(
        (a) => a.copyWith(certificationGroupBy: groupBy.name),
      );

  Future<void> setEquipmentGroupByLocation(bool value) =>
      updateListArrangements(
        (a) => a.copyWith(equipmentGroupByLocation: value),
      );
}
