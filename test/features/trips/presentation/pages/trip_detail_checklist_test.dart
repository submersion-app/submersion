import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/pages/trip_detail_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

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

/// Mock settings notifier that returns default AppSettings without
/// SharedPreferences (copied from trip_detail_page_test.dart).
class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mock notifier (copied from trip_detail_page_test.dart).
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

void main() {
  group('TripDetailPage checklist integration', () {
    testWidgets('liveaboard trip shows a Checklist tab', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final liveaboardTrip = Trip(
        id: 'checklist-lb-trip',
        name: 'Checklist Liveaboard',
        startDate: DateTime(2024, 1, 15),
        endDate: DateTime(2024, 1, 22),
        tripType: TripType.liveaboard,
        liveaboardName: 'MV Explorer',
        notes: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final liveaboardStats = TripWithStats(trip: liveaboardTrip, diveCount: 0);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(liveaboardTrip.id).overrideWith((ref) {
              return Future.value(liveaboardStats);
            }),
            diveIdsForTripProvider(liveaboardTrip.id).overrideWith((ref) {
              return Future.value(<String>[]);
            }),
            divesForTripProvider(
              liveaboardTrip.id,
            ).overrideWith((ref) async => <Dive>[]),
            tripChecklistProvider(
              liveaboardTrip.id,
            ).overrideWith((ref) async => <TripChecklistItem>[]),
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

      // The 5th tab is the Checklist tab.
      final checklistTab = find.widgetWithText(Tab, 'Checklist');
      expect(checklistTab, findsOneWidget);

      await tester.tap(checklistTab);
      await tester.pumpAndSettle();

      // TripChecklistSection renders its own "Add item" affordance for an
      // empty checklist.
      expect(find.text('Add item'), findsOneWidget);
    });

    testWidgets('non-liveaboard trip shows the checklist card on overview', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      final trip = Trip(
        id: 'checklist-standard-trip',
        name: 'Shore Trip',
        startDate: DateTime(2024, 1, 15),
        endDate: DateTime(2024, 1, 22),
        location: 'Egypt',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final tripWithStats = TripWithStats(trip: trip, diveCount: 0);
      final items = [
        TripChecklistItem(
          id: 'item-1',
          tripId: trip.id,
          title: 'Service regulator',
          isDone: false,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripWithStatsProvider(trip.id).overrideWith((ref) {
              return Future.value(tripWithStats);
            }),
            diveIdsForTripProvider(trip.id).overrideWith((ref) {
              return Future.value(<String>[]);
            }),
            tripChecklistProvider(trip.id).overrideWith((ref) async => items),
            tripChecklistProgressProvider(
              trip.id,
            ).overrideWith((ref) async => (done: 0, total: items.length)),
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
            home: TripDetailPage(tripId: trip.id),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to find the checklist card header.
      await tester.scrollUntilVisible(
        find.text('Checklist'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Checklist'), findsOneWidget);
      expect(find.text('Service regulator'), findsOneWidget);
    });
  });
}
