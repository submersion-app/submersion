import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/models/sort_state_codec.dart';
import 'package:submersion/features/certifications/presentation/utils/certification_grouping.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_grouping.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/domain/list_arrangements.dart';
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

  /// Applies [change] to the diver's gear arrangement and saves it.
  ///
  /// A diver who has not changed it since it moved per diver sees the
  /// app-wide value older builds saved, read from [legacySource], so the
  /// change builds on that rather than on the defaults. If that read fails
  /// for such a diver the change is refused (a [StateError]), since building
  /// on the defaults would save them over the diver's real arrangement. A
  /// diver with their own value never needs the read.
  Future<void> updateEquipmentArrangement(
    AppSettingsRepository legacySource,
    EquipmentArrangement Function(EquipmentArrangement current) change,
  ) async {
    // Decided after the load: until it lands, a diver switch can still show
    // the previous diver's arrangement.
    try {
      await settingsLoaded;
    } catch (_) {
      // Already logged by the load; the state it left stands.
    }
    EquipmentArrangement? legacy;
    var legacyKnown = false;
    final own = currentListArrangements.equipmentArrangement;
    if (decodeEquipmentArrangement(own) == null) {
      try {
        legacy = await legacySource.getEquipmentArrangement();
        legacyKnown = true;
      } catch (_) {
        // Unreadable: a diver without their own arrangement is refused below.
      }
    }
    await updateListArrangements((saved) {
      final current = pickEquipmentArrangement(saved.equipmentArrangement, () {
        // Unreadable, or not read because the diver had their own value when
        // this began and no longer does (another switch since): building on
        // the defaults would save them over what the diver sees.
        if (!legacyKnown) {
          throw StateError(
            'The stored gear arrangement could not be read, so a change '
            'cannot be applied to it',
          );
        }
        return legacy;
      });
      return saved.copyWith(
        equipmentArrangement: encodeEquipmentArrangement(change(current)),
      );
    });
  }

  /// How the diver left their lists as the notifier holds it now, read
  /// without a ref: a listener fires once, immediately, with the state, and
  /// is removed straight away so nothing stays registered.
  ListArrangements get currentListArrangements {
    late ListArrangements current;
    final removeListener = addListener((s) => current = s.listArrangements);
    removeListener();
    return current;
  }
}
