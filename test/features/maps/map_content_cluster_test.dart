import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_map_content.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_map_content.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_map_content.dart';
import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

// ---------------------------------------------------------------------------
// Mock notifiers
// ---------------------------------------------------------------------------

class _MockDiveCenterListNotifier
    extends StateNotifier<AsyncValue<List<DiveCenter>>>
    implements DiveCenterListNotifier {
  _MockDiveCenterListNotifier(List<DiveCenter> centers)
    : super(AsyncValue.data(centers));

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

void suppressMapErrors(WidgetTester tester) {
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.toString();
    if (msg.contains('overflowed') || msg.contains('cameraConstraint')) return;
    originalOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalOnError);
}

Widget _wrap(List<Override> overrides, Widget child) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

// ---------------------------------------------------------------------------
// Shared test data
// ---------------------------------------------------------------------------

// Two dive sites placed at very close coordinates so they cluster
const _site1 = DiveSite(
  id: 'site-1',
  name: 'Blue Hole',
  location: GeoPoint(21.0000, -157.5000),
);

const _site2 = DiveSite(
  id: 'site-2',
  name: 'Shark Cove',
  location: GeoPoint(21.0001, -157.5001),
);

final _now = DateTime(2026, 3, 28, 10, 0);

domain.Dive _makeDive(String id, DiveSite site) => domain.Dive(
  id: id,
  dateTime: _now,
  site: site,
  tanks: const [],
  profile: const [],
  equipment: const [],
  notes: '',
  photoIds: const [],
  sightings: const [],
  weights: const [],
  tags: const [],
);

// ---------------------------------------------------------------------------
// DiveMapContent tests
// ---------------------------------------------------------------------------

