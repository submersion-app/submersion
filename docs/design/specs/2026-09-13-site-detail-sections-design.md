# Site detail sections: show, hide, reorder and fold

Date: 2026-09-13
Issue: #1884

## Problem

The Dive Details page has a display-options dropdown (the tune icon in its
app bar) where a diver picks a Detailed or List layout, shows or hides each
section, drags sections into their own order, and turns everything back on
with Show all. A Reorder item opens a Settings page with the same list and a
Reset to default.

The Site Details page has none of this. Its body is a hard-coded `Column` of
sixteen cards in `site_detail_page.dart`, so a diver who never uses the tide
chart or the marine life card scrolls past them on every site, and a diver who
cares most about the dive statistics cannot move them to the top.

## Goals

- The Site Details page gets the same dropdown as Dive Details: Layout
  (Detailed / List), a Sections list with a visibility checkbox and a drag
  handle per card, Show all, and Reorder.
- Every card on the page is configurable, the map included. Nothing is
  fixed.
- A new Settings page, Settings > Appearance > Sites > Site detail sections,
  offers the same list with more room and a Reset to default.
- The List layout folds each card to a single header row, builds a card's
  content only once it is unfolded, and remembers which cards are unfolded.
- The choices are per diver, sync like the Dive Details choices, and apply
  to every site.
- The Dive Details page behaves exactly as it does today.

## Non-goals

- Per-site layouts. One configuration covers every site.
- Changing what any card shows, or the conditions under which it shows.
- Pre-loading asynchronous card data to decide whether a folded header row
  should appear (see "Self-erasing cards" below).
- Splitting the existing 1918-line `site_detail_page.dart`. New logic goes in
  new files; the existing card builders are not moved.

## Design

### 1. What the diver sees

**Dropdown.** A tune icon (`Icons.tune`) in the standalone app bar and in the
embedded master-detail header, beside Edit, opens a `MenuAnchor` with:

- A **Layout** heading with Detailed and List radio items.
- A **Sections** heading over a fixed-height, scrollable list of every card
  in the diver's saved order. Each row has a checkbox (tap toggles
  visibility), the card's icon, and a drag handle outside the tap target.
- **Show all**, disabled when every card is already visible. It turns every
  card on and leaves the order alone.
- **Reorder...**, which pushes the new Settings page.

The menu lists all sixteen cards even when some have nothing to show for the
current site. A site without coordinates can gain them later, so its map,
tide, water conditions and site features cards stay configurable. (Dive
Details hides gauge-only sections from its menu because those can never
render on that dive; no site card is in that position.)

**Cards and default order.** The default order is today's order:

| Id | Card | Shows when |
| --- | --- | --- |
| `map` | Map | site has coordinates |
| `diveStatistics` | Dives at this Site | always |
| `description` | Description | always (has an empty state) |
| `location` | Location | always |
| `depth` | Depth | always |
| `altitude` | Altitude | altitude is set |
| `features` | Site Features | site has coordinates |
| `tide` | Tide | coordinates and not freshwater |
| `reefHealth` | Water Conditions | site has coordinates |
| `marineLife` | Marine Life | always (self-manages) |
| `media` | Media | always (self-manages) |
| `difficulty` | Difficulty | difficulty is set |
| `rating` | Rating | always (has an empty state) |
| `hazards` | Hazards | hazards text is non-empty |
| `access` | Access | any access info is set |
| `notes` | Notes | always (has an empty state) |

A card renders only when it is visible in the diver's configuration AND its
"shows when" rule holds. The rules are unchanged from today.

The menu, the Settings page and the List layout's fold headers label each
card with the title the card itself shows (English: Map, Dives at this Site,
Description, Location, Depth Range, Altitude, Features, Tides, Ecosystem,
Species, Site Media, Difficulty Level, Rating, Hazards & Safety, Access &
Logistics, Notes), so the menu and the page always agree. The "Card" column
above is descriptive only.

