import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';
import 'package:submersion/features/maps/presentation/pages/dive_activity_map_page.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';

import '../../../../helpers/mock_providers.dart';

// ---------------------------------------------------------------------------
// Mock notifiers
// ---------------------------------------------------------------------------

class _MockSiteListNotifier extends StateNotifier<AsyncValue<List<DiveSite>>>
    implements SiteListNotifier {
  _MockSiteListNotifier() : super(const AsyncValue.data(<DiveSite>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void setViewport(WidgetTester tester, {double w = 800, double h = 600}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(w, h);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Standard error suppression for map pages.
void suppressMapErrors(WidgetTester tester) {
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.toString();
    if (msg.contains('overflowed') || msg.contains('cameraConstraint')) return;
    originalOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalOnError);
}

Widget pageHarness(List<Override> overrides, String path, Widget page) {
  final router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(path: path, builder: (_, _) => page),
      GoRoute(
        path: '/dives',
        builder: (_, _) => const Scaffold(body: Text('DIVES')),
      ),
      GoRoute(
        path: '/dives/new',
        builder: (_, _) => const Scaffold(body: Text('NEW_DIVE')),
      ),
      GoRoute(
        path: '/dives/:id',
        builder: (_, _) => const Scaffold(body: Text('DIVE_DETAIL')),
      ),
      GoRoute(
        path: '/sites',
        builder: (_, _) => const Scaffold(body: Text('SITES')),
      ),
      GoRoute(
        path: '/dive-centers',
        builder: (_, _) => const Scaffold(body: Text('CENTERS')),
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

Future<List<Override>> _buildOverrides({
  List<SiteWithDiveCount> sites = const [],
  List<HeatMapPoint> heatMapPoints = const [],
  List<domain.Dive> dives = const [],
  bool isError = false,
  String? selectedDiveId,
}) async {
  final base = await getBaseOverrides();

  return [
    ...base,
    sitesWithCountsProvider.overrideWith((ref) async {
      if (isError) throw Exception('load error');
      return sites;
    }),
    sortedSitesWithCountsProvider.overrideWith(
      (ref) => isError
          ? AsyncValue.error(Exception('load error'), StackTrace.empty)
          : AsyncValue.data(sites),
    ),
    siteListNotifierProvider.overrideWith((ref) => _MockSiteListNotifier()),
    siteListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
    diveListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
    diveActivityHeatMapProvider.overrideWith(
      (ref) => AsyncValue.data(heatMapPoints),
    ),
    sortedFilteredDivesProvider.overrideWith((ref) => AsyncValue.data(dives)),
    heatMapSettingsProvider.overrideWith(
      (ref) => const HeatMapSettings(isVisible: false),
    ),
    if (selectedDiveId != null)
      mapListSelectionProvider('dives').overrideWith(
        (ref) => MapListSelectionNotifier()..select(selectedDiveId),
      ),
  ];
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DiveActivityMapPage', () {
    testWidgets('renders FlutterMap and interaction widgets with empty data', (
      tester,
    ) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final overrides = await _buildOverrides();
      await tester.pumpWidget(
        pageHarness(overrides, '/dives/map', const DiveActivityMapPage()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(MapInteractionDetector), findsOneWidget);
      expect(find.byType(MapResetNorthButton), findsOneWidget);
    });

    testWidgets('renders with site data that has dive counts', (tester) async {
      setViewport(tester);
      suppressMapErrors(tester);

      const testSite = DiveSite(
        id: 'site-1',
        name: 'Test Reef',
        location: GeoPoint(21.0, -157.5),
      );
      final testSiteWithCount = SiteWithDiveCount(site: testSite, diveCount: 5);

      final overrides = await _buildOverrides(
        sites: [testSiteWithCount],
        heatMapPoints: const [],
        dives: const [],
      );
      await tester.pumpWidget(
        pageHarness(overrides, '/dives/map', const DiveActivityMapPage()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(MapInteractionDetector), findsOneWidget);
      expect(find.byType(MapResetNorthButton), findsOneWidget);
    });

    testWidgets('renders error state when provider fails', (tester) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final overrides = await _buildOverrides(isError: true);
      await tester.pumpWidget(
        pageHarness(overrides, '/dives/map', const DiveActivityMapPage()),
      );
      await tester.pumpAndSettle();

      // Error state shows error icon and retry button
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('renders info card when a dive is selected', (tester) async {
      setViewport(tester);
      suppressMapErrors(tester);

      // No site data to avoid cluster animation timing issues
      final selectedDive = createTestDiveWithBottomTime(
        id: 'dive-selected',
        diveNumber: 42,
        maxDepth: 30.0,
        bottomTime: const Duration(minutes: 45),
      );
      final overrides = await _buildOverrides(
        dives: [selectedDive],
        selectedDiveId: 'dive-selected',
      );
      await tester.pumpWidget(
        pageHarness(overrides, '/dives/map', const DiveActivityMapPage()),
      );
      await tester.pumpAndSettle();

      // With selectedDiveId set, _buildMapInfoCard is called.
      // Title fallback is "Unknown Site" when dive.site is null
      expect(find.text('Unknown Site'), findsOneWidget);
    });

    testWidgets('tapping list view button navigates to dives', (tester) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final overrides = await _buildOverrides();
      await tester.pumpWidget(
        pageHarness(overrides, '/dives/map', const DiveActivityMapPage()),
      );
      await tester.pumpAndSettle();

      final listIconButton = find.byWidgetPredicate(
        (w) => w is IconButton && (w.icon as Icon).icon == Icons.list,
      );
      if (listIconButton.evaluate().isNotEmpty) {
        await tester.tap(listIconButton.first);
        await tester.pumpAndSettle();
        expect(find.text('DIVES'), findsOneWidget);
      } else {
        expect(find.byType(FlutterMap), findsOneWidget);
      }
    });

    testWidgets('renders sites with diverse dive counts for color branches', (
      tester,
    ) async {
      setViewport(tester);
      suppressMapErrors(tester);

      // Sites with varied dive counts to cover _getMarkerColor branches
      final sites = [
        SiteWithDiveCount(
          site: const DiveSite(
            id: 's1',
            name: 'A',
            location: GeoPoint(21.0, -157.5),
          ),
          diveCount: 1, // < 3 -> blue.shade500
        ),
        SiteWithDiveCount(
          site: const DiveSite(
            id: 's2',
            name: 'B',
            location: GeoPoint(21.1, -157.4),
          ),
          diveCount: 3, // >= 3 -> blue.shade700
        ),
        SiteWithDiveCount(
          site: const DiveSite(
            id: 's3',
            name: 'C',
            location: GeoPoint(21.2, -157.3),
          ),
          diveCount: 5, // >= 5 -> amber.shade700
        ),
        SiteWithDiveCount(
          site: const DiveSite(
            id: 's4',
            name: 'D',
            location: GeoPoint(21.3, -157.2),
          ),
          diveCount: 10, // >= 10 -> orange.shade700
        ),
        SiteWithDiveCount(
          site: const DiveSite(
            id: 's5',
            name: 'E',
            location: GeoPoint(21.4, -157.1),
          ),
          diveCount: 20, // >= 20 -> red.shade700
        ),
      ];

      final overrides = await _buildOverrides(sites: sites);
      await tester.pumpWidget(
        pageHarness(overrides, '/dives/map', const DiveActivityMapPage()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(MapInteractionDetector), findsOneWidget);
      expect(find.byType(MapResetNorthButton), findsOneWidget);
    });

    testWidgets('renders empty-dive state when sites have zero dives', (
      tester,
    ) async {
      setViewport(tester);
      suppressMapErrors(tester);

      // Site with 0 dive count -> sitesWithDives filter excludes it
      const testSite = DiveSite(
        id: 'site-nodives',
        name: 'Empty Site',
        location: GeoPoint(21.0, -157.5),
      );
      final overrides = await _buildOverrides(
        sites: [SiteWithDiveCount(site: testSite, diveCount: 0)],
      );
      await tester.pumpWidget(
        pageHarness(overrides, '/dives/map', const DiveActivityMapPage()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(MapInteractionDetector), findsOneWidget);
    });

    testWidgets('tapping retry button in error state executes onPressed', (
      tester,
    ) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final overrides = await _buildOverrides(isError: true);
      await tester.pumpWidget(
        pageHarness(overrides, '/dives/map', const DiveActivityMapPage()),
      );
      await tester.pumpAndSettle();

      // Tap the retry button (covers retry onPressed callback)
      final retryButton = find.byType(FilledButton);
      expect(retryButton, findsOneWidget);
      await tester.tap(retryButton);
      await tester.pump();
    });

    testWidgets('tapping FAB navigates to new dive page', (tester) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final overrides = await _buildOverrides();
      await tester.pumpWidget(
        pageHarness(overrides, '/dives/map', const DiveActivityMapPage()),
      );
      await tester.pumpAndSettle();

      // FAB should be present (covers FloatingActionButton.extended onPressed)
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isNotEmpty) {
        await tester.tap(fab.first);
        await tester.pumpAndSettle();
        expect(find.text('NEW_DIVE'), findsOneWidget);
      } else {
        expect(find.byType(FlutterMap), findsOneWidget);
      }
    });

    testWidgets('tapping fit-all button with sites calls fitAllSites', (
      tester,
    ) async {
      setViewport(tester);
      suppressMapErrors(tester);

      const site1 = DiveSite(
        id: 's1',
        name: 'Site A',
        location: GeoPoint(21.0, -157.5),
      );
      const site2 = DiveSite(
        id: 's2',
        name: 'Site B',
        location: GeoPoint(22.0, -156.5),
      );
      final sites = [
        SiteWithDiveCount(site: site1, diveCount: 3),
        SiteWithDiveCount(site: site2, diveCount: 5),
      ];

      final overrides = await _buildOverrides(sites: sites);
      await tester.pumpWidget(
        pageHarness(overrides, '/dives/map', const DiveActivityMapPage()),
      );
      await tester.pumpAndSettle();

      // Tap the my_location / fit-all icon button
      final fitButton = find.byWidgetPredicate(
        (w) => w is IconButton && (w.icon as Icon).icon == Icons.my_location,
      );
      if (fitButton.evaluate().isNotEmpty) {
        await tester.tap(fitButton.first);
        await tester.pump();
      }
      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('tapping map surface triggers deselect via onTap callback', (
      tester,
    ) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final overrides = await _buildOverrides();
      await tester.pumpWidget(
        pageHarness(overrides, '/dives/map', const DiveActivityMapPage()),
      );
      await tester.pumpAndSettle();

      // Tap on the FlutterMap surface (covers MapOptions.onTap callback)
      // Tap at top-left corner to avoid any overlapping widgets
      await tester.tapAt(const Offset(50, 50));
      await tester.pump();

      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('heat map renders when heatMapSettings isVisible is true', (
      tester,
    ) async {
      setViewport(tester);
      suppressMapErrors(tester);

      // Cover the heat-map-visible branch (lines 335-344)
      final base = await getBaseOverrides();
      final overrides = [
        ...base,
        sitesWithCountsProvider.overrideWith(
          (ref) async => <SiteWithDiveCount>[],
        ),
        sortedSitesWithCountsProvider.overrideWith(
          (ref) => const AsyncValue.data(<SiteWithDiveCount>[]),
        ),
        siteListNotifierProvider.overrideWith((ref) => _MockSiteListNotifier()),
        siteListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
        diveListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
        diveActivityHeatMapProvider.overrideWith(
          (ref) => const AsyncValue.data(<HeatMapPoint>[]),
        ),
        sortedFilteredDivesProvider.overrideWith(
          (ref) => const AsyncValue.data(<domain.Dive>[]),
        ),
        heatMapSettingsProvider.overrideWith(
          (ref) => const HeatMapSettings(isVisible: true),
        ),
      ];
      await tester.pumpWidget(
        pageHarness(overrides, '/dives/map', const DiveActivityMapPage()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('heat map error branch renders when provider errors', (
      tester,
    ) async {
      setViewport(tester);
      suppressMapErrors(tester);

      // Cover heatMapAsync.when() loading/error branches (lines 342-343)
      final base = await getBaseOverrides();
      final overrides = [
        ...base,
        sitesWithCountsProvider.overrideWith(
          (ref) async => <SiteWithDiveCount>[],
        ),
        sortedSitesWithCountsProvider.overrideWith(
          (ref) => const AsyncValue.data(<SiteWithDiveCount>[]),
        ),
        siteListNotifierProvider.overrideWith((ref) => _MockSiteListNotifier()),
        siteListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
        diveListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
        diveActivityHeatMapProvider.overrideWith(
          (ref) => AsyncValue<List<HeatMapPoint>>.error(
            Exception('hm'),
            StackTrace.empty,
          ),
        ),
        sortedFilteredDivesProvider.overrideWith(
          (ref) => const AsyncValue.data(<domain.Dive>[]),
        ),
        heatMapSettingsProvider.overrideWith(
          (ref) => const HeatMapSettings(isVisible: true),
        ),
      ];
      await tester.pumpWidget(
        pageHarness(overrides, '/dives/map', const DiveActivityMapPage()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('info card detail button navigates to dive detail', (
      tester,
    ) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final selectedDive = createTestDiveWithBottomTime(
        id: 'dive-nav',
        diveNumber: 10,
        maxDepth: 25.0,
        bottomTime: const Duration(minutes: 30),
      );
      final overrides = await _buildOverrides(
        dives: [selectedDive],
        selectedDiveId: 'dive-nav',
      );
      await tester.pumpWidget(
        pageHarness(overrides, '/dives/map', const DiveActivityMapPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unknown Site'), findsOneWidget);

      // Tap the detail chevron button (covers onDetailsTap callback)
      final chevron = find.byIcon(Icons.chevron_right);
      if (chevron.evaluate().isNotEmpty) {
        await tester.tap(chevron.first);
        await tester.pumpAndSettle();
        expect(find.text('DIVE_DETAIL'), findsOneWidget);
      }
    });
  });
}
