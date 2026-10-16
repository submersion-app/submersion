import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/constants/trip_field.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/navigation/open_trip_list.dart';
import 'package:submersion/features/trips/presentation/pages/trip_list_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';
import 'package:submersion/shared/providers/table_details_pane_provider.dart';

import '../../../../helpers/mock_providers.dart';

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

/// A trip list opened from a gear item's "N Trips" link is PUSHED over the
/// page that opened it (#3350). It shows a back arrow at every width, and
/// when it goes away it puts back the trip filter and highlighted trip that
/// were in place before it opened.
void main() {
  const desktop = Size(1200, 800);
  const phone = Size(400, 800);

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<({GoRouter router, ProviderContainer container})> pumpHarness(
    WidgetTester tester, {
    required Size size,
    required String initial,
    ListViewMode viewMode = ListViewMode.detailed,
    bool detailsPane = false,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/root',
          builder: (_, _) => const Scaffold(body: Text('ROOT')),
        ),
        GoRoute(
          path: '/trips',
          builder: (_, state) => TripListPage(
            returnTo: state.extra is TripListReturn
                ? state.extra! as TripListReturn
                : null,
          ),
          routes: [
            GoRoute(
              path: 'new',
              builder: (_, _) => const Scaffold(body: Text('NEW TRIP')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          tripListNotifierProvider.overrideWith(
            (ref) => _MockTripListNotifier(),
          ),
          sortedFilteredTripsProvider.overrideWith(
            (ref) => const AsyncValue.data(<TripWithStats>[]),
          ),
          tripListViewModeProvider.overrideWith((ref) => viewMode),
          tableDetailsPaneProvider('trips').overrideWith((ref) => detailsPane),
          tripTableConfigProvider.overrideWith(
            (ref) => _TestTripTableConfigNotifier(),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    return (router: router, container: container);
  }

  void pushList(GoRouter router) => router.push(
    '/trips',
    extra: const TripListReturn(
      filter: TripFilterState(equipmentId: 'before'),
      highlightedTripId: 'orig',
    ),
  );

  for (final (label, size, mode, pane) in [
    ('desktop list', desktop, ListViewMode.detailed, false),
    ('desktop table', desktop, ListViewMode.table, false),
    // The table's header sits in a Column beside the pane, not as a
    // Scaffold app bar; it still has to lead with the way back.
    ('desktop table with details pane', desktop, ListViewMode.table, true),
    ('phone', phone, ListViewMode.detailed, false),
  ]) {
    testWidgets('$label: a pushed list shows a back arrow that pops and '
        'restores the filter and highlight', (tester) async {
      final h = await pumpHarness(
        tester,
        size: size,
        initial: '/root',
        viewMode: mode,
        detailsPane: pane,
      );
      h.container.read(tripFilterProvider.notifier).state =
          const TripFilterState(equipmentId: 'gear');
      h.container.read(highlightedTripIdProvider.notifier).state = 'picked';
      pushList(h.router);
      await settle(tester);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await settle(tester);

      expect(find.text('ROOT'), findsOneWidget);
      expect(h.container.read(tripFilterProvider).equipmentId, 'before');
      expect(h.container.read(highlightedTripIdProvider), 'orig');
    });
  }

  testWidgets('the Trips tab itself has no back arrow on desktop', (
    tester,
  ) async {
    await pumpHarness(tester, size: desktop, initial: '/trips');
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('Add trip on a pushed desktop list keeps the way back', (
    tester,
  ) async {
    final h = await pumpHarness(tester, size: desktop, initial: '/root');
    pushList(h.router);
    await settle(tester);

    await tester.tap(find.byType(FloatingActionButton));
    // The create form needs a database; only the route matters here.
    await tester.pump();
    tester.takeException();
    await tester.pump();
    tester.takeException();

    expect(h.router.state.uri.toString(), '/trips?mode=new');
    expect(h.router.canPop(), isTrue, reason: 'ROOT must still be underneath');
  });
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}
