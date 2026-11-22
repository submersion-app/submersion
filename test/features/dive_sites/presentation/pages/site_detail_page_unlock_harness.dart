import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/services/site_edit_save_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/models/new_site_seed.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_new_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_routes.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_edit_save_provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_exit_blocker.dart';

import '../../../../helpers/mock_providers.dart';

/// One save the page asked for.
typedef SiteSaveCall = ({
  String siteId,
  DiveSite Function(DiveSite stored) apply,
  List<String> cards,
  String? actingDiverId,
  bool hasHeldWrites,
  bool privateOnly,
});

/// One create the page asked for (a new site's Save).
typedef SiteCreateCall = ({
  DiveSite site,
  List<String> cards,
  bool hasHeldWrites,
});

/// Stands in for the save service: records what it was asked to write, and
/// fails on demand.
class FakeSiteSave implements SiteEditSaveService {
  FakeSiteSave(this.stored);

  DiveSite stored;
  Object? failWith;
  final calls = <SiteSaveCall>[];
  final creates = <SiteCreateCall>[];

  /// While set and not completed, a create waits, as a slow write does.
  Completer<void>? createGate;

  @override
  Future<({DiveSite before, DiveSite after})?> save({
    required String siteId,
    required DiveSite Function(DiveSite stored) apply,
    required Iterable<String> changedCardIds,
    String? actingDiverId,
    Future<void> Function()? writeFirst,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
    Set<String> Function()? heldLibraryFields,
    bool privateOnly = false,
  }) async {
    calls.add((
      siteId: siteId,
      apply: apply,
      cards: changedCardIds.toList()..sort(),
      actingDiverId: actingDiverId,
      // Not run: the page's held writes reach the database, which this
      // harness has none of.
      hasHeldWrites: writeFirst != null || alsoWrite != null,
      privateOnly: privateOnly,
    ));
    final failure = failWith;
    if (failure != null) throw failure;
    final applied = apply(stored);
    // As the service writes a reader's own changes: notes and rating only.
    final after = privateOnly
        ? stored.copyWith(
            notes: applied.notes,
            rating: applied.rating,
            clearRating: applied.rating == null,
          )
        : applied;
    return (before: stored, after: after);
  }

  @override
  Future<DiveSite> create({
    required DiveSite site,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
  }) async {
    await createGate?.future;
    creates.add((
      site: site,
      cards: changedCardIds.toList()..sort(),
      // Not run, as for [save].
      hasHeldWrites: alsoWrite != null,
    ));
    final failure = failWith;
    if (failure != null) throw failure;
    return site;
  }
}

/// The site page under test, with its stored site and its save.
class SiteUnlockHarness {
  SiteUnlockHarness(this.save, this.settings);

  final FakeSiteSave save;
  final MockSettingsNotifier settings;
  late ProviderContainer container;

  /// The router, when the page was pumped at an `initialLocation`.
  GoRouter? router;
  late DiveSite stored;

  /// Stores [site] as if written elsewhere (a sync), and lets the page
  /// read it again.
  void store(DiveSite site) {
    stored = site;
    save.stored = site;
    container.invalidate(siteProvider(site.id));
  }
}

const harnessSite = DiveSite(
  id: 's1',
  diverId: 'me',
  name: 'Blue Hole',
  description: 'Wall',
  notes: 'Calm',
);

/// Pumps the full site page for [site] at phone width, and returns the
/// harness.
Future<SiteUnlockHarness> pumpSitePage(
  WidgetTester tester, {
  DiveSite site = harnessSite,
  AppSettings settings = const AppSettings(),
  bool embedded = false,
  bool openUnlocked = false,
  VoidCallback? onSittingEnded,
  VoidCallback? onClose,
  Size size = const Size(600, 1400),
  String? initialLocation,
  List<RouteBase> extraRoutes = const [],
  TransitionBuilder? appBuilder,
  List<Override> extra = const [],
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final notifier = MockSettingsNotifier(settings);
  final harness = SiteUnlockHarness(FakeSiteSave(site), notifier)
    ..stored = site;
  final page = SiteDetailPage(
    siteId: site.id,
    embedded: embedded,
    openUnlocked: openUnlocked,
    onSittingEnded: onSittingEnded,
    onClose: onClose,
  );
  // At [initialLocation] the page is a route's, as in the app: a desktop
  // root visit moves it into the list pane at `/sites`.
  final router = initialLocation == null
      ? null
      : GoRouter(
          initialLocation: initialLocation,
          routes: [
            GoRoute(
              path: '/root-site',
              builder: (_, _) => embedded ? Scaffold(body: page) : page,
            ),
            GoRoute(
              path: '/sites',
              builder: (_, _) => const Scaffold(body: Text('sites pane')),
            ),
            // The app's site address and its old edit address, which
            // redirects to the page opened unlocked (issue #4527, plan 7).
            GoRoute(
              path: '/sites/:siteId',
              builder: (_, state) {
                final routed = SiteDetailPage(
                  siteId: state.pathParameters['siteId']!,
                  embedded: embedded,
                  openUnlocked: state.uri.queryParameters['mode'] == 'edit',
                );
                return embedded ? Scaffold(body: routed) : routed;
              },
              routes: [GoRoute(path: 'edit', redirect: siteEditRedirect)],
            ),
            // Pages the site page opens, for a test that follows it there.
            ...extraRoutes,
          ],
        );
  if (router != null) addTearDown(router.dispose);
  harness.router = router;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...await getBaseOverrides(settingsNotifier: notifier),
        validatedCurrentDiverIdProvider.overrideWith((_) async => 'me'),
        siteProvider(site.id).overrideWith((_) async => harness.stored),
        siteDiveCountProvider(site.id).overrideWith((_) async => 0),
        siteEditSaveServiceProvider.overrideWithValue(harness.save),
        ...extra,
      ].cast<Override>(),
      child: router != null
          ? MaterialApp.router(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            )
          : MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              // Wraps the app, for a test that sets what the app reads
              // above the page (its text scaler, say).
              builder: appBuilder,
              home: embedded ? Scaffold(body: page) : page,
            ),
    ),
  );
  await tester.pumpAndSettle();
  harness.container = ProviderScope.containerOf(
    tester.element(
      find.byType(router == null ? SiteDetailPage : Scaffold).first,
    ),
  );
  return harness;
}

