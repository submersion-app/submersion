import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/pages/trip_list_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

void main() {
  group('TripListPage', () {
    testWidgets('should display Trips title in app bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            home: TripListPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Trips'), findsOneWidget);
    });

    testWidgets('should display search icon in app bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            home: TripListPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('should display empty state when no trips', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            home: TripListPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('No trips added yet'), findsOneWidget);
      expect(
        find.text('Create trips to group your dives by destination'),
        findsOneWidget,
      );
      expect(find.text('Add Your First Trip'), findsOneWidget);
    });

    testWidgets('should display FAB with Add Trip label', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier([]);
            }),
          ],
          child: const MaterialApp(
            home: TripListPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Add Trip'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsWidgets);
    });

    testWidgets('should display trip list when trips exist', (tester) async {
      final testTrips = [
        TripWithStats(
          trip: Trip(
            id: '1',
            name: 'Red Sea Safari',
            startDate: DateTime(2024, 1, 15),
            endDate: DateTime(2024, 1, 22),
            location: 'Egypt',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          diveCount: 10,
          totalBottomTime: 3600,
        ),
        TripWithStats(
          trip: Trip(
            id: '2',
            name: 'Maldives Adventure',
            startDate: DateTime(2024, 3, 1),
            endDate: DateTime(2024, 3, 10),
            liveaboardName: 'MY Blue Force',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          diveCount: 25,
          totalBottomTime: 7200,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier(testTrips);
            }),
          ],
          child: const MaterialApp(
            home: TripListPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Red Sea Safari'), findsOneWidget);
      expect(find.text('Maldives Adventure'), findsOneWidget);
    });

    testWidgets('should display dive count for trips', (tester) async {
      final testTrips = [
        TripWithStats(
          trip: Trip(
            id: '1',
            name: 'Test Trip',
            startDate: DateTime(2024, 1, 15),
            endDate: DateTime(2024, 1, 22),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          diveCount: 15,
          totalBottomTime: 5400,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier(testTrips);
            }),
          ],
          child: const MaterialApp(
            home: TripListPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('15 dives'), findsOneWidget);
    });

    testWidgets('should show sailing icon for liveaboard trips',
        (tester) async {
      final testTrips = [
        TripWithStats(
          trip: Trip(
            id: '1',
            name: 'Liveaboard Trip',
            startDate: DateTime(2024, 1, 15),
            endDate: DateTime(2024, 1, 22),
            liveaboardName: 'MY Explorer',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          diveCount: 20,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripListNotifierProvider.overrideWith((ref) {
              return _MockTripListNotifier(testTrips);
            }),
          ],
          child: const MaterialApp(
            home: TripListPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.sailing), findsOneWidget);
    });

    testWidgets('should show loading indicator while loading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripListNotifierProvider.overrideWith((ref) {
              return _LoadingTripListNotifier();
            }),
          ],
          child: const MaterialApp(
            home: TripListPage(),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}

/// Mock notifier that returns data immediately
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
}

/// Mock notifier that stays in loading state
class _LoadingTripListNotifier
    extends StateNotifier<AsyncValue<List<TripWithStats>>>
    implements TripListNotifier {
  _LoadingTripListNotifier() : super(const AsyncValue.loading());

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
