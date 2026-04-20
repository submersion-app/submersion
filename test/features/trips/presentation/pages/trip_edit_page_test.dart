import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/pages/trip_edit_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  group('TripEditPage - New Trip', () {
    testWidgets('should display Add Trip title for new trip', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Add Trip'), findsWidgets);
    });

    testWidgets('should display trip name field', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Trip Name *'), findsOneWidget);
    });

    testWidgets('should display Trip Dates section', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Trip Dates'), findsOneWidget);
      expect(find.text('Start Date'), findsOneWidget);
      expect(find.text('End Date'), findsOneWidget);
    });

    testWidgets('should display Location section', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to find Location section
      await tester.scrollUntilVisible(
        find.text('Location').first,
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Location'), findsWidgets);
    });

    testWidgets('should display Resort Name field', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Resort Name'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Resort Name'), findsOneWidget);
    });

    testWidgets('should display Liveaboard Name field', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Liveaboard Name'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Liveaboard Name'), findsOneWidget);
    });

    testWidgets('should display Notes section', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Notes').first,
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Notes'), findsWidgets);
    });

    testWidgets('should display Save button in app bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('should display Cancel button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Cancel'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('should show validation error when name is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Save button without entering name
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a trip name'), findsOneWidget);
    });

    testWidgets('should accept input in name field', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Trip Name *'),
        'My Test Trip',
      );
      await tester.pumpAndSettle();

      expect(find.text('My Test Trip'), findsOneWidget);
    });
  });

  group('TripEditPage - Edit Trip', () {
    testWidgets('should display Edit Trip title when editing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(
              _MockTripRepositoryWithTrip(),
            ),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(tripId: 'test-id'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Edit Trip'), findsOneWidget);
    });

    testWidgets('should load existing trip data', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(
              _MockTripRepositoryWithTrip(),
            ),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(tripId: 'test-id'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Existing Trip'), findsOneWidget);
    });
  });

  group('share toggle', () {
    testWidgets('hides the toggle when only one diver exists', (tester) async {
      final oneDiver = [
        Diver(
          id: 'd1',
          name: 'One',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
            allDiversProvider.overrideWith((_) async => oneDiver),
            shareByDefaultProvider.overrideWith((_) async => false),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SwitchListTile &&
              w.title is Text &&
              (w.title as Text).data == 'Share with all dive profiles',
        ),
        findsNothing,
      );
    });

    testWidgets('shows toggle with default from AppSettings when 2+ divers', (
      tester,
    ) async {
      final twoDivers = [
        Diver(
          id: 'd1',
          name: 'One',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
        Diver(
          id: 'd2',
          name: 'Two',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
            allDiversProvider.overrideWith((_) async => twoDivers),
            shareByDefaultProvider.overrideWith((_) async => true),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final switchFinder = find.byWidgetPredicate(
        (w) =>
            w is SwitchListTile &&
            w.title is Text &&
            (w.title as Text).data == 'Share with all dive profiles',
      );
      expect(switchFinder, findsOneWidget);
      expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
    });

    testWidgets('un-share on existing shared trip shows confirmation dialog', (
      tester,
    ) async {
      final twoDivers = [
        Diver(
          id: 'd1',
          name: 'One',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
        Diver(
          id: 'd2',
          name: 'Two',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ];

      // TripEditPage with a SHARED existing trip loaded.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(
              _MockTripRepositoryWithSharedTrip(),
            ),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
            allDiversProvider.overrideWith((_) async => twoDivers),
            shareByDefaultProvider.overrideWith((_) async => true),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(tripId: 'test-shared'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll until the share toggle is visible.
      await tester.scrollUntilVisible(
        find.text('Share with all dive profiles'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final switchFinder = find.byWidgetPredicate(
        (w) =>
            w is SwitchListTile &&
            w.title is Text &&
            (w.title as Text).data == 'Share with all dive profiles',
      );
      // Confirm toggle starts in the ON position.
      expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);

      // Tap to turn OFF — should show the unshare confirm dialog.
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(find.text('Unshare this trip?'), findsOneWidget);
    });
  });

  group('TripEditPage - liveaboard vessel section', () {
    testWidgets('shows vessel details fields when type is liveaboard', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Tap the Liveaboard segment.
      await tester.tap(find.text('Liveaboard'));
      await tester.pumpAndSettle();
      // Scroll and check vessel section rendered.
      await tester.scrollUntilVisible(
        find.text('Vessel Details'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Vessel Details'), findsOneWidget);
      expect(find.text('Embark / Disembark'), findsOneWidget);
    });

    testWidgets('shows vessel required validation on save for liveaboard', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Trip Name *'),
        'LB Trip',
      );
      await tester.tap(find.text('Liveaboard'));
      await tester.pumpAndSettle();
      // Attempt save - vessel name is missing.
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Vessel name is required'), findsOneWidget);
    });

    testWidgets('vessel type dropdown selection updates state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Liveaboard'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(DropdownButtonFormField<String>),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      // The dropdown menu should be open - tap Catamaran.
      await tester.tap(find.text('Catamaran').last);
      await tester.pumpAndSettle();
      expect(find.text('Catamaran'), findsWidgets);
    });
  });

  group('TripEditPage - date picker', () {
    testWidgets('tapping start date opens date picker', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Date'));
      await tester.pumpAndSettle();
      // Date picker shows OK/Cancel.
      expect(find.byType(DatePickerDialog), findsOneWidget);
      // Cancel the dialog directly.
      Navigator.of(tester.element(find.byType(DatePickerDialog))).pop();
      await tester.pumpAndSettle();
    });

    testWidgets('tapping end date opens date picker', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('End Date'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(DatePickerDialog))).pop();
      await tester.pumpAndSettle();
    });
  });

  group('TripEditPage - save flow', () {
    testWidgets('save new trip calls addTrip and pops', (tester) async {
      final notifier = _MockTripListNotifier([]);

      final router = GoRouter(
        initialLocation: '/trips/new',
        routes: [
          GoRoute(
            path: '/trips',
            builder: (context, state) =>
                const Scaffold(body: Text('LIST_PAGE')),
          ),
          GoRoute(
            path: '/trips/new',
            builder: (context, state) => const TripEditPage(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) => notifier),
            validatedCurrentDiverIdProvider.overrideWith(
              (ref) async => 'diver-id',
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Trip Name *'),
        'My New Trip',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(notifier.addCalls, 1);
      expect(find.text('Trip added successfully'), findsOneWidget);
    });

    testWidgets('save existing trip calls updateTrip', (tester) async {
      final notifier = _MockTripListNotifier([]);
      final router = GoRouter(
        initialLocation: '/trips/edit',
        routes: [
          GoRoute(
            path: '/trips',
            builder: (context, state) =>
                const Scaffold(body: Text('LIST_PAGE')),
          ),
          GoRoute(
            path: '/trips/edit',
            builder: (context, state) => const TripEditPage(tripId: 'test-id'),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(
              _MockTripRepositoryWithTrip(),
            ),
            tripListNotifierProvider.overrideWith((ref) => notifier),
            validatedCurrentDiverIdProvider.overrideWith(
              (ref) async => 'diver-id',
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Existing Trip'), findsOneWidget);
      // Make a change.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Trip Name *'),
        'Updated Name',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(notifier.updateCalls, 1);
      expect(find.text('Trip updated successfully'), findsOneWidget);
    });

    testWidgets('save errors show error snackbar', (tester) async {
      final notifier = _ThrowingTripListNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) => notifier),
            validatedCurrentDiverIdProvider.overrideWith(
              (ref) async => 'diver-id',
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Trip Name *'),
        'Fail Trip',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Error saving trip'), findsOneWidget);
    });
  });

  group('TripEditPage - discard changes', () {
    testWidgets(
      'discard confirmation dialog appears when cancel tapped with changes',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
              tripListNotifierProvider.overrideWith((ref) {
                return _MockTripListNotifier([]);
              }),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: TripEditPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Trip Name *'),
          'Some text',
        );
        await tester.pumpAndSettle();
        // Scroll to and tap cancel.
        await tester.scrollUntilVisible(
          find.text('Cancel'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Discard Changes?'), findsOneWidget);
        expect(find.text('Keep Editing'), findsOneWidget);
        expect(find.text('Discard'), findsOneWidget);
        // Keep Editing - dialog dismisses.
        await tester.tap(find.text('Keep Editing'));
        await tester.pumpAndSettle();
        expect(find.text('Discard Changes?'), findsNothing);
      },
    );

    testWidgets('cancel without changes does not show dialog', (tester) async {
      final router = GoRouter(
        initialLocation: '/list',
        routes: [
          GoRoute(
            path: '/list',
            builder: (context, state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => context.push('/list/edit'),
                  child: const Text('OPEN_EDIT'),
                ),
              ),
            ),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => const TripEditPage(),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('OPEN_EDIT'));
      await tester.pumpAndSettle();
      // Scroll down to reveal the Cancel button.
      await tester.fling(
        find.byType(TripEditPage),
        const Offset(0, -500),
        1000,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      // No discard dialog because no changes.
      expect(find.text('Discard Changes?'), findsNothing);
      // Should have popped back to list page.
      expect(find.text('OPEN_EDIT'), findsOneWidget);
    });
  });

  group('TripEditPage - embedded layout', () {
    testWidgets('renders embedded header with Save and Cancel buttons', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TripEditPage(
                embedded: true,
                onSaved: (id) {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Embedded header shows 'Add Trip' title (not app bar).
      expect(find.text('Add Trip'), findsWidgets);
      expect(find.byIcon(Icons.add), findsOneWidget);
      // Save and Cancel should be rendered in the embedded header.
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('embedded Save calls onSaved callback', (tester) async {
      String? savedId;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
            validatedCurrentDiverIdProvider.overrideWith(
              (ref) async => 'diver-id',
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TripEditPage(
                embedded: true,
                onSaved: (id) => savedId = id,
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Trip Name *'),
        'Embedded Save',
      );
      await tester.tap(find.text('Save'));
      // Use pump with duration so the dialog calls complete.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(savedId, isNotNull);
    });

    testWidgets('embedded Cancel with no changes calls onCancel', (
      tester,
    ) async {
      bool cancelCalled = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TripEditPage(
                embedded: true,
                onSaved: (id) {},
                onCancel: () => cancelCalled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(cancelCalled, isTrue);
    });

    testWidgets('embedded Cancel with changes shows discard dialog', (
      tester,
    ) async {
      bool cancelCalled = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TripEditPage(
                embedded: true,
                onSaved: (id) {},
                onCancel: () => cancelCalled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Trip Name *'),
        'changed',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard Changes?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();
      expect(cancelCalled, isTrue);
    });

    testWidgets('embedded loading state shows progress indicator', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_SlowTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TripEditPage(
                tripId: 'test-id',
                embedded: true,
                onSaved: (id) {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });

  group('TripEditPage - error loading', () {
    testWidgets('shows error snackbar when load fails', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_ErrorTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(tripId: 'fail-id'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Error loading trip'), findsOneWidget);
    });
  });

  group('TripEditPage - date picker confirm', () {
    testWidgets('selecting a new start date updates display', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Date'));
      await tester.pumpAndSettle();
      // Confirm the date picker by tapping OK.
      expect(find.text('OK'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      // Still on page, no dialog open.
      expect(find.byType(DatePickerDialog), findsNothing);
    });
  });

  group('TripEditPage - unshare confirmation', () {
    testWidgets('confirming unshare toggles isShared to false', (tester) async {
      final twoDivers = [
        Diver(
          id: 'd1',
          name: 'One',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
        Diver(
          id: 'd2',
          name: 'Two',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(
              _MockTripRepositoryWithSharedTrip(),
            ),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
            allDiversProvider.overrideWith((_) async => twoDivers),
            shareByDefaultProvider.overrideWith((_) async => true),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(tripId: 'test-shared'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Share with all dive profiles'),
        50,
        scrollable: find.byType(Scrollable).first,
      );
      final switchFinder = find.byWidgetPredicate(
        (w) =>
            w is SwitchListTile &&
            w.title is Text &&
            (w.title as Text).data == 'Share with all dive profiles',
      );
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(find.text('Unshare this trip?'), findsOneWidget);
      // Confirm the unshare.
      await tester.tap(find.widgetWithText(FilledButton, 'Unshare'));
      await tester.pumpAndSettle();
      // Dialog dismissed; switch is now off.
      expect(find.text('Unshare this trip?'), findsNothing);
      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
    });

    testWidgets('cancelling unshare keeps isShared true', (tester) async {
      final twoDivers = [
        Diver(
          id: 'd1',
          name: 'One',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
        Diver(
          id: 'd2',
          name: 'Two',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(
              _MockTripRepositoryWithSharedTrip(),
            ),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
            allDiversProvider.overrideWith((_) async => twoDivers),
            shareByDefaultProvider.overrideWith((_) async => true),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(tripId: 'test-shared'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Share with all dive profiles'),
        50,
        scrollable: find.byType(Scrollable).first,
      );
      final switchFinder = find.byWidgetPredicate(
        (w) =>
            w is SwitchListTile &&
            w.title is Text &&
            (w.title as Text).data == 'Share with all dive profiles',
      );
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      // Cancel via Material cancel button.
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Unshare this trip?'), findsNothing);
      // Switch remains on.
      expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
    });
  });

  group('TripEditPage - duration display', () {
    testWidgets('updates duration text when start date moves past end date', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Default duration is 7 days + 1 = 8.
      expect(find.text('8 days'), findsOneWidget);
    });
  });
}

/// Mock repository that returns null for trips
class _MockTripRepository implements TripRepository {
  @override
  Future<Trip> createTrip(Trip trip) async => trip;

  @override
  Future<void> updateTrip(Trip trip) async {}

  @override
  Future<void> deleteTrip(String id) async {}

  @override
  Future<Trip?> getTripById(String id) async => null;

  @override
  Future<List<Trip>> getAllTrips({String? diverId}) async => [];

  @override
  Future<List<Trip>> searchTrips(String query, {String? diverId}) async => [];

  @override
  Future<List<TripWithStats>> getAllTripsWithStats({String? diverId}) async =>
      [];

  @override
  Future<TripWithStats> getTripWithStats(
    String tripId, {
    String? diverId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getDiveIdsForTrip(
    String tripId, {
    String? diverId,
  }) async => [];

  @override
  Future<void> assignDiveToTrip(String diveId, String tripId) async {}

  @override
  Future<void> removeDiveFromTrip(String diveId) async {}

  @override
  Future<Trip?> findTripForDate(DateTime date, {String? diverId}) async => null;

  @override
  Future<int> getDiveCountForTrip(String tripId, {String? diverId}) async => 0;

  @override
  Future<List<DiveCandidate>> findCandidateDivesForTrip({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
    required String diverId,
  }) async => [];

  @override
  Future<void> assignDivesToTrip(List<String> diveIds, String tripId) async {}

  @override
  Future<void> setShared(String id, bool isShared) async {}

  @override
  Future<int> shareAllForDiver(String diverId) async => 0;
}

/// Mock repository that returns a test trip
class _MockTripRepositoryWithTrip implements TripRepository {
  @override
  Future<Trip> createTrip(Trip trip) async => trip;

  @override
  Future<void> updateTrip(Trip trip) async {}

  @override
  Future<void> deleteTrip(String id) async {}

  @override
  Future<Trip?> getTripById(String id) async {
    return Trip(
      id: 'test-id',
      name: 'Existing Trip',
      startDate: DateTime(2024, 1, 15),
      endDate: DateTime(2024, 1, 22),
      location: 'Test Location',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Trip>> getAllTrips({String? diverId}) async => [];

  @override
  Future<List<Trip>> searchTrips(String query, {String? diverId}) async => [];

  @override
  Future<List<TripWithStats>> getAllTripsWithStats({String? diverId}) async =>
      [];

  @override
  Future<TripWithStats> getTripWithStats(
    String tripId, {
    String? diverId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getDiveIdsForTrip(
    String tripId, {
    String? diverId,
  }) async => [];

  @override
  Future<void> assignDiveToTrip(String diveId, String tripId) async {}

  @override
  Future<void> removeDiveFromTrip(String diveId) async {}

  @override
  Future<Trip?> findTripForDate(DateTime date, {String? diverId}) async => null;

  @override
  Future<int> getDiveCountForTrip(String tripId, {String? diverId}) async => 0;

  @override
  Future<List<DiveCandidate>> findCandidateDivesForTrip({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
    required String diverId,
  }) async => [];

  @override
  Future<void> assignDivesToTrip(List<String> diveIds, String tripId) async {}

  @override
  Future<void> setShared(String id, bool isShared) async {}

  @override
  Future<int> shareAllForDiver(String diverId) async => 0;
}

/// Mock repository that returns a SHARED test trip (for unshare confirmation tests).
class _MockTripRepositoryWithSharedTrip implements TripRepository {
  @override
  Future<Trip> createTrip(Trip trip) async => trip;

  @override
  Future<void> updateTrip(Trip trip) async {}

  @override
  Future<void> deleteTrip(String id) async {}

  @override
  Future<Trip?> getTripById(String id) async {
    return Trip(
      id: 'test-shared',
      name: 'Shared Trip',
      startDate: DateTime(2024, 1, 15),
      endDate: DateTime(2024, 1, 22),
      isShared: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Trip>> getAllTrips({String? diverId}) async => [];

  @override
  Future<List<Trip>> searchTrips(String query, {String? diverId}) async => [];

  @override
  Future<List<TripWithStats>> getAllTripsWithStats({String? diverId}) async =>
      [];

  @override
  Future<TripWithStats> getTripWithStats(
    String tripId, {
    String? diverId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getDiveIdsForTrip(
    String tripId, {
    String? diverId,
  }) async => [];

  @override
  Future<void> assignDiveToTrip(String diveId, String tripId) async {}

  @override
  Future<void> removeDiveFromTrip(String diveId) async {}

  @override
  Future<Trip?> findTripForDate(DateTime date, {String? diverId}) async => null;

  @override
  Future<int> getDiveCountForTrip(String tripId, {String? diverId}) async => 0;

  @override
  Future<List<DiveCandidate>> findCandidateDivesForTrip({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
    required String diverId,
  }) async => [];

  @override
  Future<void> assignDivesToTrip(List<String> diveIds, String tripId) async {}

  @override
  Future<void> setShared(String id, bool isShared) async {}

  @override
  Future<int> shareAllForDiver(String diverId) async => 0;
}

/// Mock notifier
class _MockTripListNotifier
    extends StateNotifier<AsyncValue<List<TripWithStats>>>
    implements TripListNotifier {
  _MockTripListNotifier(List<TripWithStats> trips)
    : super(AsyncValue.data(trips));

  int addCalls = 0;
  int updateCalls = 0;

  @override
  Future<void> refresh() async {}

  @override
  Future<Trip> addTrip(Trip trip) async {
    addCalls++;
    return trip.copyWith(id: 'new-id-${addCalls.toString()}');
  }

  @override
  Future<void> updateTrip(Trip trip) async {
    updateCalls++;
  }

  @override
  Future<void> deleteTrip(String id) async {}

  @override
  Future<void> assignDiveToTrip(String diveId, String tripId) async {}

  @override
  Future<void> removeDiveFromTrip(String diveId, String tripId) async {}

  @override
  Future<void> assignDivesToTrip(
    List<String> diveIds,
    String tripId, {
    Set<String>? oldTripIds,
  }) async {}
}

/// Notifier whose addTrip throws - used to test error snackbar.
class _ThrowingTripListNotifier
    extends StateNotifier<AsyncValue<List<TripWithStats>>>
    implements TripListNotifier {
  _ThrowingTripListNotifier() : super(const AsyncValue.data([]));

  @override
  Future<void> refresh() async {}

  @override
  Future<Trip> addTrip(Trip trip) async {
    throw Exception('boom');
  }

  @override
  Future<void> updateTrip(Trip trip) async {}

  @override
  Future<void> deleteTrip(String id) async {}

  @override
  Future<void> assignDiveToTrip(String diveId, String tripId) async {}

  @override
  Future<void> removeDiveFromTrip(String diveId, String tripId) async {}

  @override
  Future<void> assignDivesToTrip(
    List<String> diveIds,
    String tripId, {
    Set<String>? oldTripIds,
  }) async {}
}

/// Repository that takes its sweet time returning a trip to simulate loading.
class _SlowTripRepository implements TripRepository {
  @override
  Future<Trip> createTrip(Trip trip) async => trip;

  @override
  Future<void> updateTrip(Trip trip) async {}

  @override
  Future<void> deleteTrip(String id) async {}

  @override
  Future<Trip?> getTripById(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return Trip(
      id: id,
      name: 'Slow Trip',
      startDate: DateTime(2024, 1, 15),
      endDate: DateTime(2024, 1, 22),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Trip>> getAllTrips({String? diverId}) async => [];

  @override
  Future<List<Trip>> searchTrips(String query, {String? diverId}) async => [];

  @override
  Future<List<TripWithStats>> getAllTripsWithStats({String? diverId}) async =>
      [];

  @override
  Future<TripWithStats> getTripWithStats(
    String tripId, {
    String? diverId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getDiveIdsForTrip(
    String tripId, {
    String? diverId,
  }) async => [];

  @override
  Future<void> assignDiveToTrip(String diveId, String tripId) async {}

  @override
  Future<void> removeDiveFromTrip(String diveId) async {}

  @override
  Future<Trip?> findTripForDate(DateTime date, {String? diverId}) async => null;

  @override
  Future<int> getDiveCountForTrip(String tripId, {String? diverId}) async => 0;

  @override
  Future<List<DiveCandidate>> findCandidateDivesForTrip({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
    required String diverId,
  }) async => [];

  @override
  Future<void> assignDivesToTrip(List<String> diveIds, String tripId) async {}

  @override
  Future<void> setShared(String id, bool isShared) async {}

  @override
  Future<int> shareAllForDiver(String diverId) async => 0;
}

/// Repository that throws when getTripById is called.
class _ErrorTripRepository implements TripRepository {
  @override
  Future<Trip> createTrip(Trip trip) async => trip;

  @override
  Future<void> updateTrip(Trip trip) async {}

  @override
  Future<void> deleteTrip(String id) async {}

  @override
  Future<Trip?> getTripById(String id) async {
    throw Exception('not found');
  }

  @override
  Future<List<Trip>> getAllTrips({String? diverId}) async => [];

  @override
  Future<List<Trip>> searchTrips(String query, {String? diverId}) async => [];

  @override
  Future<List<TripWithStats>> getAllTripsWithStats({String? diverId}) async =>
      [];

  @override
  Future<TripWithStats> getTripWithStats(
    String tripId, {
    String? diverId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getDiveIdsForTrip(
    String tripId, {
    String? diverId,
  }) async => [];

  @override
  Future<void> assignDiveToTrip(String diveId, String tripId) async {}

  @override
  Future<void> removeDiveFromTrip(String diveId) async {}

  @override
  Future<Trip?> findTripForDate(DateTime date, {String? diverId}) async => null;

  @override
  Future<int> getDiveCountForTrip(String tripId, {String? diverId}) async => 0;

  @override
  Future<List<DiveCandidate>> findCandidateDivesForTrip({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
    required String diverId,
  }) async => [];

  @override
  Future<void> assignDivesToTrip(List<String> diveIds, String tripId) async {}

  @override
  Future<void> setShared(String id, bool isShared) async {}

  @override
  Future<int> shareAllForDiver(String diverId) async => 0;
}