/// The new-site page under test (issue #4527, phase 2, plan 6), with its
/// save, and what it handed back as it left.
class NewSiteHarness {
  NewSiteHarness(this.save);

  final FakeSiteSave save;

  /// Whether the full page has left, and the value it left with.
  bool left = false;
  Object? leftWith;

  /// The pane's callbacks: the id created, and whether it was cancelled.
  String? created;
  bool cancelled = false;

  /// Whether the pane shows the page: false takes it away, as the list
  /// pane does when another site is picked.
  final shown = ValueNotifier<bool>(true);
}

/// Pumps the new-site page, as a pushed route or ([embedded]) in a pane,
/// from [seed], or as a duplicate of [duplicate] (null when that site is
/// gone).
Future<NewSiteHarness> pumpNewSitePage(
  WidgetTester tester, {
  NewSiteSeed? seed,
  SiteDuplicateSource? duplicate,
  bool duplicateGone = false,
  Object? duplicateReadError,
  Future<SiteDuplicateSource?> Function()? duplicateRead,
  bool embedded = false,
  bool viaRouter = false,
  AppSettings settings = const AppSettings(),
  Size size = const Size(600, 1400),
  List<Override> extra = const [],
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final harness = NewSiteHarness(FakeSiteSave(harnessSite));
  final duplicateOfId =
      duplicate?.site.id ??
      (duplicateGone ? 'gone' : null) ??
      (duplicateReadError != null || duplicateRead != null
          ? 'unreadable'
          : null);
  final page = embedded
      ? SiteDetailPage.newSite(
          seed: seed,
          duplicateOfId: duplicateOfId,
          embedded: true,
          onCreated: (id) => harness.created = id,
          onCreateCancelled: () => harness.cancelled = true,
        )
      : SiteDetailPage.newSite(seed: seed, duplicateOfId: duplicateOfId);
  final navigator = GlobalKey<NavigatorState>();
  // As the app opens it: pushed by go_router onto a list, at a route with
  // the new site's leave check.
  final router = viaRouter
      ? GoRouter(
          initialLocation: '/list',
          routes: [
            GoRoute(
              path: '/list',
              builder: (_, _) => const Scaffold(body: Text('list')),
            ),
            GoRoute(
              path: '/sites/new',
              onExit: confirmLeaveRecordSitting,
              builder: (_, _) => page,
            ),
          ],
        )
      : null;
  if (router != null) addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...await getBaseOverrides(
          settingsNotifier: MockSettingsNotifier(settings),
        ),
        validatedCurrentDiverIdProvider.overrideWith((_) async => 'me'),
        shareByDefaultProvider.overrideWith((_) async => false),
        siteEditSaveServiceProvider.overrideWithValue(harness.save),
        if (duplicateOfId != null)
          siteDuplicateSourceProvider(duplicateOfId).overrideWith(
            (_) async => duplicateRead != null
                ? await duplicateRead()
                : duplicateReadError == null
                ? duplicate
                : throw duplicateReadError,
          ),
        ...extra,
      ].cast<Override>(),
      child: router != null
          ? MaterialApp.router(
              debugShowCheckedModeBanner: false,
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            )
          : MaterialApp(
              navigatorKey: navigator,
              debugShowCheckedModeBanner: false,
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: embedded
                  ? Scaffold(
                      body: ValueListenableBuilder<bool>(
                        valueListenable: harness.shown,
                        builder: (_, shown, _) =>
                            shown ? page : const SizedBox.shrink(),
                      ),
                    )
                  : const Scaffold(),
            ),
    ),
  );
  if (router != null) {
    router.push<String>('/sites/new').then((value) {
      harness
        ..left = true
        ..leftWith = value;
    });
  } else if (!embedded) {
    navigator.currentState!
        .push<Object?>(MaterialPageRoute(builder: (_) => page))
        .then((value) {
          harness
            ..left = true
            ..leftWith = value;
        });
  }
  await tester.pumpAndSettle();
  return harness;
}
