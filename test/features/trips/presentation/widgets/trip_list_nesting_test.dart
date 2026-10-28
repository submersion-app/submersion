import 'dart:async';

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
import 'package:submersion/features/trips/presentation/widgets/upcoming_trip_banner.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

import '../../../../helpers/mock_providers.dart';

// ---------------------------------------------------------------------------
// Mock notifiers (copied from trip_list_upcoming_test.dart scaffolding)
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
      // The assertions read English labels, so do not follow the host locale.
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Trip trip(String id, String name, {String? parent, int day = 2}) => Trip(
    id: id,
    name: name,
    startDate: DateTime(2025, 3, day),
    endDate: DateTime(2025, 3, day + 3),
    parentTripId: parent,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
  );

  final indonesia = trip('p', 'Indonesia');
  final rajaAmpat = trip('s', 'Raja Ampat', parent: 'p', day: 8);
  final all = [indonesia, rajaAmpat];

  List<Override> overrides(
    List<Trip> listed, {
    ListViewMode mode = ListViewMode.detailed,
    bool allTripsLoaded = true,
    List<Trip>? known,
  }) => [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    tripListNotifierProvider.overrideWith((ref) => _MockTripListNotifier()),
    sortedFilteredTripsProvider.overrideWith(
      (ref) =>
          AsyncValue.data([for (final t in listed) TripWithStats(trip: t)]),
    ),
    allTripsProvider.overrideWith(
      (ref) => allTripsLoaded
          ? Future.value(known ?? all)
          : Completer<List<Trip>>().future,
    ),
    tripListViewModeProvider.overrideWith((ref) => mode),
    tripTableConfigProvider.overrideWith(
      (ref) => _TestTripTableConfigNotifier(),
    ),
    for (final t in known ?? all)
      tripChecklistProgressProvider(
        t.id,
      ).overrideWith((ref) async => (done: 0, total: 0)),
  ];

  Future<void> pump(
    WidgetTester tester,
    List<Trip> listed, {
    ListViewMode mode = ListViewMode.detailed,
    double width = 400,
    bool allTripsLoaded = true,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _buildTestWidget(
        overrides: overrides(
          listed,
          mode: mode,
          allTripsLoaded: allTripsLoaded,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a side trip sits indented under its larger trip', (
    tester,
  ) async {
    await pump(tester, [rajaAmpat, indonesia]);
    final parentName = tester.getTopLeft(find.text('Indonesia'));
    final sideName = tester.getTopLeft(find.text('Raja Ampat'));
    expect(sideName.dy, greaterThan(parentName.dy));
    expect(sideName.dx, greaterThan(parentName.dx));
    expect(find.text('1 side trip'), findsOneWidget);
    expect(find.byIcon(Icons.subdirectory_arrow_right), findsOneWidget);
  });

  testWidgets('a side trip listed without its parent names it', (tester) async {
    await pump(tester, [rajaAmpat]);
    expect(find.text('Part of Indonesia'), findsOneWidget);
    expect(find.byIcon(Icons.subdirectory_arrow_right), findsNothing);
  });

  testWidgets('dense rows nest and carry the note too', (tester) async {
    await pump(tester, [rajaAmpat, indonesia], mode: ListViewMode.dense);
    expect(find.text('1 side trip'), findsOneWidget);
    expect(find.byIcon(Icons.subdirectory_arrow_right), findsOneWidget);
  });

  testWidgets('a dense side trip without its parent names it', (tester) async {
    await pump(tester, [rajaAmpat], mode: ListViewMode.dense);
    expect(find.text('Part of Indonesia'), findsOneWidget);
  });

  testWidgets('compact rows nest and carry the note too', (tester) async {
    // Wider than the others: the compact row's first line holds a fixed
    // date range, which the test font draws far wider than a real one.
    await pump(
      tester,
      [rajaAmpat, indonesia],
      mode: ListViewMode.compact,
      width: 600,
    );
    expect(find.text('1 side trip'), findsOneWidget);
    expect(find.byIcon(Icons.subdirectory_arrow_right), findsOneWidget);
  });

  testWidgets('listed trips nest before the full trip list loads', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _buildTestWidget(
        overrides: overrides([rajaAmpat, indonesia], allTripsLoaded: false),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.subdirectory_arrow_right), findsOneWidget);
    expect(find.text('1 side trip'), findsOneWidget);
  });

  testWidgets("an upcoming side trip's banner is indented with its card", (
    tester,
  ) async {
    final now = DateTime.now();
    Trip soon(String id, String name, int from, int to, {String? parent}) =>
        Trip(
          id: id,
          name: name,
          startDate: DateTime(now.year, now.month, now.day + from),
          endDate: DateTime(now.year, now.month, now.day + to),
          parentTripId: parent,
          createdAt: now,
          updatedAt: now,
        );
    final larger = soon('p2', 'Palau', 10, 24);
    final side = soon('s2', 'Palau liveaboard', 14, 18, parent: 'p2');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 1200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _buildTestWidget(
        overrides: overrides([larger, side], known: [larger, side]),
      ),
    );
    await tester.pumpAndSettle();
    final banners = find.byType(UpcomingTripBanner);
    expect(banners, findsNWidgets(2));
    final parentLeft = tester.getTopLeft(banners.at(0)).dx;
    final sideLeft = tester.getTopLeft(banners.at(1)).dx;
    expect(sideLeft, greaterThan(parentLeft));
  });
}
