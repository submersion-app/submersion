import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/constants/trip_field.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/pages/trip_list_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

import '../../../../helpers/mock_providers.dart';

// ---------------------------------------------------------------------------
// Mock notifiers (copied from trip_list_page_test.dart scaffolding)
// ---------------------------------------------------------------------------

class _MockTripListNotifier
    extends StateNotifier<AsyncValue<List<TripWithStats>>>
    implements TripListNotifier {
  _MockTripListNotifier() : super(const AsyncValue.data(<TripWithStats>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _TestTripTableConfigNotifier
    extends EntityTableConfigNotifier<TripField> {
  _TestTripTableConfigNotifier()
    : super(
        defaultConfig: EntityTableViewConfig<TripField>(
          columns: [
            EntityTableColumnConfig(field: TripField.tripName, isPinned: true),
          ],
        ),
        fieldFromName: TripFieldAdapter.instance.fieldFromName,
      );
}

// ---------------------------------------------------------------------------
// Helper to build the widget under test inside a GoRouter
// ---------------------------------------------------------------------------

Widget _buildTestWidget({required List<Override> overrides}) {
  final router = GoRouter(
    initialLocation: '/trips',
    routes: [
      GoRoute(
        path: '/trips',
        builder: (context, state) => const TripListPage(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) => const Scaffold(body: Text('detail')),
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// Local midnight [days] calendar days from today. Counted in calendar days
/// rather than adding a Duration: across a DST change a 24-hour day is an
/// hour short or long, and the countdown then reads one day off.
DateTime _dayOffset(int days) {
  final now = clock.now();
  return DateTime(now.year, now.month, now.day + days);
}

void main() {
  // The fixtures below count calendar days from today, the way the countdown
  // does (Trip.daysUntilStart). Adding a Duration to local midnight instead
  // lands an hour short of the target day across a DST fall-back, so the
  // trip started a day early and the countdown read 23 (#3152). Pinned to a
  // date whose +24 days crosses the US and EU fall-back; CI runs in UTC, so
  // this only bites in a DST zone, where the suite is run locally.
  test('_dayOffset counts calendar days across a DST change', () {
    withClock(Clock.fixed(DateTime(2026, 10, 9, 12)), () {
      expect(_dayOffset(24), DateTime(2026, 11, 2));
      expect(calendarDaysBetween(clock.now(), _dayOffset(24)), 24);
    });
  });

  group('TripListContent upcoming section', () {
    late SharedPreferences prefs;
    late Trip upcomingTrip;
    late Trip inProgressTrip;
    late Trip pastTrip;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      final now = clock.now();
      upcomingTrip = Trip(
        id: 'trip-upcoming',
        name: 'Cozumel',
        startDate: _dayOffset(24),
        endDate: _dayOffset(31),
        createdAt: now,
        updatedAt: now,
      );
      inProgressTrip = Trip(
        id: 'trip-inprogress',
        name: 'Bonaire',
        startDate: _dayOffset(-2),
        endDate: _dayOffset(3),
        createdAt: now,
        updatedAt: now,
      );
      pastTrip = Trip(
        id: 'trip-past',
        name: 'Truk Lagoon',
        startDate: _dayOffset(-30),
        endDate: _dayOffset(-20),
        createdAt: now,
        updatedAt: now,
      );
    });

    List<Override> baseOverrides(
      List<TripWithStats> trips, {
      Map<String, ({int done, int total})> checklistProgress = const {},
    }) {
      final overrides = <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        tripListNotifierProvider.overrideWith((ref) => _MockTripListNotifier()),
        sortedFilteredTripsProvider.overrideWith(
          (ref) => AsyncValue.data(trips),
        ),
        tripListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
        tripTableConfigProvider.overrideWith(
          (ref) => _TestTripTableConfigNotifier(),
        ),
      ];
      for (final trip in trips) {
        final progress = checklistProgress[trip.trip.id];
        overrides.add(
          tripChecklistProgressProvider(
            trip.trip.id,
          ).overrideWith((ref) async => progress ?? (done: 0, total: 0)),
        );
      }
      return overrides;
    }

    Future<void> setMobileSize(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    testWidgets('partitions trips into Upcoming and Past sections', (
      tester,
    ) async {
      await setMobileSize(tester);

      final trips = [
        TripWithStats(trip: pastTrip),
        TripWithStats(trip: inProgressTrip),
        TripWithStats(trip: upcomingTrip),
      ];

      await tester.pumpWidget(
        _buildTestWidget(overrides: baseOverrides(trips)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Past Trips'), findsOneWidget);

      // Upcoming sorted soonest-first: in-progress trip before the +24d trip.
      final upcomingHeaderY = tester.getTopLeft(find.text('Upcoming')).dy;
      final pastHeaderY = tester.getTopLeft(find.text('Past Trips')).dy;
      final inProgressNameY = tester.getTopLeft(find.text('Bonaire')).dy;
      final upcomingNameY = tester.getTopLeft(find.text('Cozumel')).dy;
      final pastNameY = tester.getTopLeft(find.text('Truk Lagoon')).dy;

      expect(upcomingHeaderY, lessThan(inProgressNameY));
      expect(inProgressNameY, lessThan(upcomingNameY));
      expect(upcomingNameY, lessThan(pastHeaderY));
      expect(pastHeaderY, lessThan(pastNameY));
    });

    testWidgets('upcoming tiles show countdown and progress', (tester) async {
      await setMobileSize(tester);

      final trips = [
        TripWithStats(trip: inProgressTrip),
        TripWithStats(trip: upcomingTrip),
        TripWithStats(trip: pastTrip),
      ];

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: baseOverrides(
            trips,
            checklistProgress: {upcomingTrip.id: (done: 3, total: 12)},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('In 24 days'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('3 of 12 to-dos done'), findsOneWidget);
    });

    testWidgets('past-only list renders without an Upcoming header', (
      tester,
    ) async {
      await setMobileSize(tester);

      final trips = [TripWithStats(trip: pastTrip)];

      await tester.pumpWidget(
        _buildTestWidget(overrides: baseOverrides(trips)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Upcoming'), findsNothing);
      expect(find.text('Past Trips'), findsNothing);
    });
  });
}
