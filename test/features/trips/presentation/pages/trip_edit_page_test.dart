import 'package:flutter/material.dart';
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
  Future<TripWithStats> getTripWithStats(String tripId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getDiveIdsForTrip(String tripId) async => [];

  @override
  Future<void> assignDiveToTrip(String diveId, String tripId) async {}

  @override
  Future<void> removeDiveFromTrip(String diveId) async {}

  @override
  Future<Trip?> findTripForDate(DateTime date, {String? diverId}) async => null;

  @override
  Future<int> getDiveCountForTrip(String tripId) async => 0;

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
  Future<TripWithStats> getTripWithStats(String tripId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getDiveIdsForTrip(String tripId) async => [];

  @override
  Future<void> assignDiveToTrip(String diveId, String tripId) async {}

  @override
  Future<void> removeDiveFromTrip(String diveId) async {}

  @override
  Future<Trip?> findTripForDate(DateTime date, {String? diverId}) async => null;

  @override
  Future<int> getDiveCountForTrip(String tripId) async => 0;

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
  Future<TripWithStats> getTripWithStats(String tripId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getDiveIdsForTrip(String tripId) async => [];

  @override
  Future<void> assignDiveToTrip(String diveId, String tripId) async {}

  @override
  Future<void> removeDiveFromTrip(String diveId) async {}

  @override
  Future<Trip?> findTripForDate(DateTime date, {String? diverId}) async => null;

  @override
  Future<int> getDiveCountForTrip(String tripId) async => 0;

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
