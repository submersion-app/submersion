import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/dive_import/data/services/uddf_duplicate_checker.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_import/presentation/providers/uddf_import_providers.dart';

void main() {
  group('UddfImportState', () {
    test('default state has step 0 and empty selections', () {
      const state = UddfImportState();
      expect(state.currentStep, 0);
      expect(state.isLoading, isFalse);
      expect(state.isImporting, isFalse);
      expect(state.error, isNull);
      expect(state.parsedData, isNull);
      expect(state.duplicateCheckResult, isNull);
      expect(state.totalSelected, 0);
      expect(state.importResult, isNull);
    });

    test('copyWith updates fields', () {
      const state = UddfImportState();
      final updated = state.copyWith(
        currentStep: 1,
        isLoading: true,
        error: 'something failed',
      );
      expect(updated.currentStep, 1);
      expect(updated.isLoading, isTrue);
      expect(updated.error, 'something failed');
    });

    test('copyWith preserves unchanged fields', () {
      final state = const UddfImportState().copyWith(
        selectedTrips: {0, 1},
        selectedDives: {0},
      );
      final updated = state.copyWith(currentStep: 2);
      expect(updated.selectedTrips, {0, 1});
      expect(updated.selectedDives, {0});
    });

    test('clearError resets error to null', () {
      final state = const UddfImportState().copyWith(error: 'old error');
      final updated = state.copyWith(clearError: true);
      expect(updated.error, isNull);
    });

    test('clearError takes priority over error param', () {
      final state = const UddfImportState().copyWith(error: 'old error');
      final updated = state.copyWith(clearError: true, error: 'new error');
      expect(updated.error, isNull);
    });

    test('totalSelected sums all selection sets', () {
      final state = const UddfImportState().copyWith(
        selectedTrips: {0, 1},
        selectedSites: {0, 1, 2},
        selectedDives: {0},
        selectedBuddies: {0},
      );
      expect(state.totalSelected, 7);
    });

    test('selectionFor returns correct set', () {
      final state = const UddfImportState().copyWith(
        selectedTrips: {0},
        selectedDives: {1, 2},
      );
      expect(state.selectionFor(UddfEntityType.trips), {0});
      expect(state.selectionFor(UddfEntityType.dives), {1, 2});
      expect(state.selectionFor(UddfEntityType.buddies), isEmpty);
    });

    test('totalCountFor returns data length', () {
      final data = UddfImportResult(
        trips: [
          {'name': 'A'},
          {'name': 'B'},
        ],
        dives: [
          {'dateTime': DateTime(2024)},
        ],
      );
      final state = const UddfImportState().copyWith(parsedData: data);
      expect(state.totalCountFor(UddfEntityType.trips), 2);
      expect(state.totalCountFor(UddfEntityType.dives), 1);
      expect(state.totalCountFor(UddfEntityType.buddies), 0);
    });

    test('totalCountFor returns 0 when no parsed data', () {
      const state = UddfImportState();
      expect(state.totalCountFor(UddfEntityType.trips), 0);
    });

    test('toSelections creates matching UddfImportSelections', () {
      final state = const UddfImportState().copyWith(
        selectedTrips: {0},
        selectedEquipment: {1, 2},
        selectedBuddies: {0},
        selectedDives: {0, 1, 2},
      );
      final selections = state.toSelections();
      expect(selections.trips, {0});
      expect(selections.equipment, {1, 2});
      expect(selections.buddies, {0});
      expect(selections.dives, {0, 1, 2});
      expect(selections.sites, isEmpty);
    });
  });

  group('UddfEntityType', () {
    test('has all expected values', () {
      expect(UddfEntityType.values, hasLength(11));
      expect(UddfEntityType.values, contains(UddfEntityType.trips));
      expect(UddfEntityType.values, contains(UddfEntityType.dives));
      expect(UddfEntityType.values, contains(UddfEntityType.sites));
      expect(UddfEntityType.values, contains(UddfEntityType.equipment));
      expect(UddfEntityType.values, contains(UddfEntityType.buddies));
      expect(UddfEntityType.values, contains(UddfEntityType.diveCenters));
      expect(UddfEntityType.values, contains(UddfEntityType.certifications));
      expect(UddfEntityType.values, contains(UddfEntityType.tags));
      expect(UddfEntityType.values, contains(UddfEntityType.diveTypes));
      expect(UddfEntityType.values, contains(UddfEntityType.equipmentSets));
      expect(UddfEntityType.values, contains(UddfEntityType.courses));
    });
  });

  group('UddfImportNotifier selection logic', () {
    // Test selection management using the state directly
    // (Notifier methods that use Riverpod refs need integration tests)

    test('toggle adds index when not present', () {
      final state = const UddfImportState().copyWith(selectedTrips: {0, 1});

      // Simulate toggleSelection logic
      final current = state.selectionFor(UddfEntityType.trips);
      final updated = Set<int>.from(current);
      updated.add(2);

      final newState = state.copyWith(selectedTrips: updated);
      expect(newState.selectedTrips, {0, 1, 2});
    });

    test('toggle removes index when present', () {
      final state = const UddfImportState().copyWith(selectedTrips: {0, 1, 2});

      final current = state.selectionFor(UddfEntityType.trips);
      final updated = Set<int>.from(current);
      updated.remove(1);

      final newState = state.copyWith(selectedTrips: updated);
      expect(newState.selectedTrips, {0, 2});
    });

    test('selectAll generates all indices', () {
      const data = UddfImportResult(
        trips: [
          {'name': 'A'},
          {'name': 'B'},
          {'name': 'C'},
        ],
      );
      final state = const UddfImportState().copyWith(parsedData: data);

      final count = state.totalCountFor(UddfEntityType.trips);
      final allIndices = Set<int>.from(List.generate(count, (i) => i));

      final newState = state.copyWith(selectedTrips: allIndices);
      expect(newState.selectedTrips, {0, 1, 2});
    });

    test('deselectAll clears selection', () {
      final state = const UddfImportState().copyWith(selectedTrips: {0, 1, 2});

      final newState = state.copyWith(selectedTrips: const {});
      expect(newState.selectedTrips, isEmpty);
    });
  });

  group('Duplicate auto-deselection', () {
    test('duplicates are removed from default selections', () {
      // Simulate what parseFile does: selectAll minus duplicates
      final data = UddfImportResult(
        trips: [
          {'name': 'Trip A'},
          {'name': 'Trip B'},
          {'name': 'Trip C'},
        ],
        buddies: [
          {'name': 'Alice'},
          {'name': 'Bob'},
        ],
        dives: [
          {'dateTime': DateTime(2024, 1, 1), 'maxDepth': 20.0},
          {'dateTime': DateTime(2024, 1, 2), 'maxDepth': 25.0},
        ],
      );

      const dupResult = UddfDuplicateCheckResult(
        duplicateTrips: {0, 2},
        duplicateBuddies: {1},
        diveMatches: {
          0: DiveMatchResult(
            diveId: 'existing-1',
            score: 0.8,
            timeDifferenceMs: 100,
          ),
        },
      );

      final selections = UddfImportSelections.selectAll(data);

      final state = const UddfImportState().copyWith(
        parsedData: data,
        duplicateCheckResult: dupResult,
        selectedTrips: selections.trips.difference(dupResult.duplicateTrips),
        selectedBuddies: selections.buddies.difference(
          dupResult.duplicateBuddies,
        ),
        selectedDives: selections.dives.difference(
          Set<int>.from(dupResult.diveMatches.keys),
        ),
      );

      // Trip A (0) and Trip C (2) are duplicates, only Trip B (1) selected
      expect(state.selectedTrips, {1});

      // Bob (1) is a duplicate, only Alice (0) selected
      expect(state.selectedBuddies, {0});

      // Dive 0 matches an existing dive, only dive 1 selected
      expect(state.selectedDives, {1});
    });
  });

  group('UddfEntityImportResult in state', () {
    test('import result is accessible after import', () {
      const result = UddfEntityImportResult(dives: 5, sites: 2, trips: 1);

      final state = const UddfImportState().copyWith(
        currentStep: 3,
        importResult: result,
      );

      expect(state.importResult, isNotNull);
      expect(state.importResult!.total, 8);
      expect(state.importResult!.summary, contains('5 dives'));
      expect(state.importResult!.summary, contains('2 sites'));
      expect(state.importResult!.summary, contains('1 trips'));
    });
  });

  group('Progress tracking in state', () {
    test('progress fields update correctly', () {
      final state = const UddfImportState().copyWith(
        importPhase: 'Importing dives',
        importCurrent: 3,
        importTotal: 10,
      );

      expect(state.importPhase, 'Importing dives');
      expect(state.importCurrent, 3);
      expect(state.importTotal, 10);
    });
  });
}
