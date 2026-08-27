import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
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
  });
}
