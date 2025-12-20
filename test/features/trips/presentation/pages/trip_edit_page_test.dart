import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/pages/trip_edit_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

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

    testWidgets('should show validation error when name is empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
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
            tripRepositoryProvider.overrideWithValue(_MockTripRepositoryWithTrip()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
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
            tripRepositoryProvider.overrideWithValue(_MockTripRepositoryWithTrip()),
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            home: TripEditPage(tripId: 'test-id'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Existing Trip'), findsOneWidget);
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
  Future<List<TripWithStats>> getAllTripsWithStats({String? diverId}) async => [];

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
  Future<List<TripWithStats>> getAllTripsWithStats({String? diverId}) async => [];

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
}

/// Mock notifier
class _MockTripListNotifier extends StateNotifier<AsyncValue<List<TripWithStats>>>
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
}
