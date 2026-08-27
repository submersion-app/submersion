# Dive-GPS-anchored Site Picker + Seeded New-Site Creation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In the dive edit form, anchor the site picker's distance/sort on the edited dive's own GPS (entry, else exit) and seed the "New Dive Site" form with those coordinates + a best-effort reverse-geocode — while GPS-less dives behave exactly as today.

**Architecture:** Most machinery already exists in `SitePickerSheet` (distance, sort, header, "New Dive Site" button), keyed on a single nullable anchor. We (1) add an auto-scaling, unit-aware distance formatter, (2) add two localized strings, (3) re-point the picker's anchor to a new `diveLocation` param, (4) let `SiteEditPage` accept + seed an `initialLocation` (with geocode) reachable through the `/sites/new` route's `extra`, and (5) wire the dive edit page to feed both. No DB/schema change.

**Tech Stack:** Flutter, Riverpod (StateNotifierProvider), go_router, Drift (unchanged here), Flutter gen-l10n (ARB).

## Global Constraints

- Displayed distances MUST respect the diver's unit settings (metric/imperial derived from `settings.depthUnit`). (CLAUDE.md units rule.)
- New user-facing strings go into `app_en.arb` **and all 10 non-English locales** (`ar, de, es, fr, he, hu, it, nl, pt, zh`), then regenerate with `flutter gen-l10n`.
- No emojis in code/comments. Immutability preserved. Proper error handling.
- `dart format .` must leave the whole repo unchanged before any commit.
- TDD: failing test first, minimal implementation, green, commit.
- Metric distance output MUST stay byte-identical to today (see Task 1 note); only imperial is additive.
- Anchor resolution is always `diveLocation ?? currentLocation` so a GPS-less dive passes today's device value through untouched.

---

### Task 1: Auto-scaling, unit-aware geo-distance formatter

**Files:**
- Modify: `lib/core/utils/unit_formatter.dart` (add method after `formatDistance`, ~`:44`)
- Test: `test/core/utils/unit_formatter_distance_test.dart` (append)

**Interfaces:**
- Produces: `String UnitFormatter.formatGeoDistance(double meters)` — returns value + latin unit (`"556 m"`, `"5.6 km"`, `"394 ft"`, `"2.0 mi"`), scaling by magnitude and metric/imperial preference. Consumed by Task 3.

- [ ] **Step 1: Write the failing tests**

Append inside `main()` of `test/core/utils/unit_formatter_distance_test.dart`:

```dart
  group('formatGeoDistance', () {
    const metric = UnitFormatter(AppSettings(depthUnit: DepthUnit.meters));
    const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));

    test('metric scales meters to km', () {
      expect(metric.formatGeoDistance(120), '120 m');
      expect(metric.formatGeoDistance(999), '999 m');
      expect(metric.formatGeoDistance(1000), '1.0 km');
      expect(metric.formatGeoDistance(5560), '5.6 km');
      expect(metric.formatGeoDistance(23400), '23 km');
    });

    test('imperial scales feet to miles', () {
      expect(imperial.formatGeoDistance(120), '394 ft');
      expect(imperial.formatGeoDistance(1000), '3281 ft');
      expect(imperial.formatGeoDistance(3218.688), '2.0 mi');
      expect(imperial.formatGeoDistance(160934), '100 mi');
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/unit_formatter_distance_test.dart`
Expected: FAIL — `formatGeoDistance` is not defined.

- [ ] **Step 3: Add the implementation**

In `lib/core/utils/unit_formatter.dart`, immediately after the existing `formatDistance` method (closing brace at ~`:44`), add:

