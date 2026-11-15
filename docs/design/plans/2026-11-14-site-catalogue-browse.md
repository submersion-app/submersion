# Site Catalogue: Browse Before Diving (Slice 5) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Built-in dive sites are on the Sites map by default, every
catalogue record has a read-only page of its own, and a record can be found
by name from the Import page and the Sites search.

**Architecture:** The one in-memory overlay switch becomes a two-layer
state stored on the device, and `SiteCatalogue.inBounds` reads by kind. A
mixin carries what both Sites maps do with a selected built-in record, so
the new behaviour is written once. The page is a new route built from small
new cards plus the existing tide and reef cards, fed by two providers (who
owns this record, what is near it).

**Tech Stack:** Flutter, Riverpod (`StateNotifier`, `FutureProvider`),
go_router, flutter_map with marker clusters, Drift over the local cache
database, `shared_preferences`.

**Spec:** `docs/design/specs/2026-11-14-site-catalogue-browse-design.md`

## Global Constraints

- No schema change: neither the main database nor the local cache ladder.
- No file over 800 lines. `site_detail_page.dart` (2,535) is not touched.
  `site_map_page.dart` (658) and `site_map_content.dart` (681) must end no
  longer than they start.
- Depths and distances through `UnitFormatter`; coordinates through
  `formatCoordinates`.
- Every new string in all 11 ARB files, inserted beside a neighbouring key
  of the same feature group. Removed keys are removed from all 11.
- The Sites maps `listen` to the layer state and never `watch` it from
  their own build: a rebuild recreates the `FlutterMap`.
- Catalogue reads never throw; every screen is correct while a read is
  pending or returns nothing.
- Guards: no button or chip in `ListTile.trailing`; no indeterminate
  spinner that a `pumpAndSettle` test would wait on; a test that sets
  `SharedPreferences` mock values restores them in `addTearDown`.
- Tests first. A red check runs one file per run, logged to the scratchpad
  as `.txt`. Never the whole suite; `test/architecture/` and `test/shared/`
  after files are added under `lib/`.
- Paths with `p.join`; `dart format .` before each commit.
- Commits and the PR mention no tool or model. The PR body says
  `Part of #4514`.

## Review Focus

1. **A preference stored with the wrong type** (a string where a bool is
   expected, from a hand-edited or damaged file): the map opens with the
   defaults and nothing throws. Pinned in Task 1.
2. **The catalogue finishes importing after the map is already open** on a
   first launch: pins appear without the diver moving the map. Pinned in
   Task 3.
3. **A layer turned off while its read is still under way:** the late
   result does not draw the layer that is now off. Pinned in Task 3.
4. **A record with no coordinates** opened by its route: the page shows
   its header and source, and no strip, tides, reef or nearby. Pinned in
   Task 7.
