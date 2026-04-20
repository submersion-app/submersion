import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/pages/trip_detail_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void _setMobileTestSurfaceSize(WidgetTester tester) {
  // The default widget test surface width is 800px, which trips the app's
  // desktop breakpoint (>= 800). These tests exercise the mobile layout.
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  group('TripDetailPage', () {
    final testTrip = Trip(
      id: 'test-id',
      name: 'Red Sea Safari',
      startDate: DateTime(2024, 1, 15),
      endDate: DateTime(2024, 1, 22),
      location: 'Egypt',
      resortName: 'Marsa Shagra',
      notes: 'Amazing trip with great visibility',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final testTripWithStats = TripWithStats(
      trip: testTrip,
      diveCount: 15,
      totalBottomTime: 5400,
      maxDepth: 32.5,
      avgDepth: 18.3,
    );

    testWidgets('should display trip name in app bar', (tester) async {
      _setMobileTestSurfaceSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(testTrip.id).overrideWith((ref) {
              return Future.value(testTripWithStats);
            }),
            diveIdsForTripProvider(testTrip.id).overrideWith((ref) {
              return Future.value(<String>[]);
            }),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
            settingsProvider.overrideWith((ref) {
              return _MockSettingsNotifier();
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailPage(tripId: testTrip.id),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Red Sea Safari'), findsWidgets);
    });

    testWidgets('should display trip dates', (tester) async {
      _setMobileTestSurfaceSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(testTrip.id).overrideWith((ref) {
              return Future.value(testTripWithStats);
            }),
            diveIdsForTripProvider(testTrip.id).overrideWith((ref) {
              return Future.value(<String>[]);
            }),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
            settingsProvider.overrideWith((ref) {
              return _MockSettingsNotifier();
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailPage(tripId: testTrip.id),
          ),
        ),
      );

      await tester.pumpAndSettle();
      // Check for duration
      expect(find.text('8 days'), findsOneWidget);
    });

    testWidgets('should display Trip Statistics section', (tester) async {
      _setMobileTestSurfaceSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(testTrip.id).overrideWith((ref) {
              return Future.value(testTripWithStats);
            }),
            diveIdsForTripProvider(testTrip.id).overrideWith((ref) {
              return Future.value(<String>[]);
            }),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
            settingsProvider.overrideWith((ref) {
              return _MockSettingsNotifier();
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailPage(tripId: testTrip.id),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Trip Statistics'), findsOneWidget);
    });

    testWidgets('should display dive count in statistics', (tester) async {
      _setMobileTestSurfaceSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(testTrip.id).overrideWith((ref) {
              return Future.value(testTripWithStats);
            }),
            diveIdsForTripProvider(testTrip.id).overrideWith((ref) {
              return Future.value(<String>[]);
            }),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
            settingsProvider.overrideWith((ref) {
              return _MockSettingsNotifier();
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailPage(tripId: testTrip.id),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Total Dives'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('should display total bottom time', (tester) async {
      _setMobileTestSurfaceSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(testTrip.id).overrideWith((ref) {
              return Future.value(testTripWithStats);
            }),
            diveIdsForTripProvider(testTrip.id).overrideWith((ref) {
              return Future.value(<String>[]);
            }),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
            settingsProvider.overrideWith((ref) {
              return _MockSettingsNotifier();
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailPage(tripId: testTrip.id),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Total Bottom Time'), findsOneWidget);
      expect(find.text('1h 30m'), findsOneWidget);
    });

    testWidgets('should display max depth', (tester) async {
      _setMobileTestSurfaceSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(testTrip.id).overrideWith((ref) {
              return Future.value(testTripWithStats);
            }),
            diveIdsForTripProvider(testTrip.id).overrideWith((ref) {
              return Future.value(<String>[]);
            }),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
            settingsProvider.overrideWith((ref) {
              return _MockSettingsNotifier();
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailPage(tripId: testTrip.id),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Max Depth'), findsOneWidget);
      expect(find.text('32.5m'), findsOneWidget);
    });

    testWidgets('should display Trip Details section with location', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(testTrip.id).overrideWith((ref) {
              return Future.value(testTripWithStats);
            }),
            diveIdsForTripProvider(testTrip.id).overrideWith((ref) {
              return Future.value(<String>[]);
            }),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
            settingsProvider.overrideWith((ref) {
              return _MockSettingsNotifier();
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailPage(tripId: testTrip.id),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Trip Details'), findsOneWidget);
      expect(find.text('Egypt'), findsOneWidget);
    });

    testWidgets('should display resort name', (tester) async {
      _setMobileTestSurfaceSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(testTrip.id).overrideWith((ref) {
              return Future.value(testTripWithStats);
            }),
            diveIdsForTripProvider(testTrip.id).overrideWith((ref) {
              return Future.value(<String>[]);
            }),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
            settingsProvider.overrideWith((ref) {
              return _MockSettingsNotifier();
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailPage(tripId: testTrip.id),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Resort'), findsOneWidget);
      expect(find.text('Marsa Shagra'), findsOneWidget);
    });

    testWidgets('should display Notes section', (tester) async {
      _setMobileTestSurfaceSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(testTrip.id).overrideWith((ref) {
              return Future.value(testTripWithStats);
            }),
            diveIdsForTripProvider(testTrip.id).overrideWith((ref) {
              return Future.value(<String>[]);
            }),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
            settingsProvider.overrideWith((ref) {
              return _MockSettingsNotifier();
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailPage(tripId: testTrip.id),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to find Notes section
      await tester.scrollUntilVisible(
        find.text('Amazing trip with great visibility'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Amazing trip with great visibility'), findsOneWidget);
    });

    testWidgets('should display Dives section', (tester) async {
      _setMobileTestSurfaceSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(testTrip.id).overrideWith((ref) {
              return Future.value(testTripWithStats);
            }),
            diveIdsForTripProvider(testTrip.id).overrideWith((ref) {
              return Future.value(<String>[]);
            }),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
            settingsProvider.overrideWith((ref) {
              return _MockSettingsNotifier();
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailPage(tripId: testTrip.id),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to find Dives section
      await tester.scrollUntilVisible(
        find.text('Dives'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Dives'), findsOneWidget);
    });

    testWidgets('should show empty dives message when no dives', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(testTrip.id).overrideWith((ref) {
              return Future.value(testTripWithStats);
            }),
            divesForTripProvider(testTrip.id).overrideWith((ref) {
              return Future.value([]);
            }),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
            settingsProvider.overrideWith((ref) {
              return _MockSettingsNotifier();
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailPage(tripId: testTrip.id),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to find empty message
      await tester.scrollUntilVisible(
        find.text('No dives in this trip yet'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('No dives in this trip yet'), findsOneWidget);
    });

    testWidgets('should display edit icon button', (tester) async {
      _setMobileTestSurfaceSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(testTrip.id).overrideWith((ref) {
              return Future.value(testTripWithStats);
            }),
            diveIdsForTripProvider(testTrip.id).overrideWith((ref) {
              return Future.value(<String>[]);
            }),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
            settingsProvider.overrideWith((ref) {
              return _MockSettingsNotifier();
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailPage(tripId: testTrip.id),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('should display popup menu with export and delete', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(testTrip.id).overrideWith((ref) {
              return Future.value(testTripWithStats);
            }),
            diveIdsForTripProvider(testTrip.id).overrideWith((ref) {
              return Future.value(<String>[]);
            }),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
            settingsProvider.overrideWith((ref) {
              return _MockSettingsNotifier();
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailPage(tripId: testTrip.id),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the popup menu button
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('should display flight takeoff icon for regular trip', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(testTrip.id).overrideWith((ref) {
              return Future.value(testTripWithStats);
            }),
            diveIdsForTripProvider(testTrip.id).overrideWith((ref) {
              return Future.value(<String>[]);
            }),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
            settingsProvider.overrideWith((ref) {
              return _MockSettingsNotifier();
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailPage(tripId: testTrip.id),
          ),
        ),
      );

      await tester.pumpAndSettle();
      // Regular trips show flight_takeoff icon
      expect(find.byIcon(Icons.flight_takeoff), findsOneWidget);
    });

    testWidgets('should display sailing icon for liveaboard trip', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      final liveaboardTrip = Trip(
        id: 'liveaboard-id',
        name: 'Maldives Safari',
        startDate: DateTime(2024, 3, 1),
        endDate: DateTime(2024, 3, 10),
        liveaboardName: 'MY Blue Force',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final liveaboardTripWithStats = TripWithStats(
        trip: liveaboardTrip,
        diveCount: 25,
        totalBottomTime: 9000,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(liveaboardTrip.id).overrideWith((ref) {
              return Future.value(liveaboardTripWithStats);
            }),
            diveIdsForTripProvider(liveaboardTrip.id).overrideWith((ref) {
              return Future.value(<String>[]);
            }),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
            settingsProvider.overrideWith((ref) {
              return _MockSettingsNotifier();
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailPage(tripId: liveaboardTrip.id),
          ),
        ),
      );

      await tester.pumpAndSettle();
      // Sailing icon appears in header and in Trip Details section for liveaboard
      expect(find.byIcon(Icons.sailing), findsWidgets);
    });

    testWidgets('liveaboard dives tab shows bottomTime', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final liveaboardTrip = Trip(
        id: 'liveaboard-trip',
        name: 'Liveaboard',
        startDate: DateTime(2024, 1, 15),
        endDate: DateTime(2024, 1, 22),
        tripType: TripType.liveaboard,
        liveaboardName: 'MV Explorer',
        notes: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final liveaboardStats = TripWithStats(
        trip: liveaboardTrip,
        diveCount: 1,
        totalBottomTime: 2700,
        maxDepth: 25.0,
      );
      final dives = [
        Dive(
          id: 'lb-dive-1',
          diveNumber: 1,
          dateTime: DateTime(2024, 1, 16, 9, 0),
          bottomTime: const Duration(minutes: 45),
          maxDepth: 25.0,
          tanks: const [],
          profile: const [],
          equipment: const [],
          notes: '',
          photoIds: const [],
          sightings: const [],
          weights: const [],
          tags: const [],
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(liveaboardTrip.id).overrideWith((ref) {
              return Future.value(liveaboardStats);
            }),
            diveIdsForTripProvider(liveaboardTrip.id).overrideWith((ref) {
              return Future.value(['lb-dive-1']);
            }),
            divesForTripProvider(liveaboardTrip.id).overrideWith((ref) {
              return Future.value(dives);
            }),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
            settingsProvider.overrideWith((ref) {
              return _MockSettingsNotifier();
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailPage(tripId: liveaboardTrip.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Dives tab in the liveaboard tabbed layout
      final divesTab = find.text('Dives');
      if (divesTab.evaluate().isNotEmpty) {
        await tester.tap(divesTab.first);
        await tester.pumpAndSettle();
      }

      // Should show 45min in the dives list
      expect(find.text('45min'), findsWidgets);
    });

    testWidgets('should display dive bottomTime in dives section', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      final divesWithBottomTime = [
        Dive(
          id: 'dive-trip-1',
          diveNumber: 1,
          dateTime: DateTime(2024, 1, 16, 9, 0),
          bottomTime: const Duration(minutes: 45),
          maxDepth: 25.0,
          tanks: const [],
          profile: const [],
          equipment: const [],
          notes: '',
          photoIds: const [],
          sightings: const [],
          weights: const [],
          tags: const [],
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(testTrip.id).overrideWith((ref) {
              return Future.value(testTripWithStats);
            }),
            diveIdsForTripProvider(testTrip.id).overrideWith((ref) {
              return Future.value(['dive-trip-1']);
            }),
            divesForTripProvider(testTrip.id).overrideWith((ref) {
              return Future.value(divesWithBottomTime);
            }),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
            settingsProvider.overrideWith((ref) {
              return _MockSettingsNotifier();
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailPage(tripId: testTrip.id),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll down to make the dives section visible
      await tester.scrollUntilVisible(
        find.text('45min'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Should show bottomTime formatted as minutes
      expect(find.text('45min'), findsOneWidget);
    });
  });

  group('delete confirmation on shared trip', () {
    testWidgets(
      'shows strengthened dialog when deleting a shared trip with 2+ divers',
      (tester) async {
        _setMobileTestSurfaceSize(tester);

        final sharedTrip = Trip(
          id: 'shared-trip',
          name: 'Salt Pier Getaway',
          startDate: DateTime(2024, 1, 15),
          endDate: DateTime(2024, 1, 22),
          isShared: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final sharedTripWithStats = TripWithStats(
          trip: sharedTrip,
          diveCount: 3,
          totalBottomTime: 3600,
        );
        final twoDivers = [
          Diver(
            id: 'd1',
            name: 'Alice',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
          Diver(
            id: 'd2',
            name: 'Bob',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tripWithStatsProvider(sharedTrip.id).overrideWith((ref) {
                return Future.value(sharedTripWithStats);
              }),
              diveIdsForTripProvider(sharedTrip.id).overrideWith((ref) {
                return Future.value(<String>[]);
              }),
              tripListNotifierProvider.overrideWith((ref) {
                return _MockTripListNotifier([]);
              }),
              settingsProvider.overrideWith((ref) {
                return _MockSettingsNotifier();
              }),
              allDiversProvider.overrideWith((_) async => twoDivers),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: TripDetailPage(tripId: sharedTrip.id),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Open the more menu and tap Delete.
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // The strengthened shared-trip dialog title should appear.
        expect(find.text('Delete shared trip?'), findsOneWidget);
      },
    );
  });

  group('TripDetailPage loading/error states', () {
    final loadingTrip = Trip(
      id: 'loading-trip',
      name: 'Loading Trip',
      startDate: DateTime(2024, 1, 15),
      endDate: DateTime(2024, 1, 22),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    testWidgets('shows full scaffold loading indicator when not embedded', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(loadingTrip.id).overrideWith((ref) {
              // Return a future that never completes to keep loading state.
              return Future<TripWithStats>.delayed(
                const Duration(seconds: 10),
                () => TripWithStats(trip: loadingTrip),
              );
            }),
            tripListNotifierProvider.overrideWith(
              (ref) => _MockTripListNotifier([]),
            ),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailPage(tripId: loadingTrip.id),
          ),
        ),
      );
      // pump once (no settle) - loading state should render.
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Trip'), findsWidgets);
      // Force settle by ending microtasks.
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('shows embedded loading indicator when embedded', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(loadingTrip.id).overrideWith((ref) {
              return Future<TripWithStats>.delayed(
                const Duration(seconds: 10),
                () => TripWithStats(trip: loadingTrip),
              );
            }),
            tripListNotifierProvider.overrideWith(
              (ref) => _MockTripListNotifier([]),
            ),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TripDetailPage(tripId: loadingTrip.id, embedded: true),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('shows non-embedded error scaffold on error', (tester) async {
      _setMobileTestSurfaceSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(loadingTrip.id).overrideWith((ref) {
              return Future<TripWithStats>.error(
                Exception('boom'),
                StackTrace.current,
              );
            }),
            tripListNotifierProvider.overrideWith(
              (ref) => _MockTripListNotifier([]),
            ),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailPage(tripId: loadingTrip.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Error'), findsWidgets);
      expect(find.textContaining('boom'), findsOneWidget);
    });

    testWidgets('shows embedded error text on error when embedded', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(loadingTrip.id).overrideWith((ref) {
              return Future<TripWithStats>.error(
                Exception('embedded-boom'),
                StackTrace.current,
              );
            }),
            tripListNotifierProvider.overrideWith(
              (ref) => _MockTripListNotifier([]),
            ),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TripDetailPage(tripId: loadingTrip.id, embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('embedded-boom'), findsOneWidget);
    });
  });

  group('TripDetailPage embedded layouts', () {
    final embeddedTrip = Trip(
      id: 'embedded-trip',
      name: 'Embedded Trip',
      startDate: DateTime(2024, 5, 1),
      endDate: DateTime(2024, 5, 5),
      location: 'Somewhere',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final embeddedStats = TripWithStats(
      trip: embeddedTrip,
      diveCount: 3,
      totalBottomTime: 1800,
      maxDepth: 18.0,
    );

    testWidgets('renders embedded header for standard trip', (tester) async {
      _setMobileTestSurfaceSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(
              embeddedTrip.id,
            ).overrideWith((ref) async => embeddedStats),
            diveIdsForTripProvider(
              embeddedTrip.id,
            ).overrideWith((ref) async => <String>[]),
            tripListNotifierProvider.overrideWith(
              (ref) => _MockTripListNotifier([]),
            ),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TripDetailPage(tripId: embeddedTrip.id, embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Embedded header shows the trip name and date range.
      expect(find.text('Embedded Trip'), findsWidgets);
      // Flight takeoff icon appears in embedded header avatar
      // (may also appear elsewhere in the overview tab).
      expect(find.byIcon(Icons.flight_takeoff), findsWidgets);
      // Compact map/edit/more-options icons should be present in embedded
      // header (along with potentially more on other sections).
      expect(find.byIcon(Icons.map_outlined), findsWidgets);
      expect(find.byIcon(Icons.edit_outlined), findsWidgets);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('renders embedded header for liveaboard trip', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final liveaboardTrip = Trip(
        id: 'embedded-lb',
        name: 'LB Trip',
        startDate: DateTime(2024, 6, 1),
        endDate: DateTime(2024, 6, 7),
        tripType: TripType.liveaboard,
        liveaboardName: 'MV Test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final stats = TripWithStats(trip: liveaboardTrip, diveCount: 0);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(
              liveaboardTrip.id,
            ).overrideWith((ref) async => stats),
            diveIdsForTripProvider(
              liveaboardTrip.id,
            ).overrideWith((ref) async => <String>[]),
            divesForTripProvider(
              liveaboardTrip.id,
            ).overrideWith((ref) async => []),
            tripListNotifierProvider.overrideWith(
              (ref) => _MockTripListNotifier([]),
            ),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TripDetailPage(tripId: liveaboardTrip.id, embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Embedded liveaboard header has sailing icon on the left avatar.
      expect(find.byIcon(Icons.sailing), findsWidgets);
      // Tabbed layout should be visible.
      expect(find.text('Overview'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Dives'), findsOneWidget);
      // Switch to Dives tab and verify the empty message renders.
      await tester.tap(find.widgetWithText(Tab, 'Dives'));
      await tester.pumpAndSettle();
      expect(find.text('No dives in this trip yet'), findsOneWidget);
    });

    testWidgets('embedded map button triggers dive filter and navigation', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      final routerSpy = GoRouter(
        initialLocation: '/embedded',
        routes: [
          GoRoute(
            path: '/embedded',
            builder: (context, state) => Scaffold(
              body: TripDetailPage(tripId: embeddedTrip.id, embedded: true),
            ),
          ),
          GoRoute(
            path: '/dives',
            builder: (context, state) =>
                Scaffold(body: Text('DIVES_${state.uri.query}')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(
              embeddedTrip.id,
            ).overrideWith((ref) async => embeddedStats),
            diveIdsForTripProvider(
              embeddedTrip.id,
            ).overrideWith((ref) async => <String>[]),
            tripListNotifierProvider.overrideWith(
              (ref) => _MockTripListNotifier([]),
            ),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: routerSpy,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.map_outlined));
      await tester.pumpAndSettle();
      expect(find.textContaining('DIVES_view=map'), findsOneWidget);
    });

    testWidgets('embedded edit button navigates to edit mode', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final router = GoRouter(
        initialLocation: '/embedded/slot',
        routes: [
          GoRoute(
            path: '/embedded/slot',
            builder: (context, state) => Scaffold(
              body: TripDetailPage(tripId: embeddedTrip.id, embedded: true),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(
              embeddedTrip.id,
            ).overrideWith((ref) async => embeddedStats),
            diveIdsForTripProvider(
              embeddedTrip.id,
            ).overrideWith((ref) async => <String>[]),
            tripListNotifierProvider.overrideWith(
              (ref) => _MockTripListNotifier([]),
            ),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      // Router location should now contain selected=...&mode=edit.
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        contains('mode=edit'),
      );
    });

    testWidgets('delete action on embedded trip calls onDeleted callback', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      bool onDeletedCalled = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(
              embeddedTrip.id,
            ).overrideWith((ref) async => embeddedStats),
            diveIdsForTripProvider(
              embeddedTrip.id,
            ).overrideWith((ref) async => <String>[]),
            tripListNotifierProvider.overrideWith(
              (ref) => _MockTripListNotifier([]),
            ),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            allDiversProvider.overrideWith((_) async => <Diver>[]),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TripDetailPage(
                tripId: embeddedTrip.id,
                embedded: true,
                onDeleted: () => onDeletedCalled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      // Confirm deletion via FilledButton.
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(onDeletedCalled, isTrue);
      expect(find.text('Trip deleted'), findsOneWidget);
    });
  });

  group('TripDetailPage app bar map button', () {
    final mapTrip = Trip(
      id: 'map-trip',
      name: 'Map Trip',
      startDate: DateTime(2024, 5, 1),
      endDate: DateTime(2024, 5, 5),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final mapStats = TripWithStats(trip: mapTrip, diveCount: 2);

    testWidgets('app bar map button navigates to /dives with view=map', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      final router = GoRouter(
        initialLocation: '/trips/map-trip',
        routes: [
          GoRoute(
            path: '/trips/:id',
            builder: (context, state) =>
                TripDetailPage(tripId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/dives',
            builder: (context, state) =>
                Scaffold(body: Text('DIVES_${state.uri.query}')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(
              mapTrip.id,
            ).overrideWith((ref) async => mapStats),
            diveIdsForTripProvider(
              mapTrip.id,
            ).overrideWith((ref) async => <String>[]),
            tripListNotifierProvider.overrideWith(
              (ref) => _MockTripListNotifier([]),
            ),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.map_outlined));
      await tester.pumpAndSettle();
      expect(find.textContaining('DIVES_view=map'), findsOneWidget);
    });

    testWidgets('app bar edit button pushes to edit route', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final router = GoRouter(
        initialLocation: '/trips/map-trip',
        routes: [
          GoRoute(
            path: '/trips/:id',
            builder: (context, state) =>
                TripDetailPage(tripId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) =>
                    const Scaffold(body: Text('EDIT_PAGE')),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(
              mapTrip.id,
            ).overrideWith((ref) async => mapStats),
            diveIdsForTripProvider(
              mapTrip.id,
            ).overrideWith((ref) async => <String>[]),
            tripListNotifierProvider.overrideWith(
              (ref) => _MockTripListNotifier([]),
            ),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      expect(find.text('EDIT_PAGE'), findsOneWidget);
    });
  });

  group('TripDetailPage export sheet', () {
    final exportTrip = Trip(
      id: 'export-trip',
      name: 'Export Trip',
      startDate: DateTime(2024, 5, 1),
      endDate: DateTime(2024, 5, 5),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final exportStats = TripWithStats(trip: exportTrip, diveCount: 0);

    Future<void> pumpExportPage(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(
              exportTrip.id,
            ).overrideWith((ref) async => exportStats),
            diveIdsForTripProvider(
              exportTrip.id,
            ).overrideWith((ref) async => <String>[]),
            tripListNotifierProvider.overrideWith(
              (ref) => _MockTripListNotifier([]),
            ),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailPage(tripId: exportTrip.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('tapping CSV export shows coming-soon snackbar', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      await pumpExportPage(tester);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      expect(find.text('Export to CSV'), findsOneWidget);
      expect(find.text('Export to PDF'), findsOneWidget);
      await tester.tap(find.text('Export to CSV'));
      await tester.pumpAndSettle();
      expect(find.text('CSV export coming soon'), findsOneWidget);
    });

    testWidgets('tapping PDF export shows coming-soon snackbar', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      await pumpExportPage(tester);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export to PDF'));
      await tester.pumpAndSettle();
      expect(find.text('PDF export coming soon'), findsOneWidget);
    });
  });

  group('TripDetailPage dives section edge cases', () {
    testWidgets('liveaboard dives tab shows empty message', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final lbTrip = Trip(
        id: 'empty-lb',
        name: 'Empty LB',
        startDate: DateTime(2024, 5, 1),
        endDate: DateTime(2024, 5, 7),
        tripType: TripType.liveaboard,
        liveaboardName: 'MV Empty',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final stats = TripWithStats(trip: lbTrip, diveCount: 0);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(lbTrip.id).overrideWith((ref) async => stats),
            diveIdsForTripProvider(
              lbTrip.id,
            ).overrideWith((ref) async => <String>[]),
            divesForTripProvider(lbTrip.id).overrideWith((ref) async => []),
            tripListNotifierProvider.overrideWith(
              (ref) => _MockTripListNotifier([]),
            ),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailPage(tripId: lbTrip.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Dives'));
      await tester.pumpAndSettle();
      expect(find.text('No dives in this trip yet'), findsOneWidget);
    });

    testWidgets('liveaboard dives tab shows dive with unknown site', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      final lbTrip = Trip(
        id: 'unknown-site-lb',
        name: 'Unknown Site LB',
        startDate: DateTime(2024, 5, 1),
        endDate: DateTime(2024, 5, 7),
        tripType: TripType.liveaboard,
        liveaboardName: 'MV Unknown',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final stats = TripWithStats(trip: lbTrip, diveCount: 1);
      final dive = Dive(
        id: 'unknown-dive',
        diveNumber: 42,
        dateTime: DateTime(2024, 5, 2, 10),
        bottomTime: const Duration(minutes: 30),
        maxDepth: 20.0,
        tanks: const [],
        profile: const [],
        equipment: const [],
        notes: '',
        photoIds: const [],
        sightings: const [],
        weights: const [],
        tags: const [],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(lbTrip.id).overrideWith((ref) async => stats),
            diveIdsForTripProvider(
              lbTrip.id,
            ).overrideWith((ref) async => <String>['unknown-dive']),
            divesForTripProvider(lbTrip.id).overrideWith((ref) async => [dive]),
            tripListNotifierProvider.overrideWith(
              (ref) => _MockTripListNotifier([]),
            ),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailPage(tripId: lbTrip.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Dives'));
      await tester.pumpAndSettle();
      expect(find.text('Unknown Site'), findsWidgets);
      // Dive number badge.
      expect(find.text('#42'), findsOneWidget);
    });

    testWidgets('liveaboard dives tab shows error state', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final lbTrip = Trip(
        id: 'err-lb',
        name: 'Err LB',
        startDate: DateTime(2024, 5, 1),
        endDate: DateTime(2024, 5, 7),
        tripType: TripType.liveaboard,
        liveaboardName: 'MV Err',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final stats = TripWithStats(trip: lbTrip, diveCount: 1);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(lbTrip.id).overrideWith((ref) async => stats),
            diveIdsForTripProvider(
              lbTrip.id,
            ).overrideWith((ref) async => <String>['x']),
            divesForTripProvider(
              lbTrip.id,
            ).overrideWith((ref) => Future.error(Exception('dives-err'))),
            tripListNotifierProvider.overrideWith(
              (ref) => _MockTripListNotifier([]),
            ),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripDetailPage(tripId: lbTrip.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Dives'));
      await tester.pumpAndSettle();
      expect(find.text('Unable to load dives'), findsOneWidget);
    });
  });

  group('TripDetailPage desktop redirect', () {
    final redirectTrip = Trip(
      id: 'redirect-trip',
      name: 'Redirect Test Trip',
      startDate: DateTime(2024, 1, 15),
      endDate: DateTime(2024, 1, 22),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final redirectTripWithStats = TripWithStats(
      trip: redirectTrip,
      diveCount: 0,
    );

    testWidgets(
      'redirects to master-detail on desktop when not in table mode',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1200, 800);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final overrides = await getBaseOverrides();

        final router = GoRouter(
          initialLocation: '/trips/redirect-trip',
          routes: [
            GoRoute(
              path: '/trips',
              builder: (context, state) =>
                  const Scaffold(body: Text('TRIP_LIST_PAGE')),
            ),
            GoRoute(
              path: '/trips/:id',
              builder: (context, state) =>
                  TripDetailPage(tripId: state.pathParameters['id']!),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...overrides,
              tripListViewModeProvider.overrideWith(
                (ref) => ListViewMode.detailed,
              ),
              tripWithStatsProvider(
                redirectTrip.id,
              ).overrideWith((ref) async => redirectTripWithStats),
              diveIdsForTripProvider(
                redirectTrip.id,
              ).overrideWith((ref) async => <String>[]),
              tripListNotifierProvider.overrideWith(
                (ref) => _MockTripListNotifier([]),
              ),
            ].cast(),
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('TRIP_LIST_PAGE'), findsOneWidget);
      },
    );

    testWidgets('does not redirect on desktop in table mode', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await getBaseOverrides();

      final router = GoRouter(
        initialLocation: '/trips/redirect-trip',
        routes: [
          GoRoute(
            path: '/trips',
            builder: (context, state) =>
                const Scaffold(body: Text('TRIP_LIST_PAGE')),
          ),
          GoRoute(
            path: '/trips/:id',
            builder: (context, state) =>
                TripDetailPage(tripId: state.pathParameters['id']!),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            tripListViewModeProvider.overrideWith((ref) => ListViewMode.table),
            tripWithStatsProvider(
              redirectTrip.id,
            ).overrideWith((ref) async => redirectTripWithStats),
            diveIdsForTripProvider(
              redirectTrip.id,
            ).overrideWith((ref) async => <String>[]),
            tripListNotifierProvider.overrideWith(
              (ref) => _MockTripListNotifier([]),
            ),
          ].cast(),
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('TRIP_LIST_PAGE'), findsNothing);
    });
  });
}

/// Mock settings notifier that returns default AppSettings without SharedPreferences.
class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mock notifier
class _MockTripListNotifier
    extends StateNotifier<AsyncValue<List<TripWithStats>>>
    implements TripListNotifier {
  _MockTripListNotifier(List<TripWithStats> trips)
    : super(AsyncValue.data(trips));

  @override
  Future<void> refresh() async {}

  @override
  Future<Trip> addTrip(Trip trip) async => trip;

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