**Pairs.** Difficulty + Rating and Hazards + Access are separate cards. In the
Detailed layout each pair renders side by side, at 700px of available width
or more, whenever both halves are visible and both have content, wherever
they sit in the order. The pair renders at the slot of whichever half comes
first; anything between the two drops below it. Left and right come from the
pair definition, not the order. When either half has nothing to show, both
render full width in their own slots. This is the Dive Details rule
(lookahead, not adjacency).

**List layout.** Every card folds behind a flat header row (icon and name).
Tapping the row unfolds it. A folded card's content is never built, which
matters here because the map, the tide chart and the water conditions lookup
are the expensive parts of the page. Unfolded state persists per card, so a
site reopens the way the diver left it. Pairs never form in List, and the
page uses tighter spacing.

**Spacing.** The site page keeps its own spacing rather than the dive page's:
Detailed uses a 12px gap between cards and 16px page padding (today's
values); List uses 8px and 8px.

### 2. Shared core, dive API unchanged

The parts of the dive implementation that know nothing about dives move to
shared code. The dive classes keep their public signatures and delegate.

- **`lib/core/constants/detail_section_order.dart`** (new) holds two generic
  top-level functions, each taking an `idOf` accessor:
  - `moveRenderedSection<C, T>(List<C> sections, T Function(C) idOf,
    List<T> rendered, int oldIndex, int newIndex)` re-anchors the moved
    section next to the rendered neighbour it was dropped against, leaving
    every section outside `rendered` (hidden ones included) where it was.
  - `ensureAllSections<C, T>(List<C> sections, T Function(C) idOf,
    List<T> allIds, C Function(T) create)` inserts each missing id just
    after its nearest preceding sibling in default order, or at the top.
  `DiveDetailSectionConfig.moveRenderedSection` and `.ensureAllSections`
  keep their signatures and call these. The legacy `decoO2` expansion stays
  in the dive class.
- **`lib/shared/widgets/section_properties_menu.dart`** (new) is the
  `MenuAnchor` dropdown, driven by data and callbacks:
  `layout`, `onLayoutChanged`, `List<SectionMenuEntry> entries` (key,
  label, icon, visible), `onToggle(int)`, `onReorder(int, int)`,
  `onShowAll` (the menu disables it while every entry is visible),
  `onOpenSettings`, and an optional `iconSize` for the compact embedded
  header. The tooltip text is the same on both pages, so it is not a
  parameter.
  `DiveDetailPropertiesMenu` keeps its constructor
  (`isGauge`) and becomes a wrapper that builds the entries (applying the
  gauge filter) and wires the callbacks to `settingsProvider`.
- **`lib/shared/widgets/section_fold.dart`** (moved) is today's
  `DiveSectionFold`, renamed `SectionFold`. It has one call site in
  `dive_detail_page.dart`, which is updated, and its test moves with it.
  `dive_detail_page_section_config_test.dart` finds the fold by type, so
  its `DiveSectionFold` references are renamed too (a type-name edit only).
- **Layout enum.** `DiveDetailLayout` (detailed / list, `fromName`,
  `localizedName`, `pairsSections`, `foldsSections`) is reused as is for the
  site layout. Its spacing getters are dive-specific and are not used by the
  site page.

### 3. Site pieces

- **`lib/core/constants/site_detail_sections.dart`** (new):
  `SiteDetailSectionId` (the sixteen ids above, in default order) with
  `icon` and `localizedDisplayName` / `localizedDescription`. There are no
  English-fallback getters: one value is named `description`, which a
  `description` getter would collide with, and nothing needs them. `SiteDetailSectionConfig`
  carries `id`, `visible`, `expanded`, `copyWith`, `toJson` (writes
  `expanded` only when true), `fromJson` / `tryFromJson`, `defaultSections`,
  `sectionsToJson` / `sectionsFromJson`, and `moveRenderedSection` /
  `ensureAllSections` delegating to the shared helpers.
- **`lib/core/constants/site_detail_section_pairs.dart`** (new): a small
  `SiteDetailSectionPair` (left, right, `minRowWidth` 700, `partnerOf`), the
  const list of the two pairs, and `siteDetailSectionPairFor(id)`.
