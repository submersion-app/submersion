import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_log/data/services/dive_edit_save_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_edit_save_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/services/trip_date_stretch.dart';
import 'package:submersion/features/weather/data/services/weather_service.dart';
import 'package:submersion/features/weather/domain/entities/weather_data.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_shortcuts.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_exit_blocker.dart';

import '../../../../helpers/mock_providers.dart';

/// Stands in for the save service: applies the sitting to [stored] and
/// records what it was asked to write, or fails on demand.
class FakeSave implements DiveEditSaveService {
  FakeSave(this.stored);

  Dive stored;
  Object? failWith;

  /// When set, a save waits here before it writes or fails, so a test can
  /// act while it is running.
  Completer<void>? hold;
  final calls = <({String diveId, Dive merged, List<String> cards})>[];

  /// Whether each save was told its held writes are a change of their own.
  final heldChangeFlags = <bool>[];

  /// What the next save reports as the trips whose dates it moved.
  List<TripDateStretch> tripDateStretches = const [];

  @override
  Future<({Dive before, Dive after, List<TripDateStretch> tripDateStretches})?>
  save({
    required String diveId,
    required Dive Function(Dive stored) apply,
    required Iterable<String> changedCardIds,
    Future<void> Function()? writeFirst,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
  }) async {
    await hold?.future;
    final error = failWith;
    if (error != null) throw error;
    final before = stored;
    final merged = apply(before);
    calls.add((diveId: diveId, merged: merged, cards: changedCardIds.toList()));
    heldChangeFlags.add(alsoWriteIsAChange);
    await writeFirst?.call();
    await alsoWrite?.call();
    stored = merged;
    return (
      before: before,
      after: merged,
      tripDateStretches: tripDateStretches,
    );
  }

  /// Each new dive created, with the cards its sitting changed.
  final creates = <({Dive dive, List<String> cards})>[];

  @override
  Future<({Dive after, List<TripDateStretch> tripDateStretches})> create({
    required Dive dive,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
    String? activeDiverId,
  }) async {
    await hold?.future;
    final error = failWith;
    if (error != null) throw error;
    creates.add((dive: dive, cards: changedCardIds.toList()));
    await alsoWrite?.call();
    stored = dive;
    return (after: dive, tripDateStretches: tripDateStretches);
  }
}

/// Answers every weather fetch with [data].
class FakeWeather extends WeatherService {
  FakeWeather(this.data)
    : super(client: MockClient((_) async => http.Response('', 500)));

  final WeatherData data;

  @override
  Future<WeatherData?> fetchWeather({
    required double latitude,
    required double longitude,
    required DateTime date,
    required DateTime entryTime,
  }) async => data;
}

/// Counts refreshes of the site list instead of reading sites.
class SpySites extends SiteListNotifier {
  SpySites(super.repository, super.ref);

  int refreshes = 0;

  @override
  Future<void> refresh() async => refreshes++;
}

/// A second dive, for tests that hand the page another one.
final otherDive = Dive(
  id: 'dive-2',
  diveNumber: 2,
  dateTime: DateTime(2023, 1, 2),
  notes: 'Other notes',
);

/// The dive every page test here starts from.
final dive = Dive(
  id: 'dive-1',
  diveNumber: 1,
  dateTime: DateTime(2023, 1, 1),
  notes: 'Calm',
);

