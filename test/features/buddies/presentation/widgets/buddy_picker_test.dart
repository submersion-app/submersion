import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_picker.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final _now = DateTime(2024, 1, 1);

final _testBuddies = [
  Buddy(id: '1', name: 'Alice Smith', createdAt: _now, updatedAt: _now),
  Buddy(
    id: '2',
    name: 'Bob Jones',
    certificationLevel: CertificationLevel.advancedOpenWater,
    createdAt: _now,
    updatedAt: _now,
  ),
  Buddy(id: '3', name: 'Charlie Brown', createdAt: _now, updatedAt: _now),
];

Widget _buildPicker({
  List<BuddyWithRole> selectedBuddies = const [],
  ValueChanged<List<BuddyWithRole>>? onChanged,
  List<dynamic>? overrides,
}) {
  return ProviderScope(
    overrides: overrides?.cast() ?? [],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BuddyPicker(
          selectedBuddies: selectedBuddies,
          onChanged: onChanged ?? (_) {},
        ),
      ),
    ),
  );
}

/// Opens the buddy selection bottom sheet via the add button.
Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
}

/// Sets a tall screen so that bottom sheets and role selectors fit without
/// overflow.
void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(640, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  group('BuddyPicker - BuddySelectionSheet', () {
    testWidgets('opens sheet and shows all buddies', (tester) async {
      await tester.pumpWidget(
        _buildPicker(
          overrides: [
            allBuddiesProvider.overrideWith((ref) async => _testBuddies),
            buddySearchProvider.overrideWith((ref, q) async => []),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('Bob Jones'), findsOneWidget);
      expect(find.text('Charlie Brown'), findsOneWidget);
    });

    testWidgets('shows certification level as subtitle', (tester) async {
      await tester.pumpWidget(
        _buildPicker(
          overrides: [
            allBuddiesProvider.overrideWith((ref) async => _testBuddies),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      // Bob has Advanced Open Water certification
      expect(find.text('Advanced Open Water'), findsOneWidget);
    });

    testWidgets('debounces search input by 300ms', (tester) async {
      await tester.pumpWidget(
        _buildPicker(
          overrides: [
            allBuddiesProvider.overrideWith((ref) async => _testBuddies),
            buddySearchProvider.overrideWith((ref, query) async {
              return _testBuddies
                  .where(
                    (b) => b.name.toLowerCase().contains(query.toLowerCase()),
                  )
                  .toList();
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      // Type in search field
      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.pump();

      // Before debounce fires -- still showing all buddies
      expect(find.text('Bob Jones'), findsOneWidget);
      expect(find.text('Charlie Brown'), findsOneWidget);

      // Advance past the 300ms debounce
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Now filtered to Alice only
      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('Bob Jones'), findsNothing);
      expect(find.text('Charlie Brown'), findsNothing);
    });

    testWidgets('clear button resets search immediately', (tester) async {
      await tester.pumpWidget(
        _buildPicker(
          overrides: [
            allBuddiesProvider.overrideWith((ref) async => _testBuddies),
            buddySearchProvider.overrideWith((ref, query) async {
              return _testBuddies
                  .where(
                    (b) => b.name.toLowerCase().contains(query.toLowerCase()),
                  )
                  .toList();
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      // Search and wait for debounce
      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Bob Jones'), findsNothing);

      // Tap clear button -- should reset instantly (no debounce)
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // All buddies visible again
      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('Bob Jones'), findsOneWidget);
      expect(find.text('Charlie Brown'), findsOneWidget);
    });

    testWidgets('empty query immediately clears debounced state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildPicker(
          overrides: [
            allBuddiesProvider.overrideWith((ref) async => _testBuddies),
            buddySearchProvider.overrideWith((ref, query) async {
              return _testBuddies
                  .where(
                    (b) => b.name.toLowerCase().contains(query.toLowerCase()),
                  )
                  .toList();
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      // Type something, wait for debounce, then clear via text
      await tester.enterText(find.byType(TextField), 'Al');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Now enter empty text (simulates user deleting all text)
      await tester.enterText(find.byType(TextField), '');
      await tester.pump(); // Single frame -- no debounce for empty

      // Should switch back to all buddies immediately
      await tester.pumpAndSettle();
      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('Bob Jones'), findsOneWidget);
    });

    testWidgets('shows selected state for pre-selected buddies', (
      tester,
    ) async {
      final selectedBuddy = BuddyWithRole(
        buddy: _testBuddies[0],
        role: BuddyRole.buddy,
      );

      await tester.pumpWidget(
        _buildPicker(
          selectedBuddies: [selectedBuddy],
          overrides: [
            allBuddiesProvider.overrideWith((ref) async => _testBuddies),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      // Alice should be selected (check icon + role chip)
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('tapping unselected buddy opens role selector', (tester) async {
      _useTallScreen(tester);
      await tester.pumpWidget(
        _buildPicker(
          overrides: [
            allBuddiesProvider.overrideWith((ref) async => _testBuddies),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      // Tap Alice to open role selector
      await tester.tap(find.text('Alice Smith'));
      await tester.pumpAndSettle();

      // Role selector should show all roles
      expect(find.text('Dive Guide'), findsOneWidget);
      expect(find.text('Instructor'), findsOneWidget);
      expect(find.text('Divemaster'), findsOneWidget);
    });

    testWidgets('selecting a role adds buddy to selection', (tester) async {
      _useTallScreen(tester);
      await tester.pumpWidget(
        _buildPicker(
          overrides: [
            allBuddiesProvider.overrideWith((ref) async => _testBuddies),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      // Tap Alice -> role selector
      await tester.tap(find.text('Alice Smith'));
      await tester.pumpAndSettle();

      // Select "Instructor" role
      await tester.tap(find.text('Instructor'));
      await tester.pumpAndSettle();

      // Alice should now be selected (check icon visible)
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('tapping selected buddy deselects them', (tester) async {
      _useTallScreen(tester);
      final selectedBuddy = BuddyWithRole(
        buddy: _testBuddies[0],
        role: BuddyRole.buddy,
      );

      await tester.pumpWidget(
        _buildPicker(
          selectedBuddies: [selectedBuddy],
          overrides: [
            allBuddiesProvider.overrideWith((ref) async => _testBuddies),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      // Alice is selected
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Tap Alice in the sheet list (not the chip) to deselect
      final aliceInSheet = find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Alice Smith'),
      );
      await tester.tap(aliceInSheet.first);
      await tester.pumpAndSettle();

      // Check icon should be gone
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('shows empty state when no buddies exist', (tester) async {
      await tester.pumpWidget(
        _buildPicker(
          overrides: [
            allBuddiesProvider.overrideWith((ref) async => <Buddy>[]),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      // Should show empty state with people icon
      expect(find.byIcon(Icons.people_outline), findsWidgets);
    });

    testWidgets('shows search empty state when no results', (tester) async {
      await tester.pumpWidget(
        _buildPicker(
          overrides: [
            allBuddiesProvider.overrideWith((ref) async => _testBuddies),
            buddySearchProvider.overrideWith((ref, query) async => <Buddy>[]),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      // Search for something with no results
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Should show search_off icon (empty search state)
      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });

    testWidgets('shows loading spinner when provider is loading', (
      tester,
    ) async {
      final completer = Completer<List<Buddy>>();
      addTearDown(() {
        if (!completer.isCompleted) completer.complete([]);
      });

      await tester.pumpWidget(
        _buildPicker(
          overrides: [
            allBuddiesProvider.overrideWith((ref) => completer.future),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      // Open sheet -- use pump() not pumpAndSettle() since provider never
      // completes
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('caches search results and shows LinearProgressIndicator '
        'during subsequent loading', (tester) async {
      var callCount = 0;
      final secondSearchCompleter = Completer<List<Buddy>>();
      addTearDown(() {
        if (!secondSearchCompleter.isCompleted) {
          secondSearchCompleter.complete([]);
        }
      });

      await tester.pumpWidget(
        _buildPicker(
          overrides: [
            allBuddiesProvider.overrideWith((ref) async => _testBuddies),
            buddySearchProvider.overrideWith((ref, query) {
              callCount++;
              if (callCount <= 1) {
                // First search completes immediately
                return Future.value(
                  _testBuddies
                      .where(
                        (b) =>
                            b.name.toLowerCase().contains(query.toLowerCase()),
                      )
                      .toList(),
                );
              }
              // Second search hangs in loading
              return secondSearchCompleter.future;
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      // First search -- completes immediately, caches results
      await tester.enterText(find.byType(TextField), 'Al');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Alice Smith'), findsOneWidget);

      // Second search -- provider returns loading
      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(); // Rebuild with loading state

      // Cached results should still be visible
      expect(find.text('Alice Smith'), findsOneWidget);
      // LinearProgressIndicator should appear
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('done button returns selected buddies via onChanged', (
      tester,
    ) async {
      _useTallScreen(tester);
      List<BuddyWithRole>? result;

      await tester.pumpWidget(
        _buildPicker(
          onChanged: (buddies) => result = buddies,
          overrides: [
            allBuddiesProvider.overrideWith((ref) async => _testBuddies),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      // Select Alice with "Instructor" role
      await tester.tap(find.text('Alice Smith'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Instructor'));
      await tester.pumpAndSettle();

      // Tap "Done" -- it's a TextButton in the sheet header
      // Find all TextButtons and tap the one inside the bottom sheet
      // The "Done" button is rendered by the _BuddySelectionSheet header
      final doneButton = find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.byType(TextButton),
      );
      await tester.tap(doneButton);
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.length, equals(1));
      expect(result![0].buddy.name, equals('Alice Smith'));
      expect(result![0].role, equals(BuddyRole.instructor));
    });
  });
}
