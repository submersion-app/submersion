import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_picker_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final _testSpecies = [
  const Species(
    id: '1',
    commonName: 'Clownfish',
    category: SpeciesCategory.fish,
    scientificName: 'Amphiprioninae',
  ),
  const Species(
    id: '2',
    commonName: 'Manta Ray',
    category: SpeciesCategory.ray,
    scientificName: 'Mobula birostris',
  ),
  const Species(
    id: '3',
    commonName: 'Green Turtle',
    category: SpeciesCategory.turtle,
    scientificName: 'Chelonia mydas',
  ),
  const Species(
    id: '4',
    commonName: 'Blue Shark',
    category: SpeciesCategory.shark,
    scientificName: 'Prionace glauca',
  ),
];

/// Sets a tall, wide screen so the dialog and filter chips fit.
void _useLargeScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _buildDialog({
  Set<String> initialSelection = const {},
  List<dynamic>? overrides,
}) {
  return ProviderScope(
    overrides: overrides?.cast() ?? [],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SpeciesPickerDialog(initialSelection: initialSelection),
        ),
      ),
    ),
  );
}

void main() {
  group('SpeciesPickerDialog', () {
    testWidgets('shows species list grouped by category', (tester) async {
      _useLargeScreen(tester);
      await tester.pumpWidget(
        _buildDialog(
          overrides: [
            allSpeciesProvider.overrideWith((ref) async => _testSpecies),
            speciesSearchProvider.overrideWith((ref, q) async => []),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Species names visible
      expect(find.text('Clownfish'), findsOneWidget);
      expect(find.text('Manta Ray'), findsOneWidget);
      expect(find.text('Green Turtle'), findsOneWidget);
      expect(find.text('Blue Shark'), findsOneWidget);

      // Category headers visible
      expect(find.text('Fish'), findsWidgets); // header + filter chip
      expect(find.text('Ray'), findsWidgets);
      expect(find.text('Turtle'), findsWidgets);
      expect(find.text('Shark'), findsWidgets);
    });

    testWidgets('shows scientific names as subtitles', (tester) async {
      _useLargeScreen(tester);
      await tester.pumpWidget(
        _buildDialog(
          overrides: [
            allSpeciesProvider.overrideWith((ref) async => _testSpecies),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Amphiprioninae'), findsOneWidget);
      expect(find.text('Mobula birostris'), findsOneWidget);
      expect(find.text('Chelonia mydas'), findsOneWidget);
      expect(find.text('Prionace glauca'), findsOneWidget);
    });

    testWidgets('debounces search input by 300ms', (tester) async {
      await tester.pumpWidget(
        _buildDialog(
          overrides: [
            allSpeciesProvider.overrideWith((ref) async => _testSpecies),
            speciesSearchProvider.overrideWith((ref, query) async {
              return _testSpecies
                  .where(
                    (s) => s.commonName.toLowerCase().contains(
                      query.toLowerCase(),
                    ),
                  )
                  .toList();
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Clown');
      await tester.pump();

      // Before debounce -- all species still visible
      expect(find.text('Manta Ray'), findsOneWidget);
      expect(find.text('Green Turtle'), findsOneWidget);

      // Advance past 300ms debounce
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Now filtered
      expect(find.text('Clownfish'), findsOneWidget);
      expect(find.text('Manta Ray'), findsNothing);
      expect(find.text('Green Turtle'), findsNothing);
    });

    testWidgets('clear button resets search immediately', (tester) async {
      await tester.pumpWidget(
        _buildDialog(
          overrides: [
            allSpeciesProvider.overrideWith((ref) async => _testSpecies),
            speciesSearchProvider.overrideWith((ref, query) async {
              return _testSpecies
                  .where(
                    (s) => s.commonName.toLowerCase().contains(
                      query.toLowerCase(),
                    ),
                  )
                  .toList();
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Search and wait for debounce
      await tester.enterText(find.byType(TextField), 'Clown');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Manta Ray'), findsNothing);

      // Tap clear
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // All species visible again
      expect(find.text('Clownfish'), findsOneWidget);
      expect(find.text('Manta Ray'), findsOneWidget);
      expect(find.text('Green Turtle'), findsOneWidget);
    });

    testWidgets('empty text input clears debounced state immediately', (
      tester,
    ) async {
      _useLargeScreen(tester);
      await tester.pumpWidget(
        _buildDialog(
          overrides: [
            allSpeciesProvider.overrideWith((ref) async => _testSpecies),
            speciesSearchProvider.overrideWith((ref, query) async {
              return _testSpecies
                  .where(
                    (s) => s.commonName.toLowerCase().contains(
                      query.toLowerCase(),
                    ),
                  )
                  .toList();
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Search
      await tester.enterText(find.byType(TextField), 'Manta');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Clear by entering empty text
      await tester.enterText(find.byType(TextField), '');
      await tester.pump(); // Single frame -- no debounce for empty
      await tester.pumpAndSettle();

      // All species visible
      expect(find.text('Clownfish'), findsOneWidget);
      expect(find.text('Blue Shark'), findsOneWidget);
    });

    testWidgets('category filter chips filter the list', (tester) async {
      _useLargeScreen(tester);
      await tester.pumpWidget(
        _buildDialog(
          overrides: [
            allSpeciesProvider.overrideWith((ref) async => _testSpecies),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // All species visible initially
      expect(find.text('Clownfish'), findsOneWidget);
      expect(find.text('Manta Ray'), findsOneWidget);
      expect(find.text('Green Turtle'), findsOneWidget);
      expect(find.text('Blue Shark'), findsOneWidget);

      // Tap the "Fish" filter chip (last instance since it also appears as
      // a category header in the list)
      final fishChips = find.ancestor(
        of: find.text('Fish'),
        matching: find.byType(FilterChip),
      );
      await tester.tap(fishChips.first);
      await tester.pumpAndSettle();

      // Only fish species visible
      expect(find.text('Clownfish'), findsOneWidget);
      expect(find.text('Manta Ray'), findsNothing);
      expect(find.text('Green Turtle'), findsNothing);
      expect(find.text('Blue Shark'), findsNothing);
    });

    testWidgets('selecting "All" filter shows all species', (tester) async {
      _useLargeScreen(tester);
      await tester.pumpWidget(
        _buildDialog(
          overrides: [
            allSpeciesProvider.overrideWith((ref) async => _testSpecies),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Filter to fish first
      final fishChip = find.ancestor(
        of: find.text('Fish'),
        matching: find.byType(FilterChip),
      );
      await tester.tap(fishChip.first);
      await tester.pumpAndSettle();
      expect(find.text('Manta Ray'), findsNothing);

      // Tap "All" chip to reset
      final allChip = find.ancestor(
        of: find.text('All'),
        matching: find.byType(FilterChip),
      );
      await tester.tap(allChip.first);
      await tester.pumpAndSettle();

      // All species visible again
      expect(find.text('Clownfish'), findsOneWidget);
      expect(find.text('Manta Ray'), findsOneWidget);
    });

    testWidgets('empty category filter shows empty state', (tester) async {
      _useLargeScreen(tester);
      await tester.pumpWidget(
        _buildDialog(
          overrides: [
            allSpeciesProvider.overrideWith((ref) async => _testSpecies),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Mammal" filter -- no test species in this category
      final mammalChip = find.ancestor(
        of: find.text('Mammal'),
        matching: find.byType(FilterChip),
      );
      await tester.tap(mammalChip.first);
      await tester.pumpAndSettle();

      // Should show search_off icon (empty state)
      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });

    testWidgets('multi-select checkboxes toggle selection', (tester) async {
      await tester.pumpWidget(
        _buildDialog(
          overrides: [
            allSpeciesProvider.overrideWith((ref) async => _testSpecies),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Initially nothing selected -- find checkboxes
      var checkboxTiles = tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(checkboxTiles.every((cb) => cb.value == false), isTrue);

      // Tap Clownfish to select
      await tester.tap(find.text('Clownfish'));
      await tester.pumpAndSettle();

      // Clownfish should now be checked
      checkboxTiles = tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      final clownfishTile = checkboxTiles.firstWhere(
        (cb) => (cb.title as Text?)?.data == 'Clownfish',
      );
      expect(clownfishTile.value, isTrue);

      // Tap again to deselect
      await tester.tap(find.text('Clownfish'));
      await tester.pumpAndSettle();

      checkboxTiles = tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      final deselectedTile = checkboxTiles.firstWhere(
        (cb) => (cb.title as Text?)?.data == 'Clownfish',
      );
      expect(deselectedTile.value, isFalse);
    });

    testWidgets('initial selection is reflected in checkboxes', (tester) async {
      _useLargeScreen(tester);
      await tester.pumpWidget(
        _buildDialog(
          initialSelection: {'1', '3'},
          overrides: [
            allSpeciesProvider.overrideWith((ref) async => _testSpecies),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final checkboxTiles = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .toList();
      final clownfish = checkboxTiles.firstWhere(
        (cb) => (cb.title as Text?)?.data == 'Clownfish',
      );
      final turtle = checkboxTiles.firstWhere(
        (cb) => (cb.title as Text?)?.data == 'Green Turtle',
      );
      final ray = checkboxTiles.firstWhere(
        (cb) => (cb.title as Text?)?.data == 'Manta Ray',
      );

      expect(clownfish.value, isTrue);
      expect(turtle.value, isTrue);
      expect(ray.value, isFalse);
    });

    testWidgets('shows loading spinner when provider is loading', (
      tester,
    ) async {
      final completer = Completer<List<Species>>();
      addTearDown(() {
        if (!completer.isCompleted) completer.complete([]);
      });

      await tester.pumpWidget(
        _buildDialog(
          overrides: [
            allSpeciesProvider.overrideWith((ref) => completer.future),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('caches search results and shows LinearProgressIndicator '
        'during subsequent loading', (tester) async {
      var callCount = 0;
      final secondSearchCompleter = Completer<List<Species>>();
      addTearDown(() {
        if (!secondSearchCompleter.isCompleted) {
          secondSearchCompleter.complete([]);
        }
      });

      await tester.pumpWidget(
        _buildDialog(
          overrides: [
            allSpeciesProvider.overrideWith((ref) async => _testSpecies),
            speciesSearchProvider.overrideWith((ref, query) {
              callCount++;
              if (callCount <= 1) {
                return Future.value(
                  _testSpecies
                      .where(
                        (s) => s.commonName.toLowerCase().contains(
                          query.toLowerCase(),
                        ),
                      )
                      .toList(),
                );
              }
              return secondSearchCompleter.future;
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // First search -- completes immediately, caches results
      await tester.enterText(find.byType(TextField), 'Cl');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Clownfish'), findsOneWidget);

      // Second search -- provider hangs in loading
      await tester.enterText(find.byType(TextField), 'Clown');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      // Cached results still visible
      expect(find.text('Clownfish'), findsOneWidget);
      // Linear progress indicator on top
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('close button dismisses dialog', (tester) async {
      await tester.pumpWidget(
        _buildDialog(
          overrides: [
            allSpeciesProvider.overrideWith((ref) async => _testSpecies),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Dialog should be dismissed -- species list gone
      expect(find.text('Clownfish'), findsNothing);
    });
  });
}
