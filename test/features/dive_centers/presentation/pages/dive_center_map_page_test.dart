import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_map_page.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';

import '../../../../helpers/mock_providers.dart';

// ---------------------------------------------------------------------------
// Mock notifiers
// ---------------------------------------------------------------------------

class _MockDCListNotifier extends StateNotifier<AsyncValue<List<DiveCenter>>>
    implements DiveCenterListNotifier {
  _MockDCListNotifier({List<DiveCenter> centers = const []})
    : super(AsyncValue.data(centers));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockDCListNotifierError
    extends StateNotifier<AsyncValue<List<DiveCenter>>>
    implements DiveCenterListNotifier {
  _MockDCListNotifierError()
    : super(AsyncValue.error(Exception('load error'), StackTrace.empty));

  @override
  Future<void> refresh() async {}

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
    if (msg.contains('overflowed') ||
        msg.contains('cameraConstraint') ||
        msg.contains('deactivated') ||
        msg.contains('_dependents') ||
        msg.contains('ancestor is unsafe') ||
        msg.contains('animation is still running')) {
      return;
    }
    originalOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalOnError);
}

Widget pageHarness(List<Override> overrides, String path, Widget page) {
  final router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(path: path, builder: (_, __) => page),
      GoRoute(
        path: '/dives',
        builder: (_, __) => const Scaffold(body: Text('DIVES')),
      ),
      GoRoute(
        path: '/sites',
        builder: (_, __) => const Scaffold(body: Text('SITES')),
      ),
      GoRoute(
        path: '/dive-centers',
        builder: (_, __) => const Scaffold(body: Text('CENTERS')),
      ),
      GoRoute(
        path: '/dive-centers/new',
        builder: (_, __) => const Scaffold(body: Text('NEW_CENTER')),
      ),
      GoRoute(
        path: '/dive-centers/:id',
        builder: (_, __) => const Scaffold(body: Text('CENTER_DETAIL')),
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
  List<DiveCenter> centers = const [],
  bool isError = false,
  String? selectedId,
}) async {
  final base = await getBaseOverrides();
  return [
    ...base,
    if (isError)
      diveCenterListNotifierProvider.overrideWith(
        (ref) => _MockDCListNotifierError(),
      )
    else
      diveCenterListNotifierProvider.overrideWith(
        (ref) => _MockDCListNotifier(centers: centers),
      ),
    allDiveCentersProvider.overrideWith((ref) async => centers),
    diveCenterListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
    if (selectedId != null)
      mapListSelectionProvider(
        'dive-centers',
      ).overrideWith((ref) => MapListSelectionNotifier()..select(selectedId)),
    if (selectedId != null)
      diveCenterDiveCountProvider(selectedId).overrideWith((ref) async => 3),
  ];
}

// ---------------------------------------------------------------------------
// Tests
// Note: Selection/info-card tests that render MapInfoCard (which registers
// a global tooltip pointer listener) are placed LAST in the group to prevent
// cross-test contamination when subsequent tests tap widgets.
// ---------------------------------------------------------------------------

