import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/services/trip_edit_save_service.dart';
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_draft.dart';
import 'package:submersion/features/trips/presentation/pages/trip_detail_page.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/shared_items_fixture.dart';
import 'new_trip_test_helpers.dart';
import 'trip_detail_page_unlock_harness.dart';

/// How a new trip's page (issue #4527, phase 3, plan 11) ended, and the
/// fakes it wrote through.
class NewTripHarness {
  late FakeTripSave save;
  late FakeTripDives tripDives;
  late FakeVessels vessels;
  late FakeItemShares shares;
  late ProviderContainer container;
  Object? popped;
  bool poppedAtAll = false;
  final createdIds = <String>[];
  int cancelled = 0;
}

final _createdProvider = StateProvider<Trip?>((ref) => null);

/// The active diver on a new trip's page; a test switches profile by
/// setting it.
final newTripPageDiverProvider = StateProvider<String?>((ref) => 'd1');

/// Pumps a new trip's page, from [draft] when given, pushed over a
/// launcher at `/trips/new`; or the pane's ([embedded]). The dives the
/// question at Save finds are [candidates]; the active diver is
/// [activeDiverId] ([newTripPageDiverProvider]); [trips] are the trips
/// stored, for a larger trip to name. Nothing is stood in for the new
/// trip's id: its stats and story reach the fake repository, which cannot
/// answer them and throws, as the real providers throw for a trip not
/// found, and a read of the trip itself finds none. Needs the test
/// database for the Documents card.
Future<NewTripHarness> pumpNewTripPage(
  WidgetTester tester, {
  TripDraft? draft,
  bool embedded = false,
  Map<String, Trip> trips = const {},
  List<DiveCandidate> candidates = const [],
  String? activeDiverId = 'd1',
  Size size = const Size(600, 1600),
  List<Diver>? divers,
  bool shareByDefault = false,
  List<Object> extraOverrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  final harness = NewTripHarness()
    ..tripDives = (FakeTripDives(candidates)..byId.addAll(trips))
    ..vessels = FakeVessels()
    ..shares = FakeItemShares();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: embedded
              ? TripDetailPage.newTrip(
                  draft: draft,
                  embedded: true,
                  onCreated: harness.createdIds.add,
                  onCreateCancelled: () => harness.cancelled++,
                )
              : TextButton(
                  onPressed: () async {
                    final result = await context.push<Object?>('/trips/new');
                    harness
                      ..poppedAtAll = true
                      ..popped = result;
                  },
                  child: const Text('open'),
                ),
        ),
      ),
      GoRoute(
        path: '/trips/new',
        builder: (_, _) => TripDetailPage.newTrip(draft: draft),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        newTripPageDiverProvider.overrideWith((ref) => activeDiverId),
        validatedCurrentDiverIdProvider.overrideWith(
          (ref) async => ref.watch(newTripPageDiverProvider),
        ),
        shareByDefaultProvider.overrideWith((ref) async => shareByDefault),
        if (divers != null)
          allDiversProvider.overrideWith((ref) async => divers),
        tripRepositoryProvider.overrideWithValue(harness.tripDives),
        liveaboardDetailsRepositoryProvider.overrideWithValue(harness.vessels),
        itemSharesRepositoryProvider.overrideWithValue(harness.shares),
        tripListNotifierProvider.overrideWith((ref) => FakeTripList()),
        tripEditSaveServiceProvider.overrideWith(
          (ref) =>
              harness.save = FakeTripSave(ref.watch(_createdProvider.notifier)),
        ),
        ...extraOverrides,
      ].cast(),
      child: MaterialApp.router(
        theme: AppThemeRegistry.resolveTheme(
          AppThemeRegistry.presets.first,
          Brightness.light,
        ),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (!embedded) {
    await tester.tap(find.text('open'));
    await tester.pump();
  }
  await pumpUntilNewTripPageOpens(tester);
  harness.container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  harness.container.read(tripEditSaveServiceProvider);
  return harness;
}
