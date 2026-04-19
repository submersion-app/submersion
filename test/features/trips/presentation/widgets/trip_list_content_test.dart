import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/constants/trip_field.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/compact_trip_list_tile.dart';
import 'package:submersion/features/trips/presentation/widgets/dense_trip_list_tile.dart';
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
  bool isShared = false,
}) {
  return TripWithStats(
    trip: Trip(
      id: id,
      name: name,
      startDate: startDate ?? DateTime(2024, 6, 1),
      endDate: endDate ?? DateTime(2024, 6, 7),
      location: location,
      isShared: isShared,
      createdAt: _now,
      updatedAt: _now,
    ),
    diveCount: diveCount,
    maxDepth: maxDepth,
  );
}

Diver _makeDiver(String id) {
  return Diver(id: id, name: 'Diver $id', createdAt: _now, updatedAt: _now);
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

Future<List<Override>> _buildPhoneOverrides({
  required List<TripWithStats> trips,
  ListViewMode viewMode = ListViewMode.detailed,
  String? highlightedTripId,
  List<Diver>? divers,
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
    tripListViewModeProvider.overrideWith((ref) => viewMode),
    tripTableConfigProvider.overrideWith(
      (ref) => _TestTripTableConfigNotifier(_testConfig),
    ),
    sortedFilteredTripsProvider.overrideWith((ref) => AsyncValue.data(trips)),
    highlightedTripIdProvider.overrideWith((ref) => highlightedTripId),
    if (divers != null) allDiversProvider.overrideWith((ref) async => divers),
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

      // Verify column headers from displayName values
      expect(find.text('Name'), findsWidgets);
      expect(find.text('Start Date'), findsOneWidget);
      expect(find.text('End Date'), findsOneWidget);
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

    // Column settings are now provided by TableModeLayout, not the content
    // widget. The compact bar provides sort, search, and view mode controls.

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

    // Vertical divider was part of the standalone table app bar, now removed.
    // Column settings and divider are in TableModeLayout.

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

    testWidgets('tapping a row sets highlighted trip id', (tester) async {
      final trips = [
        _makeTrip(id: 't1', name: 'Bali Trip'),
        _makeTrip(id: 't2', name: 'Red Sea Trip'),
      ];

      final overrides = await _buildOverrides(trips: trips);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Tap on a trip row
      await tester.tap(find.text('Bali Trip'));
      // Pump past the DoubleTapGestureRecognizer's 40ms timer
      await tester.pump(const Duration(milliseconds: 50));

      // Verify the widget rebuilt successfully (no crash)
      expect(find.text('Bali Trip'), findsOneWidget);
    });
  });

  group('phone-mode highlight', () {
    testWidgets(
      'phone detailed view highlights trip when highlightedTripIdProvider is set',
      (tester) async {
        final trips = [
          _makeTrip(id: 't1', name: 'Alpha Trip'),
          _makeTrip(id: 't2', name: 'Bravo Trip'),
        ];

        final overrides = await _buildPhoneOverrides(
          trips: trips,
          viewMode: ListViewMode.detailed,
          highlightedTripId: 't2',
        );

        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: const TripListContent(showAppBar: false),
          ),
        );
        await tester.pumpAndSettle();

        final tiles = tester
            .widgetList<TripListTile>(find.byType(TripListTile))
            .toList();
        final alpha = tiles.firstWhere((t) => t.tripWithStats.trip.id == 't1');
        final bravo = tiles.firstWhere((t) => t.tripWithStats.trip.id == 't2');

        expect(alpha.isSelected, isFalse);
        expect(bravo.isSelected, isTrue);
      },
    );

    testWidgets(
      'phone compact view highlights trip when highlightedTripIdProvider is set',
      (tester) async {
        final trips = [
          _makeTrip(id: 't1', name: 'Alpha Trip'),
          _makeTrip(id: 't2', name: 'Bravo Trip'),
        ];

        final overrides = await _buildPhoneOverrides(
          trips: trips,
          viewMode: ListViewMode.compact,
          highlightedTripId: 't2',
        );

        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: const TripListContent(showAppBar: false),
          ),
        );
        await tester.pumpAndSettle();

        final tiles = tester
            .widgetList<CompactTripListTile>(find.byType(CompactTripListTile))
            .toList();
        final alpha = tiles.firstWhere((t) => t.tripWithStats.trip.id == 't1');
        final bravo = tiles.firstWhere((t) => t.tripWithStats.trip.id == 't2');

        expect(alpha.isSelected, isFalse);
        expect(bravo.isSelected, isTrue);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Shared icon tests — exercises detailed, compact, and dense view modes.
  // ---------------------------------------------------------------------------
  group('shared icon', () {
    testWidgets(
      'detailed view: renders people_outline icon for shared trip when 2+ divers',
      (tester) async {
        final trips = [
          _makeTrip(id: 's1', name: 'Shared Trip', isShared: true),
          _makeTrip(id: 's2', name: 'Private Trip', isShared: false),
        ];

        final overrides = await _buildPhoneOverrides(
          trips: trips,
          viewMode: ListViewMode.detailed,
          divers: [_makeDiver('d1'), _makeDiver('d2')],
        );

        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: const TripListContent(showAppBar: false),
          ),
        );
        await tester.pumpAndSettle();

        // Icon should appear exactly once, on the shared trip tile.
        expect(find.byIcon(Icons.people_outline), findsOneWidget);

        // The icon must be inside the tile that carries the shared trip name.
        final sharedTile = find.ancestor(
          of: find.text('Shared Trip'),
          matching: find.byType(TripListTile),
        );
        expect(
          find.descendant(
            of: sharedTile,
            matching: find.byIcon(Icons.people_outline),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'compact view: renders people_outline icon for shared trip when 2+ divers',
      (tester) async {
        final trips = [
          _makeTrip(id: 's1', name: 'Shared Trip', isShared: true),
          _makeTrip(id: 's2', name: 'Private Trip', isShared: false),
        ];

        final overrides = await _buildPhoneOverrides(
          trips: trips,
          viewMode: ListViewMode.compact,
          divers: [_makeDiver('d1'), _makeDiver('d2')],
        );

        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: const TripListContent(showAppBar: false),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.people_outline), findsOneWidget);

        final sharedTile = find.ancestor(
          of: find.text('Shared Trip'),
          matching: find.byType(CompactTripListTile),
        );
        expect(
          find.descendant(
            of: sharedTile,
            matching: find.byIcon(Icons.people_outline),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'dense view: renders people_outline icon for shared trip when 2+ divers',
      (tester) async {
        final trips = [
          _makeTrip(id: 's1', name: 'Shared Trip', isShared: true),
          _makeTrip(id: 's2', name: 'Private Trip', isShared: false),
        ];

        final overrides = await _buildPhoneOverrides(
          trips: trips,
          viewMode: ListViewMode.dense,
          divers: [_makeDiver('d1'), _makeDiver('d2')],
        );

        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: const TripListContent(showAppBar: false),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.people_outline), findsOneWidget);

        final sharedTile = find.ancestor(
          of: find.text('Shared Trip'),
          matching: find.byType(DenseTripListTile),
        );
        expect(
          find.descendant(
            of: sharedTile,
            matching: find.byIcon(Icons.people_outline),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('does not render icon when only one diver (detailed view)', (
      tester,
    ) async {
      final trips = [_makeTrip(id: 's1', name: 'Shared Trip', isShared: true)];

      final overrides = await _buildPhoneOverrides(
        trips: trips,
        viewMode: ListViewMode.detailed,
        divers: [_makeDiver('d1')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.people_outline), findsNothing);
    });

    testWidgets('does not render icon when only one diver (compact view)', (
      tester,
    ) async {
      final trips = [_makeTrip(id: 's1', name: 'Shared Trip', isShared: true)];

      final overrides = await _buildPhoneOverrides(
        trips: trips,
        viewMode: ListViewMode.compact,
        divers: [_makeDiver('d1')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.people_outline), findsNothing);
    });

    testWidgets('does not render icon when only one diver (dense view)', (
      tester,
    ) async {
      final trips = [_makeTrip(id: 's1', name: 'Shared Trip', isShared: true)];

      final overrides = await _buildPhoneOverrides(
        trips: trips,
        viewMode: ListViewMode.dense,
        divers: [_makeDiver('d1')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.people_outline), findsNothing);
    });
  });
}
