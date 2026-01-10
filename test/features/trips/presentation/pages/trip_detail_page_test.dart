import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/pages/trip_detail_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

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
          ],
          child: MaterialApp(home: TripDetailPage(tripId: testTrip.id)),
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
          ],
          child: MaterialApp(home: TripDetailPage(tripId: testTrip.id)),
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
          ],
          child: MaterialApp(home: TripDetailPage(tripId: testTrip.id)),
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
          ],
          child: MaterialApp(home: TripDetailPage(tripId: testTrip.id)),
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
          ],
          child: MaterialApp(home: TripDetailPage(tripId: testTrip.id)),
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
          ],
          child: MaterialApp(home: TripDetailPage(tripId: testTrip.id)),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Max Depth'), findsOneWidget);
      expect(find.text('32.5 m'), findsOneWidget);
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
          ],
          child: MaterialApp(home: TripDetailPage(tripId: testTrip.id)),
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
          ],
          child: MaterialApp(home: TripDetailPage(tripId: testTrip.id)),
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
          ],
          child: MaterialApp(home: TripDetailPage(tripId: testTrip.id)),
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
          ],
          child: MaterialApp(home: TripDetailPage(tripId: testTrip.id)),
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
          ],
          child: MaterialApp(home: TripDetailPage(tripId: testTrip.id)),
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
          ],
          child: MaterialApp(home: TripDetailPage(tripId: testTrip.id)),
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
          ],
          child: MaterialApp(home: TripDetailPage(tripId: testTrip.id)),
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
          ],
          child: MaterialApp(home: TripDetailPage(tripId: testTrip.id)),
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
          ],
          child: MaterialApp(home: TripDetailPage(tripId: liveaboardTrip.id)),
        ),
      );

      await tester.pumpAndSettle();
      // Sailing icon appears in header and in Trip Details section for liveaboard
      expect(find.byIcon(Icons.sailing), findsWidgets);
    });
  });
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
}
