# Surface GPS Interactive Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dive detail "Surface GPS" section's text rows + "Open in Maps" button with an embedded interactive map (entry/exit/site markers, dashed drift track, fullscreen expand) and tap-to-focus / copyable coordinate rows.

**Architecture:** Extract a shared `DiveLocationsMap` widget that renders the tile layer, entry/exit/site markers, and the dotted track polyline from typed `GeoPoint?` inputs. Reuse it in three places: the (refactored) decorative header map, a new interactive `SurfaceGpsSection`, and a new fullscreen `DiveLocationsMapPage`. A `MapController` enables tap-to-focus recentering.

**Tech Stack:** Flutter, Riverpod (via `package:submersion/core/providers/provider.dart` barrel), flutter_map 8.2.2, latlong2, flutter_map_tile_caching (via `TileCacheService`), `flutter gen-l10n` ARB localization.

**Branch:** Work on `main` (per user preference — do not create a feature branch).

---

## Spec

See `docs/superpowers/specs/2026-05-25-surface-gps-interactive-map-design.md`.

## Files & responsibilities

**New:**
- `lib/features/dive_log/presentation/widgets/dive_locations_map.dart` — `DiveLocationsMap` (`ConsumerWidget`): draws a map of entry/exit/site points. No clipboard/nav logic.
- `lib/features/dive_log/presentation/pages/dive_locations_map_page.dart` — `DiveLocationsMapPage` (`StatelessWidget`): fullscreen scaffold wrapping an interactive `DiveLocationsMap`.
- `lib/features/dive_log/presentation/widgets/surface_gps_section.dart` — `SurfaceGpsSection` (`ConsumerStatefulWidget`): the collapsible section — inline map + coordinate rows + drift + expand button. Owns the `MapController`, clipboard, and navigation.
- `test/features/dive_log/presentation/widgets/dive_locations_map_test.dart`
- `test/features/dive_log/presentation/pages/dive_locations_map_page_test.dart`
- `test/features/dive_log/presentation/widgets/surface_gps_section_test.dart`

**Changed:**
- `lib/l10n/arb/app_en.arb` — 3 new keys.
- `lib/features/dive_log/presentation/pages/dive_detail_page.dart` — refactor header map onto `DiveLocationsMap`; swap the Surface GPS section for `SurfaceGpsSection`; delete `_buildSurfaceGpsSection`, `_openInMaps`, `_mapPin`.
- `test/features/dive_log/presentation/pages/dive_surface_gps_section_test.dart` — drop the two "Open in Maps" tests; assert the new map + coordinates.

**Unchanged but must stay green:** `test/features/dive_log/presentation/pages/dive_header_gps_test.dart` (relies on exactly one `FlutterMap` on the page + marker keys `gps-entry-marker`/`gps-exit-marker`).

---

### Task 1: Add localization strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`

- [ ] **Step 1: Add the three keys to the English template**

Add these entries to the JSON object in `lib/l10n/arb/app_en.arb` (place them next to the existing `"diveLog_detail_surfaceGps_entryOnly"` entry; ensure surrounding commas keep the JSON valid):

```json
  "diveLog_detail_surfaceGps_site": "Site",
  "diveLog_detail_locationsMap_title": "Dive Locations",
  "diveLog_detail_coordinatesCopied": "Coordinates copied to clipboard",
```

Note: only the template (`app_en.arb`) is required; the other 10 locale ARBs fall back to English until translated. Leave the now-unused `diveLog_detail_openInMaps` key in place (removing it across 11 files is out of scope).

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: completes without error; `lib/l10n/arb/app_localizations.dart` regenerates with new getters `diveLog_detail_surfaceGps_site`, `diveLog_detail_locationsMap_title`, `diveLog_detail_coordinatesCopied`.

- [ ] **Step 3: Verify analysis**

