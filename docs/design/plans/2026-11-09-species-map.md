# Species Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in one session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Species Map page (places mode and species mode) plus a "Where seen" section on each species' detail page, from the diver's own logbook, with an opt-in GBIF public layer.

**Architecture:** A new read-only `SpeciesMapRepository` (diver-scoped SQL, like `SeenSpeciesRepository`) feeds ticked Riverpod providers. Two device preferences (public layer, expected-site scope) live in SharedPreferences. The public layer reuses the reef feature's GBIF nearby-species provider for site cards and adds a licence-filtered GBIF `adhoc` tile layer for one taxon. The page reuses `MapListScaffold`, `WorldWrappedMarkerClusterLayer`, `MapCornerControls` and `MapCameraAnimator` from the Sites map.

**Tech Stack:** Flutter, Riverpod (`package:submersion/core/providers/provider.dart`), Drift `customSelect`, flutter_map + flutter_map_marker_cluster, go_router, `http`, ARB l10n.

**Spec:** `docs/design/specs/2026-11-09-species-map-design.md`

## Global Constraints

- No schema change, no new table, no migration rung.
- Public layer OFF by default. While off, no request leaves the species map (no taxon resolve, no tiles, no nearby fetch).
- GBIF licence filter on every public request: `license=CC0_1_0&license=CC_BY_4_0`. Tiles use the `/v2/map/occurrence/adhoc/` endpoint only (the `density` endpoint ignores `license`).
- GBIF requests send `User-Agent: Submersion/1.0 (https://submersion.app)` and use `reefRequestTimeout`.
- Own sightings are scoped like the Species page: `currentDiverIdProvider`, `DiveStatsScope.and(alias: 'd')`, never the Insights filter.
- Preference keys: `species_map.public_layer` (bool, default false), `species_map.expected_scope` (`mine` | `allVisible`, default `mine`). Device-only, not synced.
- Valid coordinates only: latitude in [-90, 90], longitude in [-180, 180], both non-null (same filter as `SiteMapPage._buildMap`).
- Every new user-visible string is an ARB key in all 11 locales (`ar de en es fr he hu it nl pt zh`), translated, then `flutter gen-l10n`.
- No em-dashes or en-dashes as punctuation in code, comments, strings or docs.
- Every new provider that reads a table subscribes to that table's tick, or carries a `// no-tick:` comment with the reason (`test/architecture/provider_change_tick_test.dart`).
- The full page's `FlutterMap` carries `MapCornerControls`; the detail page's mini map is locked (`InteractionOptions(flags: InteractiveFlag.none)`) and carries none (`map_style_switcher_adoption_test.dart`).

## Review Focus

1. **Route with an unknown or deleted `?species=` id:** the page opens in places mode, no error. Test in Task 6.
2. **Diver switch while the page is open:** pins re-query for the new diver (providers watch `currentDiverIdProvider`). Test in Task 3.
3. **Species with no scientific name, or a custom species GBIF cannot match confidently:** public layer on shows the "no public records for this species" note instead of tiles; own pins still draw. Tests in Tasks 1 and 5.
4. **Sightings on a dive with no site, or a site without valid coordinates:** counted as unplaced, never a pin, the line under the map shows the count. Tests in Tasks 2 and 6.
5. **Expected scope "all visible" with a site the diver has hidden:** that site's expected pin does not appear (VisibilityFilter excludes `site_hides`). Test in Task 2.

---

### Task 1: GBIF taxon key resolution and tile URL

**Files:**
- Modify: `lib/features/reef/domain/services/species_catalog_matcher.dart`
- Create: `lib/features/marine_life/data/services/gbif_species_map_service.dart`
- Test: `test/features/reef/domain/services/species_catalog_matcher_test.dart` (extend), `test/features/marine_life/data/services/gbif_species_map_service_test.dart`