```dart
  /// Format a geographic distance (meters) for site lists and pickers.
  ///
  /// Unlike [formatDistance] (depth-unit m/ft, for short surface drift), this
  /// auto-scales across the full range of site distances and respects the
  /// diver's metric/imperial preference (derived from depth unit): metric -> m
  /// under 1 km else km; imperial -> ft under 1 mile else mi. Unit symbols are
  /// latin (m/km/ft/mi), consistent with [formatDepth].
  String formatGeoDistance(double meters) {
    final isMetric = settings.depthUnit == DepthUnit.meters;
    if (isMetric) {
      if (meters < 1000) return '${meters.round()} m';
      final km = meters / 1000;
      final text = km < 10 ? km.toStringAsFixed(1) : km.round().toString();
      return '$text km';
    }
    final feet = meters * 3.28084;
    const feetPerMile = 5280.0;
    if (feet < feetPerMile) return '${feet.round()} ft';
    final miles = feet / feetPerMile;
    final text = miles < 10 ? miles.toStringAsFixed(1) : miles.round().toString();
    return '$text mi';
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/utils/unit_formatter_distance_test.dart`
Expected: PASS.

- [ ] **Step 5: Format + commit**

```bash
dart format lib/core/utils/unit_formatter.dart test/core/utils/unit_formatter_distance_test.dart
git add lib/core/utils/unit_formatter.dart test/core/utils/unit_formatter_distance_test.dart
git commit -m "feat(units): add auto-scaling unit-aware formatGeoDistance"
```

---

### Task 2: Localized strings (header + distance wrapper)

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (add 2 keys + metadata)
- Modify: `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb` (add 2 keys each, value-only)
- Generated: `lib/l10n/arb/app_localizations*.dart` via `flutter gen-l10n`

**Interfaces:**
- Produces: `context.l10n.diveLog_sitePicker_sortedByDiveDistance` (no args) and `context.l10n.diveLog_sitePicker_distanceAway(String distance)`. Consumed by Task 3.

- [ ] **Step 1: Add English keys + metadata**

In `lib/l10n/arb/app_en.arb`, add the value keys next to the existing `diveLog_sitePicker_*` entries (alphabetical block around `:2746`):

```json
  "diveLog_sitePicker_distanceAway": "{distance} away",
  "diveLog_sitePicker_sortedByDiveDistance": "Sorted by distance from this dive",
```

And add metadata next to the existing `@diveLog_sitePicker_*` block (around `:3328`):

```json
  "@diveLog_sitePicker_distanceAway": {
    "description": "A site's distance from the reference point; {distance} already includes the unit, e.g. '1.2 km' or '800 ft'",
    "placeholders": {
      "distance": { "type": "String", "example": "1.2 km" }
    }
  },
  "@diveLog_sitePicker_sortedByDiveDistance": {
    "description": "Site picker header shown when sites are sorted by distance from the edited dive's GPS position"
  },
```

- [ ] **Step 2: Add translations to all non-English locales (value-only)**

Add these two keys to each locale ARB. Values mirror each locale's existing `diveLog_sitePicker_distanceKm` / `diveLog_sitePicker_sortedByDistance` phrasing (`{distance}` now carries the unit, so drop the hard-coded "km"). Native review welcome before merge:

| locale | `diveLog_sitePicker_distanceAway` | `diveLog_sitePicker_sortedByDiveDistance` |
|---|---|---|
| ar | `"{distance} بعيداً"` | `"مرتبة حسب المسافة من هذه الغطسة"` |
| de | `"{distance} entfernt"` | `"Nach Entfernung zu diesem Tauchgang sortiert"` |
| es | `"a {distance}"` | `"Ordenados por distancia a esta inmersión"` |
| fr | `"à {distance}"` | `"Trié par distance à cette plongée"` |
| he | `"{distance} משם"` | `"ממוין לפי מרחק מהצלילה הזו"` |
| hu | `"{distance} távolságra"` | `"Távolság szerint rendezve ettől a merüléstől"` |
| it | `"{distance} di distanza"` | `"Ordinati per distanza da questa immersione"` |
| nl | `"{distance} afstand"` | `"Gesorteerd op afstand tot deze duik"` |
| pt | `"{distance} de distância"` | `"Ordenado por distância deste mergulho"` |
| zh | `"距离 {distance}"` | `"按与本次潜水的距离排序"` |

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: no errors; `app_localizations.dart` now declares `diveLog_sitePicker_sortedByDiveDistance` and `diveLog_sitePicker_distanceAway(String distance)`.

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze lib/l10n`
Expected: no new issues.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/arb/
git commit -m "i18n(site-picker): add dive-distance header + distance-away strings"
```

