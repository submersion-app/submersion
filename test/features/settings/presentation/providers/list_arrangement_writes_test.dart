import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/certifications/presentation/utils/certification_grouping.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_grouping.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/list_arrangement_writes.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Holds the settings load at its first read until [gate] completes, so a
/// test can act inside the window where [SettingsNotifier] still holds its
/// defaults.
class _GatedDiverRepository extends DiverRepository {
  _GatedDiverRepository(this.gate);

  final Completer<void> gate;

  @override
  Future<Diver?> getDiverById(String id) async {
    await gate.future;
    return super.getDiverById(id);
  }
}

/// A list saves how the diver left it (issue #3748) through these setters.
/// They wait for the diver's settings to load, or a sort tapped at launch
/// would be overwritten when the load lands.
void main() {
  late ProviderContainer container;
  late Completer<void> gate;
  late String diverId;

  Future<SettingsNotifier> loaded() async {
    gate.complete();
    final notifier = container.read(settingsProvider.notifier);
    await notifier.initialLoad;
    return notifier;
  }

  Future<AppSettings> stored() async =>
      (await DiverSettingsRepository().getSettingsForDiver(diverId))!;

  setUp(() async {
    await setUpTestDatabase();
    final now = DateTime.now();
    final diver = await DiverRepository().createDiver(
      Diver(id: '', name: 'A', createdAt: now, updatedAt: now),
    );
    diverId = diver.id;
    SharedPreferences.setMockInitialValues({currentDiverIdKey: diverId});
    final prefs = await SharedPreferences.getInstance();
    gate = Completer<void>();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        diverRepositoryProvider.overrideWithValue(_GatedDiverRepository(gate)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test('setDiveSort saves the encoded value for the active diver', () async {
    final notifier = await loaded();
    await notifier.setDiveSort(
      const SortState(
        field: DiveSortField.depth,
        direction: SortDirection.ascending,
      ),
    );
    expect(
      container.read(settingsProvider).listArrangements.diveSort,
      'depth:ascending',
    );
    expect((await stored()).listArrangements.diveSort, 'depth:ascending');
  });

  test('every setter saves into its own field', () async {
    final notifier = await loaded();
    await notifier.setDivePlanSort(
      const SortState(field: DivePlanSortField.name),
    );
    await notifier.setTripSort(const SortState(field: TripSortField.name));
    await notifier.setCourseSort(const SortState(field: CourseSortField.name));
    await notifier.setBuddySort(const SortState(field: BuddySortField.name));
    await notifier.setDiveCenterSort(
      const SortState(field: DiveCenterSortField.name),
    );
    await notifier.setSiteSort(const SortState(field: SiteSortField.name));
    await notifier.setCertificationSort(
      const SortState(field: CertificationSortField.name),
    );
    await notifier.setEquipmentSort(
      const SortState(field: EquipmentSortField.name),
    );
    await notifier.setSiteGroupBy(SiteGroupBy.values.last);
    await notifier.setCertificationGroupBy(CertificationGroupBy.values.last);
    await notifier.setEquipmentGroupByLocation(true);

    final a = (await stored()).listArrangements;
    expect(a.divePlanSort, 'name:descending');
    expect(a.tripSort, 'name:descending');
    expect(a.courseSort, 'name:descending');
    expect(a.buddySort, 'name:descending');
    expect(a.diveCenterSort, 'name:descending');
    expect(a.siteSort, 'name:descending');
    expect(a.certificationSort, 'name:descending');
    expect(a.equipmentSort, 'name:descending');
    expect(a.siteGroupBy, SiteGroupBy.values.last.name);
    expect(a.certificationGroupBy, CertificationGroupBy.values.last.name);
    expect(a.equipmentGroupByLocation, isTrue);
    expect(a.diveSort, isNull);
  });

  test('a list save leaves the device-local preferences alone', () async {
    // A sort is one of the most frequent taps in the app; it saves one
    // diver-settings column and has no business rewriting every
    // device-local preference as well.
    final notifier = await loaded();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SettingsKeys.o2CellUnit, 'untouched');

    await notifier.setTripSort(const SortState(field: TripSortField.name));

    expect(prefs.getString(SettingsKeys.o2CellUnit), 'untouched');
    expect((await stored()).listArrangements.tripSort, 'name:descending');
  });

  test('two quick sorts both land', () async {
    final notifier = await loaded();
    await Future.wait([
      notifier.setSiteSort(const SortState(field: SiteSortField.name)),
      notifier.setTripSort(const SortState(field: TripSortField.name)),
    ]);
    final a = (await stored()).listArrangements;
    expect(a.siteSort, 'name:descending');
    expect(a.tripSort, 'name:descending');
  });

  test('setter waits for the load', () async {
    final notifier = container.read(settingsProvider.notifier);
    final pending = notifier.setDiveSort(
      const SortState(field: DiveSortField.depth),
    );
    // The stored row holds no sort; releasing the load now would overwrite
    // the tap if the setter did not wait for it.
    gate.complete();
    await pending;

    expect(
      container.read(settingsProvider).listArrangements.diveSort,
      'depth:descending',
    );
    expect((await stored()).listArrangements.diveSort, 'depth:descending');
  });

  test('two group-trips toggles made before the load both count', () async {
    final notifier = container.read(settingsProvider.notifier);
    final first = notifier.toggleGroupTripsInDiveList();
    final second = notifier.toggleGroupTripsInDiveList();
    gate.complete();
    await Future.wait([first, second]);

    expect(container.read(settingsProvider).groupTripsInDiveList, isFalse);
    expect((await stored()).groupTripsInDiveList, isFalse);
  });

  test('setSiteListViewMode waits for the load', () async {
    final notifier = container.read(settingsProvider.notifier);
    final pending = notifier.setSiteListViewMode(ListViewMode.table);
    gate.complete();
    await pending;

    expect(
      container.read(settingsProvider).siteListViewMode,
      ListViewMode.table,
    );
    expect((await stored()).siteListViewMode, ListViewMode.table);
  });
}