**Interfaces:**
- Produces: `int? SpeciesCatalogMatcher.gbifKeyFor(String speciesId)`; `class GbifSpeciesMapService { GbifSpeciesMapService({http.Client? client, SpeciesCatalogMatcher? matcher, Duration timeout = reefRequestTimeout}); Future<int?> resolveTaxonKey({required String speciesId, String? scientificName}); static String tileUrlTemplate(int taxonKey); }`

- [ ] **Step 1: Write the failing tests**
  - `gbifKeyFor returns the species-rank key for a built-in id` (fixture JSON `{"speciesKeys":{"2417522":"sp_whale_shark"},"taxonKeys":[1]}` gives `2417522` for `sp_whale_shark`, null for `sp_unknown`).
  - `resolveTaxonKey prefers the bundled key and makes no request` (MockClient that fails the test if called).
  - `resolveTaxonKey matches by scientific name` (MockClient answers `/v1/species/match` with `{"usageKey":9241141,"rank":"SPECIES","matchType":"EXACT","status":"ACCEPTED"}`; expect 9241141; assert the request carries `name=Mobula alfredi`, `strict=true` and the User-Agent).
  - `resolveTaxonKey follows a synonym` (`status: "SYNONYM"`, `acceptedUsageKey: 7`, expect 7).
  - `resolveTaxonKey returns null for a non-species or fuzzy match` (`rank: "GENUS"`; and `matchType: "FUZZY"`, `confidence: 80`; both null).
  - `resolveTaxonKey returns null with no scientific name and makes no request`.
  - `resolveTaxonKey returns null on HTTP 500 and on timeout, and does not cache the failure` (second call issues a second request).
  - `resolveTaxonKey caches a success per species id` (one request for two calls).
  - `tileUrlTemplate has the adhoc endpoint and both licences`: contains `api.gbif.org/v2/map/occurrence/adhoc/{z}/{x}/{y}@1x.png`, `taxonKey=9241141`, `license=CC0_1_0`, `license=CC_BY_4_0`, `occurrenceStatus=PRESENT`, `hasGeospatialIssue=false`.

- [ ] **Step 2: Run them, expect FAIL** (`flutter test test/features/reef/domain/services/species_catalog_matcher_test.dart test/features/marine_life/data/services/gbif_species_map_service_test.dart`)

- [ ] **Step 3: Implement.** `gbifKeyFor` inverts `_byGbifKey` lazily (first key wins on a duplicate id). Query `/v1/species/match` with `name`, `strict=true` and `rank=SPECIES`; accept the answer only when `rank == "SPECIES"` and `matchType == "EXACT"`, using `acceptedUsageKey` when present, else `usageKey`. Tile template style: `style=orange.marker&bin=hex&hexPerTile=60` (builder may tune the style, never drop the filters). The service caches successes in a `Map<String, int?>` that stores a confident null too (a species GBIF does not know stays unknown for the session); failures are not stored.

- [ ] **Step 4: Run, expect PASS**

- [ ] **Step 5: Commit** `feat(marine-life): resolve species to GBIF taxa for the species map`

### Task 2: SpeciesMapRepository

**Files:**
- Create: `lib/features/marine_life/domain/entities/species_map_pins.dart`
- Create: `lib/features/marine_life/data/repositories/species_map_repository.dart`
- Test: `test/features/marine_life/data/repositories/species_map_repository_test.dart` (fixtures copied from `seen_species_repository_test.dart`, sites given coordinates via a `latitude`/`longitude` parameter on `insertTestSite`, plus `site_species`, `site_hides` and shared-library rows as needed)