Run: `flutter analyze lib/l10n`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb/app_en.arb lib/l10n/arb/app_localizations.dart
git commit -m "feat(surface-gps): add l10n strings for site row, map title, copy toast"
```

---

### Task 2: Create the shared `DiveLocationsMap` widget

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_locations_map.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_locations_map_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/widgets/dive_locations_map_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_locations_map.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 300, height: 300, child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('renders entry, exit, site markers and a track line', (
    tester,
  ) async {
    await _pump(
      tester,
      const DiveLocationsMap(
        entry: GeoPoint(12.34567, 98.76543),
        exit: GeoPoint(12.34612, 98.76489),
        site: GeoPoint(12.34000, 98.76000),
      ),
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const ValueKey('gps-entry-marker')), findsOneWidget);
    expect(find.byKey(const ValueKey('gps-exit-marker')), findsOneWidget);
    expect(find.byKey(const ValueKey('gps-site-marker')), findsOneWidget);
    expect(find.byType(PolylineLayer), findsOneWidget);
  });

  testWidgets('entry-only: no track line, no exit/site markers', (tester) async {
    await _pump(
      tester,
      const DiveLocationsMap(entry: GeoPoint(12.34567, 98.76543)),
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(PolylineLayer), findsNothing);
    expect(find.byKey(const ValueKey('gps-entry-marker')), findsOneWidget);
    expect(find.byKey(const ValueKey('gps-exit-marker')), findsNothing);
    expect(find.byKey(const ValueKey('gps-site-marker')), findsNothing);
  });

  testWidgets('renders nothing when no points are provided', (tester) async {
    await _pump(tester, const DiveLocationsMap());
    expect(find.byType(FlutterMap), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_locations_map_test.dart`
Expected: FAIL — compile error "Target of URI doesn't exist: '.../dive_locations_map.dart'".

- [ ] **Step 3: Implement `DiveLocationsMap`**

Create `lib/features/dive_log/presentation/widgets/dive_locations_map.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';

/// Marker colors for the GPS entry/exit fixes, matching the values the dive
/// detail header map has always used.
const Color kGpsEntryColor = Color(0xFF34C759);
const Color kGpsExitColor = Color(0xFFFF9F0A);

/// Renders a map of a dive's surface locations: the GPS entry fix, the GPS exit
/// fix, and the associated dive site. Reused by the dive detail header
/// (decorative, non-interactive), the Surface GPS section (inline, interactive),
/// and the fullscreen locations page.
///
/// This widget only draws a map. Clipboard, navigation, and row logic live in
/// the callers.
class DiveLocationsMap extends ConsumerWidget {
  const DiveLocationsMap({
    super.key,
    this.entry,
    this.exit,
    this.site,
    this.interactive = false,
    this.controller,
    this.initialCenter,
    this.initialZoom,
  });

  /// GPS entry fix.
  final GeoPoint? entry;

  /// GPS exit fix.
  final GeoPoint? exit;

  /// Associated dive site location.
  final GeoPoint? site;

  /// Whether the user can pan/zoom. False renders a static, decorative map.
  final bool interactive;

  /// Optional controller for programmatic recentering (tap-to-focus).
  final MapController? controller;

  /// When set, the camera uses this center/zoom verbatim instead of fitting all
  /// points. The header passes this to preserve its fixed zoom-12 look.
  final LatLng? initialCenter;
  final double? initialZoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final points = <LatLng>[
      if (entry != null) LatLng(entry!.latitude, entry!.longitude),
      if (exit != null) LatLng(exit!.latitude, exit!.longitude),
      if (site != null) LatLng(site!.latitude, site!.longitude),
    ];
    if (points.isEmpty) return const SizedBox.shrink();

    LatLng center;
    double zoom;
    CameraFit? fit;
    if (initialCenter != null) {
      center = initialCenter!;
      zoom = initialZoom ?? 12.0;
    } else if (points.length >= 2) {
      center = points.first;
      zoom = 13.0;
      fit = CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(48),
      );
    } else {
      center = points.first;
      zoom = 14.0;
    }

    final markers = <Marker>[
      if (entry != null)
        Marker(
          key: const ValueKey('gps-entry-marker'),
          point: LatLng(entry!.latitude, entry!.longitude),
          width: 28,
          height: 28,
          child: _mapPin(colorScheme, Icons.south, kGpsEntryColor),
        ),
      if (exit != null)
        Marker(
          key: const ValueKey('gps-exit-marker'),
          point: LatLng(exit!.latitude, exit!.longitude),
          width: 28,
          height: 28,
          child: _mapPin(colorScheme, Icons.north, kGpsExitColor),
        ),
      if (site != null)
        Marker(
          key: const ValueKey('gps-site-marker'),
          point: LatLng(site!.latitude, site!.longitude),
          width: 32,
          height: 32,
          child: _mapPin(colorScheme, Icons.anchor, colorScheme.primary),
        ),
    ];

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        initialCameraFit: fit,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: ref.watch(mapTileUrlProvider),
          userAgentPackageName: 'app.submersion',
          maxZoom: ref.watch(mapTileMaxZoomProvider),
          tileProvider: TileCacheService.instance.isInitialized
              ? TileCacheService.instance.getTileProvider()
              : null,
        ),
        if (entry != null && exit != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [
                  LatLng(entry!.latitude, entry!.longitude),
                  LatLng(exit!.latitude, exit!.longitude),
                ],
                strokeWidth: 3.0,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                pattern: const StrokePattern.dotted(),
              ),
            ],
          ),
        MarkerLayer(markers: markers),
        const MapAttribution(),
      ],
    );
  }
}

Widget _mapPin(ColorScheme colorScheme, IconData icon, Color color) {
  return Container(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: colorScheme.onPrimary, width: 2),
    ),
    child: Center(child: Icon(icon, size: 14, color: colorScheme.onPrimary)),
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_locations_map_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_locations_map.dart test/features/dive_log/presentation/widgets/dive_locations_map_test.dart
git commit -m "feat(surface-gps): add shared DiveLocationsMap widget"
```