---

### Task 3: Anchor the picker on the dive's GPS (unit-aware, dive-labelled)

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/pickers/site_picker_sheet.dart`
- Test: `test/features/dive_log/presentation/widgets/pickers/site_picker_sheet_test.dart`

**Interfaces:**
- Consumes: `UnitFormatter.formatGeoDistance` (Task 1); `diveLog_sitePicker_sortedByDiveDistance` / `diveLog_sitePicker_distanceAway` (Task 2); `distanceMeters(GeoPoint, GeoPoint)` from `lib/core/utils/geo_math.dart:10`.
- Produces: `SitePickerSheet(... GeoPoint? diveLocation)` — new optional param. Consumed by Task 5.

- [ ] **Step 1: Update the test harness + write failing tests**

In `site_picker_sheet_test.dart`, add imports at top:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
```

Add a test settings notifier (mirrors `test/l10n/localization_test.dart:326`; note the explicit `super(initial)` — `StateNotifier`'s positional param is private, so a `super.` parameter will not compile) above `_pump`:

```dart
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(AppSettings initial) : super(initial);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

Replace the `_pump` helper to add `diveLocation` + a settings override:

```dart
Future<void> _pump(
  WidgetTester tester, {
  required List<DiveSite> sites,
  LocationResult? currentLocation,
  GeoPoint? diveLocation,
  AppSettings settings = const AppSettings(),
  String? selectedSiteId,
  void Function(DiveSite)? onSiteSelected,
  VoidCallback? onCreateNewSite,
}) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sitesProvider.overrideWith((ref) async => sites),
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SitePickerSheet(
            scrollController: ScrollController(),
            selectedSiteId: selectedSiteId,
            currentLocation: currentLocation,
            diveLocation: diveLocation,
            onSiteSelected: onSiteSelected ?? (_) {},
            onCreateNewSite: onCreateNewSite ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
```

Add new tests inside `main()`:

```dart
  testWidgets('sorts by diveLocation when provided', (tester) async {
    await _pump(
      tester,
      sites: const [_farSite, _nearSite, _midSite],
      diveLocation: const GeoPoint(10.0, 10.0),
    );
    expect(_tileTitles(tester), ['House Reef', 'Channel', 'Blue Hole']);
    expect(find.text('Sorted by distance from this dive'), findsOneWidget);
  });

  testWidgets('falls back to currentLocation when diveLocation is null',
      (tester) async {
    await _pump(
      tester,
      sites: const [_farSite, _nearSite, _midSite],
      currentLocation: _here,
    );
    expect(_tileTitles(tester), ['House Reef', 'Channel', 'Blue Hole']);
    expect(find.text('Sorted by distance'), findsOneWidget);
    expect(find.text('Sorted by distance from this dive'), findsNothing);
  });

  testWidgets('distance readout respects imperial units', (tester) async {
    await _pump(
      tester,
      sites: const [_farSite],
      diveLocation: const GeoPoint(10.0, 10.0),
      settings: const AppSettings(depthUnit: DepthUnit.feet),
    );
    expect(find.textContaining('mi'), findsWidgets);
    expect(find.textContaining('km'), findsNothing);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/pickers/site_picker_sheet_test.dart`
Expected: FAIL — `diveLocation` is not a parameter of `SitePickerSheet`.

- [ ] **Step 3: Add the `diveLocation` param + imports**

In `site_picker_sheet.dart`, add imports (keep `location_service.dart` for `LocationResult`):

```dart
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
```

Add the field + constructor param (after `currentLocation`, `:16`/`:24`):

```dart
  final LocationResult? currentLocation;
  final GeoPoint? diveLocation;
```
```dart
    this.currentLocation,
    this.diveLocation,
```

- [ ] **Step 4: Resolve the anchor + switch distance to meters via geo_math**

Replace `_distanceToSite` (`:43-53`) with a resolved-anchor version returning **meters**:

```dart
  /// The point distances are measured from: the dive's GPS if present,
  /// otherwise the device location (today's behavior).
  GeoPoint? get _anchor {
    if (widget.diveLocation != null) return widget.diveLocation;
    final cl = widget.currentLocation;
    return cl == null ? null : GeoPoint(cl.latitude, cl.longitude);
  }

  /// Distance from the resolved anchor to a site, in meters.
  double? _distanceToSite(DiveSite site) {
    final anchor = _anchor;
    if (anchor == null || site.location == null) return null;
    return distanceMeters(anchor, site.location!);
  }
```

- [ ] **Step 5: Replace `_formatDistance` with the unit-aware wrapper**

Replace `_formatDistance` (`:55-64`) with:

```dart
  /// Format a site distance (meters) for display, unit-aware.
  String _formatDistance(BuildContext context, UnitFormatter units, double m) {
    return context.l10n.diveLog_sitePicker_distanceAway(
      units.formatGeoDistance(m),
    );
  }
```

- [ ] **Step 6: Update `build` — units, header, sort, list, nearby**

After `final sitesAsync = ref.watch(sitesProvider);` add:

```dart
    final units = UnitFormatter(ref.watch(settingsProvider));
```

Change the header condition (`:86`) from `if (widget.currentLocation != null)` to a dive-aware block:

```dart
                  if (_anchor != null)
                    Row(
                      children: [
                        Icon(
                          widget.diveLocation != null
                              ? Icons.place
                              : Icons.my_location,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.diveLocation != null
                              ? context.l10n.diveLog_sitePicker_sortedByDiveDistance
                              : context.l10n.diveLog_sitePicker_sortedByDistance,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.primary),
                        ),
                      ],
                    ),
```

Change the sort gate (`:189`) from `if (widget.currentLocation != null)` to `if (_anchor != null)` (inner sort logic and `_SiteWithDistance` unchanged — `distance` now holds meters).

Change `isNearby` (`:236`) to meters:

```dart
                  final isNearby =
                      distance != null && distance < 50000; // within 50 km
```

Change the distance subtitle (`:260-270`) to the unit-aware formatter:

```dart
                        if (distance != null)
                          Text(
                            _formatDistance(context, units, distance),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isNearby
                                      ? colorScheme.tertiary
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: isNearby ? FontWeight.w600 : null,
                                ),
                          ),
```

`LocationService.instance` is no longer called; the `location_service.dart` import stays for `LocationResult`.

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/pickers/site_picker_sheet_test.dart`
Expected: PASS (new tests + all pre-existing tests, whose metric strings are byte-identical).

- [ ] **Step 8: Format + commit**

```bash
dart format lib/features/dive_log/presentation/widgets/pickers/site_picker_sheet.dart test/features/dive_log/presentation/widgets/pickers/site_picker_sheet_test.dart
git add lib/features/dive_log/presentation/widgets/pickers/site_picker_sheet.dart test/features/dive_log/presentation/widgets/pickers/site_picker_sheet_test.dart
git commit -m "feat(site-picker): anchor distance/sort on dive GPS, unit-aware readout"
```

---

### Task 4: Seed `SiteEditPage` from `initialLocation` (+ router `extra`)

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart`
- Modify: `lib/core/router/app_router.dart:379`
- Test: `test/features/dive_sites/presentation/pages/site_edit_seed_location_test.dart` (create)

**Interfaces:**
- Consumes: `GeoPoint`; `locationServiceProvider` → `reverseGeocode` (`lib/core/services/location_service.dart:188`).
- Produces: `SiteEditPage(... GeoPoint? initialLocation)`; the `/sites/new` route maps a `GeoPoint` `state.extra` into it. Consumed by Task 5.

**Testing note:** the Location `FormSection` is collapsed by default for new sites (`_siteSectionExpanded('location') == false`, `site_edit_page.dart:524`). Its collapsed summary renders exactly `"{lat}, {lng}"` (`_locationSummary`, `:573-579`), which is the stable assertion target — do not assert on the individual (unbuilt) lat/lng fields.

- [ ] **Step 1: Write the failing test file**

Create `test/features/dive_sites/presentation/pages/site_edit_seed_location_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

/// Records the coordinates it was asked to reverse-geocode and returns a fixed
/// placemark, so tests can prove the seed path fires geocoding. (The
/// fill-only-empty write of country/region is already covered by the existing
/// site_edit_page_test.dart geocode tests.)
class _RecordingLocationService implements LocationService {
  ({double lat, double lng})? geocodedWith;

  @override
  Future<({String? country, String? region, String? locality})> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    geocodedWith = (lat: latitude, lng: longitude);
    return (country: 'Testland', region: 'Test Region', locality: null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Diver> _divers() => [
      Diver(
        id: 'd1',
        name: 'Me',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    ];

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  testWidgets('seeds coordinates and fires geocoding from initialLocation',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final geocoder = _RecordingLocationService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allDiversProvider.overrideWith((_) async => _divers()),
          shareByDefaultProvider.overrideWith((_) async => false),
          locationServiceProvider.overrideWithValue(geocoder),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SiteEditPage(initialLocation: GeoPoint(34.0182, -118.4965)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Location section is collapsed by default; its summary is "{lat}, {lng}".
    expect(find.text('34.018200, -118.496500'), findsOneWidget);
    // Seeding fired a reverse-geocode for exactly those coordinates.
    expect(geocoder.geocodedWith, isNotNull);
    expect(geocoder.geocodedWith!.lat, closeTo(34.0182, 1e-9));
    expect(geocoder.geocodedWith!.lng, closeTo(-118.4965, 1e-9));
  });

  testWidgets('/sites/new maps a GeoPoint extra into initialLocation',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(
          path: '/start',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => context.push(
                    '/sites/new',
                    extra: const GeoPoint(1.5, 2.5),
                  ),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/sites/new',
          builder: (context, state) => SiteEditPage(
            initialLocation:
                state.extra is GeoPoint ? state.extra as GeoPoint : null,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allDiversProvider.overrideWith((_) async => _divers()),
          shareByDefaultProvider.overrideWith((_) async => false),
          locationServiceProvider.overrideWithValue(_RecordingLocationService()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('1.500000, 2.500000'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_seed_location_test.dart`
Expected: FAIL — `initialLocation` is not a parameter of `SiteEditPage`.

- [ ] **Step 3: Add the `initialLocation` constructor param**

In `site_edit_page.dart`, add the field and constructor arg (near `siteId`, `:33`/`:40`) and a second assert:

```dart
  final String? siteId;
  final List<String>? mergeSiteIds;
  final bool embedded;
  final void Function(String savedId)? onSaved;
  final VoidCallback? onCancel;
  final GeoPoint? initialLocation;

  const SiteEditPage({
    super.key,
    this.siteId,
    this.mergeSiteIds,
    this.embedded = false,
    this.onSaved,
    this.onCancel,
    this.initialLocation,
  }) : assert(
         siteId == null || mergeSiteIds == null,
         'siteId and mergeSiteIds are mutually exclusive',
       ),
       assert(
         initialLocation == null || (siteId == null && mergeSiteIds == null),
         'initialLocation is only valid when creating a new site',
       );
```

- [ ] **Step 4: Seed on the new-site init path**

Replace the new-site init block in `build` (`:511-513`):

```dart
    if (!_isInitialized) {
      _isInitialized = true;
    }
    return _buildForm(context, units);
```

with:

```dart
    if (!_isInitialized) {
      _isInitialized = true;
      _seedInitialLocation();
    }
    return _buildForm(context, units);
```

Add these methods near `_initializeFromSite`:

```dart
  /// Seed a brand-new site form from [SiteEditPage.initialLocation]: fill the
  /// coordinate fields immediately (as non-dirtying initial values), then
  /// best-effort reverse-geocode country/region into the empty fields.
  void _seedInitialLocation() {
    final loc = widget.initialLocation;
    if (loc == null) return;

    _isApplyingInitialValues = true;
    _latitudeController.text = loc.latitude.toStringAsFixed(6);
    _longitudeController.text = loc.longitude.toStringAsFixed(6);
    _isApplyingInitialValues = false;

    WidgetsBinding.instance.addPostFrameCallback((_) => _geocodeSeed(loc));
  }

  Future<void> _geocodeSeed(GeoPoint loc) async {
    final result = await ref
        .read(locationServiceProvider)
        .reverseGeocode(loc.latitude, loc.longitude);
    if (!mounted) return;
    setState(() {
      _isApplyingInitialValues = true;
      if (_countryController.text.isEmpty && result.country != null) {
        _countryController.text = result.country!;
      }
      if (_regionController.text.isEmpty && result.region != null) {
        _regionController.text = result.region!;
      }
      _isApplyingInitialValues = false;
    });
  }
```

(`locationServiceProvider` is already imported — used by `_useMyLocation`.)

- [ ] **Step 5: Wire the `/sites/new` route to read `extra`**

In `lib/core/router/app_router.dart`, add the import if absent:

```dart
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
```

Replace `:379`:

```dart
                builder: (context, state) => const SiteEditPage(),
```

with:

```dart
                builder: (context, state) => SiteEditPage(
                  initialLocation:
                      state.extra is GeoPoint ? state.extra as GeoPoint : null,
                ),
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_seed_location_test.dart`
Expected: PASS (both the seed test and the router-mapping test).

- [ ] **Step 7: Format + commit**

```bash
dart format lib/features/dive_sites/presentation/pages/site_edit_page.dart lib/core/router/app_router.dart test/features/dive_sites/presentation/pages/site_edit_seed_location_test.dart
git add lib/features/dive_sites/presentation/pages/site_edit_page.dart lib/core/router/app_router.dart test/features/dive_sites/presentation/pages/site_edit_seed_location_test.dart
git commit -m "feat(site-edit): seed new-site form from initialLocation + geocode; wire /sites/new extra"
```

---

### Task 5: Wire the dive edit page to feed the dive's GPS

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (`_showSitePicker`, `:1927-1963`)
- Test: `test/features/dive_log/presentation/pages/dive_edit_site_gps_test.dart` (create)

**Interfaces:**
- Consumes: `SitePickerSheet.diveLocation` (Task 3); `/sites/new` `extra` → `initialLocation` (Task 4). `GeoPoint` already imported via `dive_site.dart` (`dive_edit_page.dart:18`).

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/pages/dive_edit_site_gps_test.dart` (harness copied from `dive_edit_page_test.dart`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  testWidgets('site picker is anchored on the dive GPS', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dive = Dive(
      id: 'dive-gps',
      diveNumber: 1,
      dateTime: DateTime(2026, 3, 28, 10, 0),
      entryTime: DateTime(2026, 3, 28, 10, 5),
      bottomTime: const Duration(minutes: 40),
      maxDepth: 20.0,
      entryLocation: const GeoPoint(34.0182, -118.4965),
      tanks: const [],
      profile: const [],
      equipment: const [],
      notes: '',
      photoIds: const [],
      sightings: const [],
      weights: const [],
      tags: const [],
    );
    final created = await repository.createDive(dive);
    final base = await getBaseOverrides();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveEditPage(diveId: created.id, embedded: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open the site picker via the "Add site" FormRow.picker placeholder.
    await tester.ensureVisible(find.text('Add site'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add site'));
    await tester.pumpAndSettle();

    // Dive has entry GPS -> the picker is anchored on it.
    expect(find.text('Sorted by distance from this dive'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_site_gps_test.dart`
Expected: FAIL — header text absent (picker still anchored on `_currentLocation`, which is null here).

- [ ] **Step 3: Feed the dive anchor + seed the create route**

In `dive_edit_page.dart` `_showSitePicker` (`:1927`), add before `showModalBottomSheet`:

```dart
    final anchor =
        _existingDive?.entryLocation ?? _existingDive?.exitLocation;
```

Pass it to the sheet (after `currentLocation: _currentLocation,`, `:1939`):

```dart
          currentLocation: _currentLocation,
          diveLocation: anchor,
```

Change the create-new push (`:1953`) to carry the coordinates (null is safe — the route ignores non-`GeoPoint` extras):

```dart
      final siteId = await context.push<String>('/sites/new', extra: anchor);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_site_gps_test.dart`
Expected: PASS.

- [ ] **Step 5: Full analyze + targeted regression run**

Run:
```bash
flutter analyze lib/features/dive_log/presentation/pages/dive_edit_page.dart lib/features/dive_log/presentation/widgets/pickers/site_picker_sheet.dart lib/features/dive_sites/presentation/pages/site_edit_page.dart lib/core/router/app_router.dart
flutter test test/features/dive_log/presentation/widgets/pickers/site_picker_sheet_test.dart test/features/dive_sites/presentation/pages/site_edit_page_test.dart test/features/dive_log/presentation/pages/dive_edit_page_test.dart
```
Expected: no analyzer issues; all listed suites PASS (proves existing site-edit and dive-edit behavior is unregressed).

- [ ] **Step 6: Format + commit**

```bash
dart format lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/presentation/pages/dive_edit_site_gps_test.dart
git add lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/presentation/pages/dive_edit_site_gps_test.dart
git commit -m "feat(dive-edit): anchor site picker on dive GPS and seed New Dive Site coords"
```

---

## Manual verification (after all tasks)

1. Open a downloaded dive that has entry GPS → Edit → tap the site field ("Add site").
   - Existing sites are sorted nearest-first, each showing distance in your unit
     setting; header reads "Sorted by distance from this dive".
2. Tap "New Dive Site" → the editor opens with latitude/longitude pre-filled and,
   after a moment, country/region populated (online). Save the site, then save the
   dive edit → the dive is associated to the new site.
3. Switch units (Settings → depth m/ft) and reopen → distances render in km/mi vs
   m/ft accordingly.
4. Open a **manually created** dive with no GPS → Edit → site picker behaves exactly
   as before (device-location sort if available; "New Dive Site" opens a blank editor).

## Self-review coverage map

- Behavior contract (dive-anchored sort/distance) → Tasks 1, 3, 5.
- "New Dive Site" pre-fill + geocode → Task 4; fed by Task 5.
- Unit-aware distance (project rule) → Task 1; consumed Task 3.
- GPS-less dives unchanged → anchor `?? currentLocation` (Task 3), metric strings byte-identical (Task 1), null `extra` ignored (Task 4 router), manual step 4.
- l10n all-locales → Task 2.
- No DB/schema change → confirmed (no migration task).
- Open items resolved: (1) DivePrefill has no GPS → `_existingDive` sole source (Task 5); (2) distance shape → `formatGeoDistance` + `distanceAway` wrapper (Tasks 1-2); (3) header icon → `Icons.place` (Task 3).
```