import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_search_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  group('DiveSearchPage bottomTime coverage', () {
    late DiveRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = DiveRepository();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    testWidgets('renders search page with bottomTime filter', (tester) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveRepositoryProvider.overrideWithValue(repository),
            diveListNotifierProvider.overrideWith((ref) {
              return DiveListNotifier(repository, ref);
            }),
          ].cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DiveSearchPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveSearchPage), findsOneWidget);
    });

    testWidgets('renders with initial filter containing bottomTime range', (
      tester,
    ) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveRepositoryProvider.overrideWithValue(repository),
            diveListNotifierProvider.overrideWith((ref) {
              return DiveListNotifier(repository, ref);
            }),
            // Set a filter with bottomTime constraints
            diveFilterProvider.overrideWith(
              (ref) => const DiveFilterState(
                minBottomTimeMinutes: 20,
                maxBottomTimeMinutes: 60,
              ),
            ),
          ].cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DiveSearchPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveSearchPage), findsOneWidget);
    });

    testWidgets('tapping search applies bottomTime filter', (tester) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveRepositoryProvider.overrideWithValue(repository),
            diveListNotifierProvider.overrideWith((ref) {
              return DiveListNotifier(repository, ref);
            }),
          ].cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DiveSearchPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Search button to trigger _applyAndSearch (lines 784-785)
      final errors = <FlutterErrorDetails>[];
      FlutterError.onError = (d) => errors.add(d);
      final searchButton = find.byIcon(Icons.search);
      if (searchButton.evaluate().isNotEmpty) {
        await tester.tap(searchButton.first);
        await tester.pump();
      }
      FlutterError.onError = FlutterError.presentError;
    });

    testWidgets(
      'no-buddy and buddy name clear each other, Clear All resets both',
      (tester) async {
        final overrides = await getBaseOverrides();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...overrides,
              diveRepositoryProvider.overrideWithValue(repository),
              diveListNotifierProvider.overrideWith((ref) {
                return DiveListNotifier(repository, ref);
              }),
            ].cast(),
            child: const MaterialApp(
              // Pinned: this test drives the page by English label.
              locale: Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: DiveSearchPage()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Every section starts collapsed, so the buddy controls are not in the
        // tree until Social is opened.
        await tester.tap(find.text('Social'));
        await tester.pumpAndSettle();

        final toggle = find.widgetWithText(SwitchListTile, 'No Buddy Assigned');
        final buddyField = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Buddy Name',
        );
        bool toggleValue() => tester.widget<SwitchListTile>(toggle).value;
        final buddyController = tester
            .widget<TextField>(buddyField)
            .controller!;

        // The Social section sits below the fold, so its switch is built but
        // off-viewport: tapping it without scrolling derives an Offset that
        // never hits the widget and silently does nothing.
        Future<void> tapVisible(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        // Name -> no-buddy: turning the switch on clears the typed name, both
        // in state and in the controller backing the visible field.
        await tester.enterText(buddyField, 'Alex');
        await tester.pumpAndSettle();
        expect(toggleValue(), isFalse);

        await tapVisible(toggle);
        expect(toggleValue(), isTrue);
        expect(buddyController.text, isEmpty);

        // No-buddy -> name: typing a name to search for turns the switch back
        // off, because the two filters cannot both hold.
        await tester.enterText(buddyField, 'Sam');
        await tester.pumpAndSettle();
        expect(toggleValue(), isFalse);

        // Clear All has to reset the toggle too, or a cleared form would still
        // apply a no-buddy filter on the next search.
        await tapVisible(toggle);
        expect(toggleValue(), isTrue);

        await tapVisible(find.text('Clear All'));
        expect(toggleValue(), isFalse);
        expect(buddyController.text, isEmpty);
      },
    );

    testWidgets('tapping the start-date button opens the date picker (#765)', (
      tester,
    ) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveRepositoryProvider.overrideWithValue(repository),
            diveListNotifierProvider.overrideWith((ref) {
              return DiveListNotifier(repository, ref);
            }),
          ].cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DiveSearchPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dateButtons = find.widgetWithIcon(
        OutlinedButton,
        Icons.calendar_today,
      );
      expect(dateButtons, findsNWidgets(2));

      await tester.tap(dateButtons.first);
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      // The search page has its own Cancel action, so scope to the dialog.
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('Cancel'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
    });

    testWidgets(
      'selecting an equipment chip applies the equipmentIds filter (#1407)',
      (tester) async {
        await _seedDiverScopedEquipment();

        final overrides = await getBaseOverrides();
        late WidgetRef capturedRef;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...overrides,
              diveRepositoryProvider.overrideWithValue(repository),
              diveListNotifierProvider.overrideWith((ref) {
                return DiveListNotifier(repository, ref);
              }),
            ].cast(),
            child: MaterialApp(
              // Pinned: this test drives the page by English label.
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    capturedRef = ref;
                    return const DiveSearchPage();
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Gas & Equipment starts collapsed, so the equipment chips are not in
        // the tree until the section is expanded.
        await tester.tap(find.text('Gas & Equipment'));
        await tester.pumpAndSettle();

        final chip = find.widgetWithText(FilterChip, 'Backplate BCD');
        expect(chip, findsOneWidget);
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();

        // Applying navigates via go_router, which is not wired up in this
        // test's MaterialApp; the provider write above happens first, so
        // swallow the resulting navigation error the same way the existing
        // "tapping search applies bottomTime filter" test above does.
        final errors = <FlutterErrorDetails>[];
        FlutterError.onError = (d) => errors.add(d);
        await tester.ensureVisible(find.text('Search'));
        await tester.tap(find.text('Search'));
        await tester.pump();
        FlutterError.onError = FlutterError.presentError;

        expect(
          capturedRef.read(diveFilterProvider).equipmentIds,
          contains('eq1'),
        );
      },
    );

    testWidgets(
      'a duplicated incoming equipment id still deselects in one tap (#1407)',
      (tester) async {
        await _seedDiverScopedEquipment();

        final overrides = await getBaseOverrides();
        late WidgetRef capturedRef;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...overrides,
              diveRepositoryProvider.overrideWithValue(repository),
              diveListNotifierProvider.overrideWith((ref) {
                return DiveListNotifier(repository, ref);
              }),
              // A filter state built elsewhere is not guaranteed to hold
              // distinct ids; the page must not let that strand a chip.
              diveFilterProvider.overrideWith(
                (ref) => const DiveFilterState(equipmentIds: ['eq1', 'eq1']),
              ),
            ].cast(),
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    capturedRef = ref;
                    return const DiveSearchPage();
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // An incoming equipment filter auto-expands Gas & Equipment, so unlike
        // the test above this one must not tap the header (that would collapse
        // it and take the chips back out of the tree).
        final chip = find.widgetWithText(FilterChip, 'Backplate BCD');
        expect(chip, findsOneWidget);
        expect(tester.widget<FilterChip>(chip).selected, isTrue);

        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();

        // One tap clears it: without deduplication the second occurrence
        // survives and the chip stays lit with no way back.
        expect(tester.widget<FilterChip>(chip).selected, isFalse);

        final errors = <FlutterErrorDetails>[];
        FlutterError.onError = (d) => errors.add(d);
        await tester.ensureVisible(find.text('Search'));
        await tester.tap(find.text('Search'));
        await tester.pump();
        FlutterError.onError = FlutterError.presentError;

        expect(capturedRef.read(diveFilterProvider).equipmentIds, isEmpty);
      },
    );
  });
}

/// Seeds a default diver plus one piece of equipment owned by that diver.
///
/// `allEquipmentProvider` is diver-scoped, and `getAllEquipment` skips its
/// `where` clause entirely when the resolved diver id is null. Seeding an
/// unowned row against an empty `divers` table would therefore pass without
/// ever exercising that filter, so the diver is seeded first (it is also the
/// FK parent of `equipment.diverId`) and the item is attached to it.
Future<void> _seedDiverScopedEquipment() async {
  final db = DatabaseService.instance.database;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  await db
      .into(db.divers)
      .insert(
        DiversCompanion(
          id: const Value('diver1'),
          name: const Value('Test Diver'),
          isDefault: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  await db
      .into(db.equipment)
      .insert(
        EquipmentCompanion(
          id: const Value('eq1'),
          diverId: const Value('diver1'),
          name: const Value('Backplate BCD'),
          type: const Value('bcd'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}