---

### Task 3: Refactor the header map onto `DiveLocationsMap`

The header keeps its look (fixed center, zoom 12, gradient overlay, "View Site" chip) but renders through `DiveLocationsMap` and no longer needs its own marker list or `_mapPin`. `dive_header_gps_test.dart` must stay green unchanged.

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`
- Test (must pass): `test/features/dive_log/presentation/pages/dive_header_gps_test.dart`

- [ ] **Step 1: Add the import**

In `dive_detail_page.dart`, add to the import block:

```dart
import 'package:submersion/features/dive_log/presentation/widgets/dive_locations_map.dart';
```

- [ ] **Step 2: Delete the inline `markers` list**

In `_buildHeaderSection`, delete the entire `final markers = <Marker>[ ... ];` block (currently lines ~903-927 — the `siteLoc`/`entryLoc`/`exitLoc` Marker list). Keep `final site = dive.site;` and the `mapCenter` computation above it.

- [ ] **Step 3: Replace the inline `FlutterMap` with `DiveLocationsMap`**

In the returned `Stack`, replace the `Positioned.fill` map block (currently lines ~941-977, the `Positioned.fill(child: FlutterMap(...))`) with:

```dart
              // Map background (decorative, non-interactive).
              Positioned.fill(
                child: DiveLocationsMap(
                  entry: entryLoc,
                  exit: exitLoc,
                  site: hasGps ? null : siteLoc,
                  interactive: false,
                  initialCenter: mapCenter,
                  initialZoom: 12.0,
                ),
              ),
```

Leave the gradient overlay, the `content`, and the "View Site" button blocks that follow it untouched.

- [ ] **Step 4: Delete the now-unused `_mapPin` method**

Delete the `Widget _mapPin(ColorScheme colorScheme, IconData icon, Color color) { ... }` method (currently lines ~1047-1056).

- [ ] **Step 5: Run analyze and remove the unused flutter_map import if flagged**

Run: `flutter analyze lib/features/dive_log/presentation/pages/dive_detail_page.dart`
Expected: If it reports `unused_import` for `package:flutter_map/flutter_map.dart`, remove that import line and re-run. (latlong2's `LatLng` is still used by `mapCenter`, so keep `package:latlong2/latlong.dart`.) Expected final: No issues.

- [ ] **Step 6: Run the header tests to verify they still pass**

Run: `flutter test test/features/dive_log/presentation/pages/dive_header_gps_test.dart`
Expected: PASS (5 tests). The header still renders one `FlutterMap`, a `PolylineLayer` for entry+exit, `gps-entry-marker`/`gps-exit-marker`, and the "View Site" affordance.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart
git commit -m "refactor(surface-gps): render header map via DiveLocationsMap"
```

---

### Task 4: Create the fullscreen `DiveLocationsMapPage`

**Files:**
- Create: `lib/features/dive_log/presentation/pages/dive_locations_map_page.dart`
- Test: `test/features/dive_log/presentation/pages/dive_locations_map_page_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/pages/dive_locations_map_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_locations_map_page.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  testWidgets('renders an interactive map with entry/exit/site markers', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DiveLocationsMapPage(
            title: 'Dive Locations',
            entry: GeoPoint(12.34567, 98.76543),
            exit: GeoPoint(12.34612, 98.76489),
            site: GeoPoint(12.34000, 98.76000),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Dive Locations'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const ValueKey('gps-site-marker')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/pages/dive_locations_map_page_test.dart`