/// Pumps the page on top of a home route, with only Tags and Notes shown
/// so both are on screen, and returns the router and the fake service.
/// [routes] join the router, for the pages a test opens from the dive.
Future<({GoRouter router, FakeSave save})> pumpPage(
  WidgetTester tester, {
  bool embedded = false,
  bool openUnlocked = false,
  VoidCallback? onSittingEnded,
  Size size = const Size(700, 1000),
  Dive? stored,
  Set<DiveDetailSectionId> visible = const {
    DiveDetailSectionId.tags,
    DiveDetailSectionId.notes,
  },
  Completer<void>? reloadGate,
  Object? Function()? reloadError,
  String initialLocation = '/home/dive',
  List<Override> extra = const [],
  bool imperial = false,
  ValueNotifier<String>? shownDiveId,
  List<DiveDataSource> sources = const [],
  bool shortcuts = false,
  List<RouteBase> routes = const [],
  bool siteInPane = false,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  // One notifier for the life of the page: made in the route's builder it
  // would be a new one, never disposed, each time the route rebuilt.
  final shownId = shownDiveId ?? ValueNotifier(dive.id);
  if (shownDiveId == null) addTearDown(shownId.dispose);

  final save = FakeSave(stored ?? dive);
  var loads = 0;
  final overrides = await getBaseOverrides(
    settingsNotifier: MockSettingsNotifier(
      AppSettings(
        hasAcceptedPlanningDisclaimer: true,
        depthUnit: imperial ? DepthUnit.feet : DepthUnit.meters,
        altitudeUnit: imperial ? AltitudeUnit.feet : AltitudeUnit.meters,
        diveDetailSections: [
          for (final id in DiveDetailSectionId.values)
            DiveDetailSectionConfig(id: id, visible: visible.contains(id)),
        ],
      ),
    ),
  );
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      // The dive as a root page, the way a deep link opens it.
      GoRoute(
        path: '/root-dive',
        builder: (context, state) => DiveDetailPage(
          diveId: dive.id,
          openUnlocked: openUnlocked,
          onSittingEnded: onSittingEnded,
        ),
      ),
      GoRoute(
        path: '/dives',
        builder: (context, state) => const Scaffold(body: Text('PANE')),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('HOME')),
        routes: [
          GoRoute(
            path: 'dive',
            // As the app's dive routes: leaving by `go` asks the sitting.
            onExit: confirmLeaveRecordSitting,
            // With [shownDiveId] the same page is handed another dive,
            // keeping its state, as the list pane does with its detail.
            builder: (context, state) => ValueListenableBuilder<String>(
              valueListenable: shownId,
              builder: (context, id, _) {
                final page = DiveDetailPage(
                  diveId: id,
                  embedded: embedded,
                  openUnlocked: openUnlocked,
                  onSittingEnded: onSittingEnded,
                  // With [siteInPane], a `site=` in the location shows that
                  // site in the dive's place, as the list pane does.
                  embeddedSiteId: siteInPane
                      ? state.uri.queryParameters['site']
                      : null,
                );
                // The list pane sits in the master-detail scaffold.
                return embedded ? Scaffold(body: page) : page;
              },
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/dives/:id',
        builder: (context, state) =>
            Scaffold(body: Text('OTHER ${state.pathParameters['id']}')),
      ),
      // Stands in for the profile editor, which saves on its own page.
      GoRoute(
        path: '/profile-editor/:diveId',
        name: 'editProfile',
        builder: (context, state) => Scaffold(
          body: Column(
            children: [
              Text('PROFILE EDITOR ${state.uri.queryParameters['mode']}'),
              TextButton(
                onPressed: () => context.pop(true),
                child: const Text('SAVE PROFILE'),
              ),
              TextButton(
                onPressed: () => context.pop(false),
                child: const Text('LEAVE PROFILE'),
              ),
            ],
          ),
        ),
      ),
      // Whatever else a test's page opens.
      ...routes,
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        // Reads the fake's dive, so a save shows on the page as it would
        // from the database.
        diveProvider(dive.id).overrideWith((ref) async {
          // Every load after the first waits on [reloadGate], so a test
          // can look at the page before the saved dive is read back.
          if (++loads > 1 && reloadGate != null) await reloadGate.future;
          // A load after the first fails with what [reloadError] answers
          // then, as a database read can after an operation has written.
          final error = loads > 1 ? reloadError?.call() : null;
          if (error != null) throw error;
          return save.stored;
        }),
        diveDataSourcesProvider(dive.id).overrideWith((ref) async => sources),
        diveNeighborsProvider(
          dive.id,
        ).overrideWith((ref) => (previousId: null, nextId: 'dive-2')),
        diveProvider(otherDive.id).overrideWith((ref) async => otherDive),
        diveDataSourcesProvider(
          otherDive.id,
        ).overrideWith((ref) async => <DiveDataSource>[]),
        diveNeighborsProvider(
          otherDive.id,
        ).overrideWith((ref) => (previousId: dive.id, nextId: null)),
        diveEditSaveServiceProvider.overrideWithValue(save),
        ...extra,
      ],
      child: MaterialApp.router(
        routerConfig: router,
        // The editing keys, as the app's shell mounts them.
        builder: shortcuts
            ? (context, child) => RecordEditShortcuts(child: child!)
            : null,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return (router: router, save: save);
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Taps the Add strip's chip for [cardId], scrolling the strip to it first:
/// with more chips than the strip is wide, it may start out of view.
Future<void> tapStripChip(WidgetTester tester, String cardId) async {
  final chip = find.byKey(ValueKey('addStrip_$cardId'));
  await tester.ensureVisible(chip);
  await tester.pump();
  await tester.tap(chip);
}

Future<void> unlock(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Unlock to edit'));
  await settle(tester);
}

Future<void> openNotes(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Edit Notes'));
  await settle(tester);
}

AppBarTextAction action(WidgetTester tester, String label) =>
    tester.widget<AppBarTextAction>(
      find.byWidgetPredicate((w) => w is AppBarTextAction && w.label == label),
    );

String location(GoRouter router) => router.state.uri.toString();