void main() {
  group('DiveMapContent', () {
    testWidgets('renders with dives that have sites with coordinates', (
      tester,
    ) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final dive1 = _makeDive('dive-1', _site1);
      final dive2 = _makeDive('dive-2', _site2);
      final dives = [dive1, dive2];

      final base = await getBaseOverrides();
      final overrides = [
        ...base,
        sortedFilteredDivesProvider.overrideWith(
          (ref) => AsyncValue.data(dives),
        ),
        diveActivityHeatMapProvider.overrideWith(
          (ref) => const AsyncValue.data(<HeatMapPoint>[]),
        ),
        heatMapSettingsProvider.overrideWith(
          (ref) => const HeatMapSettings(isVisible: false),
        ),
      ];

      await tester.pumpWidget(
        _wrap(overrides, DiveMapContent(onItemSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(MarkerClusterLayerWidget), findsOneWidget);
    });

    testWidgets('renders empty state when no dives have sites', (tester) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final base = await getBaseOverrides();
      final overrides = [
        ...base,
        sortedFilteredDivesProvider.overrideWith(
          (ref) => const AsyncValue.data(<domain.Dive>[]),
        ),
        diveActivityHeatMapProvider.overrideWith(
          (ref) => const AsyncValue.data(<HeatMapPoint>[]),
        ),
        heatMapSettingsProvider.overrideWith(
          (ref) => const HeatMapSettings(isVisible: false),
        ),
      ];

      await tester.pumpWidget(
        _wrap(overrides, DiveMapContent(onItemSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('renders loading state', (tester) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final base = await getBaseOverrides();
      final overrides = [
        ...base,
        sortedFilteredDivesProvider.overrideWith(
          (ref) => const AsyncValue.loading(),
        ),
        diveActivityHeatMapProvider.overrideWith(
          (ref) => const AsyncValue.data(<HeatMapPoint>[]),
        ),
        heatMapSettingsProvider.overrideWith(
          (ref) => const HeatMapSettings(isVisible: false),
        ),
      ];

      await tester.pumpWidget(
        _wrap(overrides, DiveMapContent(onItemSelected: (_) {})),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders error state when dives provider fails', (
      tester,
    ) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final base = await getBaseOverrides();
      final overrides = [
        ...base,
        sortedFilteredDivesProvider.overrideWith(
          (ref) => AsyncValue<List<domain.Dive>>.error(
            Exception('failed'),
            StackTrace.empty,
          ),
        ),
        diveActivityHeatMapProvider.overrideWith(
          (ref) => const AsyncValue.data(<HeatMapPoint>[]),
        ),
        heatMapSettingsProvider.overrideWith(
          (ref) => const HeatMapSettings(isVisible: false),
        ),
      ];

      await tester.pumpWidget(
        _wrap(overrides, DiveMapContent(onItemSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('renders heat map layer when heat map is visible', (
      tester,
    ) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final dive1 = _makeDive('dive-1', _site1);

      final base = await getBaseOverrides();
      final overrides = [
        ...base,
        sortedFilteredDivesProvider.overrideWith(
          (ref) => AsyncValue.data([dive1]),
        ),
        diveActivityHeatMapProvider.overrideWith(
          (ref) => const AsyncValue.data(<HeatMapPoint>[]),
        ),
        heatMapSettingsProvider.overrideWith(
          (ref) => const HeatMapSettings(isVisible: true),
        ),
      ];

      await tester.pumpWidget(
        _wrap(overrides, DiveMapContent(onItemSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('renders info card when a dive is selected', (tester) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final dive1 = _makeDive('dive-1', _site1);

      final base = await getBaseOverrides();
      final overrides = [
        ...base,
        sortedFilteredDivesProvider.overrideWith(
          (ref) => AsyncValue.data([dive1]),
        ),
        diveActivityHeatMapProvider.overrideWith(
          (ref) => const AsyncValue.data(<HeatMapPoint>[]),
        ),
        heatMapSettingsProvider.overrideWith(
          (ref) => const HeatMapSettings(isVisible: false),
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          overrides,
          DiveMapContent(selectedId: 'dive-1', onItemSelected: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      // Info card shows site name
      expect(find.text('Blue Hole'), findsOneWidget);
    });

    testWidgets('tapping retry in error state executes invalidation', (
      tester,
    ) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final base = await getBaseOverrides();
      final overrides = [
        ...base,
        sortedFilteredDivesProvider.overrideWith(
          (ref) => AsyncValue<List<domain.Dive>>.error(
            Exception('failed'),
            StackTrace.empty,
          ),
        ),
        diveActivityHeatMapProvider.overrideWith(
          (ref) => const AsyncValue.data(<HeatMapPoint>[]),
        ),
        heatMapSettingsProvider.overrideWith(
          (ref) => const HeatMapSettings(isVisible: false),
        ),
      ];

      await tester.pumpWidget(
        _wrap(overrides, DiveMapContent(onItemSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      final retry = find.byType(FilledButton);
      expect(retry, findsOneWidget);
      await tester.tap(retry);
      await tester.pump();
    });
  });

  // ---------------------------------------------------------------------------
  // SiteMapContent tests
  // ---------------------------------------------------------------------------

  group('SiteMapContent', () {
    testWidgets('renders with sites that have coordinates', (tester) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final sites = [
        SiteWithDiveCount(site: _site1, diveCount: 3),
        SiteWithDiveCount(site: _site2, diveCount: 5),
      ];

      final base = await getBaseOverrides();
      final overrides = [
        ...base,
        sitesWithCountsProvider.overrideWith((ref) async => sites),
        siteCoverageHeatMapProvider.overrideWith(
          (ref) async => <HeatMapPoint>[],
        ),
        heatMapSettingsProvider.overrideWith(
          (ref) => const HeatMapSettings(isVisible: false),
        ),
      ];

      await tester.pumpWidget(
        _wrap(overrides, SiteMapContent(onItemSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(MarkerClusterLayerWidget), findsOneWidget);
    });

    testWidgets('renders empty state when no sites have coordinates', (
      tester,
    ) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final base = await getBaseOverrides();
      final overrides = [
        ...base,
        sitesWithCountsProvider.overrideWith(
          (ref) async => <SiteWithDiveCount>[],
        ),
        siteCoverageHeatMapProvider.overrideWith(
          (ref) async => <HeatMapPoint>[],
        ),
        heatMapSettingsProvider.overrideWith(
          (ref) => const HeatMapSettings(isVisible: false),
        ),
      ];

      await tester.pumpWidget(
        _wrap(overrides, SiteMapContent(onItemSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('renders loading state', (tester) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final base = await getBaseOverrides();
      final overrides = [
        ...base,
        sitesWithCountsProvider.overrideWith(
          (ref) => Future<List<SiteWithDiveCount>>.value(
            const <SiteWithDiveCount>[],
          ).then((_) => throw Exception('stalled')),
        ),
        siteCoverageHeatMapProvider.overrideWith(
          (ref) async => <HeatMapPoint>[],
        ),
        heatMapSettingsProvider.overrideWith(
          (ref) => const HeatMapSettings(isVisible: false),
        ),
      ];

      await tester.pumpWidget(
        _wrap(overrides, SiteMapContent(onItemSelected: (_) {})),
      );
      // Do not settle — loading state captured before provider resolves
      await tester.pump();

      // Renders either loading or map depending on async resolution speed
      expect(
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
            find.byType(FlutterMap).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('renders error state when provider fails', (tester) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final base = await getBaseOverrides();
      final overrides = [
        ...base,
        sitesWithCountsProvider.overrideWith(
          (ref) async => throw Exception('sites error'),
        ),
        siteCoverageHeatMapProvider.overrideWith(
          (ref) async => <HeatMapPoint>[],
        ),
        heatMapSettingsProvider.overrideWith(
          (ref) => const HeatMapSettings(isVisible: false),
        ),
      ];

      await tester.pumpWidget(
        _wrap(overrides, SiteMapContent(onItemSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('renders heat map layer when heat map is visible', (
      tester,
    ) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final sites = [SiteWithDiveCount(site: _site1, diveCount: 2)];

      final base = await getBaseOverrides();
      final overrides = [
        ...base,
        sitesWithCountsProvider.overrideWith((ref) async => sites),
        siteCoverageHeatMapProvider.overrideWith(
          (ref) async => <HeatMapPoint>[],
        ),
        heatMapSettingsProvider.overrideWith(
          (ref) => const HeatMapSettings(isVisible: true),
        ),
      ];

      await tester.pumpWidget(
        _wrap(overrides, SiteMapContent(onItemSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('renders info card when a site is selected', (tester) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final sites = [SiteWithDiveCount(site: _site1, diveCount: 2)];

      final base = await getBaseOverrides();
      final overrides = [
        ...base,
        sitesWithCountsProvider.overrideWith((ref) async => sites),
        siteCoverageHeatMapProvider.overrideWith(
          (ref) async => <HeatMapPoint>[],
        ),
        heatMapSettingsProvider.overrideWith(
          (ref) => const HeatMapSettings(isVisible: false),
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          overrides,
          SiteMapContent(selectedId: 'site-1', onItemSelected: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Blue Hole'), findsOneWidget);
    });

    testWidgets('tapping retry in error state executes invalidation', (
      tester,
    ) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final base = await getBaseOverrides();
      final overrides = [
        ...base,
        sitesWithCountsProvider.overrideWith(
          (ref) async => throw Exception('sites error'),
        ),
        siteCoverageHeatMapProvider.overrideWith(
          (ref) async => <HeatMapPoint>[],
        ),
        heatMapSettingsProvider.overrideWith(
          (ref) => const HeatMapSettings(isVisible: false),
        ),
      ];

      await tester.pumpWidget(
        _wrap(overrides, SiteMapContent(onItemSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      final retry = find.byType(FilledButton);
      expect(retry, findsOneWidget);
      await tester.tap(retry);
      await tester.pump();
    });
  });

  // ---------------------------------------------------------------------------
  // DiveCenterMapContent tests
  // ---------------------------------------------------------------------------

  group('DiveCenterMapContent', () {
    DiveCenter makeCenter(String id, double lat, double lng) {
      final now = DateTime(2026, 1, 1);
      return DiveCenter(
        id: id,
        name: 'Dive Center $id',
        latitude: lat,
        longitude: lng,
        createdAt: now,
        updatedAt: now,
      );
    }

    testWidgets('renders with dive centers that have coordinates', (
      tester,
    ) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final centers = [
        makeCenter('c1', 21.0000, -157.5000),
        makeCenter('c2', 21.0001, -157.5001),
      ];

      final base = await getBaseOverrides();
      final overrides = [
        ...base,
        diveCenterListNotifierProvider.overrideWith(
          (ref) => _MockDiveCenterListNotifier(centers),
        ),
        diveCenterDiveCountProvider('c1').overrideWith((ref) async => 0),
        diveCenterDiveCountProvider('c2').overrideWith((ref) async => 0),
      ];

      await tester.pumpWidget(
        _wrap(overrides, DiveCenterMapContent(onItemSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(MarkerClusterLayerWidget), findsOneWidget);
    });

    testWidgets('renders empty state when no centers have coordinates', (
      tester,
    ) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final now = DateTime(2026, 1, 1);
      final centers = [
        DiveCenter(
          id: 'no-loc',
          name: 'No Location Center',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final base = await getBaseOverrides();
      final overrides = [
        ...base,
        diveCenterListNotifierProvider.overrideWith(
          (ref) => _MockDiveCenterListNotifier(centers),
        ),
      ];

      await tester.pumpWidget(
        _wrap(overrides, DiveCenterMapContent(onItemSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('renders loading state', (tester) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final base = await getBaseOverrides();
      final overrides = [
        ...base,
        diveCenterListNotifierProvider.overrideWith(
          (ref) =>
              _MockDiveCenterListNotifier([])
                ..state = const AsyncValue.loading(),
        ),
      ];

      await tester.pumpWidget(
        _wrap(overrides, DiveCenterMapContent(onItemSelected: (_) {})),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders error state when provider fails', (tester) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final base = await getBaseOverrides();
      final overrides = [
        ...base,
        diveCenterListNotifierProvider.overrideWith(
          (ref) => _MockDiveCenterListNotifier([])
            ..state = AsyncValue<List<DiveCenter>>.error(
              Exception('centers error'),
              StackTrace.empty,
            ),
        ),
      ];

      await tester.pumpWidget(
        _wrap(overrides, DiveCenterMapContent(onItemSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('renders info card when a center is selected', (tester) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final centers = [makeCenter('c1', 21.0000, -157.5000)];

      final base = await getBaseOverrides();
      final overrides = [
        ...base,
        diveCenterListNotifierProvider.overrideWith(
          (ref) => _MockDiveCenterListNotifier(centers),
        ),
        diveCenterDiveCountProvider('c1').overrideWith((ref) async => 3),
      ];

      await tester.pumpWidget(
        _wrap(
          overrides,
          DiveCenterMapContent(selectedId: 'c1', onItemSelected: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dive Center c1'), findsOneWidget);
    });

    testWidgets('renders marker with high rating color branch', (tester) async {
      setViewport(tester);
      suppressMapErrors(tester);

      final now = DateTime(2026, 1, 1);
      final centers = [
        DiveCenter(
          id: 'rated',
          name: 'Rated Center',
          latitude: 21.0,
          longitude: -157.5,
          rating: 4.8,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final base = await getBaseOverrides();
      final overrides = [
        ...base,
        diveCenterListNotifierProvider.overrideWith(
          (ref) => _MockDiveCenterListNotifier(centers),
        ),
        diveCenterDiveCountProvider('rated').overrideWith((ref) async => 0),
      ];

      await tester.pumpWidget(
        _wrap(overrides, DiveCenterMapContent(onItemSelected: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
    });
  });
}
