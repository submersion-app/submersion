import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  group('AppSettings showDetailsPane* defaults', () {
    test('defaults all showDetailsPane* fields to false', () {
      const settings = AppSettings();
      expect(settings.showDetailsPaneDives, isFalse);
      expect(settings.showDetailsPaneSites, isFalse);
      expect(settings.showDetailsPaneBuddies, isFalse);
      expect(settings.showDetailsPaneTrips, isFalse);
      expect(settings.showDetailsPaneEquipment, isFalse);
      expect(settings.showDetailsPaneDiveCenters, isFalse);
      expect(settings.showDetailsPaneCertifications, isFalse);
      expect(settings.showDetailsPaneCourses, isFalse);
    });
  });

  group('AppSettings copyWith for showDetailsPane* fields', () {
    test('copyWith sets showDetailsPaneDives to true', () {
      const settings = AppSettings();
      final updated = settings.copyWith(showDetailsPaneDives: true);
      expect(updated.showDetailsPaneDives, isTrue);
      expect(updated.showDetailsPaneSites, isFalse);
      expect(updated.showDetailsPaneBuddies, isFalse);
      expect(updated.showDetailsPaneTrips, isFalse);
      expect(updated.showDetailsPaneEquipment, isFalse);
      expect(updated.showDetailsPaneDiveCenters, isFalse);
      expect(updated.showDetailsPaneCertifications, isFalse);
      expect(updated.showDetailsPaneCourses, isFalse);
    });

    test('copyWith sets showDetailsPaneSites to true', () {
      const settings = AppSettings();
      final updated = settings.copyWith(showDetailsPaneSites: true);
      expect(updated.showDetailsPaneSites, isTrue);
      expect(updated.showDetailsPaneDives, isFalse);
    });

    test('copyWith sets showDetailsPaneBuddies to true', () {
      const settings = AppSettings();
      final updated = settings.copyWith(showDetailsPaneBuddies: true);
      expect(updated.showDetailsPaneBuddies, isTrue);
      expect(updated.showDetailsPaneDives, isFalse);
    });

    test('copyWith sets showDetailsPaneTrips to true', () {
      const settings = AppSettings();
      final updated = settings.copyWith(showDetailsPaneTrips: true);
      expect(updated.showDetailsPaneTrips, isTrue);
      expect(updated.showDetailsPaneDives, isFalse);
    });

    test('copyWith sets showDetailsPaneEquipment to true', () {
      const settings = AppSettings();
      final updated = settings.copyWith(showDetailsPaneEquipment: true);
      expect(updated.showDetailsPaneEquipment, isTrue);
      expect(updated.showDetailsPaneDives, isFalse);
    });

    test('copyWith sets showDetailsPaneDiveCenters to true', () {
      const settings = AppSettings();
      final updated = settings.copyWith(showDetailsPaneDiveCenters: true);
      expect(updated.showDetailsPaneDiveCenters, isTrue);
      expect(updated.showDetailsPaneDives, isFalse);
    });

    test('copyWith sets showDetailsPaneCertifications to true', () {
      const settings = AppSettings();
      final updated = settings.copyWith(showDetailsPaneCertifications: true);
      expect(updated.showDetailsPaneCertifications, isTrue);
      expect(updated.showDetailsPaneDives, isFalse);
    });

    test('copyWith sets showDetailsPaneCourses to true', () {
      const settings = AppSettings();
      final updated = settings.copyWith(showDetailsPaneCourses: true);
      expect(updated.showDetailsPaneCourses, isTrue);
      expect(updated.showDetailsPaneDives, isFalse);
    });

    test('copyWith preserves showDetailsPane* when not specified', () {
      const settings = AppSettings(
        showDetailsPaneDives: true,
        showDetailsPaneSites: true,
        showDetailsPaneBuddies: true,
        showDetailsPaneTrips: true,
        showDetailsPaneEquipment: true,
        showDetailsPaneDiveCenters: true,
        showDetailsPaneCertifications: true,
        showDetailsPaneCourses: true,
      );
      final updated = settings.copyWith();
      expect(updated.showDetailsPaneDives, isTrue);
      expect(updated.showDetailsPaneSites, isTrue);
      expect(updated.showDetailsPaneBuddies, isTrue);
      expect(updated.showDetailsPaneTrips, isTrue);
      expect(updated.showDetailsPaneEquipment, isTrue);
      expect(updated.showDetailsPaneDiveCenters, isTrue);
      expect(updated.showDetailsPaneCertifications, isTrue);
      expect(updated.showDetailsPaneCourses, isTrue);
    });
  });

  group('Runtime view mode providers', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('diveListViewModeProvider defaults to detailed', () {
      expect(container.read(diveListViewModeProvider), ListViewMode.detailed);
    });

    test('diveListViewModeProvider can be updated to table', () {
      container.read(diveListViewModeProvider.notifier).state =
          ListViewMode.table;
      expect(container.read(diveListViewModeProvider), ListViewMode.table);
    });

    test('siteListViewModeProvider defaults to detailed', () {
      expect(container.read(siteListViewModeProvider), ListViewMode.detailed);
    });

    test('siteListViewModeProvider can be updated to compact', () {
      container.read(siteListViewModeProvider.notifier).state =
          ListViewMode.compact;
      expect(container.read(siteListViewModeProvider), ListViewMode.compact);
    });

    test('tripListViewModeProvider defaults to detailed', () {
      expect(container.read(tripListViewModeProvider), ListViewMode.detailed);
    });

    test('tripListViewModeProvider can be updated to dense', () {
      container.read(tripListViewModeProvider.notifier).state =
          ListViewMode.dense;
      expect(container.read(tripListViewModeProvider), ListViewMode.dense);
    });

    test('equipmentListViewModeProvider defaults to detailed', () {
      expect(
        container.read(equipmentListViewModeProvider),
        ListViewMode.detailed,
      );
    });

    test('equipmentListViewModeProvider can be updated to table', () {
      container.read(equipmentListViewModeProvider.notifier).state =
          ListViewMode.table;
      expect(container.read(equipmentListViewModeProvider), ListViewMode.table);
    });

    test('buddyListViewModeProvider defaults to detailed', () {
      expect(container.read(buddyListViewModeProvider), ListViewMode.detailed);
    });

    test('buddyListViewModeProvider can be updated to compact', () {
      container.read(buddyListViewModeProvider.notifier).state =
          ListViewMode.compact;
      expect(container.read(buddyListViewModeProvider), ListViewMode.compact);
    });

    test('diveCenterListViewModeProvider defaults to detailed', () {
      expect(
        container.read(diveCenterListViewModeProvider),
        ListViewMode.detailed,
      );
    });

    test('diveCenterListViewModeProvider can be updated to table', () {
      container.read(diveCenterListViewModeProvider.notifier).state =
          ListViewMode.table;
      expect(
        container.read(diveCenterListViewModeProvider),
        ListViewMode.table,
      );
    });
  });
}