- **`lib/features/dive_sites/presentation/widgets/site_detail_properties_menu.dart`**
  (new): the site wrapper around `SectionPropertiesMenu`.
- **`lib/features/dive_sites/presentation/widgets/site_detail_section_list.dart`**
  (new): turns the diver's configuration plus a map of card builders into
  the page body's children. It applies the visibility filter, pair lookahead,
  List folding with persisted unfold state, and exactly one gap between
  consecutive cards.
- **`lib/features/settings/presentation/pages/site_detail_sections_page.dart`**
  (new): toggle and drag list with a Reset to default overflow action. Route
  `/settings/site-detail-sections`, named `siteDetailSections`, linked from a
  new row on the Sites appearance page (`section_appearance_page.dart`),
  matching the Dives row that links to `/settings/dive-detail-sections`.
- **`site_detail_page.dart`** changes only its `build()` and headers:
  - `build()` replaces the hard-coded `Column` children with a
    `Map<SiteDetailSectionId, Widget?>` built in the page's own `build`
    (several card builders call `ref.watch`, which only works there). An
    entry is null when the card's "shows when" rule fails. Building a card
    widget is cheap; in the List layout a folded card is never mounted. The
    map goes to `SiteDetailSectionList`.
  - The existing `_build*Section` methods are unchanged.
  - `_pairOrSingle` is removed; pairing now happens in the section list.
  - The tune button is added to the standalone `AppBar` actions and to
    `_buildEmbeddedHeader`.

**Self-erasing cards.** Tide, Water Conditions, Marine Life, Media and Site
Features decide whether they have content only after their data loads, so
their builders always return a widget. In the List layout their header row
can therefore appear even when the unfolded content turns out empty. The
Dive Details page's Tide, Water Conditions and Sightings sections behave the
same way today; this design matches that rather than pre-loading data to
hide a header.

### 4. Settings, storage, migration, sync

**Settings model.** `AppSettings` gains:

- `siteDetailSections` (`List<SiteDetailSectionConfig>`, default
  `SiteDetailSectionConfig.defaultSections`)
- `siteDetailLayout` (`DiveDetailLayout`, default `detailed`)

`copyWith` gains both, plus `clearSiteDetailSections`. `SettingsNotifier`
gains `setSiteDetailSections`, `resetSiteDetailSections`,
`setSiteDetailLayout`, and `setSiteDetailSectionExpanded(id, expanded)`,
which returns without saving when nothing would change.

**Storage.** Two nullable `TEXT` columns on `diver_settings`:

- `site_detail_sections`: JSON array in the dive format,
  `[{"id":"map","visible":true}, ...]`, with `"expanded": true` only when
  set.
- `site_detail_layout`: the layout's `name`.

Null, empty, or unparseable values read back as the defaults. Unknown ids
are dropped. Ids missing from a saved order are inserted by default-order
adjacency, so a card added in a later release lands in a sensible place.
`DiverSettingsRepository` writes both columns on insert and on update and
reads them back, following the dive columns.

**Migration, schema v218.**