5. **A crowded neighbourhood** (hundreds of register records within 10 km,
   several of them the diver's own): Nearby still lists 6, none of them
   the diver's. Pinned in Task 6.

---

## File Structure

New:

| File | Responsibility |
|---|---|
| `lib/features/dive_sites/presentation/providers/built_in_map_layers_provider.dart` | The two-layer state, its stored notifier and provider |
| `lib/features/dive_sites/presentation/widgets/built_in_layers_button.dart` | The globe button and its two-row menu |
| `lib/features/dive_sites/presentation/widgets/catalogue_kind_glyph.dart` | The icon for a record's kind, used by pins, the menu, the strip and Nearby |
| `lib/features/dive_sites/presentation/widgets/built_in_map_selection.dart` | Mixin for both maps: the selected record, its card, adding it, clearing it |
| `lib/features/dive_sites/domain/services/catalogue_nearby.dart` | Pure rule: what is near a record |
| `lib/features/dive_sites/presentation/providers/catalogue_site_page_providers.dart` | Owner of a record, nearby, sea name |
| `lib/features/dive_sites/presentation/pages/catalogue_site_page.dart` | The page shell: states, redirect, app bar, add |
| `lib/features/dive_sites/presentation/widgets/catalogue_page/catalogue_site_map_strip.dart` | Locked strip and its fullscreen map |
| `lib/features/dive_sites/presentation/widgets/catalogue_page/catalogue_site_header.dart` | Name, place, kind line, "your site here" |
| `lib/features/dive_sites/presentation/widgets/catalogue_page/catalogue_about_card.dart` | Chips, description, hazards card |
| `lib/features/dive_sites/presentation/widgets/catalogue_page/catalogue_location_card.dart` | Place rows and coordinates |
| `lib/features/dive_sites/presentation/widgets/catalogue_page/catalogue_nearby_card.dart` | The two nearby lists |
| `lib/features/dive_sites/presentation/widgets/catalogue_page/catalogue_source_card.dart` | Name, credit, licence, links, register sentence |
| `lib/features/dive_sites/presentation/widgets/search_built_in_sites_row.dart` | The row under the Sites search field |

Changed: `site_catalogue.dart`, `local_site_catalogue.dart`,
`built_in_sites_providers.dart`, `built_in_overlay_view.dart`,
`built_in_site_marker_layer.dart`, `built_in_site_info_card.dart`,
`catalogue_site_display.dart`, `site_map_page.dart`,
`site_map_content.dart`, `site_import_page.dart`,
`catalogue_import_site_card.dart`, `site_list_content.dart`,
`entity_search_header.dart`, `app_router.dart`, `root_overrides.dart`,
`settings_providers.dart` (two keys), the 11 ARB files,
`test/helpers/fake_site_catalogue.dart`, `docs/user/dive-sites.md`.

Removed: `built_in_sites_toggle_button.dart` and its test;
`showBuiltInSitesProvider`.

---

### Task 1: The two-layer state

**Files:**
- Create: `lib/features/dive_sites/presentation/providers/built_in_map_layers_provider.dart`
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (`SettingsKeys`), `lib/core/providers/root_overrides.dart`
- Test: `test/features/dive_sites/presentation/providers/built_in_map_layers_provider_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class BuiltInMapLayers extends Equatable {
    const BuiltInMapLayers({this.diveSites = true, this.registers = false});
    final bool diveSites;
    final bool registers;
    bool get any;                       // either on
    Set<CatalogueKind> get kinds;       // the kinds that are on
    bool shows(CatalogueKind kind);
    BuiltInMapLayers withKind(CatalogueKind kind, bool on);
  }
  class BuiltInMapLayersNotifier extends StateNotifier<BuiltInMapLayers> {
    BuiltInMapLayersNotifier(SharedPreferences prefs);
    BuiltInMapLayersNotifier.unstored([BuiltInMapLayers layers]);
    Future<void> setLayer(CatalogueKind kind, bool on);
  }
  final builtInMapLayersNotifierProvider; // StateNotifierProvider, unstored defaults
  ```
- `SettingsKeys.builtInDiveSitesOnMap = 'built_in_dive_sites_on_map'`,
  `SettingsKeys.builtInRegistersOnMap = 'built_in_registers_on_map'`.

- [ ] **Step 1: Failing tests.** Names and assertions:
  - `defaults with nothing stored`: `diveSites` true, `registers` false,
    `kinds == {CatalogueKind.site}`.
  - `each stored combination is read back`: the four combinations.
  - `a change is written under its own key and nothing else is`: after
    `setLayer(register, true)` only `built_in_registers_on_map` exists.
  - `nothing is written at start`: constructing writes no key.
  - `a value of the wrong type reads as the default` (Review Focus 1):
    mock values `{'built_in_dive_sites_on_map': 'no'}` gives `diveSites`
    true and no throw.
  - `the unstored notifier changes only the live state`.
  - `the provider's default is unstored defaults`.
  Mock values are set with `SharedPreferences.setMockInitialValues` and
  put back to `{}` in `addTearDown`.
- [ ] **Step 2:** Run the file; it fails to compile.
- [ ] **Step 3:** Implement. Read each key with `prefs.get(key)` and take
  it only when it is a `bool`. `setLayer` returns without writing when
  the state does not change.
- [ ] **Step 4:** Add the stored notifier to `rootProviderOverrides`, with
  a comment in the style of its neighbours.
- [ ] **Step 5:** Run the file; passes. Format, commit
  `feat(dive-sites): remember which built-in layers the Sites map shows`.

### Task 2: `inBounds` by kind

**Files:**
- Modify: `lib/features/dive_sites/domain/repositories/site_catalogue.dart`, `lib/features/dive_sites/data/catalogue/local_site_catalogue.dart`, `test/helpers/fake_site_catalogue.dart`
- Test: `test/features/dive_sites/data/catalogue/local_site_catalogue_bounds_test.dart`

**Interfaces:**
- Produces:
  ```dart
  Future<CatalogueBoundsResult> inBounds(
    CatalogueBounds bounds, {
    int limit = 1500,
    Set<CatalogueKind> kinds = const {CatalogueKind.site, CatalogueKind.register},
  });
  ```
  `FakeSiteCatalogue` gains `final List<Set<CatalogueKind>> kindsAsked`.

- [ ] **Step 1: Failing tests** in the bounds test, over the real local
  cache database the file already opens:
  - `dive sites only`: no register record returned; `truncated` true only
    when dive site records exceed the limit, though registers abound.
  - `registers only`: no dive site record; nearest the middle first.
  - `no kind reads nothing`: empty, `truncated` false.
  - `both kinds, as before`: the existing order test still passes
    unchanged.
- [ ] **Step 2:** Run; fails.
- [ ] **Step 3:** Implement in `LocalSiteCatalogue.inBounds`: skip each of
  the two reads when its kind is absent; with dive sites absent the
  register read takes the whole limit. Mirror it in the fake.
- [ ] **Step 4:** Run the bounds test and
  `test/features/dive_sites/data/catalogue/local_site_catalogue_test.dart`;
  both pass. Commit
  `feat(dive-sites): read the catalogue for a map by kind of record`.

### Task 3: The overlay follows the layers

**Files:**
- Modify: `lib/features/dive_sites/presentation/providers/built_in_sites_providers.dart`, `lib/features/dive_sites/presentation/widgets/built_in_overlay_view.dart`
- Test: `test/features/dive_sites/presentation/providers/visible_built_in_sites_provider_test.dart`, `test/features/dive_sites/presentation/widgets/built_in_overlay_view_test.dart`

**Interfaces:**
- Consumes: `builtInMapLayersNotifierProvider`, `inBounds(kinds:)`.
- Produces: `showBuiltInSitesProvider` no longer exists. The reporter and
  the caption read `builtInMapLayersNotifierProvider.select((l) => l.any)`.
  `visibleBuiltInSitesProvider` and `builtInOverlayTruncatedProvider` keep
  their names and types.

- [ ] **Step 1: Failing tests.**
  - Provider: `the layers that are on are the kinds asked for`
    (`catalogue.kindsAsked.last`); `with both layers off nothing is read`;
    `the marker limit holds for one kind` (the existing "limit is of
    markers shown" case, run with dive sites only);
    `turning a layer off drops its records` (Review Focus 3: registers on,
    read, registers off, the value holds no register record);
    `an import that lands redraws the view` (Review Focus 2: empty fake,
    bounds reported, then `sites` filled and
    `siteCatalogueRevisionProvider` bumped gives the pins).
  - Replace `showBuiltInSitesProvider defaults to false` with the layer
    default.
  - Overlay view: the reporter reports with the default layers and stops
    with both off; the caption shows only with a layer on and a truncated
    view. Existing tests that set `showBuiltInSitesProvider` move to
    `builtInMapLayersNotifierProvider.overrideWith(...unstored(...))`.
- [ ] **Step 2:** Run each file alone; fail.
- [ ] **Step 3:** Implement. `_builtInSitesInViewProvider` watches the
  layers and returns the empty result at once when none is on. Delete
  `showBuiltInSitesProvider`.
- [ ] **Step 4:** Both files pass. Do not commit yet: the maps still name
  the removed provider. Tasks 4 and 5 restore the build; commit there.

### Task 4: Pins by kind and the layer menu

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/catalogue_kind_glyph.dart`, `lib/features/dive_sites/presentation/widgets/built_in_layers_button.dart`
- Delete: `lib/features/dive_sites/presentation/widgets/built_in_sites_toggle_button.dart`, `test/features/dive_sites/presentation/widgets/built_in_sites_toggle_button_test.dart`
- Modify: `lib/features/dive_sites/presentation/widgets/built_in_site_marker_layer.dart`, 11 ARB files
- Test: `test/features/dive_sites/presentation/widgets/built_in_site_marker_layer_test.dart`, `test/features/dive_sites/presentation/widgets/built_in_layers_button_test.dart`

**Interfaces:**
- Produces:
  ```dart
  IconData catalogueKindIcon(CatalogueKind kind);
  //   site     -> Icons.location_on_outlined
  //   register -> Icons.anchor
  class BuiltInLayersButton extends ConsumerWidget { const BuiltInLayersButton({super.key}); }
  // keys: ValueKey('builtInLayer_site'), ValueKey('builtInLayer_register')
  ```
- Strings (English):
  - `diveSites_map_layers_tooltip`: "Built-in sites on the map"
  - `diveSites_map_layers_diveSites`: "Built-in dive sites"
  - `diveSites_map_layers_registers`: "Charted wrecks and reefs"
  - `diveSites_map_semantics_registerMarker`: "Charted wreck or reef: {name}"
  - Removed: `diveSites_map_builtInSites_hide`, `_show`, `_on`, `_off`.

- [ ] **Step 1: Failing tests.**
  - Marker layer: a register record's pin is `Icons.anchor`, a dive site
    record's `Icons.location_on_outlined`; the semantics labels are the
    two strings; a selected register pin takes the primary colour.
  - Button: opening it shows two rows with their glyphs; the dive site
    row is ticked and the register row is not, by default; tapping a row
    changes the state and leaves the menu open; the button shows
    `Icons.public` with either layer on and `Icons.public_off` with none;
    at 320 px wide in German the rows do not overflow.
- [ ] **Step 2:** Run each alone; fail.
- [ ] **Step 3:** Implement. The menu is a `MenuAnchor` with two
  `CheckboxMenuButton`s, `closeOnActivate: false`. The button's
  `Semantics` carries the tooltip as its label.
- [ ] **Step 4:** Add the strings to all 11 ARB files and remove the four
  old ones; regenerate l10n (`flutter gen-l10n`).
- [ ] **Step 5:** Both files pass. Still no commit (see Task 5).

### Task 5: Both maps, through one mixin

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/built_in_map_selection.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_map_page.dart`, `lib/features/dive_sites/presentation/widgets/site_map_content.dart`, `lib/features/dive_sites/presentation/widgets/built_in_site_info_card.dart`, 11 ARB files
- Test: `test/features/dive_sites/presentation/pages/site_map_page_built_in_test.dart`, `test/features/dive_sites/presentation/widgets/site_map_content_built_in_test.dart`, `test/features/dive_sites/presentation/widgets/built_in_site_info_card_test.dart`

**Interfaces:**
- Produces:
  ```dart
  mixin BuiltInMapSelection<T extends ConsumerStatefulWidget> on ConsumerState<T> {
    String? get selectedBuiltInId;
    void selectBuiltIn(String? id);         // setState inside
    /// Call from build(): clears the selection when its layer goes off or
    /// its record becomes the diver's.
    void listenForBuiltInSelectionReset();
    Widget? buildBuiltInInfoCard(BuildContext context);
    Future<void> addBuiltInSite(CatalogueSite site);
    /// The built-in layers of the map: the reporter and the marker layer.
    List<Widget> builtInMapLayers({required void Function(CatalogueSite) onTap});
  }
  ```
  `BuiltInSiteInfoCard` gains `final VoidCallback? onDetails;` and
  `showCatalogueSiteDetails` passes none.
- String: `diveSites_builtIn_details`: "Details".
- Route used by the card: `/sites/catalogue/<id>`, pushed. The route
  itself arrives in Task 7; this task's tests assert the location pushed
  through a stub router.

- [ ] **Step 1: Failing tests**, the same set in both map test files:
  - `built-in dive site pins show with nothing switched on`.
  - `a diver with no sites sees pins, not the empty card`; `with both
    layers off the empty card returns`.
  - `the card's Details opens the record's page` (location
    `/sites/catalogue/a`).
  - `turning a selected pin's layer off clears its card`.
  - `a selected record that becomes the diver's loses its card`: the
    diver's sites gain one with `catalogueId: 'a'`.
  - Info card test: no Details button without `onDetails`; with it, a
    button that calls it.
  Existing cases that switched the overlay on now override the layers.
- [ ] **Step 2:** Run each alone; fail.
- [ ] **Step 3:** Write the mixin by moving `_selectedBuiltInId`,
  `_buildBuiltInInfoCard` and `_addBuiltInSite` out of both files as they
  are, then add the reset rule: listen to `builtInMapLayersNotifierProvider` and
  to `sitesWithCountsProvider`; clear when the selected record's kind is
  not shown or `linkedCatalogueIds(userSites)` contains its id. The
  selected record's kind is read from the card's record
  (`visibleBuiltInSitesProvider` value, else `catalogueSiteProvider`).
- [ ] **Step 4:** Both maps use the mixin, `BuiltInLayersButton` and the
  empty-card condition `sitesWithLocation.isEmpty && !layers.any` (the
  card is its own small `Consumer`, so the map does not rebuild).
- [ ] **Step 5:** `flutter analyze` on the whole repo is clean. Run the
  three test files, then `site_map_page_test.dart`,
  `site_map_content_test.dart`, `test/architecture/`, `test/shared/`.
  Check both map files are no longer than they were. Commit Tasks 3 to 5
  together:
  `feat(dive-sites): built-in dive sites on the Sites map by default, wrecks and reefs as a second layer`.

### Task 6: What is near a record

**Files:**
- Create: `lib/features/dive_sites/domain/services/catalogue_nearby.dart`, `lib/features/dive_sites/presentation/providers/catalogue_site_page_providers.dart`
- Test: `test/features/dive_sites/domain/services/catalogue_nearby_test.dart`, `test/features/dive_sites/presentation/providers/catalogue_site_page_providers_test.dart`

**Interfaces:**
- Produces:
  ```dart
  const double kCatalogueNearbyRadiusMeters = 10000;
  const int kCatalogueNearbyOwnLimit = 5;
  const int kCatalogueNearbyRecordLimit = 6;

  class NearbyOwnSite { final DiveSite site; final int diveCount; final double meters; }
  class NearbyRecord { final CatalogueSite record; final double meters; }
  class CatalogueNearby {
    final List<NearbyOwnSite> yours;      // nearest first, at most 5
    final List<NearbyRecord> builtIn;     // dive sites then registers, at most 6
    final NearbyOwnSite? here;            // nearest unlinked own site within 150 m
    bool get isEmpty;                     // both lists empty
  }
  CatalogueNearby catalogueNearby({
    required CatalogueSite record,
    required List<CatalogueSite> candidates,   // any order, may hold the record
    required List<SiteWithDiveCount> userSites,
  });

  /// The id of the diver's site that claims [catalogueId], or null.
  final catalogueOwnerSiteIdProvider; // Provider.family<String?, String>
  final catalogueNearbyProvider;      // FutureProvider.autoDispose.family<CatalogueNearby, String>
  final catalogueSeaNameProvider;     // FutureProvider.autoDispose.family<String?, String>
  ```
  The owner is the site whose `catalogueId` is the id; failing that, one
  whose `catalogueAnswers.also` holds it. `catalogueNearbyProvider` reads
  `near(point, radiusMeters: 10000, limit: 500)` once and hands the rows
  to the rule. `catalogueSeaNameProvider` gives
  `catalogueSeaInDiversLanguage(...) ?? record.bodyOfWater`.

- [ ] **Step 1: Failing tests.**
  - Rule: own sites within 10 km nearest first with counts, capped at 5,
    one at 10.1 km left out; built-in list puts a dive site record at
    8 km before a register record at 1 km; the record itself, a record
    the diver has linked and a record within 150 m of an unlinked own
    site are all absent; `here` is the nearest unlinked own site within
    150 m and is null for a linked one; a record without coordinates
    gives the empty result; a crowded neighbourhood (Review Focus 5): 40
    register records within 10 km, the 10 nearest linked by the diver,
    still returns 6.
  - Providers: owner by link, by `also`, null otherwise, and it changes
    when the diver's sites do; the sea falls back to the catalogue's text
    in English.
- [ ] **Step 2:** Run each alone; fail.
- [ ] **Step 3:** Implement. The hiding goes through
  `offerableCatalogueSites(..., byPosition: true)`.
- [ ] **Step 4:** Pass. Commit
  `feat(dive-sites): work out what lies near a built-in site`.

### Task 7: The built-in page

**Files:**
- Create: `catalogue_site_page.dart` and the six files under `widgets/catalogue_page/` (see File Structure)
- Modify: `lib/features/dive_sites/presentation/catalogue_site_display.dart`, `lib/core/router/app_router.dart`, `lib/features/dive_sites/presentation/widgets/built_in_site_info_card.dart` (the fact chip moves out to be shared), 11 ARB files
- Test: `test/features/dive_sites/presentation/pages/catalogue_site_page_test.dart`, `test/features/dive_sites/presentation/catalogue_site_display_test.dart`, `test/core/router/catalogue_site_route_test.dart`

**Interfaces:**
- Consumes: Task 6's providers; `catalogueSiteProvider`,
  `catalogueSourceProvider`; `TideSection(location:)`;
  `ReefSection(location:, waterType:)`; `catalogueKindIcon`.
- Produces:
  ```dart
  class CatalogueSitePage extends ConsumerStatefulWidget {
    const CatalogueSitePage({super.key, required this.catalogueId});
    final String catalogueId;
  }
  const double kCatalogueSitePageMaxWidth = 720;
  String catalogueSitePath(String catalogueId); // '/sites/catalogue/<id>'

  // catalogue_site_display.dart
  String catalogueKindLabel(CatalogueSite site, AppLocalizations l10n);
  Uri? catalogueSourceLinkUri(CatalogueSite site, CatalogueSource? source);
  ```
  `catalogueSourceLinkUri` returns null when `sourceRef` is not http or
  https, equals the source's `licenceUrl`, or its path ends in one of
  `.kml .kmz .zip .csv .json .xml .gpx .geojson` (case ignored).
- Route: `GoRoute(path: 'catalogue/:catalogueId', name: 'catalogueSite')`
  among the children of `/sites`, before `:siteId`.
- Page keys: `ValueKey('catalogueAddAction')` (app bar),
  `ValueKey('catalogueAddButton')` (foot),
  `ValueKey('catalogueYourSiteHere')`.
- Strings (English):
  - `diveSites_builtInPage_kindDiveSite`: "Built-in dive site"
  - `diveSites_builtInPage_kindWreck`: "Charted wreck"
  - `diveSites_builtInPage_kindReef`: "Charted reef"
  - `diveSites_builtInPage_notYours`: "Not in your sites"
  - `diveSites_builtInPage_yourSiteHere`: "Your site \"{name}\" is {distance} from here"
  - `diveSites_builtInPage_about`: "About"
  - `diveSites_builtInPage_nearby`: "Nearby"
  - `diveSites_builtInPage_nearbyYours`: "Your sites"
  - `diveSites_builtInPage_nearbyBuiltIn`: "Built-in sites"
  - `diveSites_builtInPage_source`: "Source"
  - `diveSites_builtInPage_credit`: "Credit: {credit}"
  - `diveSites_builtInPage_licence`: "Licence: {licence}"
  - `diveSites_builtInPage_notAGuide`: "A charted position, not a dive guide. Not for navigation."
  - `diveSites_builtInPage_notFound`: "This built-in site is no longer available"
  Reused: the Location card's row labels, the hazards title, "Website",
  the dive count, "Coordinates copied", the fullscreen map label, the
  water type's own name.

- [ ] **Step 1: Failing tests.**
  - Display: the kind label for a dive site record, a register typed
    `wreck`, one typed `artificial_reef`, one typed both (wreck); the
    source link for an OSM record, for a `sourceRef` equal to the licence
    address (null), for the AWOIS `.kml` (null), for `mailto:` (null).
  - Route: `/sites/catalogue/osm_node_1` builds `CatalogueSitePage` with
    that id and not `SiteDetailPage`.
  - Page, with `FakeSiteCatalogue` and overridden sites:
    - `a full record shows every card`: strip, header with "Built-in dive
      site" and "Not in your sites", About chips with depth in the
      diver's unit (a metric and an imperial run), Hazards, Location with
      formatted coordinates, `TideSection`, `ReefSection`, Nearby, Source
      with name, credit, licence and both links.
    - `a thin record shows no empty cards`: no About, no Hazards.
    - `a fresh-water record has no tides` and shows the water type chip.
    - `a register record`: "Charted wreck", the anchor on the strip, the
      "not a dive guide" sentence.
    - `no coordinates` (Review Focus 4): header and Source only.
    - `not found`: the message, no add buttons.
    - `a record that is the diver's opens their site`: by link and by
      `also`, at open; and when the sites change while the page is open.
    - `your site here`: the line, and tapping it opens that site.
    - `nearby rows open the right page`.
    - `held to a column on a wide window`: at 1,400 px the content is no
      wider than 720 and is centred.
    - `German at 360 px does not overflow`.
  Tides and reef are overridden to a fixed state in the page tests, as
  the site detail page's own tests do.
- [ ] **Step 2:** Run each alone; fail.
- [ ] **Step 3:** Implement the display helpers and the route.
- [ ] **Step 4:** Implement the page. The redirect uses
  `context.pushReplacement('/sites/<id>')` from a `ref.listen` on
  `catalogueOwnerSiteIdProvider` plus one check after the first frame,
  guarded so it fires once; while the owner is known the body is a
  progress indicator, never the record. The strip's map is locked
  (`InteractiveFlag.none`, inside `LockedMapScrollPassthrough`); its
  fullscreen page is interactive with the map style control. The body is
  a `SingleChildScrollView` whose child is `Center` over a
  `ConstrainedBox(maxWidth: 720)`.
- [ ] **Step 5:** Strings into all 11 ARB files; regenerate.
- [ ] **Step 6:** The three test files pass; `test/architecture/` and
  `test/shared/`; no new file over 800 lines. Commit
  `feat(dive-sites): a page for each built-in site`.

### Task 8: Adding from the page

**Files:**
- Modify: `catalogue_site_page.dart`
- Test: `test/features/dive_sites/presentation/pages/catalogue_site_page_add_test.dart`

**Interfaces:**
- Consumes: `catalogueSiteAdopterProvider`, `captureRulesAfterCreate`,
  `sitesWithCountsProvider`.

- [ ] **Step 1: Failing tests.** `two taps adopt once` (a completer holds
  the adopter; both buttons are disabled meanwhile); `a created site gets
  its rules and one that existed does not`; `on success the page is
  replaced by the site's page and a message shows`; `on failure the page
  stays and says so`; `the page is replaced once`, though the owner
  provider also changes.
- [ ] **Step 2:** Run; fail.
- [ ] **Step 3:** Implement, sharing one "replace once" guard with the
  redirect of Task 7.
- [ ] **Step 4:** Pass. Commit
  `feat(dive-sites): add a built-in site from its page`.

### Task 9: Import results open the page

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_import_page.dart`, `lib/features/dive_sites/presentation/widgets/catalogue_import_site_card.dart`, `lib/core/router/app_router.dart`
- Test: `test/features/dive_sites/presentation/pages/site_import_page_test.dart`

**Interfaces:**
- Produces: `SiteImportPage({super.key, this.initialQuery})`; the route
  passes `state.uri.queryParameters['q']`.
  `CatalogueImportSiteCard` takes `onOpen` in place of opening the sheet
  itself.

- [ ] **Step 1: Failing tests.** `tapping a result opens its page`;
  `tapping an imported result opens the diver's site` (the owner's id,
  from the diver's sites); `an initial query fills the field and runs the
  search once`; `a blank initial query does nothing`.
- [ ] **Step 2:** Run; fail.
- [ ] **Step 3:** Implement. The Import button on the card is unchanged.
- [ ] **Step 4:** Pass. Commit
  `feat(dive-sites): open a built-in site's page from an Import result`.

### Task 10: The Sites search row

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/search_built_in_sites_row.dart`
- Modify: `lib/features/query/presentation/widgets/entity_search_header.dart`, `lib/features/dive_sites/presentation/widgets/site_list_content.dart`, 11 ARB files
- Test: `test/features/dive_sites/presentation/widgets/search_built_in_sites_row_test.dart`, `test/features/query/presentation/widgets/entity_search_header_test.dart`

**Interfaces:**
- Produces:
  ```dart
  // entity_search_header.dart
  /// Rows of a list's own, under "Search everything": given the typed
  /// text and its clean tree, null when the text does not parse.
  final List<Widget> Function(String text, QueryNode? parsed)? extraRows;

  const kSearchBuiltInSitesRowKey = ValueKey('search-built-in-sites-row');
  class SearchBuiltInSitesRow extends ConsumerWidget { const SearchBuiltInSitesRow({super.key, required this.text}); }
  bool isPlainWordsQuery(QueryNode? parsed); // a TextNode, or an AndNode of TextNodes
  ```
  The row pushes `Uri(path: '/sites/import', queryParameters: {'q': text.trim()})`.
- String: `diveSites_search_builtIn`: "Search built-in sites for \"{text}\"".

- [ ] **Step 1: Failing tests.** `isPlainWordsQuery`: one word, two words,
  a field condition (false), null (false). Header: `extraRows` is called
  with the text and the tree only while the field is focused and has
  text, and gets null for text that does not parse; a list that passes
  none shows only "Search everything". Row: it shows for "thistlegorm",
  not for "depth>20", not for a half-typed "depth>", not in demo mode
  (`demoModeActiveProvider` true); tapping it pushes the Import location
  with `q=thistlegorm`.
- [ ] **Step 2:** Run each alone; fail.
- [ ] **Step 3:** Implement; `site_list_content.dart` passes `extraRows`
  from `_buildSearchHeader`.
- [ ] **Step 4:** Pass, plus `test/architecture/` and `test/shared/`.
  Commit
  `feat(dive-sites): search the built-in catalogue from the Sites search field`.

### Task 11: Documentation and the last checks

**Files:**
- Modify: `docs/user/dive-sites.md`

- [ ] **Step 1:** Update the map section (two layers, defaults, kept on
  the device, the anchor), add "Built-in site pages", and amend the Import
  and list search text, as spec section 10 says.
- [ ] **Step 2:** `dart format .`; whole-repo `flutter analyze`;
  `python3.14 scripts/check_docs_links.py`; the tests of every file this
  branch touched, one area per run; `test/architecture/`, `test/shared/`
  and `test/l10n/`.
- [ ] **Step 3:** Time the overlay's read on the shipped catalogue (the
  world view, dive site records only, over a real local cache database)
  and note the figure for the PR.
- [ ] **Step 4:** Commit `docs(dive-sites): built-in site pages and map layers`.
- [ ] **Step 5:** After screenshots from the real app (the "before" set is
  taken before Task 1): the Sites map at its default on a phone and a
  desktop width, the layer menu, wrecks on, a pin's card with Details,
  the built-in page for a full record, a thin record and a register
  record in light and dark, the Import page, and the Sites search row.
