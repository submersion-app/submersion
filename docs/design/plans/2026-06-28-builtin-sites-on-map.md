# Built-in Dive Sites on the Sites Map — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an opt-in toggle to the Sites map that overlays recessive, hollow-grey markers for the app's built-in dive-site database alongside the user's own sites, with tap-to-add import and dedup of sites the user already has.

**Architecture:** New small units — a data accessor, a pure dedup function, three providers, a toggle button, and a marker-layer widget — are consumed by the two existing map widgets (`SiteMapPage`, `SiteMapContent`), which each gain only a conditional layer plus a toggle button. Built-in selection is held in each map widget's local `State` (not the shared `mapListSelectionProvider`), keeping the change additive and avoiding ripple into other map sections (`dive-centers`, etc.).

**Tech Stack:** Flutter, Riverpod, flutter_map + flutter_map_marker_cluster, Drift (via existing repositories), latlong2.

## Global Constraints

- Dart must pass `dart format .` with no changes (run before every commit).
- `flutter analyze` must be clean.
- No emojis in code, comments, or docs.
- Immutability: never mutate lists/objects; build new ones.
- Respect the existing in-memory map-toggle convention (`heatMapSettingsProvider` is a non-persisted `StateProvider`); the built-in toggle is likewise non-persisted.
- Dedup "same site" radius = 150 m (the matcher's `SiteMatchSensitivity.balanced` `innerRadiusMeters`).
- l10n: add new keys to the template `lib/l10n/arb/app_en.arb`. Missing keys in other locales fall back to the template at generation time; locale translations are a separate follow-up and are out of scope here.
- Geo helper: `distanceMeters(GeoPoint a, GeoPoint b)` in `lib/core/utils/geo_math.dart`; `GeoPoint(lat, lng)` from `dive_sites/domain/entities/dive_site.dart`.

---

### Task 1: Built-in sites data accessor + provider

**Files:**
- Modify: `lib/features/dive_sites/data/services/dive_site_api_service.dart`
- Create: `lib/features/dive_sites/presentation/providers/built_in_sites_providers.dart`
- Test: `test/features/dive_sites/data/services/dive_site_api_service_built_in_test.dart`

**Interfaces:**
- Consumes: existing `DiveSiteApiService` (with private `_loadBundledSites()` cache) and `diveSiteApiServiceProvider` (in `site_providers.dart`).
- Produces:
  - `Future<List<ExternalDiveSite>> DiveSiteApiService.allSitesWithCoordinates()`
  - `final builtInSitesProvider = FutureProvider<List<ExternalDiveSite>>(...)`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_sites/data/services/dive_site_api_service_built_in_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('allSitesWithCoordinates returns only sites that have coordinates', () async {
    final service = DiveSiteApiService();
    final sites = await service.allSitesWithCoordinates();

    expect(sites, isNotEmpty);
    expect(sites.every((s) => s.hasCoordinates), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/data/services/dive_site_api_service_built_in_test.dart`
Expected: FAIL — `allSitesWithCoordinates` is not defined.

- [ ] **Step 3: Add the accessor**

In `dive_site_api_service.dart`, add a public method to `DiveSiteApiService` (next to `searchSites`):

```dart
  /// All bundled dive sites that have valid coordinates, for map display.
  /// Reuses the [_loadBundledSites] cache so the asset is parsed once.
  Future<List<ExternalDiveSite>> allSitesWithCoordinates() async {
    final sites = await _loadBundledSites();
    return sites.where((s) => s.hasCoordinates).toList();
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/data/services/dive_site_api_service_built_in_test.dart`
Expected: PASS

- [ ] **Step 5: Create the provider**

```dart
// lib/features/dive_sites/presentation/providers/built_in_sites_providers.dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

/// All built-in (bundled) dive sites with coordinates.
/// Static for the app lifetime; loaded once via the service cache.
final builtInSitesProvider = FutureProvider<List<ExternalDiveSite>>((ref) async {
  final service = ref.watch(diveSiteApiServiceProvider);
  return service.allSitesWithCoordinates();
});

/// Whether built-in site markers are shown on the Sites map.
/// In-memory only (matches the heat-map toggle convention); resets each launch.
final showBuiltInSitesProvider = StateProvider<bool>((ref) => false);
```

- [ ] **Step 6: Run format + analyze**

Run: `dart format . && flutter analyze`
Expected: no changes, no issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_sites/data/services/dive_site_api_service.dart \
        lib/features/dive_sites/presentation/providers/built_in_sites_providers.dart \
        test/features/dive_sites/data/services/dive_site_api_service_built_in_test.dart
git commit -m "feat(sites): expose built-in sites accessor and providers"
```

---

### Task 2: Pure dedup function (grid-bucketed)

**Files:**
- Create: `lib/features/dive_sites/domain/services/built_in_site_dedup.dart`
- Test: `test/features/dive_sites/domain/services/built_in_site_dedup_test.dart`

**Interfaces:**
- Consumes: `ExternalDiveSite` (from the api service), `DiveSite` / `GeoPoint`, `distanceMeters`.
- Produces:
  - `List<ExternalDiveSite> visibleBuiltInSites(List<ExternalDiveSite> builtIn, List<DiveSite> userSites, {double radiusMeters = 150})`

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/dive_sites/domain/services/built_in_site_dedup_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/built_in_site_dedup.dart';

ExternalDiveSite ext(String id, double lat, double lng) => ExternalDiveSite(
      externalId: id,
      name: id,
      latitude: lat,
      longitude: lng,
      source: 'test',
    );

DiveSite usr(String id, double lat, double lng) =>
    DiveSite(id: id, name: id, location: GeoPoint(lat, lng));

void main() {
  test('suppresses a built-in coincident with a user site', () {
    final result = visibleBuiltInSites(
      [ext('a', 10.0, 20.0)],
      [usr('u', 10.0, 20.0)],
    );
    expect(result, isEmpty);
  });

  test('keeps a built-in far from any user site', () {
    final result = visibleBuiltInSites(
      [ext('a', 10.0, 20.0)],
      [usr('u', 40.0, 80.0)],
    );
    expect(result.map((s) => s.externalId), ['a']);
  });

  test('keeps a built-in just outside the radius, suppresses just inside', () {
    // ~0.001 deg latitude is ~111 m (inside 150 m);
    // ~0.01 deg latitude is ~1.1 km (outside 150 m).
    final result = visibleBuiltInSites(
      [ext('inside', 10.001, 20.0), ext('outside', 10.01, 20.0)],
      [usr('u', 10.0, 20.0)],
    );
    expect(result.map((s) => s.externalId), ['outside']);
  });

  test('grid-bucketed result equals the naive cross-product', () {
    final builtIn = [
      for (var i = 0; i < 50; i++) ext('b$i', (i % 10) * 1.0, (i ~/ 10) * 1.0),
    ];
    final users = [
      usr('u0', 0.0, 0.0),
      usr('u1', 5.0, 2.0),
      usr('u2', 9.0, 4.0),
    ];
    final fast = visibleBuiltInSites(builtIn, users).map((s) => s.externalId).toSet();
    final naive = builtIn
        .where((b) => !users.any((u) =>
            distanceMetersForTest(b.latitude!, b.longitude!,
                u.location!.latitude, u.location!.longitude) <= 150))
        .map((s) => s.externalId)
        .toSet();
    expect(fast, naive);
  });
}

// Local mirror of the haversine for the equivalence test, so the test does
// not depend on the production grid path.
double distanceMetersForTest(double lat1, double lng1, double lat2, double lng2) {
  return distanceMeters(GeoPoint(lat1, lng1), GeoPoint(lat2, lng2));
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_sites/domain/services/built_in_site_dedup_test.dart`
Expected: FAIL — `visibleBuiltInSites` not defined.

- [ ] **Step 3: Implement the dedup**

```dart
// lib/features/dive_sites/domain/services/built_in_site_dedup.dart
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Returns the built-in sites that are NOT within [radiusMeters] of any user
/// site. User sites are bucketed into a coarse lat/lng grid so each built-in
/// is tested only against user sites in its own and adjacent cells, keeping
/// the cost near-linear instead of |builtIn| x |userSites|.
List<ExternalDiveSite> visibleBuiltInSites(
  List<ExternalDiveSite> builtIn,
  List<DiveSite> userSites, {
  double radiusMeters = 150,
}) {
  // Cell size of 1 degree comfortably exceeds the 150 m radius at any
  // latitude, so a match can only fall in the same or an adjacent cell.
  const cellDeg = 1.0;
  int keyOf(int gx, int gy) => gx * 100000 + gy;

  final grid = <int, List<GeoPoint>>{};
  for (final site in userSites) {
    final loc = site.location;
    if (loc == null) continue;
    final gx = (loc.longitude / cellDeg).floor();
    final gy = (loc.latitude / cellDeg).floor();
    (grid[keyOf(gx, gy)] ??= <GeoPoint>[]).add(loc);
  }

  bool hasNearbyUserSite(double lat, double lng) {
    final gx = (lng / cellDeg).floor();
    final gy = (lat / cellDeg).floor();
    final probe = GeoPoint(lat, lng);
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        final bucket = grid[keyOf(gx + dx, gy + dy)];
        if (bucket == null) continue;
        for (final u in bucket) {
          if (distanceMeters(probe, u) <= radiusMeters) return true;
        }
      }
    }
    return false;
  }

  return builtIn
      .where((b) =>
          b.latitude != null &&
          b.longitude != null &&
          !hasNearbyUserSite(b.latitude!, b.longitude!))
      .toList();
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_sites/domain/services/built_in_site_dedup_test.dart`
Expected: PASS (all 4)

- [ ] **Step 5: Format + analyze**

Run: `dart format . && flutter analyze`
Expected: no changes, no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_sites/domain/services/built_in_site_dedup.dart \
        test/features/dive_sites/domain/services/built_in_site_dedup_test.dart
git commit -m "feat(sites): add grid-bucketed built-in site dedup"
```

---

### Task 3: Visible-built-in provider (compose load + dedup)

**Files:**
- Modify: `lib/features/dive_sites/presentation/providers/built_in_sites_providers.dart`
- Test: `test/features/dive_sites/presentation/providers/visible_built_in_sites_provider_test.dart`

**Interfaces:**
- Consumes: `builtInSitesProvider`, `sitesWithCountsProvider` (returns `List<SiteWithDiveCount>`), `visibleBuiltInSites(...)`.
- Produces: `final visibleBuiltInSitesProvider = FutureProvider<List<ExternalDiveSite>>(...)`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_sites/presentation/providers/visible_built_in_sites_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_sites_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

ExternalDiveSite ext(String id, double lat, double lng) => ExternalDiveSite(
      externalId: id, name: id, latitude: lat, longitude: lng, source: 't');

void main() {
  test('showBuiltInSitesProvider defaults to false', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(showBuiltInSitesProvider), isFalse);
  });

  test('visibleBuiltInSitesProvider removes built-ins matching user sites', () async {
    final container = ProviderContainer(overrides: [
      builtInSitesProvider.overrideWith((ref) async => [
            ext('keep', 50.0, 50.0),
            ext('dupe', 10.0, 20.0),
          ]),
      sitesWithCountsProvider.overrideWith((ref) async => [
            SiteWithDiveCount(
              site: DiveSite(id: 'u', name: 'u', location: GeoPoint(10.0, 20.0)),
              diveCount: 0,
            ),
          ]),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(visibleBuiltInSitesProvider.future);
    expect(result.map((s) => s.externalId), ['keep']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/providers/visible_built_in_sites_provider_test.dart`
Expected: FAIL — `visibleBuiltInSitesProvider` not defined.

- [ ] **Step 3: Add the composing provider**

Append to `built_in_sites_providers.dart` (and add imports for `built_in_site_dedup.dart`):

```dart
import 'package:submersion/features/dive_sites/domain/services/built_in_site_dedup.dart';

/// Built-in sites with the user's already-owned sites deduped out.
/// Recomputes when either the built-in list or the user's sites change.
final visibleBuiltInSitesProvider = FutureProvider<List<ExternalDiveSite>>((ref) async {
  final builtIn = await ref.watch(builtInSitesProvider.future);
  final userSites = await ref.watch(sitesWithCountsProvider.future);
  return visibleBuiltInSites(
    builtIn,
    userSites.map((s) => s.site).toList(),
  );
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/presentation/providers/visible_built_in_sites_provider_test.dart`
Expected: PASS

- [ ] **Step 5: Format + analyze + commit**

```bash
dart format . && flutter analyze
git add lib/features/dive_sites/presentation/providers/built_in_sites_providers.dart \
        test/features/dive_sites/presentation/providers/visible_built_in_sites_provider_test.dart
git commit -m "feat(sites): add deduped visible built-in sites provider"
```

---

### Task 4: Toggle button + l10n strings

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/built_in_sites_toggle_button.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/dive_sites/presentation/widgets/built_in_sites_toggle_button_test.dart`

**Interfaces:**
- Consumes: `showBuiltInSitesProvider`, `context.l10n`.
- Produces: `class BuiltInSitesToggleButton extends ConsumerWidget`.

- [ ] **Step 1: Add l10n keys**

In `lib/l10n/arb/app_en.arb`, add (keep alphabetical grouping near other `diveSites_map_` keys; each string key needs an `@`-metadata sibling per file convention):

```json
  "diveSites_map_builtInSites_show": "Show built-in sites",
  "@diveSites_map_builtInSites_show": { "description": "Tooltip to enable built-in dive site markers on the map" },
  "diveSites_map_builtInSites_hide": "Hide built-in sites",
  "@diveSites_map_builtInSites_hide": { "description": "Tooltip to disable built-in dive site markers on the map" },
  "diveSites_map_builtInSites_on": "Built-in sites shown",
  "@diveSites_map_builtInSites_on": { "description": "Accessibility label when built-in sites are visible" },
  "diveSites_map_builtInSites_off": "Built-in sites hidden",
  "@diveSites_map_builtInSites_off": { "description": "Accessibility label when built-in sites are hidden" },
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: regenerates `lib/l10n/arb/app_localizations.dart` with the four new getters; no errors.

- [ ] **Step 3: Write the failing test**

```dart
// test/features/dive_sites/presentation/widgets/built_in_sites_toggle_button_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_sites_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_sites_toggle_button.dart';

void main() {
  testWidgets('tapping the toggle flips showBuiltInSitesProvider', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: BuiltInSitesToggleButton()),
      ),
    ));

    expect(container.read(showBuiltInSitesProvider), isFalse);
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(container.read(showBuiltInSitesProvider), isTrue);
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/widgets/built_in_sites_toggle_button_test.dart`
Expected: FAIL — `BuiltInSitesToggleButton` not defined.

- [ ] **Step 5: Implement the toggle button**

```dart
// lib/features/dive_sites/presentation/widgets/built_in_sites_toggle_button.dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_sites_providers.dart';

/// Toggle button for showing/hiding built-in dive site markers on the map.
class BuiltInSitesToggleButton extends ConsumerWidget {
  const BuiltInSitesToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(showBuiltInSitesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: show
          ? context.l10n.diveSites_map_builtInSites_on
          : context.l10n.diveSites_map_builtInSites_off,
      toggled: show,
      child: IconButton(
        icon: Icon(
          show ? Icons.public : Icons.public_off,
          color: show ? colorScheme.primary : null,
        ),
        tooltip: show
            ? context.l10n.diveSites_map_builtInSites_hide
            : context.l10n.diveSites_map_builtInSites_show,
        onPressed: () =>
            ref.read(showBuiltInSitesProvider.notifier).state = !show,
      ),
    );
  }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/presentation/widgets/built_in_sites_toggle_button_test.dart`
Expected: PASS

- [ ] **Step 7: Format + analyze + commit**

```bash
dart format . && flutter analyze
git add lib/features/dive_sites/presentation/widgets/built_in_sites_toggle_button.dart \
        lib/l10n/arb/app_en.arb lib/l10n/arb/app_localizations.dart \
        test/features/dive_sites/presentation/widgets/built_in_sites_toggle_button_test.dart
git commit -m "feat(sites): add built-in sites toggle button"
```

---

### Task 5: Recessive built-in marker layer widget

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/built_in_site_marker_layer.dart`
- Test: `test/features/dive_sites/presentation/widgets/built_in_site_marker_layer_test.dart`

**Interfaces:**
- Consumes: `ExternalDiveSite`, `flutter_map`, `flutter_map_marker_cluster`.
- Produces:
  - `class BuiltInSiteMarkerLayer extends StatelessWidget` with
    `BuiltInSiteMarkerLayer({required List<ExternalDiveSite> sites, required String? selectedExternalId, required void Function(ExternalDiveSite) onTap})`
  - The hollow-grey pin is wrapped with `Key('builtInPin_<externalId>')` for test/lookup.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_sites/presentation/widgets/built_in_site_marker_layer_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_site_marker_layer.dart';

ExternalDiveSite ext(String id, double lat, double lng) => ExternalDiveSite(
      externalId: id, name: id, latitude: lat, longitude: lng, source: 't');

Widget _host(Widget layer) => MaterialApp(
      home: Scaffold(
        body: FlutterMap(
          options: const MapOptions(initialCenter: LatLng(10, 20), initialZoom: 8),
          children: [layer],
        ),
      ),
    );

void main() {
  testWidgets('renders a pin per built-in site and reports taps', (tester) async {
    ExternalDiveSite? tapped;
    await tester.pumpWidget(_host(BuiltInSiteMarkerLayer(
      sites: [ext('a', 10.0, 20.0)],
      selectedExternalId: null,
      onTap: (s) => tapped = s,
    )));
    await tester.pump();

    expect(find.byKey(const Key('builtInPin_a')), findsOneWidget);
    await tester.tap(find.byKey(const Key('builtInPin_a')));
    expect(tapped?.externalId, 'a');
  });

  testWidgets('renders nothing when there are no sites', (tester) async {
    await tester.pumpWidget(_host(BuiltInSiteMarkerLayer(
      sites: const [],
      selectedExternalId: null,
      onTap: (_) {},
    )));
    await tester.pump();
    expect(find.byKey(const Key('builtInPin_a')), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/widgets/built_in_site_marker_layer_test.dart`
Expected: FAIL — `BuiltInSiteMarkerLayer` not defined.

- [ ] **Step 3: Implement the layer**

```dart
// lib/features/dive_sites/presentation/widgets/built_in_site_marker_layer.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';

/// A recessive marker-cluster layer for built-in (bundled) dive sites.
/// Rendered BELOW the user-site layer and clustered separately, so built-in
/// markers never merge into the user's clusters. Markers are hollow grey pins,
/// smaller than the user's filled circles.
class BuiltInSiteMarkerLayer extends StatelessWidget {
  final List<ExternalDiveSite> sites;
  final String? selectedExternalId;
  final void Function(ExternalDiveSite) onTap;

  const BuiltInSiteMarkerLayer({
    super.key,
    required this.sites,
    required this.selectedExternalId,
    required this.onTap,
  });

  static const _grey = Color(0xFF607D8B); // muted slate-grey

  @override
  Widget build(BuildContext context) {
    if (sites.isEmpty) return const SizedBox.shrink();

    return MarkerClusterLayerWidget(
      options: MarkerClusterLayerOptions(
        maxClusterRadius: 80,
        size: const Size(40, 40),
        markers: sites.map((site) {
          final selected = site.externalId == selectedExternalId;
          return Marker(
            point: LatLng(site.latitude!, site.longitude!),
            width: selected ? 34 : 28,
            height: selected ? 40 : 34,
            child: GestureDetector(
              key: Key('builtInPin_${site.externalId}'),
              onTap: () => onTap(site),
              child: Icon(
                Icons.location_on_outlined,
                size: selected ? 36 : 30,
                color: selected ? Theme.of(context).colorScheme.primary : _grey,
              ),
            ),
          );
        }).toList(),
        builder: (context, markers) => _cluster(markers.length),
        zoomToBoundsOnClick: true,
      ),
    );
  }

  Widget _cluster(int count) {
    return Container(
      decoration: BoxDecoration(
        color: _grey.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Center(
        child: Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/presentation/widgets/built_in_site_marker_layer_test.dart`
Expected: PASS (both)

- [ ] **Step 5: Format + analyze + commit**

```bash
dart format . && flutter analyze
git add lib/features/dive_sites/presentation/widgets/built_in_site_marker_layer.dart \
        test/features/dive_sites/presentation/widgets/built_in_site_marker_layer_test.dart
git commit -m "feat(sites): add recessive built-in site marker layer"
```

---

### Task 6: Built-in info card with "Add to my sites"

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/built_in_site_info_card.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/dive_sites/presentation/widgets/built_in_site_info_card_test.dart`

**Interfaces:**
- Consumes: `ExternalDiveSite`, `MapInfoCard` (`lib/shared/widgets/map_list_layout/map_info_card.dart`), `context.l10n`.
- Produces: `class BuiltInSiteInfoCard extends StatelessWidget` with
  `BuiltInSiteInfoCard({required ExternalDiveSite site, required Future<void> Function() onAdd})`.

- [ ] **Step 1: Add l10n keys**

In `lib/l10n/arb/app_en.arb`:

```json
  "diveSites_map_builtInSites_add": "Add to my sites",
  "@diveSites_map_builtInSites_add": { "description": "Button to import a built-in dive site into the user's library" },
  "diveSites_map_builtInSites_added": "Added to your sites",
  "@diveSites_map_builtInSites_added": { "description": "Snackbar confirmation after importing a built-in site" },
```

Run: `flutter gen-l10n`
Expected: two new getters generated.

- [ ] **Step 2: Write the failing test**

```dart
// test/features/dive_sites/presentation/widgets/built_in_site_info_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_site_info_card.dart';

void main() {
  testWidgets('shows the site name and calls onAdd when the add button is tapped',
      (tester) async {
    var addCalls = 0;
    final site = ExternalDiveSite(
      externalId: 'x', name: 'Blue Hole', country: 'Belize',
      latitude: 17.3, longitude: -87.5, source: 't');

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BuiltInSiteInfoCard(
          site: site,
          onAdd: () async => addCalls++,
        ),
      ),
    ));

    expect(find.text('Blue Hole'), findsOneWidget);
    await tester.tap(find.text('Add to my sites'));
    await tester.pump();
    expect(addCalls, 1);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/widgets/built_in_site_info_card_test.dart`
Expected: FAIL — `BuiltInSiteInfoCard` not defined.

- [ ] **Step 4: Implement the info card**

```dart
// lib/features/dive_sites/presentation/widgets/built_in_site_info_card.dart
import 'package:flutter/material.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';

/// Info card shown when a built-in (bundled) site marker is tapped.
/// Offers a primary "Add to my sites" action that imports the site.
class BuiltInSiteInfoCard extends StatelessWidget {
  final ExternalDiveSite site;
  final Future<void> Function() onAdd;

  const BuiltInSiteInfoCard({super.key, required this.site, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = [site.region, site.country]
        .where((e) => e != null && e.isNotEmpty)
        .join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(site.name, style: theme.textTheme.titleMedium),
            if (location.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(location, style: theme.textTheme.bodySmall),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.add_location_alt, size: 18),
                label: Text(context.l10n.diveSites_map_builtInSites_add),
                onPressed: onAdd,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/presentation/widgets/built_in_site_info_card_test.dart`
Expected: PASS

- [ ] **Step 6: Format + analyze + commit**

```bash
dart format . && flutter analyze
git add lib/features/dive_sites/presentation/widgets/built_in_site_info_card.dart \
        lib/l10n/arb/app_en.arb lib/l10n/arb/app_localizations.dart \
        test/features/dive_sites/presentation/widgets/built_in_site_info_card_test.dart
git commit -m "feat(sites): add built-in site info card with add action"
```

---

### Task 7: Wire built-in layer into `SiteMapPage`

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_map_page.dart`
- Test: `test/features/dive_sites/presentation/pages/site_map_page_built_in_test.dart`

**Interfaces:**
- Consumes: `showBuiltInSitesProvider`, `visibleBuiltInSitesProvider`, `BuiltInSitesToggleButton`, `BuiltInSiteMarkerLayer`, `BuiltInSiteInfoCard`, `siteListNotifierProvider`, `sitesWithCountsProvider`.
- Produces: behavior only (no new exported symbols).

Local state added to `_SiteMapPageState`: `String? _selectedBuiltInId;` and a `Future<void> _addBuiltInSite(ExternalDiveSite site)` helper.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_sites/presentation/pages/site_map_page_built_in_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_sites_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_map_page.dart';

// NOTE: this test exercises only the built-in layer's presence under the
// toggle, using overrides for the data providers so no database is needed.
void main() {
  testWidgets('built-in pins appear only when the toggle is on', (tester) async {
    final container = ProviderContainer(overrides: [
      sitesWithCountsProvider.overrideWith((ref) async => []),
      visibleBuiltInSitesProvider.overrideWith((ref) async => [
            ExternalDiveSite(
                externalId: 'a', name: 'A', latitude: 10, longitude: 20, source: 't'),
          ]),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SiteMapPage(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('builtInPin_a')), findsNothing);

    container.read(showBuiltInSitesProvider.notifier).state = true;
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('builtInPin_a')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/pages/site_map_page_built_in_test.dart`
Expected: FAIL — no built-in pin rendered (layer not wired).

- [ ] **Step 3: Add imports and local state**

At the top of `site_map_page.dart`, add imports:

```dart
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_sites_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_site_marker_layer.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_site_info_card.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_sites_toggle_button.dart';
```

In `_SiteMapPageState`, add a field after `_mapController`:

```dart
  String? _selectedBuiltInId;
```

- [ ] **Step 4: Add the toggle button to the actions row**

In `build`, in the `actions:` list, add as the first action (before `HeatMapToggleButton`):

```dart
        const BuiltInSitesToggleButton(),
```

- [ ] **Step 5: Add the built-in layer below the user markers**

In `_buildMap`, inside the `FlutterMap` `children:` list, insert this BEFORE the existing `MarkerClusterLayerWidget` (so built-in pins render underneath the user's), wrapped in a `Consumer`:

```dart
              Consumer(
                builder: (context, ref, _) {
                  final show = ref.watch(showBuiltInSitesProvider);
                  if (!show) return const SizedBox.shrink();
                  final builtInAsync = ref.watch(visibleBuiltInSitesProvider);
                  return builtInAsync.maybeWhen(
                    data: (builtIn) => BuiltInSiteMarkerLayer(
                      sites: builtIn,
                      selectedExternalId: _selectedBuiltInId,
                      onTap: (site) {
                        ref
                            .read(mapListSelectionProvider('sites').notifier)
                            .deselect();
                        setState(() => _selectedBuiltInId = site.externalId);
                        _animateToLocation(site.latitude!, site.longitude!);
                      },
                    ),
                    orElse: () => const SizedBox.shrink(),
                  );
                },
              ),
```

- [ ] **Step 6: Clear built-in selection on map tap and own-marker tap**

In `MapOptions.onTap`, after the existing `deselect()` call, add:

```dart
                setState(() => _selectedBuiltInId = null);
```

In `_onMarkerTapped`, at the start of the method, add:

```dart
    setState(() => _selectedBuiltInId = null);
```

- [ ] **Step 7: Render the built-in info card and add helper**

In `build`, change the `infoCard:` argument to prefer the built-in card when a built-in site is selected:

```dart
      infoCard: _selectedBuiltInId != null
          ? _buildBuiltInInfoCard(context)
          : (selectedSite != null
              ? _buildMapInfoCard(context, selectedSite)
              : null),
```

Add these methods to `_SiteMapPageState`:

```dart
  Widget? _buildBuiltInInfoCard(BuildContext context) {
    final async = ref.watch(visibleBuiltInSitesProvider);
    final site = async.maybeWhen(
      data: (list) =>
          list.where((s) => s.externalId == _selectedBuiltInId).firstOrNull,
      orElse: () => null,
    );
    if (site == null) return null;
    return BuiltInSiteInfoCard(site: site, onAdd: () => _addBuiltInSite(site));
  }

  Future<void> _addBuiltInSite(ExternalDiveSite site) async {
    await ref.read(siteListNotifierProvider.notifier).addSite(site.toDiveSite());
    // addSite reloads the notifier but not the map's FutureProvider; invalidate
    // so the new site appears and the built-in duplicate is deduped out.
    ref.invalidate(sitesWithCountsProvider);
    if (!mounted) return;
    setState(() => _selectedBuiltInId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.diveSites_map_builtInSites_added)),
    );
  }
```

- [ ] **Step 8: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/presentation/pages/site_map_page_built_in_test.dart`
Expected: PASS

- [ ] **Step 9: Run the full dive_sites test suite, format, analyze**

Run: `flutter test test/features/dive_sites/ && dart format . && flutter analyze`
Expected: all pass, no changes, no issues.

- [ ] **Step 10: Commit**

```bash
git add lib/features/dive_sites/presentation/pages/site_map_page.dart \
        test/features/dive_sites/presentation/pages/site_map_page_built_in_test.dart
git commit -m "feat(sites): show built-in sites on the full-page Sites map"
```

---

### Task 8: Wire built-in layer into `SiteMapContent`

**Files:**
- Modify: `lib/features/dive_sites/presentation/widgets/site_map_content.dart`
- Test: `test/features/dive_sites/presentation/widgets/site_map_content_built_in_test.dart`

**Interfaces:**
- Consumes: same set as Task 7. Mirrors the wiring in the embeddable pane.
- Produces: behavior only.

Local state added to `_SiteMapContentState`: `String? _selectedBuiltInId;` and `Future<void> _addBuiltInSite(ExternalDiveSite site)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_sites/presentation/widgets/site_map_content_built_in_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_sites_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_map_content.dart';

void main() {
  testWidgets('built-in pins appear only when the toggle is on', (tester) async {
    final container = ProviderContainer(overrides: [
      sitesWithCountsProvider.overrideWith((ref) async => []),
      visibleBuiltInSitesProvider.overrideWith((ref) async => [
            ExternalDiveSite(
                externalId: 'a', name: 'A', latitude: 10, longitude: 20, source: 't'),
          ]),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SiteMapContent(onItemSelected: (_) {}),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('builtInPin_a')), findsNothing);

    container.read(showBuiltInSitesProvider.notifier).state = true;
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('builtInPin_a')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/widgets/site_map_content_built_in_test.dart`
Expected: FAIL — no built-in pin (layer not wired).

- [ ] **Step 3: Add imports and local state**

Add the same five imports as Task 7 Step 3 to `site_map_content.dart`. In `_SiteMapContentState`, add after `_mapReady`:

```dart
  String? _selectedBuiltInId;
```

- [ ] **Step 4: Add the toggle button to the controls overlay**

In `_buildMapWithInfoCard`, inside the controls `Row` (the `Card` at top-right), add as the first child, before `HeatMapToggleButton`:

```dart
                  const BuiltInSitesToggleButton(),
```

- [ ] **Step 5: Add the built-in layer below the user markers**

In `_buildMap`, in the `FlutterMap` `children:` list, insert BEFORE the existing `MarkerClusterLayerWidget`:

```dart
              Consumer(
                builder: (context, ref, _) {
                  final show = ref.watch(showBuiltInSitesProvider);
                  if (!show) return const SizedBox.shrink();
                  final builtInAsync = ref.watch(visibleBuiltInSitesProvider);
                  return builtInAsync.maybeWhen(
                    data: (builtIn) => BuiltInSiteMarkerLayer(
                      sites: builtIn,
                      selectedExternalId: _selectedBuiltInId,
                      onTap: (site) {
                        widget.onItemSelected(null);
                        setState(() => _selectedBuiltInId = site.externalId);
                        _animateToLocation(
                          LatLng(site.latitude!, site.longitude!),
                        );
                      },
                    ),
                    orElse: () => const SizedBox.shrink(),
                  );
                },
              ),
```

- [ ] **Step 6: Clear built-in selection on map tap and own-marker tap**

In `MapOptions.onTap`, after `widget.onItemSelected(null);`, add:

```dart
                setState(() => _selectedBuiltInId = null);
```

In `_onMarkerTapped`, at the start, add:

```dart
    setState(() => _selectedBuiltInId = null);
```

- [ ] **Step 7: Render the built-in info card and add helper**

In `_buildMapWithInfoCard`, replace the `if (selectedSite != null)` info-card block's condition so the built-in card takes precedence. Add this just before that block:

```dart
        if (_selectedBuiltInId != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: _buildBuiltInInfoCard(context) ?? const SizedBox.shrink(),
              ),
            ),
          ),
```

Add these methods to `_SiteMapContentState`:

```dart
  Widget? _buildBuiltInInfoCard(BuildContext context) {
    final async = ref.watch(visibleBuiltInSitesProvider);
    final site = async.maybeWhen(
      data: (list) =>
          list.where((s) => s.externalId == _selectedBuiltInId).firstOrNull,
      orElse: () => null,
    );
    if (site == null) return null;
    return BuiltInSiteInfoCard(site: site, onAdd: () => _addBuiltInSite(site));
  }

  Future<void> _addBuiltInSite(ExternalDiveSite site) async {
    await ref.read(siteListNotifierProvider.notifier).addSite(site.toDiveSite());
    ref.invalidate(sitesWithCountsProvider);
    if (!mounted) return;
    setState(() => _selectedBuiltInId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.diveSites_map_builtInSites_added)),
    );
  }
```

Add the import for `siteListNotifierProvider` if not already present: it lives in `site_providers.dart` (already imported in this file). Add `import 'package:submersion/l10n/l10n_extension.dart';` if not present (it is).

- [ ] **Step 8: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/presentation/widgets/site_map_content_built_in_test.dart`
Expected: PASS

- [ ] **Step 9: Run the full dive_sites suite, format, analyze**

Run: `flutter test test/features/dive_sites/ && dart format . && flutter analyze`
Expected: all pass, no changes, no issues.

- [ ] **Step 10: Commit**

```bash
git add lib/features/dive_sites/presentation/widgets/site_map_content.dart \
        test/features/dive_sites/presentation/widgets/site_map_content_built_in_test.dart
git commit -m "feat(sites): show built-in sites on the embedded Sites map pane"
```

---

### Task 9: Full-suite verification

**Files:** none (verification only).

- [ ] **Step 1: Run the entire test suite**

Run: `flutter test`
Expected: all pass.

- [ ] **Step 2: Format + analyze the whole project**

Run: `dart format . && flutter analyze`
Expected: no changes, no issues. (Format the whole repo, not a subdir — CI checks the whole project.)

- [ ] **Step 3: Manual device smoke test (macOS)**

Run: `flutter run -d macos`
Verify: Sites map → toggle the globe icon on → grey hollow pins appear; tap one → info card with "Add to my sites"; tap Add → pin becomes your colored marker and the grey pin disappears; toggle off → grey pins gone. Confirm both the full-page map and the master-detail pane.

---

## Self-Review

**Spec coverage:**
- Data accessor + `builtInSitesProvider` → Task 1.
- Toggle (`showBuiltInSitesProvider`, button, l10n) → Tasks 1, 4.
- Dedup (`visibleBuiltInSites` + `visibleBuiltInSitesProvider`, 150 m, grid) → Tasks 2, 3.
- Recessive hollow-grey marker layer, separate cluster, below user layer → Task 5, wired in 7/8.
- Tap → info card → "Add to my sites" → repo create + invalidate → Tasks 6, 7, 8.
- Both map widgets updated → Tasks 7, 8.
- Selection model: implemented as local widget state (refinement over the spec's shared-type idea, to avoid rippling into other map sections) → Tasks 7, 8.
- Tests across data/provider/widget/add-flow → every task; full suite → Task 9.

**Placeholder scan:** No TBD/TODO; every code step shows full code; l10n values are real strings.

**Type consistency:** `allSitesWithCoordinates()`, `visibleBuiltInSites(builtIn, userSites, {radiusMeters})`, `builtInSitesProvider`, `showBuiltInSitesProvider`, `visibleBuiltInSitesProvider`, `BuiltInSitesToggleButton`, `BuiltInSiteMarkerLayer({sites, selectedExternalId, onTap})`, `BuiltInSiteInfoCard({site, onAdd})`, and the `Key('builtInPin_<externalId>')` are used identically across all tasks.

**Note on the spec's selection model:** The spec proposed a typed `MapSiteSelection { kind, id }` on the shared selection provider. During planning, that provider proved to be shared across map sections (`sites`, `dive-centers`), so the plan instead holds built-in selection in each map widget's local `State` — strictly additive and equivalent in behavior. This is a deliberate, documented divergence.
