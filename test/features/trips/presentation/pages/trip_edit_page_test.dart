import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/pages/trip_edit_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/trips/presentation/widgets/dive_assignment_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Pumps a fresh-trip page behind a router, so the `context.pop(savedId)` that
/// follows a successful save has somewhere to go. Creating a trip always
/// triggers the post-save scan (`datesChanged` is `!isEditing`), which keeps
/// these tests clear of date-picker choreography.
///
/// The surface is enlarged because the assignment sheet is a
/// `DraggableScrollableSheet` at 60% height - at the default 800x600 the
/// candidate rows would need scrolling before they could be tapped.
Future<void> _pumpNewTripPage(
  WidgetTester tester, {
  required TripRepository repository,
  required TripListNotifier notifier,
  required String? activeDiverId,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: '/trips/new',
    routes: [
      GoRoute(
        path: '/trips',
        builder: (context, state) => const Scaffold(body: Text('LIST_PAGE')),
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
        tripRepositoryProvider.overrideWithValue(repository),
        tripListNotifierProvider.overrideWith((ref) => notifier),
        validatedCurrentDiverIdProvider.overrideWith(
          (ref) async => activeDiverId,
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
}

/// Advances a fixed budget of frames instead of settling.
///
/// `pumpAndSettle` is unusable while a save is in flight: `_saveTrip` sets
/// `_isSaving` before awaiting and only clears it on the error path, so the
/// Save button's `CircularProgressIndicator` schedules frames for as long as
/// the assignment sheet is open. A bounded pump advances fake time far enough
/// to cover the awaited futures plus the sheet's entry and exit animations.
Future<void> _pumpSaveFrames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _saveNewTrip(WidgetTester tester, String name) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Trip Name *'),
    name,
  );
  await tester.tap(find.text('Save'));
  await _pumpSaveFrames(tester);
}

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

    testWidgets(
      'end date picker opens positioned at the just-picked start date',
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
              // Pin the locale: this test types a US-format date.
              locale: Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: TripEditPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Pick a start date far in the past -- well before the default
        // end date (today + 7 days), so the auto-sync in _selectDate that
        // pushes _endDate forward when start moves past it never fires.
        // This is exactly the reported scenario: picking a start date
        // leaves the stale, far-away default end date behind.
        await tester.tap(find.text('Start Date'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byType(DatePickerDialog),
            matching: find.byType(TextField),
          ),
          '01/15/2023',
        );
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('End Date'));
        await tester.pumpAndSettle();

        final dialog = tester.widget<DatePickerDialog>(
          find.byType(DatePickerDialog),
        );
        expect(dialog.initialDate, DateTime(2023, 1, 15));
      },
    );

    testWidgets(
      'end date picker keeps opening at an explicitly picked end date',
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
              locale: Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: TripEditPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Explicitly pick an end date. _startDate defaults to today for a
        // new trip and bounds the end picker's firstDate, so the target
        // must stay safely in the future regardless of when this runs.
        final target = DateTime(DateTime.now().year + 2, 3, 10);
        await tester.tap(find.text('End Date'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();
        final month = target.month.toString().padLeft(2, '0');
        final day = target.day.toString().padLeft(2, '0');
        await tester.enterText(
          find.descendant(
            of: find.byType(DatePickerDialog),
            matching: find.byType(TextField),
          ),
          '$month/$day/${target.year}',
        );
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        // Reopening the end-date picker must keep showing the diver's own
        // choice, not fall back to _startDate now that it's been touched.
        await tester.tap(find.text('End Date'));
        await tester.pumpAndSettle();

        final dialog = tester.widget<DatePickerDialog>(
          find.byType(DatePickerDialog),
        );
        expect(dialog.initialDate, target);
      },
    );
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

    testWidgets('save with unchanged dates runs no scan and no diver lookup', (
      tester,
    ) async {
      final repo = _RecordingScanRepo();
      var diverLookups = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(repo),
            tripListNotifierProvider.overrideWith(
              (ref) => _MockTripListNotifier([]),
            ),
            validatedCurrentDiverIdProvider.overrideWith((ref) async {
              diverLookups++;
              return 'MAB';
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
      // Edit the name only, leaving both dates alone.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Trip Name *'),
        'Updated Name',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repo.scanCalls, 0);
      // The trip already has an owner, so the `??` at the top of _saveTrip
      // short-circuits and never resolves the provider. That leaves the scan
      // as the only possible reader, and it must not run for unchanged dates.
      expect(diverLookups, 0);
    });

    testWidgets(
      'post-save scan searches the active diver, not the trip owner',
      (tester) async {
        // Trip is owned by BAB but shared with, and being edited by, MAB.
        final repo = _RecordingScanRepo();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tripRepositoryProvider.overrideWithValue(repo),
              tripListNotifierProvider.overrideWith(
                (ref) => _MockTripListNotifier([]),
              ),
              validatedCurrentDiverIdProvider.overrideWith(
                (ref) async => 'MAB',
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: TripEditPage(tripId: 'test-id'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Move the start date so the post-save scan is triggered.
        await tester.tap(find.text('Start Date'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(DatePickerDialog),
            matching: find.text('18'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(repo.scanCalls, 1);
        // Ownership stays with BAB; the dives searched belong to the viewer.
        expect(repo.scannedDiverId, 'MAB');
      },
    );

    testWidgets('picked dives are assigned to the trip the save returned', (
      tester,
    ) async {
      final repo = _CandidateScanRepo();
      final notifier = _MockTripListNotifier([]);
      await _pumpNewTripPage(
        tester,
        repository: repo,
        notifier: notifier,
        activeDiverId: 'diver-id',
      );
      await _saveNewTrip(tester, 'Red Sea 2024');

      // The two unassigned dives arrive pre-checked. Add the Egypt Trip dive
      // as well, and leave the Palau Trip dive untouched.
      expect(find.text('Add 2 Dives'), findsOneWidget);
      await tester.tap(find.text('Site 43'));
      await tester.pump();
      await tester.tap(find.text('Add 3 Dives'));
      await _pumpSaveFrames(tester);

      expect(notifier.assignCalls, 1);
      expect(
        notifier.assignedDiveIds,
        unorderedEquals(['dive-1', 'dive-2', 'dive-3']),
      );
      // savedId is the id addTrip handed back, not widget.tripId (null here).
      expect(notifier.assignedTripId, 'new-id-1');
      // Only trips actually losing a dive get invalidated: the unassigned
      // dives contribute nothing, and Palau was never selected.
      expect(notifier.assignedOldTripIds, {'egypt-trip'});
      expect(find.text('Added 3 dives to trip'), findsOneWidget);
    });

    testWidgets('dismissing the dive dialog assigns nothing', (tester) async {
      final repo = _CandidateScanRepo();
      final notifier = _MockTripListNotifier([]);
      await _pumpNewTripPage(
        tester,
        repository: repo,
        notifier: notifier,
        activeDiverId: 'diver-id',
      );
      await _saveNewTrip(tester, 'Red Sea 2024');

      expect(find.byType(DiveAssignmentDialog), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(DiveAssignmentDialog),
          matching: find.text('Cancel'),
        ),
      );
      await _pumpSaveFrames(tester);

      expect(notifier.assignCalls, 0);
      expect(find.textContaining('dives to trip'), findsNothing);
      // The trip itself is saved either way - only the dives were declined.
      expect(notifier.addCalls, 1);
      expect(find.text('Trip added successfully'), findsOneWidget);
    });

    testWidgets('no active diver saves the trip without scanning', (
      tester,
    ) async {
      final repo = _CandidateScanRepo();
      final notifier = _MockTripListNotifier([]);
      await _pumpNewTripPage(
        tester,
        repository: repo,
        notifier: notifier,
        activeDiverId: null,
      );
      await _saveNewTrip(tester, 'Red Sea 2024');

      // With no diver resolved there is nobody to scan for, so the query never
      // runs and the dialog never opens - but the trip still saves.
      expect(repo.scanCalls, 0);
      expect(find.byType(DiveAssignmentDialog), findsNothing);
      expect(notifier.addCalls, 1);
      expect(find.text('Trip added successfully'), findsOneWidget);
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

  group('TripEditPage - return flight', () {
    Future<void> pumpNewTrip(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            // Pinned: these tests assert English strings.
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripEditPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows Not set and sets a flight via date + time pickers', (
      tester,
    ) async {
      await pumpNewTrip(tester);

      await tester.scrollUntilVisible(
        find.text('Return Flight'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Return Flight'), findsOneWidget);
      expect(find.text('Not set'), findsOneWidget);

      await tester.tap(find.text('Return Flight'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Not set'), findsNothing);
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('clear icon reverts the flight to Not set', (tester) async {
      await pumpNewTrip(tester);

      await tester.scrollUntilVisible(
        find.text('Return Flight'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Return Flight'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Not set'), findsNothing);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      expect(find.text('Not set'), findsOneWidget);
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

/// Candidates for the post-save scan: two loose dives plus two already sitting
/// on other trips. The assignment tests select `dive-3` and leave `dive-4`
/// alone, so `egypt-trip` is the only trip that should get invalidated.
List<DiveCandidate> _scanCandidates() => [
  DiveCandidate(dive: _candidateDive('dive-1', 41)),
  DiveCandidate(dive: _candidateDive('dive-2', 42)),
  DiveCandidate(
    dive: _candidateDive('dive-3', 43),
    currentTripId: 'egypt-trip',
    currentTripName: 'Egypt Trip',
  ),
  DiveCandidate(
    dive: _candidateDive('dive-4', 44),
    currentTripId: 'palau-trip',
    currentTripName: 'Palau Trip',
  ),
];

Dive _candidateDive(String id, int diveNumber) => Dive(
  id: id,
  dateTime: DateTime(2024, 1, 16),
  diveNumber: diveNumber,
  site: DiveSite(id: 'site-$id', name: 'Site $diveNumber'),
);

/// Repository for the new-trip flow that hands the page a real candidate list
/// so the assignment dialog actually opens.
class _CandidateScanRepo extends _MockTripRepository {
  int scanCalls = 0;

  @override
  Future<List<DiveCandidate>> findCandidateDivesForTrip({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
    required String diverId,
  }) async {
    scanCalls++;
    return _scanCandidates();
  }
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

  @override
  Stream<void> watchTripsChanges() => const Stream<void>.empty();
}

/// Existing trip owned by another diver, recording which diver the post-save
/// scan actually queries. Mirrors the shared-trip case from issue #891.
class _RecordingScanRepo extends _MockTripRepositoryWithTrip {
  String? scannedDiverId;
  int scanCalls = 0;

  @override
  Future<Trip?> getTripById(String id) async => Trip(
    id: 'test-id',
    diverId: 'BAB',
    name: 'Existing Trip',
    startDate: DateTime(2024, 1, 15),
    endDate: DateTime(2024, 1, 22),
    location: 'Test Location',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  @override
  Future<List<DiveCandidate>> findCandidateDivesForTrip({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
    required String diverId,
  }) async {
    scanCalls++;
    scannedDiverId = diverId;
    return [];
  }
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

  @override
  Stream<void> watchTripsChanges() => const Stream<void>.empty();
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

  @override
  Stream<void> watchTripsChanges() => const Stream<void>.empty();
}

/// Mock notifier
class _MockTripListNotifier
    extends StateNotifier<AsyncValue<List<TripWithStats>>>
    implements TripListNotifier {
  _MockTripListNotifier(List<TripWithStats> trips)
    : super(AsyncValue.data(trips));

  int addCalls = 0;
  int updateCalls = 0;
  int assignCalls = 0;
  List<String>? assignedDiveIds;
  String? assignedTripId;
  Set<String>? assignedOldTripIds;

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
  }) async {
    assignCalls++;
    assignedDiveIds = diveIds;
    assignedTripId = tripId;
    assignedOldTripIds = oldTripIds;
  }
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

  @override
  Stream<void> watchTripsChanges() => const Stream<void>.empty();
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

  @override
  Stream<void> watchTripsChanges() => const Stream<void>.empty();
}
