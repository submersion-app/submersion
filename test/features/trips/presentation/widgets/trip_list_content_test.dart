import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/constants/trip_field.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_list_content.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _TestTripTableConfigNotifier
    extends EntityTableConfigNotifier<TripField> {
  _TestTripTableConfigNotifier(EntityTableViewConfig<TripField> config)
    : super(
        defaultConfig: config,
        fieldFromName: TripFieldAdapter.instance.fieldFromName,
      );
}

class _MockTripListNotifier
    extends StateNotifier<AsyncValue<List<TripWithStats>>>
    implements TripListNotifier {
  _MockTripListNotifier(List<TripWithStats> trips)
    : super(AsyncValue.data(trips));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _testConfig = EntityTableViewConfig<TripField>(
  columns: [
    EntityTableColumnConfig(field: TripField.tripName, isPinned: true),
    EntityTableColumnConfig(field: TripField.startDate),
    EntityTableColumnConfig(field: TripField.endDate),
    EntityTableColumnConfig(field: TripField.location),
    EntityTableColumnConfig(field: TripField.diveCount),
    EntityTableColumnConfig(field: TripField.maxDepth),
  ],
);

final _now = DateTime.now();

TripWithStats _makeTrip({
  required String id,
  required String name,
  DateTime? startDate,
  DateTime? endDate,
  String? location,
  int diveCount = 0,
  double? maxDepth,
}) {
  return TripWithStats(
    trip: Trip(
      id: id,
      name: name,
      startDate: startDate ?? DateTime(2024, 6, 1),
      endDate: endDate ?? DateTime(2024, 6, 7),
      location: location,
      createdAt: _now,
      updatedAt: _now,
    ),
    diveCount: diveCount,
    maxDepth: maxDepth,
  );
}

Future<List<Override>> _buildOverrides({
  required List<TripWithStats> trips,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    tripListNotifierProvider.overrideWith(
      (ref) => _MockTripListNotifier(trips),
    ),
    tripListViewModeProvider.overrideWith((ref) => ListViewMode.table),
    tripTableConfigProvider.overrideWith(
      (ref) => _TestTripTableConfigNotifier(_testConfig),
    ),
    // Override the sortedFilteredTrips provider so it returns our data
    // directly instead of going through the filter chain.
    sortedFilteredTripsProvider.overrideWith((ref) => AsyncValue.data(trips)),
  ];
}

void main() {
  group('TripListContent in table mode', () {
    testWidgets('renders table with column headers', (tester) async {
      final trips = [
        _makeTrip(
          id: 't1',
          name: 'Maldives Trip',
          startDate: DateTime(2024, 6, 1),
          endDate: DateTime(2024, 6, 7),
          location: 'Maldives',
          diveCount: 12,
          maxDepth: 30.0,
        ),
        _makeTrip(
          id: 't2',
          name: 'Red Sea Safari',
          startDate: DateTime(2024, 8, 10),
          endDate: DateTime(2024, 8, 17),
          location: 'Egypt',
          diveCount: 18,
          maxDepth: 35.0,
        ),
      ];

      final overrides = await _buildOverrides(trips: trips);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Verify column headers from shortLabel values
      expect(find.text('Name'), findsWidgets);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('End'), findsOneWidget);
    });

    testWidgets('renders rows for each trip', (tester) async {
      final trips = [
        _makeTrip(id: 't1', name: 'Maldives Trip'),
        _makeTrip(id: 't2', name: 'Red Sea Safari'),
        _makeTrip(id: 't3', name: 'Indonesia Live'),
      ];

      final overrides = await _buildOverrides(trips: trips);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Maldives Trip'), findsOneWidget);
      expect(find.text('Red Sea Safari'), findsOneWidget);
      expect(find.text('Indonesia Live'), findsOneWidget);
    });

    testWidgets('shows empty state when no trips', (tester) async {
      final overrides = await _buildOverrides(trips: []);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.flight_takeoff), findsOneWidget);
    });

    testWidgets('table app bar includes column settings button', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        trips: [_makeTrip(id: 't1', name: 'Test Trip')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.view_column_outlined), findsOneWidget);
    });

    testWidgets('renders with showAppBar false (compact bar)', (tester) async {
      final overrides = await _buildOverrides(
        trips: [_makeTrip(id: 't1', name: 'Bali Dive Trip')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.text('Bali Dive Trip'), findsOneWidget);
    });

    testWidgets('table app bar has search button', (tester) async {
      final overrides = await _buildOverrides(
        trips: [_makeTrip(id: 't1', name: 'Test Trip')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('table app bar has sort button', (tester) async {
      final overrides = await _buildOverrides(
        trips: [_makeTrip(id: 't1', name: 'Test Trip')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.sort), findsOneWidget);
    });

    testWidgets('table app bar has more options popup', (tester) async {
      final overrides = await _buildOverrides(
        trips: [_makeTrip(id: 't1', name: 'Test Trip')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('table app bar popup menu shows view mode items', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        trips: [_makeTrip(id: 't1', name: 'Test Trip')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Detailed'), findsOneWidget);
      expect(find.text('Compact'), findsOneWidget);
    });

    testWidgets('table app bar has vertical divider', (tester) async {
      final overrides = await _buildOverrides(
        trips: [_makeTrip(id: 't1', name: 'Test Trip')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byType(VerticalDivider), findsOneWidget);
    });

    testWidgets('compact bar has search button', (tester) async {
      final overrides = await _buildOverrides(
        trips: [_makeTrip(id: 't1', name: 'Bali Dive Trip')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('compact bar has sort button', (tester) async {
      final overrides = await _buildOverrides(
        trips: [_makeTrip(id: 't1', name: 'Bali Dive Trip')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.sort), findsOneWidget);
    });

    testWidgets('compact bar has popup menu', (tester) async {
      final overrides = await _buildOverrides(
        trips: [_makeTrip(id: 't1', name: 'Bali Dive Trip')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('table renders trip data in cells', (tester) async {
      final trips = [
        _makeTrip(
          id: 't1',
          name: 'Maldives Trip',
          startDate: DateTime(2024, 6, 1),
          endDate: DateTime(2024, 6, 7),
          location: 'Maldives',
          diveCount: 12,
          maxDepth: 30.0,
        ),
      ];

      final overrides = await _buildOverrides(trips: trips);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Maldives Trip'), findsOneWidget);
    });

    testWidgets('renders trips with various locations', (tester) async {
      final trips = [
        _makeTrip(id: 'vl1', name: 'Japan Trip', location: 'Okinawa'),
        _makeTrip(id: 'vl2', name: 'Mexico Trip', location: 'Cozumel'),
        _makeTrip(id: 'vl3', name: 'Philippines', location: 'Malapascua'),
      ];

      final overrides = await _buildOverrides(trips: trips);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Japan Trip'), findsOneWidget);
      expect(find.text('Mexico Trip'), findsOneWidget);
      expect(find.text('Philippines'), findsOneWidget);
    });

    testWidgets('renders trip with null location', (tester) async {
      final trips = [
        _makeTrip(id: 'nl1', name: 'Local Diving', location: null),
      ];

      final overrides = await _buildOverrides(trips: trips);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Local Diving'), findsOneWidget);
    });

    testWidgets('compact bar shows more menu', (tester) async {
      final overrides = await _buildOverrides(
        trips: [_makeTrip(id: 't1', name: 'Test Trip')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('renders many trips without crash', (tester) async {
      final trips = List.generate(
        15,
        (i) => _makeTrip(id: 'mt$i', name: 'Trip $i', diveCount: i * 3),
      );

      final overrides = await _buildOverrides(trips: trips);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Trip 0'), findsOneWidget);
    });

    testWidgets('renders trips with dive stats', (tester) async {
      final trips = [
        _makeTrip(id: 'ds1', name: 'Stats Trip', diveCount: 24, maxDepth: 42.0),
      ];

      final overrides = await _buildOverrides(trips: trips);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Stats Trip'), findsOneWidget);
    });

    testWidgets('tapping sort button opens sort sheet and selects option', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        trips: [_makeTrip(id: 't1', name: 'Test Trip')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      expect(find.text('Sort Trips'), findsOneWidget);

      await tester.tap(find.text('End Date'));
      await tester.pumpAndSettle();
    });

    testWidgets('tapping popup Detailed switches from table mode', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        trips: [_makeTrip(id: 't1', name: 'Test Trip')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Detailed'));
      await tester.pumpAndSettle();

      // View mode was changed from table
      expect(find.byIcon(Icons.view_column_outlined), findsNothing);
    });

    testWidgets('compact bar sort button opens sheet and selects option', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        trips: [_makeTrip(id: 't1', name: 'Test Trip')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      expect(find.text('Sort Trips'), findsOneWidget);

      await tester.tap(find.text('End Date'));
      await tester.pumpAndSettle();
    });

    testWidgets('compact bar popup Detailed switches view mode', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        trips: [_makeTrip(id: 't1', name: 'Test Trip')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Detailed'));
      await tester.pumpAndSettle();

      // View mode was changed from table
      expect(find.byIcon(Icons.view_column_outlined), findsNothing);
    });
  });
}
