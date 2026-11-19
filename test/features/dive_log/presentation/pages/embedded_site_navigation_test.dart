import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart'
    as providers;
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_locations_map.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart'
    as marine;
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_pane_header.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

class MockDiveRepository extends Mock implements DiveRepository {
  @override
  Stream<void> watchDivesChanges() => const Stream.empty();

  @override
  Stream<void> watchDiveListChanges() => const Stream.empty();

  @override
  Future<List<DiveSummary>> getDiveSummaries({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    DiveSummaryCursor? cursor,
    int? offset,
    int limit = 50,
    SortState<DiveSortField>? sort,
    Set<String> disabledSafetyRules = const {},
  }) async => [];

  @override
  Future<int> getDiveCount({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async => 0;

  @override
  Future<List<String>> getOrderedDiveIds({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    SortState<DiveSortField>? sort,
  }) async => [];
}

class MockSpeciesRepository extends Mock implements SpeciesRepository {
  @override
  Stream<void> watchSpeciesChanges() => const Stream.empty();

  @override
  Future<List<marine.Species>> getAllSpecies({List<String>? ids}) async => [];

  @override
  Future<List<marine.SiteSpeciesEntry>> getExpectedSpeciesForSite(
    String siteId,
  ) async => [];

  @override
  Future<List<marine.SiteSpeciesSummary>> getSpeciesSpottedAtSite(
    String siteId, {
    String? excludeDiveId,
    bool statsScope = true,
  }) async => [];
}

void main() {
  final l = AppLocalizationsEn();
  const site = DiveSite(
    id: 'site-1',
    name: 'Blue Hole',
    location: GeoPoint(12.3, 45.6),
  );
  final dive = Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2023, 1, 1),
    site: site,
  );
  final summary = DiveSummary.fromDive(dive);

  // The site page's cards read the tag and site type vocabularies from the
  // database (issue #1765).
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  // Returns the location-card InkWell (the one carrying a non-null onTap).
  InkWell locationInkWell(WidgetTester tester) {
    final candidates = tester.widgetList<InkWell>(
      find.ancestor(
        of: find.byType(DiveLocationsMap),
        matching: find.byType(InkWell),
      ),
    );
    return candidates.firstWhere((w) => w.onTap != null);
  }

  testWidgets(
    'Full navigation cycle: Dive -> Site (locked) -> mode=edit (unlocked) '
    '-> Cancel -> Site -> back to the Dive',
    (tester) async {
      // Set desktop size for master-detail
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await getBaseOverrides();
      final mockRepo = MockDiveRepository();
      final mockSpeciesRepo = MockSpeciesRepository();

      final router = GoRouter(
        initialLocation: '/dives?selected=${dive.id}',
        routes: [
          GoRoute(
            path: '/dives',
            builder: (context, state) => const DiveListPage(),
          ),
          GoRoute(
            path: '/sites',
            builder: (context, state) =>
                const Scaffold(body: Text('SITES_LIST')),
          ),
        ],
      );

      // Suppress overflow errors from map/gradient
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        originalOnError?.call(details);
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            speciesRepositoryProvider.overrideWithValue(mockSpeciesRepo),
            providers.diveRepositoryProvider.overrideWithValue(mockRepo),
            providers.diveProvider(dive.id).overrideWith((ref) async => dive),
            providers.paginatedDiveListProvider.overrideWith((ref) {
              return providers.PaginatedDiveListNotifier(mockRepo, ref)
                ..state = AsyncValue.data(
                  PaginatedDiveListState(
                    dives: [summary],
                    hasMore: false,
                    totalCount: 1,
                  ),
                );
            }),
            siteProvider(site.id).overrideWith((ref) async => site),
            siteDiveCountProvider(site.id).overrideWith((ref) async => 1),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Dive Detail is shown
      expect(find.byType(DiveDetailPage), findsOneWidget);
      expect(find.text('Blue Hole'), findsWidgets);

      // 2. Navigate to Site Detail by tapping the location card
      locationInkWell(tester).onTap!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Site Detail is shown (embedded)
      expect(find.byType(SiteDetailPage), findsOneWidget);
      expect(router.state.uri.toString(), contains('site=${site.id}'));
      expect(router.state.uri.toString(), contains('selected=${dive.id}'));

      // 3. The site shows the lock and no Edit pencil: the lock is the one
      // way in (issue #4527, phase 2, plan 7).
      final inSite = find.byType(SiteDetailPage);
      expect(
        find.descendant(of: inSite, matching: find.byIcon(Icons.lock_outline)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: inSite,
          matching: find.widgetWithIcon(IconButton, Icons.edit),
        ),
        findsNothing,
      );

      // 4. The pane's edit mode (`&mode=edit`) opens the site unlocked,
      // still within the dive.
      router.go('/dives?selected=${dive.id}&site=${site.id}&mode=edit');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(SiteDetailPage), findsOneWidget);
      expect(find.byType(RecordEditPaneHeader), findsOneWidget);

      // 5. Cancel with nothing changed returns the site to view mode.
      await tester.tap(find.text(l.forms_cancel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      // The unlocked pane cross-fades out to the site in view mode.
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(RecordEditPaneHeader), findsNothing);
      expect(find.byType(SiteDetailPage), findsOneWidget);
      expect(router.state.uri.toString(), isNot(contains('mode=edit')));
      expect(router.state.uri.toString(), contains('site=${site.id}'));
      expect(router.state.uri.toString(), contains('selected=${dive.id}'));

      // 6. The locked site's back arrow returns to the dive it was opened
      // from.
      await tester.tap(
        find.descendant(
          of: inSite,
          matching: find.byTooltip(l.common_action_back),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(SiteDetailPage), findsNothing);
      expect(find.byType(DiveDetailPage), findsOneWidget);
      expect(router.state.uri.toString(), isNot(contains('site=')));
      expect(router.state.uri.toString(), contains('selected=${dive.id}'));

      FlutterError.onError = originalOnError;
    },
  );
}

// Extension to get router state from tester easily
extension GoRouterTester on GoRouter {
  GoRouterState? get state =>
      routerDelegate.currentConfiguration.last.matchedLocation == ''
      ? null
      : routerDelegate.currentConfiguration.last as GoRouterState;
}