- `currentSchemaVersion` 215 -> 218. Main reached 215 on 2026-09-13 (#1639).
  Open PR #1860 renumbered to 216 and #1849 claims 217, so this rung takes
  218 and should merge after both (ascending merges). Re-scan the ladder
  immediately before pushing.
- `_assertSiteDetailColumns()` is PRAGMA-guarded and idempotent, and adds any
  missing column of the two. It runs from `onUpgrade` under `from < 218` and
  again from the `beforeOpen` backstop, like
  `_assertDiveDetailLayoutColumn`.
- `minimumCompatibleSchemaVersion` stays at 210. The change is additive and
  nullable, so older peers still sync.
- Tests that assert the previous scalar as shorthand for "the ladder
  finished" are pointed at `AppDatabase.currentSchemaVersion`; only the new
  rung's test pins 218.

**Sync.** `diver_settings` syncs at row level through the generic
`SyncDataSerializer` table entry, so the new columns travel with no
serializer change. A round-trip test proves it.

### 5. Strings

All 11 locales.

- Card names reuse the keys the cards already use for their titles:
  `diveSites_detail_section_*` (dive statistics, description, location,
  depth range, altitude, difficulty level, rating, hazards, access, notes),
  `siteFeature_sectionTitle`, `tides_title`, `reef_section_title`,
  `marineLife_siteSection_title`, `media_siteMediaSection_title`.
- New: one name key for the Map card, sixteen one-line description keys
  (`siteDetailSection_<id>_description`), the Settings page title
  (`settings_siteDetailSections_title`), and a "Site Details" group header
  on the Sites appearance page (`settings_appearance_header_siteDetails`).
  The link row under that header reuses the Dives row's existing
  "Section Order & Visibility" title and subtitle keys.
- The menu's labels (Layout, Sections, Show all, Reorder..., Detailed, List,
  Reset to default) reuse the existing Dive Details keys; the text is
  identical.
- `app_en.arb` is alphabetical; the other locale files are grouped by
  feature, so inserts anchor on a neighbouring key in every file.

## Error handling

- Settings JSON that fails to parse, or entries that fail to decode, fall
  back per entry (`tryFromJson`) and then to defaults, never throwing into
  the page.
- An out-of-range or no-op reorder returns the list unchanged.
- The migration helper tolerates a missing `diver_settings` table (fresh
  database) and an already-present column.

## Testing

TDD: each unit starts from a failing test.

**Unit**

- `test/core/constants/detail_section_order_test.dart`: moving between
  rendered sections with hidden ones in between, at either end, with
  out-of-range and equal indices; inserting missing ids after the nearest
  default-order sibling and at the top.
- `test/core/constants/site_detail_sections_test.dart`: JSON round trip,
  `expanded` omitted when false, null / empty / garbage input gives
  defaults, unknown ids dropped, missing ids inserted in place.
- `test/core/constants/site_detail_section_pairs_test.dart`: each id is in
  at most one pair, `partnerOf`, and default order lists each pair's halves
  adjacently.

**Dive regression.** These pass with no edits:
`dive_detail_sections_test`, `dive_detail_section_pairs_test`,
`dive_detail_properties_menu_test`, `dive_detail_page_section_config_test`,
`dive_detail_page_paired_sections_test`. `dive_section_fold_test` moves to
`test/shared/widgets/section_fold_test.dart`, and
`dive_detail_page_section_config_test` changes only its `DiveSectionFold`
type references; neither changes an assertion.

**Persistence and sync**

- Repository: both columns written and read back; null columns give
  defaults.
- `settings_providers_test`: each setter, reset, and the
  `setSiteDetailSectionExpanded` no-op.
- `migration_v218_test`: a v215 database gains both columns; the backstop is
  idempotent; the 218 tripwire. Older "ladder finished" literals now read
  `currentSchemaVersion`.
- Sync: both columns survive an export/import round trip of the
  `diverSettings` row.

**Widget**

- `site_detail_properties_menu_test`: toggle writes visibility; Show all
  disabled when all visible and restores visibility otherwise; drag writes
  the re-anchored order; layout radio switches; Reorder pushes the route.
- `site_detail_sections_page_test`: toggle, drag, Reset to default.
- `site_detail_page_section_config_test`:
  - a hidden card is not rendered, and the saved order is respected;
  - Difficulty + Rating sit side by side at 1400px wide and stack at
    390px;
  - a pair split by other cards still forms at the first half's slot;
  - a pair with an empty half falls back to two full-width cards;
  - List folds every card, and a folded card's content is not built;
  - tapping a header unfolds the card and persists it;
  - the tune button is present in the standalone and embedded headers.

**Verification before the PR.** `dart format .`; `flutter analyze` over the
whole project (infos are fatal in CI); the targeted tests, then one full
suite run; a throwaway golden (not committed) to screenshot the menu and
both layouts.

## Delivery

One PR, linked with `Closes #1884`.