Expected: FAIL — compile error "Target of URI doesn't exist: '.../dive_locations_map_page.dart'".

- [ ] **Step 3: Implement `DiveLocationsMapPage`**

Create `lib/features/dive_log/presentation/pages/dive_locations_map_page.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/widgets/dive_locations_map.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Fullscreen, fully-interactive map of a dive's surface locations.
class DiveLocationsMapPage extends StatelessWidget {
  const DiveLocationsMapPage({
    super.key,
    required this.title,
    this.entry,
    this.exit,
    this.site,
  });

  final String title;
  final GeoPoint? entry;
  final GeoPoint? exit;
  final GeoPoint? site;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: DiveLocationsMap(
        entry: entry,
        exit: exit,
        site: site,
        interactive: true,
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/pages/dive_locations_map_page_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_locations_map_page.dart test/features/dive_log/presentation/pages/dive_locations_map_page_test.dart
git commit -m "feat(surface-gps): add fullscreen DiveLocationsMapPage"
```

---

### Task 5: Create the `SurfaceGpsSection` widget

The collapsible section: inline interactive map (with fullscreen expand) + Entry/Exit/Site coordinate rows (tap = focus map, copy icon = clipboard) + drift row. Content builds lazily (only when expanded) so the page never holds a second offscreen map.

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/surface_gps_section.dart`
- Test: `test/features/dive_log/presentation/widgets/surface_gps_section_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/widgets/surface_gps_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_locations_map_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/surface_gps_section.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Dive _dive() => Dive(
  id: 'sgps',
  diveNumber: 1,
  dateTime: DateTime(2026, 5, 22, 9, 14),
  maxDepth: 30.0,
  entryLocation: const GeoPoint(12.34567, 98.76543),
  exitLocation: const GeoPoint(12.34612, 98.76489),
  site: const DiveSite(
    id: 'site-1',
    name: 'Blue Hole',
    location: GeoPoint(12.34000, 98.76000),
  ),
);

Future<void> _pump(WidgetTester tester, {MapController? controller}) async {
  final overrides = await getBaseOverrides();
  await tester.binding.setSurfaceSize(const Size(600, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.toString().contains('overflowed')) return;
    originalOnError?.call(d);
  };
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        surfaceGpsSectionExpandedProvider.overrideWithValue(true),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SurfaceGpsSection(dive: _dive(), controller: controller),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  FlutterError.onError = originalOnError;
}

