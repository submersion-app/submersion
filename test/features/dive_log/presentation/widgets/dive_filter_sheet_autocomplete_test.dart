import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late StateProvider<DiveFilterState> filterProvider;
  final now = DateTime(2026, 7, 29);

  final testBuddies = [
    Buddy(id: 'b1', name: 'Alice Anderson', createdAt: now, updatedAt: now),
    Buddy(id: 'b2', name: 'Bob Brown', createdAt: now, updatedAt: now),
    Buddy(id: 'b3', name: 'Charlie Chaplin', createdAt: now, updatedAt: now),
  ];

  setUp(() async {
    await setUpTestDatabase();
    filterProvider = StateProvider<DiveFilterState>(
      (ref) => const DiveFilterState(),
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> openSheet(WidgetTester tester) async {
    final overrides = await getBaseOverrides();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          filterProvider.overrideWith((ref) => const DiveFilterState()),
          allBuddiesProvider.overrideWith((ref) async => testBuddies),
        ].cast(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => DiveFilterSheet(
                        ref: ref,
                        filterProvider: filterProvider,
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Finder scrollable() => find.byType(Scrollable).first;

  testWidgets(
    'buddy autocomplete shows suggestions and updates state on selection',
    (tester) async {
      await openSheet(tester);

      final buddyField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Buddy Name',
      );

      // Scroll to buddy field
      await tester.scrollUntilVisible(
        buddyField,
        100.0,
        scrollable: scrollable(),
      );
      await tester.pumpAndSettle();

      // Type "Al" to see suggestions
      await tester.enterText(buddyField, 'Al');
      await tester.pumpAndSettle();

      // Alice should be a suggestion. RawAutocomplete might show it in the overlay.
      // We expect at least one Alice Anderson (the suggestion list).
      // If the TextField also has "Al", it shouldn't match "Alice Anderson" exactly unless it's completed.
      expect(find.text('Alice Anderson'), findsOneWidget);

      // Tap the suggestion
      await tester.tap(find.text('Alice Anderson').last);
      await tester.pumpAndSettle();

      // Buddy name field should now have the full name
      expect(find.widgetWithText(TextField, 'Alice Anderson'), findsOneWidget);

      // Apply filters
      final applyButton = find.text('Apply Filters');
      await tester.scrollUntilVisible(
        applyButton,
        100.0,
        scrollable: scrollable(),
      );
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      // Check the provider state
      final element = tester.element(find.byType(MaterialApp));
      final container = ProviderScope.containerOf(element);
      expect(container.read(filterProvider).buddyNameFilter, 'Alice Anderson');
    },
  );

  testWidgets('buddy autocomplete filters suggestions case-insensitively', (
    tester,
  ) async {
    await openSheet(tester);

    final buddyField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Buddy Name',
    );

    await tester.scrollUntilVisible(
      buddyField,
      100.0,
      scrollable: scrollable(),
    );
    await tester.pumpAndSettle();

    // Type "bob" (lowercase)
    await tester.enterText(buddyField, 'bob');
    await tester.pumpAndSettle();

    // Bob Brown should be suggested
    expect(find.text('Bob Brown'), findsOneWidget);

    // Type "xyz" (no match)
    await tester.enterText(buddyField, 'xyz');
    await tester.pumpAndSettle();

    expect(find.text('Alice Anderson'), findsNothing);
    expect(find.text('Bob Brown'), findsNothing);
    expect(find.text('Charlie Chaplin'), findsNothing);
  });

  testWidgets('buddy autocomplete supports multiple selections with commas', (
    tester,
  ) async {
    await openSheet(tester);

    final buddyField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Buddy Name',
    );

    await tester.scrollUntilVisible(
      buddyField,
      100.0,
      scrollable: scrollable(),
    );
    await tester.pumpAndSettle();

    // Select first buddy
    await tester.enterText(buddyField, 'Ali');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alice Anderson').last);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Alice Anderson'), findsOneWidget);

    // Add comma and start typing second buddy
    await tester.enterText(buddyField, 'Alice Anderson, Bo');
    await tester.pumpAndSettle();

    // Should suggest Bob
    expect(find.text('Bob Brown'), findsOneWidget);

    // Select Bob
    await tester.tap(find.text('Bob Brown').last);
    await tester.pumpAndSettle();

    // Apply and check state
    final applyButton = find.text('Apply Filters');
    await tester.scrollUntilVisible(
      applyButton,
      100.0,
      scrollable: scrollable(),
    );
    await tester.tap(applyButton);
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(MaterialApp));
    final container = ProviderScope.containerOf(element);
    expect(
      container.read(filterProvider).buddyNameFilter,
      'Alice Anderson, Bob Brown',
    );
  });

  testWidgets('buddy autocomplete commits highlighted suggestion on submit', (
    tester,
  ) async {
    await openSheet(tester);

    final buddyField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Buddy Name',
    );

    await tester.scrollUntilVisible(
      buddyField,
      100.0,
      scrollable: scrollable(),
    );
    await tester.pumpAndSettle();

    await tester.enterText(buddyField, 'Ali');
    await tester.pumpAndSettle();

    expect(find.text('Alice Anderson'), findsOneWidget);

    // Submitting from the keyboard commits the highlighted suggestion rather
    // than leaving the partial text in the field.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Alice Anderson'), findsOneWidget);

    final applyButton = find.text('Apply Filters');
    await tester.scrollUntilVisible(
      applyButton,
      100.0,
      scrollable: scrollable(),
    );
    await tester.tap(applyButton);
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(MaterialApp));
    final container = ProviderScope.containerOf(element);
    expect(container.read(filterProvider).buddyNameFilter, 'Alice Anderson');
  });
}
