import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/pages/species_manage_page.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';

import '../../../../helpers/bulk_delete_contract.dart';
import '../../../../helpers/selection_contract.dart';
import '../../../../helpers/test_app.dart';

Species _species({
  required String id,
  required String name,
  bool isBuiltIn = false,
}) => Species(
  id: id,
  commonName: name,
  category: SpeciesCategory.fish,
  isBuiltIn: isBuiltIn,
);

/// Mutable source for the contract test's filter step.
final _visibleSpeciesProvider = StateProvider<List<Species>>((ref) => const []);

void main() {
  Widget host({
    required List<Species> species,
    Map<String, int> sightingCounts = const {},
  }) {
    return testApp(
      locale: const Locale('en'),
      overrides: [
        _visibleSpeciesProvider.overrideWith((ref) => species),
        speciesListNotifierProvider.overrideWith(
          (ref) => _MockSpeciesNotifier(ref.watch(_visibleSpeciesProvider)),
        ),
        speciesSightingCountsProvider.overrideWith(
          (ref) async => sightingCounts,
        ),
      ],
      child: const SpeciesManagePage(),
    );
  }

  group('SpeciesManagePage selection', () {
    testWidgets('satisfies the shared selection contract', (tester) async {
      final all = [
        _species(id: 's1', name: 'Aaa fish'),
        _species(id: 's2', name: 'Bbb fish'),
        _species(id: 's3', name: 'Ccc fish'),
      ];

      await verifySelectionContract(
        tester,
        build: () => host(species: all),
        selectButton: find.byKey(const ValueKey('enter_selection')),
        // Non-selectable species render no checkbox, so pin to the row the
        // contract already drives rather than whichever sorts first.
        rowRoot: find.ancestor(
          of: find.text('Aaa fish'),
          matching: find.byType(ListTile),
        ),
        firstRow: find.text('Aaa fish'),
        applyFilter: (tester) async {
          final container = ProviderScope.containerOf(
            tester.element(find.byType(SpeciesManagePage)),
          );
          container.read(_visibleSpeciesProvider.notifier).state = [all.first];
        },
        visibleAfterFilter: 1,
      );
    });

    testWidgets('deletes every checked species and reports the count', (
      tester,
    ) async {
      final all = [
        _species(id: 's1', name: 'Aaa fish'),
        _species(id: 's2', name: 'Bbb fish'),
      ];
      final notifier = _MockSpeciesNotifier(all);
      final widget = testApp(
        locale: const Locale('en'),
        overrides: [
          _visibleSpeciesProvider.overrideWith((ref) => all),
          speciesListNotifierProvider.overrideWith((ref) => notifier),
          speciesSightingCountsProvider.overrideWith((ref) async => const {}),
        ],
        child: const SpeciesManagePage(),
      );

      await verifyBulkDelete(
        tester,
        build: () => widget,
        selectButton: find.byKey(const ValueKey('enter_selection')),
        expectedDeletedCount: 2,
      );

      expect(notifier.deleted, ['s1', 's2']);
      expect(find.text('2 deleted'), findsOneWidget);
    });

    testWidgets('one species throwing does not abandon the rest', (
      tester,
    ) async {
      final all = [
        _species(id: 's1', name: 'Aaa fish'),
        _species(id: 's2', name: 'Bbb fish'),
      ];
      // The counts are a prefetched snapshot, so a species can gain a
      // sighting after the list loads and throw at delete time.
      final notifier = _MockSpeciesNotifier(all, throwingIds: const {'s1'});
      final widget = testApp(
        locale: const Locale('en'),
        overrides: [
          _visibleSpeciesProvider.overrideWith((ref) => all),
          speciesListNotifierProvider.overrideWith((ref) => notifier),
          speciesSightingCountsProvider.overrideWith((ref) async => const {}),
        ],
        child: const SpeciesManagePage(),
      );

      await verifyBulkDelete(
        tester,
        build: () => widget,
        selectButton: find.byKey(const ValueKey('enter_selection')),
        expectedDeletedCount: 2,
      );

      expect(notifier.deleted, [
        's2',
      ], reason: 'the surviving species must still be deleted');
      expect(
        find.textContaining('Error deleting species'),
        findsOneWidget,
        reason: 'the failure must be surfaced, not swallowed',
      );
    });

    testWidgets('built-in species render no checkbox', (tester) async {
      await tester.pumpWidget(
        host(
          species: [
            _species(id: 'b1', name: 'Built-in fish', isBuiltIn: true),
            _species(id: 'c1', name: 'Custom fish'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();

      expect(
        find.byType(Checkbox),
        findsOneWidget,
        reason: 'only the custom species is selectable',
      );
    });

    testWidgets('selection mode hides the per-row edit and delete actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          species: [_species(id: 'c1', name: 'Custom fish')],
        ),
      );
      await tester.pumpAndSettle();

      // Normal mode offers both row actions.
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();

      // In selection mode the only delete is the bulk one, which the shared
      // bar keeps behind its overflow menu. A live per-row trash beside the
      // checkbox would undo that.
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byKey(const ValueKey('selection_overflow')), findsOneWidget);
    });

    testWidgets('a species with sightings renders no checkbox and is '
        'excluded from select-all', (tester) async {
      await tester.pumpWidget(
        host(
          species: [
            _species(id: 'c1', name: 'Unseen fish'),
            _species(id: 'c2', name: 'Seen fish'),
          ],
          // deleteSpecies throws for a referenced species, so the UI must not
          // let one be checked in the first place.
          sightingCounts: const {'c2': 12},
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('selection_select_all')));
      await tester.pumpAndSettle();

      expect(
        find.text('1 selected'),
        findsOneWidget,
        reason: 'select-all must skip species the repository refuses to delete',
      );
    });
  });
}

class _MockSpeciesNotifier extends StateNotifier<AsyncValue<List<Species>>>
    implements SpeciesListNotifier {
  _MockSpeciesNotifier(List<Species> species, {this.throwingIds = const {}})
    : super(AsyncValue.data(species));

  /// Ids whose delete should throw, standing in for a species that gained a
  /// sighting since the counts were prefetched.
  final Set<String> throwingIds;

  final deleted = <String>[];

  @override
  Future<void> deleteSpecies(String id) async {
    if (throwingIds.contains(id)) {
      throw Exception('Cannot delete species that is referenced by sightings');
    }
    deleted.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