void main() {
  testWidgets('renders an interactive map and entry/exit/site coordinate rows', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('12.34567, 98.76543'), findsOneWidget); // entry, 5 dp
    expect(find.text('12.34612, 98.76489'), findsOneWidget); // exit, 5 dp
    expect(find.text('12.34000, 98.76000'), findsOneWidget); // site, 5 dp
    expect(find.text('Open in Maps'), findsNothing);
  });

  testWidgets('copy icon copies the coordinate at full (6-dp) precision', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('gps-copy-entry')));
    await tester.pump();

    final setData = calls.firstWhere((c) => c.method == 'Clipboard.setData');
    final text = (setData.arguments as Map)['text'] as String;
    expect(text, '12.345670, 98.765430');
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('tapping a coordinate recenters the map on that point', (
    tester,
  ) async {
    final controller = MapController();
    await _pump(tester, controller: controller);

    await tester.tap(find.byKey(const ValueKey('gps-coord-exit')));
    await tester.pump();

    expect(controller.camera.center.latitude, closeTo(12.34612, 1e-4));
    expect(controller.camera.center.longitude, closeTo(98.76489, 1e-4));
  });

  testWidgets('expand button opens the fullscreen locations page', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('gps-expand')));
    await tester.pumpAndSettle();

    expect(find.byType(DiveLocationsMapPage), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/surface_gps_section_test.dart`
Expected: FAIL — compile error "Target of URI doesn't exist: '.../surface_gps_section.dart'".

- [ ] **Step 3: Implement `SurfaceGpsSection`**

Create `lib/features/dive_log/presentation/widgets/surface_gps_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_locations_map_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_locations_map.dart';
import 'package:submersion/features/dive_log/presentation/widgets/field_attribution_badge.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const double _kFocusZoom = 16.0;
const double _kMapHeight = 180.0;

/// The dive detail "Surface GPS" section: an interactive map of the entry/exit
/// GPS fixes and the associated dive site, plus copyable coordinate rows.
class SurfaceGpsSection extends ConsumerStatefulWidget {
  const SurfaceGpsSection({
    super.key,
    required this.dive,
    this.sourceName,
    @visibleForTesting this.controller,
  });

  final Dive dive;
  final String? sourceName;

  /// Test-only injection point for the inline map's controller.
  final MapController? controller;

  @override
  ConsumerState<SurfaceGpsSection> createState() => _SurfaceGpsSectionState();
}

class _SurfaceGpsSectionState extends ConsumerState<SurfaceGpsSection> {
  late final MapController _controller = widget.controller ?? MapController();

  void _focusOn(GeoPoint p) {
    _controller.move(LatLng(p.latitude, p.longitude), _kFocusZoom);
  }

  Future<void> _copy(BuildContext context, GeoPoint p) async {
    await Clipboard.setData(ClipboardData(text: p.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.diveLog_detail_coordinatesCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => DiveLocationsMapPage(
          title: context.l10n.diveLog_detail_locationsMap_title,
          entry: widget.dive.entryLocation,
          exit: widget.dive.exitLocation,
          site: widget.dive.site?.location,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dive = widget.dive;
    final entry = dive.entryLocation;
    final exit = dive.exitLocation;
    final site = dive.site?.location;
    final isExpanded = ref.watch(surfaceGpsSectionExpandedProvider);
    final units = UnitFormatter(ref.watch(settingsProvider));

    String? driftText;
    if (entry != null && exit != null) {
      final dist = distanceMeters(entry, exit);
      final bearing = initialBearingDegrees(entry, exit);
      driftText = '${units.formatDistance(dist)} · ${formatBearing(bearing)}';
    }

    final collapsedSubtitle = driftText != null
        ? '${context.l10n.diveLog_detail_label_drift}: $driftText'
        : (entry != null
              ? context.l10n.diveLog_detail_surfaceGps_entryOnly
              : context.l10n.diveLog_detail_surfaceGps_exitOnly);

    return CollapsibleCardSection(
      title: context.l10n.diveLog_detail_section_surfaceGps,
      icon: Icons.my_location,
      collapsedSubtitle: collapsedSubtitle,
      isExpanded: isExpanded,
      onToggle: (expanded) {
        ref
            .read(collapsibleSectionProvider.notifier)
            .setSurfaceGpsExpanded(expanded);
      },
      // Build the (heavy) map content only when expanded so the page never
      // holds a second offscreen FlutterMap.
      contentBuilder: (context) => isExpanded
          ? _content(context, entry, exit, site, driftText)
          : const SizedBox.shrink(),
    );
  }

  Widget _content(
    BuildContext context,
    GeoPoint? entry,
    GeoPoint? exit,
    GeoPoint? site,
    String? driftText,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: _kMapHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DiveLocationsMap(
                      entry: entry,
                      exit: exit,
                      site: site,
                      interactive: true,
                      controller: _controller,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Material(
                      color: colorScheme.surface.withValues(alpha: 0.9),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: IconButton(
                        key: const ValueKey('gps-expand'),
                        icon: const Icon(Icons.fullscreen),
                        tooltip: context.l10n.diveLog_detail_locationsMap_title,
                        onPressed: () => _openFullscreen(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (entry != null)
            _GpsCoordinateRow(
              dotColor: kGpsEntryColor,
              label: context.l10n.diveLog_detail_surfaceGps_entry,
              point: entry,
              coordKey: const ValueKey('gps-coord-entry'),
              copyKey: const ValueKey('gps-copy-entry'),
              sourceName: widget.sourceName,
              onFocus: () => _focusOn(entry),
              onCopy: () => _copy(context, entry),
            ),
          if (exit != null)
            _GpsCoordinateRow(
              dotColor: kGpsExitColor,
              label: context.l10n.diveLog_detail_surfaceGps_exit,
              point: exit,
              coordKey: const ValueKey('gps-coord-exit'),
              copyKey: const ValueKey('gps-copy-exit'),
              sourceName: widget.sourceName,
              onFocus: () => _focusOn(exit),
              onCopy: () => _copy(context, exit),
            ),
          if (site != null)
            _GpsCoordinateRow(
              dotColor: colorScheme.primary,
              label: context.l10n.diveLog_detail_surfaceGps_site,
              point: site,
              coordKey: const ValueKey('gps-coord-site'),
              copyKey: const ValueKey('gps-copy-site'),
              onFocus: () => _focusOn(site),
              onCopy: () => _copy(context, site),
            ),
          if (driftText != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.swap_calls,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text('${context.l10n.diveLog_detail_label_drift}: $driftText'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One coordinate row: colored dot, label, tappable (focus) coordinate link,
/// and a copy button.
class _GpsCoordinateRow extends StatelessWidget {
  const _GpsCoordinateRow({
    required this.dotColor,
    required this.label,
    required this.point,
    required this.coordKey,
    required this.copyKey,
    required this.onFocus,
    required this.onCopy,
    this.sourceName,
  });

  final Color dotColor;
  final String label;
  final GeoPoint point;
  final Key coordKey;
  final Key copyKey;
  final VoidCallback onFocus;
  final VoidCallback onCopy;
  final String? sourceName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final coordText =
        '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              key: coordKey,
              onTap: onFocus,
              child: Text(
                coordText,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          if (sourceName != null) ...[
            FieldAttributionBadge(sourceName: sourceName),
            const SizedBox(width: 4),
          ],
          IconButton(
            key: copyKey,
            icon: const Icon(Icons.copy, size: 18),
            visualDensity: VisualDensity.compact,
            tooltip: MaterialLocalizations.of(context).copyButtonLabel,
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/surface_gps_section_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/surface_gps_section.dart test/features/dive_log/presentation/widgets/surface_gps_section_test.dart
git commit -m "feat(surface-gps): add interactive SurfaceGpsSection widget"
```

---

### Task 6: Wire `SurfaceGpsSection` into the page and remove the old section

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`
- Modify: `test/features/dive_log/presentation/pages/dive_surface_gps_section_test.dart`

- [ ] **Step 1: Add the import**

In `dive_detail_page.dart`, add:

```dart
import 'package:submersion/features/dive_log/presentation/widgets/surface_gps_section.dart';
```

- [ ] **Step 2: Swap the section call**

Replace the call at ~line 338:

```dart
              return _buildSurfaceGpsSection(
                context,
                ref,
                dive,
                units,
                sourceName: showBadges ? attribution['gps'] : null,
              );
```

with:

```dart
              return SurfaceGpsSection(
                dive: dive,
                sourceName: showBadges ? attribution['gps'] : null,
              );
```

- [ ] **Step 3: Delete the old `_buildSurfaceGpsSection` and `_openInMaps` methods**

Delete the entire `Widget _buildSurfaceGpsSection(...) { ... }` method (currently ~lines 1058-1131) and the `Future<void> _openInMaps(GeoPoint point) async { ... }` method (currently ~lines 1133-1141).

- [ ] **Step 4: Run analyze; remove the unused `url_launcher` import if flagged**

Run: `flutter analyze lib/features/dive_log/presentation/pages/dive_detail_page.dart`
Expected: If it reports `unused_import` for `package:url_launcher/url_launcher.dart`, remove that line and re-run. (Search the file for `launchUrl(` / `canLaunchUrl(` first — remove the import only if there are no remaining references.) Expected final: No issues.

- [ ] **Step 5: Update the existing Surface GPS section test**

In `test/features/dive_log/presentation/pages/dive_surface_gps_section_test.dart`:

(a) Add this import near the other `flutter_map`/widget imports:

```dart
import 'package:flutter_map/flutter_map.dart';
```

(b) Replace the first test ("shows drift summary, coordinates and open-in-maps when expanded", currently ~lines 59-73) with:

```dart
  testWidgets('Surface GPS section shows the map, drift and coordinates, and '
      'no Open in Maps button when expanded', (tester) async {
    await _pump(
      tester,
      _gpsDive(
        entry: const GeoPoint(12.34567, 98.76543),
        exit: const GeoPoint(12.34612, 98.76489),
      ),
      expanded: true,
    );

    final section = find.ancestor(
      of: find.text('Surface GPS'),
      matching: find.byType(CollapsibleCardSection),
    );
    expect(
      find.descendant(of: section, matching: find.byType(FlutterMap)),
      findsOneWidget,
    );
    expect(find.textContaining('Drift'), findsWidgets);
    expect(find.text('12.34567, 98.76543'), findsOneWidget);
    expect(find.text('Open in Maps'), findsNothing);
  });
```

(c) Delete the entire last test ("tapping Open in Maps launches an OpenStreetMap url", currently ~lines 162-202) including its `setSurfaceSize`/url_launcher mock setup.

Leave the other three tests ("no Surface GPS section when dive has no GPS", the attribution-badge test, and "exit-only dive shows the exit-only collapsed subtitle") and the "tapping the header toggles..." test unchanged.

- [ ] **Step 6: Run the updated section test and the header test together**

Run: `flutter test test/features/dive_log/presentation/pages/dive_surface_gps_section_test.dart test/features/dive_log/presentation/pages/dive_header_gps_test.dart`
Expected: PASS (all tests in both files). The header still finds exactly one `FlutterMap` because the section content builds lazily when collapsed.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/dive_log/presentation/pages/dive_surface_gps_section_test.dart
git commit -m "feat(surface-gps): use interactive section, remove Open in Maps"
```

---

### Task 7: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Analyze the whole project**

Run: `flutter analyze`
Expected: No issues. (If any unused imports remain in `dive_detail_page.dart`, remove them and re-run.)

- [ ] **Step 2: Format the changed files**

Run: `dart format lib/features/dive_log/presentation/widgets/dive_locations_map.dart lib/features/dive_log/presentation/widgets/surface_gps_section.dart lib/features/dive_log/presentation/pages/dive_locations_map_page.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/dive_log/presentation/widgets/dive_locations_map_test.dart test/features/dive_log/presentation/widgets/surface_gps_section_test.dart test/features/dive_log/presentation/pages/dive_locations_map_page_test.dart test/features/dive_log/presentation/pages/dive_surface_gps_section_test.dart`
Expected: "0 changed" or the files reformatted (commit any changes).

- [ ] **Step 3: Run all touched test files together**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_locations_map_test.dart test/features/dive_log/presentation/widgets/surface_gps_section_test.dart test/features/dive_log/presentation/pages/dive_locations_map_page_test.dart test/features/dive_log/presentation/pages/dive_surface_gps_section_test.dart test/features/dive_log/presentation/pages/dive_header_gps_test.dart`
Expected: All PASS.

- [ ] **Step 4: Commit any formatting changes**

```bash
git add -A
git commit -m "chore(surface-gps): apply dart format" || echo "nothing to format"
```

---

## Self-Review

**Spec coverage:**
- Clickable coordinate links (tap = focus map) → Task 5 (`_GpsCoordinateRow.onFocus` → `_controller.move`). ✓
- Copyable coordinates (copy icon) → Task 5 (`onCopy` → `Clipboard.setData(GeoPoint.toString())` + toast). ✓
- Embedded map with entry/exit/site + dive site coordinates → Tasks 2 + 5. ✓
- Dashed Entry→Exit track line → Task 2 (`PolylineLayer`). ✓
- Fullscreen expand → Tasks 4 + 5 (`_openFullscreen`). ✓
- Remove "Open in Maps" → Task 6 (delete method/button; test asserts absent). ✓
- Marker style: green ↓ / orange ↑ / blue anchor → Task 2. ✓
- Keep both maps; header refactored to share widget; anchor everywhere → Task 3. ✓
- Section visibility gate unchanged (entry||exit) → preserved (call site at ~line 325/338 untouched gate). ✓
- New l10n strings → Task 1. ✓

**Placeholder scan:** No TBD/TODO; every code step contains complete code; every test step has real assertions. ✓

**Type consistency:** `DiveLocationsMap({entry, exit, site, interactive, controller, initialCenter, initialZoom})` used identically in Tasks 2/3/4/5. Marker keys `gps-entry-marker`/`gps-exit-marker`/`gps-site-marker` consistent across Task 2 (definition) and tests. `kGpsEntryColor`/`kGpsExitColor` defined in Task 2, consumed in Task 5. `DiveLocationsMapPage({title, entry, exit, site})` defined in Task 4, used in Task 5. Row test keys (`gps-coord-*`, `gps-copy-*`, `gps-expand`) defined in Task 5 impl and used in Task 5 test. ✓