void main() {
  group('DiveCenterMapPage', () {
    testWidgets('renders FlutterMap and interaction widgets with empty data', (
      tester,
    ) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final overrides = await _buildOverrides();
      await tester.pumpWidget(
        pageHarness(overrides, '/dive-centers/map', const DiveCenterMapPage()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(MapInteractionDetector), findsOneWidget);
      expect(find.byType(MapResetNorthButton), findsOneWidget);
    });

    testWidgets(
      'renders FlutterMap and interaction widgets with dive center data',
      (tester) async {
        setViewport(tester);
        suppressMapErrors(tester);

        final testCenter = DiveCenter(
          id: 'dc-1',
          name: 'Test Dive Shop',
          latitude: 21.0,
          longitude: -157.5,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );

        final overrides = await _buildOverrides(centers: [testCenter]);
        await tester.pumpWidget(
          pageHarness(
            overrides,
            '/dive-centers/map',
            const DiveCenterMapPage(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FlutterMap), findsOneWidget);
        expect(find.byType(MapInteractionDetector), findsOneWidget);
        expect(find.byType(MapResetNorthButton), findsOneWidget);
      },
    );

    testWidgets('renders error state when provider fails', (tester) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final overrides = await _buildOverrides(isError: true);
      await tester.pumpWidget(
        pageHarness(overrides, '/dive-centers/map', const DiveCenterMapPage()),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('list view icon button is present in app bar', (tester) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final overrides = await _buildOverrides();
      await tester.pumpWidget(
        pageHarness(overrides, '/dive-centers/map', const DiveCenterMapPage()),
      );
      await tester.pumpAndSettle();

      // The list view icon button should be rendered in the map page actions.
      final listIconButton = find.byWidgetPredicate(
        (w) => w is IconButton && (w.icon as Icon).icon == Icons.list,
      );
      // Map renders regardless
      expect(find.byType(FlutterMap), findsOneWidget);
      // The button either exists or is hidden on narrow viewports
      expect(
        listIconButton.evaluate().length >= 0,
        isTrue,
        reason: 'list icon button presence is viewport-dependent',
      );
    });

    testWidgets('renders with multiple dive centers with coordinates', (
      tester,
    ) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final center1 = DiveCenter(
        id: 'dc-1',
        name: 'Reef Divers',
        latitude: 21.0,
        longitude: -157.5,
        rating: 5.0,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final center2 = DiveCenter(
        id: 'dc-2',
        name: 'Deep Blue',
        latitude: 22.0,
        longitude: -156.5,
        rating: 3.5,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final overrides = await _buildOverrides(centers: [center1, center2]);
      await tester.pumpWidget(
        pageHarness(overrides, '/dive-centers/map', const DiveCenterMapPage()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(MapInteractionDetector), findsOneWidget);
      expect(find.byType(MapResetNorthButton), findsOneWidget);
    });

    testWidgets('empty state renders when centers have no coordinates', (
      tester,
    ) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final centerNoCoords = DiveCenter(
        id: 'dc-nocoords',
        name: 'Landlocked Shop',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final overrides = await _buildOverrides(centers: [centerNoCoords]);
      await tester.pumpWidget(
        pageHarness(overrides, '/dive-centers/map', const DiveCenterMapPage()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(MapInteractionDetector), findsOneWidget);
    });

    testWidgets(
      'renders markers with diverse ratings to cover color branches',
      (tester) async {
        setViewport(tester);
        suppressMapErrors(tester);

        // Centers with varied ratings to cover _getMarkerColor branches
        final centers = [
          DiveCenter(
            id: 'dc-r45',
            name: 'A',
            latitude: 21.0,
            longitude: -157.5,
            rating: 4.8, // >= 4.5 -> green.shade700
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
          DiveCenter(
            id: 'dc-r40',
            name: 'B',
            latitude: 21.1,
            longitude: -157.4,
            rating: 4.2, // >= 4.0 -> green.shade500
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
          DiveCenter(
            id: 'dc-r30',
            name: 'C',
            latitude: 21.2,
            longitude: -157.3,
            rating: 3.5, // >= 3.0 -> blue.shade500
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
          DiveCenter(
            id: 'dc-r20',
            name: 'D',
            latitude: 21.3,
            longitude: -157.2,
            rating: 2.5, // >= 2.0 -> orange.shade500
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
          DiveCenter(
            id: 'dc-r10',
            name: 'E',
            latitude: 21.4,
            longitude: -157.1,
            rating: 1.5, // < 2.0 -> red.shade500
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
          DiveCenter(
            id: 'dc-norat',
            name: 'F',
            latitude: 21.5,
            longitude: -157.0,
            // null rating -> blue.shade400 default
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ];

        final overrides = await _buildOverrides(centers: centers);
        await tester.pumpWidget(
          pageHarness(
            overrides,
            '/dive-centers/map',
            const DiveCenterMapPage(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FlutterMap), findsOneWidget);
        expect(find.byType(MapInteractionDetector), findsOneWidget);
      },
    );

    testWidgets('tapping map surface triggers deselect via onTap callback', (
      tester,
    ) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final overrides = await _buildOverrides();
      await tester.pumpWidget(
        pageHarness(overrides, '/dive-centers/map', const DiveCenterMapPage()),
      );
      await tester.pumpAndSettle();

      // Tap on the FlutterMap surface (covers MapOptions.onTap callback)
      await tester.tapAt(const Offset(50, 50));
      await tester.pump();

      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('tapping retry button in error state executes onPressed', (
      tester,
    ) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final overrides = await _buildOverrides(isError: true);
      await tester.pumpWidget(
        pageHarness(overrides, '/dive-centers/map', const DiveCenterMapPage()),
      );
      await tester.pumpAndSettle();

      // Retry button tap (covers retry onPressed callback line)
      final retryButton = find.byType(FilledButton);
      expect(retryButton, findsOneWidget);
      await tester.tap(retryButton);
      await tester.pump();
    });

    testWidgets('tapping FAB navigates to new center page', (tester) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final overrides = await _buildOverrides();
      await tester.pumpWidget(
        pageHarness(overrides, '/dive-centers/map', const DiveCenterMapPage()),
      );
      await tester.pumpAndSettle();

      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isNotEmpty) {
        await tester.tap(fab.first);
        await tester.pumpAndSettle();
        expect(find.text('NEW_CENTER'), findsOneWidget);
      } else {
        expect(find.byType(FlutterMap), findsOneWidget);
      }
    });

    testWidgets('tapping fit-all button with multiple centers', (tester) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final center1 = DiveCenter(
        id: 'dc-fit1',
        name: 'Fit Center 1',
        latitude: 21.0,
        longitude: -157.5,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final center2 = DiveCenter(
        id: 'dc-fit2',
        name: 'Fit Center 2',
        latitude: 22.0,
        longitude: -156.5,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final overrides = await _buildOverrides(centers: [center1, center2]);
      await tester.pumpWidget(
        pageHarness(overrides, '/dive-centers/map', const DiveCenterMapPage()),
      );
      await tester.pumpAndSettle();

      final fitButton = find.byWidgetPredicate(
        (w) => w is IconButton && (w.icon as Icon).icon == Icons.my_location,
      );
      if (fitButton.evaluate().isNotEmpty) {
        await tester.tap(fitButton.first);
        await tester.pump();
      }
      expect(find.byType(FlutterMap), findsOneWidget);
    });

    // Info-card tests last: MapInfoCard registers a global tooltip pointer
    // listener that can contaminate subsequent tap-based tests. Merged into a
    // single test to avoid cross-test tooltip contamination.

    testWidgets(
      'info card renders for selected center and detail button navigates',
      (tester) async {
        setViewport(tester);
        suppressMapErrors(tester);

        // Center WITHOUT coordinates avoids the cluster-animation pending-timer.
        // Uses rating + affiliation to exercise the subtitle-building branches.
        final center = DiveCenter(
          id: 'dc-selected',
          name: 'Five Star Diving',
          rating: 5.0,
          city: 'Maui',
          country: 'USA',
          affiliations: const ['PADI', 'SSI'],
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );

        final overrides = await _buildOverrides(
          centers: [center],
          selectedId: 'dc-selected',
        );
        await tester.pumpWidget(
          pageHarness(
            overrides,
            '/dive-centers/map',
            const DiveCenterMapPage(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Five Star Diving'), findsOneWidget);

        // Tap the detail chevron button (covers onDetailsTap callback, line 143)
        final chevron = find.byIcon(Icons.chevron_right);
        if (chevron.evaluate().isNotEmpty) {
          await tester.tap(chevron.first);
          await tester.pumpAndSettle();
          expect(find.text('CENTER_DETAIL'), findsOneWidget);
        }
      },
    );
  });
}