**Interfaces:**
- Produces:
  - `enum ExpectedSiteScope { mine, allVisible }`
  - `class SiteSpeciesPin extends Equatable { final String siteId; final String siteName; final double latitude; final double longitude; final int speciesCount; final int sightingCount; }`
  - `enum SpeciesPinKind { logged, expected }`
  - `class SpeciesSitePin extends Equatable { final String siteId; final String siteName; final double latitude; final double longitude; final SpeciesPinKind kind; final int sightingCount; }` (0 for expected)
  - `class LoggedSpeciesAtSite extends Equatable { final String speciesId; final int sightingCount; }`
  - `SpeciesMapRepository`:
    - `Future<List<SiteSpeciesPin>> getSitePins({String? diverId})`
    - `Future<List<SpeciesSitePin>> getPinsForSpecies(String speciesId, {String? diverId, ExpectedSiteScope scope = ExpectedSiteScope.mine})`
    - `Future<int> countUnplacedSightings({String? speciesId, String? diverId})` (sum of `sightings.count`; null `speciesId` counts every species)
    - `Future<List<LoggedSpeciesAtSite>> getLoggedSpeciesAtSite(String siteId, {String? diverId})` (most seen first, then species id)

- [ ] **Step 1: Write the failing tests** against a seeded logbook (two divers, three sites with coordinates, one site without, one site with lat 95):
  - `getSitePins counts distinct species and summed sightings per site, scoped to the diver`.
  - `getSitePins drops sites without valid coordinates and dives without a site`.
  - `getSitePins honours DiveStatsScope` (an `excluded_from_stats = 1` dive and an `is_planned = 1` dive contribute nothing).
  - `getPinsForSpecies returns logged pins with summed counts`.
  - `getPinsForSpecies adds expected pins only where not logged` (a site both logged and expected appears once, as logged).
  - `getPinsForSpecies mine scope keeps owned or dived sites` (an expected row on another diver's unshared site is excluded; on a site the diver dived but does not own, included).
  - `getPinsForSpecies allVisible scope uses VisibilityFilter` (a shared-library site the diver is a member of is included; the same site after a `site_hides` row for the diver is excluded).
  - `countUnplacedSightings sums sightings on site-less and coordinate-less dives`, per species and overall.
  - `getLoggedSpeciesAtSite is diver-scoped and ordered by count`.

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement.** SQL in `customSelect` like `SeenSpeciesRepository` (diver clause `AND d.diver_id = ?` only when non-null; `DiveStatsScope.and(alias: 'd')`; coordinate validity in the `WHERE`). For expected pins: one `customSelect` for `site_species` rows of the species joined to `dive_sites` with valid coordinates, then narrow the candidate site ids with a Drift `select(diveSites)` whose scope is `VisibilityFilter.applyToDiveSites(db, q, diverId)` for `allVisible`, or `diver_id = diverId OR id IN (SELECT site_id FROM dives WHERE diver_id = diverId)` for `mine`. A null `diverId` applies no scope. Errors propagate (no catch), as in `SeenSpeciesRepository`.

- [ ] **Step 4: Run, expect PASS**

- [ ] **Step 5: Commit** `feat(marine-life): species map queries`

### Task 3: Preferences and providers

**Files:**
- Create: `lib/features/marine_life/presentation/providers/species_map_prefs_providers.dart`
- Create: `lib/features/marine_life/presentation/providers/species_map_providers.dart`
- Test: `test/features/marine_life/presentation/providers/species_map_providers_test.dart`

**Interfaces:**
- Consumes: Task 1 service, Task 2 repository and entities.
- Produces:
  - `final speciesMapPublicLayerProvider = StateNotifierProvider<SpeciesMapPublicLayerNotifier, bool>` with `Future<void> set(bool on)`
  - `final speciesMapExpectedScopeProvider = StateNotifierProvider<SpeciesMapExpectedScopeNotifier, ExpectedSiteScope>` with `Future<void> set(ExpectedSiteScope scope)`
  - `final speciesMapRepositoryProvider = Provider<SpeciesMapRepository>`
  - `final gbifSpeciesMapServiceProvider = Provider<GbifSpeciesMapService>`
  - `final speciesMapSitePinsProvider = FutureProvider<List<SiteSpeciesPin>>`
  - `final speciesMapSpeciesPinsProvider = FutureProvider.family<List<SpeciesSitePin>, String>` (watches the scope provider)
  - `final speciesMapUnplacedCountProvider = FutureProvider.family<int, String?>`
  - `final speciesMapLoggedAtSiteProvider = FutureProvider.family<List<LoggedSpeciesAtSite>, String>`
  - `final speciesGbifTaxonKeyProvider = FutureProvider.autoDispose.family<int?, String>` (reads the species from `speciesProvider(id)` for its scientific name; `// no-tick:` remote, session-cached in the service)

- [ ] **Step 1: Write the failing tests**
  - `public layer defaults to off and persists` (empty `SharedPreferences.setMockInitialValues({})`; read false; `set(true)`; a new container over the same prefs reads true).
  - `expected scope defaults to mine, persists, and an unknown stored value reads as mine`.
  - `site pins re-query when the current diver changes` (override `currentDiverIdProvider`, change it, expect a second repository call with the new id; fake repository records calls).
  - `species pins re-query when the scope changes`.
  - `species pins refresh on a sightings tick` (fake repository exposes the tick streams; emit one; expect a re-query).

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement.** Ticks: site pins and logged-at-site watch `watchSightingChanges`, `watchDivesChanges` and `watchSitesChanges`; species pins add `watchSiteSpeciesChanges`; unplaced count watches sightings, dives, sites. Notifier pattern after `DebugModeNotifier` (state from prefs in the constructor, write through on set).

- [ ] **Step 4: Run, expect PASS**, then `flutter test test/architecture/provider_change_tick_test.dart test/architecture/provider_family_scanner_test.dart`

- [ ] **Step 5: Commit** `feat(marine-life): species map providers and device preferences`

### Task 4: Read-only nearby tier

**Files:**
- Modify: `lib/features/reef/presentation/widgets/nearby_species_tier.dart`
- Test: `test/features/reef/presentation/widgets/nearby_species_tier_test.dart` (extend)

**Interfaces:**
- Produces: `NearbySpeciesTier({required String siteId, required GeoPoint location, ValueChanged<String>? onSpeciesTap})`. When `onSpeciesTap` is non-null the tier is read-only: a matched chip calls it with the species id instead of adding to Expected, an unmatched chip is not tappable, no add tooltip.

- [ ] **Step 1: Failing test** `with onSpeciesTap a matched chip opens the species and adds nothing` (tap calls back with the id; no `site_species` write on the fake repository), and `with onSpeciesTap an unmatched chip has no tap action`.
- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement** the branch in `_matchedChip` / `_unmatchedChip`.
- [ ] **Step 4: Run the whole file, expect PASS** (existing add-to-Expected tests unchanged).
- [ ] **Step 5: Commit** `feat(reef): read-only nearby species tier`

### Task 5: Map building blocks

**Files:** (all under `lib/features/marine_life/presentation/widgets/species_map/`)
- Create: `species_map_markers.dart`: `SiteSpeciesMarker({required int speciesCount, required bool selected})`, `LoggedSpeciesMarker({required int sightingCount, required bool selected})`, `ExpectedSpeciesMarker({required bool selected})`, and `double siteSpeciesMarkerSize(int speciesCount)` (32 at 1, growing on a log scale, capped at 52).
- Create: `species_map_legend.dart`: `SpeciesMapLegend({required bool speciesMode, required bool publicOn})`
- Create: `species_map_layers_button.dart`: `SpeciesMapLayersButton()` (a map-corner-style button opening a menu with the public switch and its one-line explanation, and the two scope choices)
- Create: `gbif_occurrence_layer.dart`: `GbifOccurrenceLayer({required String speciesId})` (renders nothing while the public layer is off; resolves the key via `speciesGbifTaxonKeyProvider`; a null key renders nothing, the note is the page's job; a `TileLayer` with `GbifSpeciesMapService.tileUrlTemplate`, `userAgentPackageName: 'app.submersion'`, tile errors ignored)
- Create: `species_map_site_card.dart`: `SpeciesMapSiteCard({required SiteSpeciesPin pin, required VoidCallback onClose})` (places mode: logged chips via `speciesMapLoggedAtSiteProvider`, expected-not-logged via `siteExpectedSpeciesProvider` minus logged, `NearbySpeciesTier(onSpeciesTap: ...)` only when the public layer is on, site name opens `/sites/<id>`, species chips open `/species/<id>`; scrolls inside a max height of 45% of the screen)
- Create: `species_map_species_site_card.dart`: `SpeciesMapSpeciesSiteCard({required SpeciesSitePin pin, required String speciesId, required VoidCallback onClose})` (species mode: logged pin lists that site's rows from `speciesSightingsProvider(speciesId)` filtered by site id, each opening `/dives/<diveId>`; expected pin shows "Expected here")
- Test: one widget test file per widget under `test/features/marine_life/presentation/widgets/species_map/`

**Interfaces:**
- Consumes: Tasks 2 to 4.
- Produces: the widgets named above, for Tasks 6 and 7.

- [ ] **Step 1: Failing tests**
  - Markers: `logged marker shows its count`, `expected marker is hollow` (no fill colour, border present), `marker size grows with species count and caps at 52`.
  - Legend: shows "Public records" only when `publicOn`; shows "Expected" and "My sightings" in species mode, "Species logged" in places mode.
  - Layers button: `switch reads off by default and turning it on persists`, `scope choice persists`.
  - `GbifOccurrenceLayer makes no request while off` (the service fake records zero calls and the tree has no `TileLayer`); `with the layer on and a key it adds a TileLayer whose url has both licences`.
  - Site card: `lists logged species most seen first`, `lists expected not yet logged and omits logged ones`, `nearby tier only with the public layer on`, `tapping a species opens its page` (GoRouter test harness).
  - Species site card: `logged pin lists that site's sightings only`, `expected pin says Expected here`.
- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement.** Colours from the theme: logged `colorScheme.primary` fill with `onPrimary` text; expected `surface` fill with a 2 px `primary` border; public tiles' orange is GBIF's own and stays under the pins. Check contrast in light and dark.
- [ ] **Step 4: Run, expect PASS**
- [ ] **Step 5: Commit** `feat(marine-life): species map markers, layers and cards`

### Task 6: Species Map page, route and entry point

**Files:**
- Create: `lib/features/marine_life/presentation/pages/species_map_page.dart`: `SpeciesMapPage({String? initialSpeciesId})`
- Create: `lib/features/marine_life/presentation/widgets/species_map/species_map_list_pane.dart`: `SpeciesMapListPane({required String? selectedSpeciesId, required ValueChanged<String?> onSelected})` (seen species from `seenSpeciesProvider` with "N sightings, M sites"; a search field over `allSpeciesProvider`, matching the localized common name and scientific name case- and accent-insensitively; unseen results say "Not seen yet"; a "Show all sites" row clears the pick)
- Modify: `lib/core/router/app_router.dart` (a `map` route under `/species`, declared before `:speciesId`, name `speciesMap`, `initialSpeciesId: state.uri.queryParameters['species']`)
- Modify: `lib/features/marine_life/presentation/pages/species_page.dart` (app bar `IconButton(key: ValueKey('species_map'), icon: Icon(Icons.map_outlined))` pushing `/species/map`)
- Test: `test/features/marine_life/presentation/pages/species_map_page_test.dart`, `.../widgets/species_map/species_map_list_pane_test.dart`, extend `species_page_test.dart`

**Interfaces:**
- Consumes: Tasks 3 and 5.
- Produces: route `/species/map?species=<id>` for Task 7.

- [ ] **Step 1: Failing tests**
  - `places mode shows one marker per site pin`.
  - `picking a species switches to logged and expected markers` and `the clear row returns to places mode`.
  - `?species= seeds species mode`; `an unknown ?species= id opens places mode` (Review Focus 1).
  - `unplaced line shows only when non-zero` ("2 sightings are on dives without a mapped site").
  - `public on with no taxon key shows the no-public-records note`; with a key, no note (Review Focus 3).
  - `species mode with no pins and public off suggests turning on public records`.
  - `on a phone width the picker opens from the app bar search button` (`tester.view.physicalSize = Size(400, 800)`, restored in `addTearDown`).
  - Species page: `map button opens /species/map`.
  - List pane: `search finds an unseen catalog species and marks it Not seen yet`.
- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement.** `MapListScaffold(sectionKey: 'speciesMap', ...)`; selected site held in `mapListSelectionProvider('speciesMap')`; picked species held in page state. FlutterMap children in order: tile layer (`mapTileUrlProvider`, `TileCacheService`), `GbifOccurrenceLayer` in species mode, `WorldWrappedMarkerClusterLayer` of pins, `MapAttribution`, plus a "Records: GBIF.org" attribution chip opening `reef_attribution_sheet.dart` while public is on. Overlays: `MapCornerControls(controller:)` with `SpeciesMapLayersButton` above it at top-right, `SpeciesMapLegend` bottom-left, unplaced line and notes under the map. Camera: `MapCameraAnimator.fitAllCameraFit` over the current pins on first data and on each species change; no pins fits the world. Phone: an app bar search `IconButton` opens `SpeciesMapListPane` in `showModalBottomSheet(isScrollControlled: true, useSafeArea: true)`.
- [ ] **Step 4: Run, expect PASS**, then `flutter test test/architecture/`
- [ ] **Step 5: Commit** `feat(marine-life): species map page`

### Task 7: "Where seen" on the species detail page

**Files:**
- Create: `lib/features/marine_life/presentation/widgets/species_where_seen_section.dart`: `SpeciesWhereSeenSection({required String speciesId})`
- Modify: `lib/features/marine_life/presentation/pages/species_detail_page.dart` (insert above `SpeciesSightingsSection`)
- Test: `test/features/marine_life/presentation/widgets/species_where_seen_section_test.dart`

**Interfaces:**
- Consumes: `speciesMapSpeciesPinsProvider`, markers from Task 5, route from Task 6.

- [ ] **Step 1: Failing tests**
  - `shows a locked map with the species' pins and up to three sites by count` ("Manta Point (6), Crystal Bay (2), Batu Bolong (1)" from four logged sites, the fourth omitted).
  - `with no pins shows the empty line and the open button`.
  - `Open full map pushes /species/map?species=<id>`.
  - `never builds a GBIF layer even with the public layer on`.
- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement.** 160 px `FlutterMap` with `interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)`, `initialCameraFit` over the pins (padding 24, max zoom 10), plain `MarkerLayer` (no clustering). Section header styled like the detail page's other sections.
- [ ] **Step 4: Run, expect PASS**, plus `test/architecture/map_style_switcher_adoption_test.dart`
- [ ] **Step 5: Commit** `feat(marine-life): where seen section on species detail`

### Task 8: Translations and final checks

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb` (each new key, beside its English group neighbour)

- [ ] **Step 1:** List the English keys added in Tasks 5 to 7 (`grep -o '"speciesMap_[A-Za-z_]*"' lib/l10n/arb/app_en.arb`), translate each into the 10 other locales, keep placeholders and plural categories (`one`/`other`, never `=1` with a literal digit), insert each beside the same group in each file.
- [ ] **Step 2:** `flutter gen-l10n`, then `dart format .`, `flutter analyze` (expect "No issues found!"), `flutter test test/features/marine_life test/features/reef test/architecture test/shared` (expect all pass).
- [ ] **Step 3: Commit** `feat(marine-life): translate the species map`
