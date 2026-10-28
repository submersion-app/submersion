import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_grouping_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/utils/certification_grouping.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_grouping.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_grouping_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/settings/domain/list_arrangements.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

import '../../../../helpers/mock_providers.dart';

/// Every list reads how the diver left it from the active diver's settings
/// (issue #3748), so it comes back after a restart, follows a diver switch
/// and follows a change synced in from another device.
void main() {
  late MockSettingsNotifier settings;
  late ProviderContainer container;

  setUp(() {
    settings = MockSettingsNotifier();
    container = ProviderContainer(
      overrides: [settingsProvider.overrideWith((ref) => settings)],
    );
  });
  tearDown(() => container.dispose());

  void saved(ListArrangements a) =>
      settings.state = settings.state.copyWith(listArrangements: a);

  test('each sort provider reads its saved value', () {
    saved(
      const ListArrangements(
        diveSort: 'depth:ascending',
        divePlanSort: 'name:ascending',
        tripSort: 'name:ascending',
        courseSort: 'name:ascending',
        buddySort: 'diveCount:ascending',
        diveCenterSort: 'diveCount:ascending',
        siteSort: 'rating:ascending',
        certificationSort: 'name:ascending',
        equipmentSort: 'purchaseDate:ascending',
      ),
    );
    const up = SortDirection.ascending;
    expect(
      container.read(diveSortProvider),
      const SortState(field: DiveSortField.depth, direction: up),
    );
    expect(
      container.read(divePlanSortProvider),
      const SortState(field: DivePlanSortField.name, direction: up),
    );
    expect(
      container.read(tripSortProvider),
      const SortState(field: TripSortField.name, direction: up),
    );
    expect(
      container.read(courseSortProvider),
      const SortState(field: CourseSortField.name, direction: up),
    );
    expect(
      container.read(buddySortProvider),
      const SortState(field: BuddySortField.diveCount, direction: up),
    );
    expect(
      container.read(diveCenterSortProvider),
      const SortState(field: DiveCenterSortField.diveCount, direction: up),
    );
    expect(
      container.read(siteSortProvider),
      const SortState(field: SiteSortField.rating, direction: up),
    );
    expect(
      container.read(certificationSortProvider),
      const SortState(field: CertificationSortField.name, direction: up),
    );
    expect(
      container.read(equipmentSortProvider),
      const SortState(field: EquipmentSortField.purchaseDate, direction: up),
    );
  });

  test('the buddy picker keeps its own starting order', () {
    saved(const ListArrangements(buddySort: 'name:ascending'));
    expect(
      container.read(buddyPickerSortProvider).field,
      BuddySortField.diveCount,
    );
  });

  test('each grouping provider reads its saved value', () {
    saved(
      const ListArrangements(
        siteGroupBy: 'water',
        certificationGroupBy: 'agency',
      ),
    );
    expect(container.read(siteGroupByProvider), SiteGroupBy.water);
    expect(
      container.read(certificationGroupByProvider),
      CertificationGroupBy.agency,
    );
  });

  test('never set gives the starting order', () {
    expect(
      container.read(diveSortProvider),
      const SortState(
        field: DiveSortField.date,
        direction: SortDirection.descending,
      ),
    );
    expect(container.read(siteGroupByProvider), SiteGroupBy.none);
    expect(
      container.read(certificationGroupByProvider),
      CertificationGroupBy.status,
    );
  });

  test('unknown value falls back', () {
    saved(
      const ListArrangements(diveSort: 'bogus:ascending', siteGroupBy: 'bogus'),
    );
    expect(container.read(diveSortProvider).field, DiveSortField.date);
    expect(container.read(siteGroupByProvider), SiteGroupBy.none);
  });

  test('follows a diver switch', () {
    saved(const ListArrangements(diveSort: 'depth:ascending'));
    expect(container.read(diveSortProvider).field, DiveSortField.depth);
    // A diver switch replaces the whole settings state with the other
    // diver's row.
    settings.state = const AppSettings(
      listArrangements: ListArrangements(diveSort: 'rating:descending'),
      siteListViewMode: ListViewMode.table,
    );
    expect(container.read(diveSortProvider).field, DiveSortField.rating);
    expect(container.read(siteListViewModeProvider), ListViewMode.table);
  });

  test('follows an Appearance change', () async {
    expect(container.read(siteListViewModeProvider), ListViewMode.detailed);
    await settings.setSiteListViewMode(ListViewMode.compact);
    expect(container.read(siteListViewModeProvider), ListViewMode.compact);
    await settings.setCourseListViewMode(ListViewMode.table);
    expect(container.read(courseListViewModeProvider), ListViewMode.table);
    await settings.setGroupTripsInDiveList(true);
    expect(container.read(diveListGroupTripsProvider), isTrue);
  });
}
