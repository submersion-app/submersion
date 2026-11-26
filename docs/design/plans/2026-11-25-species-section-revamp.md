# Species Section Revamp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (native, in one session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `/species` into a photo-first life list and a species' page into a field-guide page, with cover crops and ID practice that remembers misses (issue #5027).

**Architecture:** New read-only queries (best crop per species, crops for one species, place memberships, month counts, photo depths) feed pure domain functions (picture choice, rarity, life list summary, grouping, Leitner scheduling) that the rebuilt list page, species page and a new practice page render. Two new per-diver synced tables (`species_covers`, `species_practice`) hold the only new writes; nothing writes to the `species` row.

**Tech Stack:** Flutter, Riverpod (`lib/core/providers/provider.dart`), Drift (raw `customSelect` SQL as the existing repositories do), go_router, fl_chart 1.1, SharedPreferences for device prefs.

**Spec:** `docs/design/specs/2026-11-25-species-section-revamp-design.md`

## Global Constraints

- Nothing writes to the `species` table (a stamped `hlc` freezes built-in catalog text).
- Pictures follow the media library scope: `(m.dive_id IS NULL OR d.diver_id = ?)`. Counts, the no-photo count and the practice pool follow the life list scope (the diver's dives under `DiveStatsScope.and(alias: 'd')`).
- A crop belongs to species S when its identification is `accepted`, `decided_species_id = S`, and a `media_species` row exists for (media, S). One crop per media per species: the largest `MIN(box_pixel_width, box_pixel_height)`, newest `m.taken_at` on a tie.
- Practice uses only crops whose tag is confirmed: `COALESCE(ms.unconfirmed, 0) = 0`.
- Picture preference everywhere: cover, best crop, newest tagged photo, category tile.
- Rarity: New = first seen within 90 days; Seen once = `diveCount == 1`; Not seen lately = last seen more than 2 years (730 days) ago; Mastered = practice box 5. First match wins, in that order.
- Leitner: boxes 1 to 5; right moves up one box (max 5) with next due 1, 3, 7, 21 days for boxes 2, 3, 4, 5; wrong sets box 1, due now. Session size 10; practice offered with 4 or more eligible species.
- Season chart counts dives that saw the species per calendar month across all years (not a rate).
- Depth: dots from `media.depth_meters` of tagged media on life-list dives; with none, the band is the range of dive `max_depth`, labelled "Dive max depth". Every depth through `UnitFormatter`.
- Group by and grid/list are device prefs (SharedPreferences), not synced.
- Every new string in `app_en.arb` and translated in all 10 other ARBs (ar de es fr he hu it nl pt zh); Arabic plurals carry zero/one/two/few/many/other; run `flutter gen-l10n` LAST.
- No em-dashes in code, comments, docs or strings. Files under 800 lines. `dart format .` before each commit. Run only the test files you wrote or changed, by path.
- Dates and times read from Drift `dateTime()` columns come back local-flagged; dive times are wall-clock-as-UTC: compare and bucket months on the stored wall-clock fields, never `toLocal()`.

## Review Focus

1. A species with 300 crops on 17 photos (Brown chromis in the real log): the strip shows 17 tiles, practice draws from 17 shots, no duplicates of one photo.
2. A cover whose media, identification or tag was deleted: the page shows the best crop, never a broken image or a crash.
3. A diver with no identification model and no crops: the grid shows tagged photos, then category tiles; practice explains it needs 4 species with confirmed crops.
4. A synced device without the originals (or a video crop): the hero shows the stored 320 px crop, not a spinner or an error tile.
5. Grouping by Trip or Site with dives that have no trip or no site: those species land in "No trip" / "No site" and are not lost; a species seen on 3 trips appears in 3 sections.

---

## File map

| File | Responsibility |
| --- | --- |
| `lib/features/marine_life/domain/entities/species_crop.dart` (new) | `SpeciesCrop`, `SpeciesPicture` (sealed), `chooseSpeciesPicture` |
| `lib/features/marine_life/domain/species_rarity.dart` (new) | `SpeciesRarity`, `rarityFor` |
| `lib/features/marine_life/domain/life_list_summary.dart` (new) | `LifeListSummary`, `summarizeLifeList` |
| `lib/features/marine_life/domain/species_grouping.dart` (new) | `SpeciesGroupBy`, `SpeciesGroup`, `SpeciesPlaces`, `groupSeenSpecies` |
| `lib/features/marine_life/domain/practice/leitner.dart` (new) | `PracticeState`, `applyAnswer`, `pickPracticeSession`, `pickDistractors` |
| `lib/features/marine_life/data/repositories/species_gallery_repository.dart` (new) | best crop per species, crops for a species, practice pool |
| `lib/features/marine_life/data/repositories/species_facts_repository.dart` (new) | place memberships, month counts, photo depths |
| `lib/features/marine_life/data/repositories/species_cover_repository.dart` (new) | covers table reads and writes |
| `lib/features/marine_life/data/repositories/species_practice_repository.dart` (new) | practice table reads and writes |
| `lib/core/database/tables/species_revamp_tables.dart` (new) | `SpeciesCovers`, `SpeciesPractice` tables |
| `lib/features/marine_life/presentation/providers/species_gallery_providers.dart` (new) | providers over the new repositories |
| `lib/features/marine_life/presentation/providers/species_browse_prefs_providers.dart` (new) | Group by and grid/list prefs |
| `lib/features/marine_life/presentation/widgets/species_picture_view.dart` (new) | draws a `SpeciesPicture` at any size |
| `lib/features/marine_life/presentation/widgets/species_hero.dart` (new) | sharp hero with box zoom and fallback |
| `lib/features/marine_life/presentation/widgets/life_list_header.dart` (new) | header figures, growth line, no-photo chip |
| `lib/features/marine_life/presentation/widgets/species_card.dart` (new) | grid card with rarity badge |
| `lib/features/marine_life/presentation/widgets/species_grouped_view.dart` (new) | None grid, shelves, stacked sections |
| `lib/features/marine_life/presentation/widgets/species_crop_strip.dart` (new) | the strip, viewer launch, cover menu |
| `lib/features/marine_life/presentation/widgets/species_facts_row.dart` (new) | facts row |
| `lib/features/marine_life/presentation/widgets/species_depth_season_section.dart` (new) | depth band and month bars |
| `lib/features/marine_life/presentation/widgets/species_sightings_timeline.dart` (new) | dot per dive across years |
| `lib/features/marine_life/presentation/pages/species_page.dart` (modify) | rebuilt list page |
| `lib/features/marine_life/presentation/pages/species_detail_page.dart` (+ new part `species_detail_page_layout.dart`) | rebuilt species page |
| `lib/features/marine_life/presentation/pages/species_practice_page.dart` (new) | practice session and summary |
| `lib/features/media/presentation/pages/media_viewer_page.dart`, `media_viewer_launcher.dart` (modify) | optional video start position |
| `lib/core/router/app_router.dart` (modify) | `/species/practice` before `:speciesId` |
| `docs/user/marine-life-and-photos.md` (modify) | user guide |

---

### Task 1: Pictures: crop entity and picture choice

**Files:**
- Create: `lib/features/marine_life/domain/entities/species_crop.dart`
- Test: `test/features/marine_life/domain/entities/species_crop_test.dart`

**Interfaces:**
- Produces:
  - `class SpeciesCrop extends Equatable { identificationId, mediaId, IdentificationBox box, int shorterSide, int? bestMs, bool isVideo, DateTime? takenAt, bool confirmed }` with `copyWith`.
  - `sealed class SpeciesPicture`; `CropPicture(SpeciesCrop crop)`, `PhotoPicture(MediaItem media)`, `NoPicture()`.
  - `SpeciesPicture chooseSpeciesPicture({SpeciesCrop? cover, MediaItem? coverPhoto, SpeciesCrop? bestCrop, MediaItem? newestPhoto})`: cover crop, then cover photo, then best crop, then newest photo, else `NoPicture`.

- [ ] **Step 1: Write the failing tests** `chooses the cover crop over the best crop`, `a cover photo without a crop beats the best crop`, `falls back to the best crop, then the newest photo, then nothing`.
- [ ] **Step 2: Run** `flutter test test/features/marine_life/domain/entities/species_crop_test.dart`; expect a compile failure.
- [ ] **Step 3: Implement** the entity and function (reuse `IdentificationBox` from `species_id/domain/entities/media_identification.dart`).
- [ ] **Step 4: Run** the test; expect PASS.
- [ ] **Step 5: Commit** `feat(marine-life): species crop entity and picture choice`.

### Task 2: Rarity, life list summary and grouping (pure domain)

**Files:**
- Create: `lib/features/marine_life/domain/species_rarity.dart`, `life_list_summary.dart`, `species_grouping.dart`
- Test: `test/features/marine_life/domain/species_rarity_test.dart`, `life_list_summary_test.dart`, `species_grouping_test.dart`

**Interfaces:**
- Produces:
  - `enum SpeciesRarity { newSpecies, seenOnce, notSeenLately, mastered }`; `SpeciesRarity? rarityFor(SeenSpecies e, {required DateTime now, int? practiceBox})`.
  - `class LifeListSummary { int total; int newThisYear; List<({DateTime date, int cumulative})> growth; }`; `LifeListSummary summarizeLifeList(List<SeenSpecies> entries, {required DateTime now})` (growth: one point per distinct first-seen date, ascending).
  - `enum SpeciesGroupBy { none, category, firstSeen, trip, site }`.
  - `class SpeciesPlace { String? id; String name; DateTime? sortDate; }` (`id == null` means "No trip"/"No site").
  - `class SpeciesPlaces { Map<String, List<SpeciesPlace>> tripsBySpecies; Map<String, List<SpeciesPlace>> sitesBySpecies; Map<String, String?> firstTripBySpecies; Map<String, String?> firstSiteBySpecies; }`.
  - `class SpeciesGroup { String key; String? label; SpeciesCategory? category; int? year; SpeciesPlace? place; List<SeenSpecies> entries; Set<String> firstSeenHere; }` (label null for none, a category or a year: the widget localizes).
  - `List<SpeciesGroup> groupSeenSpecies(List<SeenSpecies> sorted, {required SpeciesGroupBy by, SpeciesPlaces? places})`.

- [ ] **Step 1: Write failing tests:**
  - rarity: `new beats seen once` (first seen 10 days ago, 1 dive gives `newSpecies`); `89 days is new, 91 is not`; `seen once`; `731 days since last seen is not seen lately, 729 is not`; `mastered only when nothing else applies`; `null for an ordinary species`.
  - summary: `counts new this calendar year only`; `growth is cumulative by first-seen date with ties merged`; `empty list gives zeros and no points`.
  - grouping: `none is one group in the given order`; `category groups follow SpeciesCategory order and skip empty categories`; `first seen groups by year newest first, each species once`; `trip lists a species under every trip, newest trip first, then No trip last`; `site orders by most species then name, No site last`; `firstSeenHere marks the species whose first trip is that trip`; `order inside each group keeps the input order`.
- [ ] **Step 2: Run** the three test files; expect failures.
- [ ] **Step 3: Implement.** `now` and dates compare on wall-clock fields (dive times are wall-clock-as-UTC).
- [ ] **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(marine-life): rarity, life list summary and grouping`.

### Task 3: Leitner practice scheduling (pure domain)

**Files:**
- Create: `lib/features/marine_life/domain/practice/leitner.dart`
- Test: `test/features/marine_life/domain/practice/leitner_test.dart`

**Interfaces:**
- Produces:
  - `class PracticeState extends Equatable { String speciesId; int box; DateTime dueAt; int rightCount; int wrongCount; DateTime? lastPractisedAt; }` with `copyWith`; `PracticeState.fresh(String speciesId, DateTime now)` (box 1, due now).
  - `PracticeState applyAnswer(PracticeState s, {required bool correct, required DateTime now})`.
  - `const kLeitnerDelays = {2: Duration(days: 1), 3: Duration(days: 3), 4: Duration(days: 7), 5: Duration(days: 21)}`.
  - `List<String> pickPracticeSession({required List<String> pool, required Map<String, PracticeState> states, required DateTime now, required Random random, int size = 10})`: due first (lowest box, then oldest due), then never practised (random), then the rest (random); no repeats; at most `size`.
  - `List<String> pickDistractors({required String answer, required Map<String, SpeciesCategory> categoryOf, required Random random, int count = 3})`: same category first, topped up from any other species; never the answer; distinct.

- [ ] **Step 1: Write failing tests:** `right answer in box 1 moves to box 2 due in 1 day`; `box 5 stays 5 and is due in 21 days`; `wrong answer goes to box 1 due now and counts wrong`; `session takes due species first, lowest box first`; `then never practised, then the rest`; `session is at most 10 and never repeats`; `pool of 6 gives a session of 6`; `distractors prefer the same category`; `distractors top up from other categories when the category is small`; `distractors never include the answer`. Seed `Random(1)`.
- [ ] **Step 2: Run**; expect failures.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(marine-life): Leitner scheduling for species practice`.

### Task 4: Gallery and facts queries

**Files:**
- Create: `lib/features/marine_life/data/repositories/species_gallery_repository.dart`, `species_facts_repository.dart`
- Test: `test/features/marine_life/data/repositories/species_gallery_repository_test.dart`, `species_facts_repository_test.dart` (in-memory database through the helper the existing `seen_species_repository_test.dart` uses)

**Interfaces:**
- Consumes: `SpeciesCrop` (Task 1), `SpeciesPlace`, `SpeciesPlaces` (Task 2).
- Produces:
  - `SpeciesGalleryRepository.bestCropBySpecies({String? diverId}) -> Future<Map<String, SpeciesCrop>>` (one SQL with `ROW_NUMBER() OVER (PARTITION BY decided_species_id ...)`).
  - `SpeciesGalleryRepository.cropsForSpecies(String speciesId, {String? diverId}) -> Future<List<SpeciesCrop>>`: one per media, newest first.
  - `SpeciesGalleryRepository.practicePool({String? diverId}) -> Future<Map<String, List<SpeciesCrop>>>`: life-list species only, confirmed tags only, one crop per media.
  - `SpeciesGalleryRepository.watchChanges() -> Stream<void>`: ticks on `media_identifications`, `media_species`, `media`, `media_identification_crops`.
  - `SpeciesFactsRepository.places({String? diverId}) -> Future<SpeciesPlaces>`.
  - `SpeciesFactsRepository.monthCounts(String speciesId, {String? diverId}) -> Future<List<int>>` (12 entries, January first; `strftime('%m', d.dive_date_time / 1000, 'unixepoch')` on the stored wall clock).
  - `SpeciesFactsRepository.photoDepths(String speciesId, {String? diverId}) -> Future<List<double>>` (meters).

- [ ] **Step 1: Write failing tests:**
  - `best crop is the largest box among accepted identifications with a tag`; `a rejected or undecided identification never counts`; `an accepted identification whose tag was removed does not count`; `20 crops on one photo give one crop for that photo` (cropsForSpecies length 1); `media of another diver is excluded, media with no dive is included`; `practice pool skips unconfirmed tags and species not on the life list`.
  - `places lists each trip once per species, a dive with no trip as No trip`; `firstTripBySpecies is the trip of the earliest sighting`; `month counts count dives, not sightings, by calendar month`; `photo depths come from tagged media on the diver's dives and skip null depths`.
- [ ] **Step 2: Run** both files; expect failures.
- [ ] **Step 3: Implement** with parameterized `customSelect` (as `SeenSpeciesRepository` does) and `DiveStatsScope.and(alias: 'd')` on life-list queries.
- [ ] **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(marine-life): queries for species crops, places, months and depths`.

<!-- TASKS 5 AND 6 (synced tables) ARE INSERTED HERE -->

### Task 7: Providers and device prefs

**Files:**
- Create: `lib/features/marine_life/presentation/providers/species_gallery_providers.dart`, `species_browse_prefs_providers.dart`
- Test: `test/features/marine_life/presentation/providers/species_browse_prefs_providers_test.dart`, `species_gallery_providers_test.dart`

**Interfaces:**
- Consumes: Tasks 1 to 6.
- Produces:
  - `speciesBestCropsProvider: FutureProvider<Map<String, SpeciesCrop>>`; `speciesCropsProvider: FutureProvider.family<List<SpeciesCrop>, String>`; `speciesPlacesProvider: FutureProvider<SpeciesPlaces>`; `speciesMonthCountsProvider`, `speciesPhotoDepthsProvider`: `FutureProvider.family<..., String>`; `speciesCoversProvider: FutureProvider<Map<String, SpeciesCover>>`; `speciesPracticeStatesProvider: FutureProvider<Map<String, PracticeState>>`; `speciesPracticePoolProvider: FutureProvider<Map<String, List<SpeciesCrop>>>`.
  - `speciesPicturesProvider: FutureProvider<Map<String, SpeciesPicture>>`: combines covers, best crops and `speciesCoverMediaProvider` through `chooseSpeciesPicture` (a cover whose crop is no longer in `speciesCropsProvider`/best crops falls through).
  - `speciesGroupByProvider: StateNotifierProvider<..., SpeciesGroupBy>` (key `species_page.group_by`, default `none`); `speciesBrowseGridProvider: StateNotifierProvider<..., bool>` (key `species_page.grid`, default `true`). Pattern: `species_map_prefs_providers.dart`; an unknown stored value reads as the default.
  - Every provider scoped by `currentDiverIdProvider` and invalidated by the same ticks as `seenSpeciesProvider` plus the gallery `watchChanges()` and the cover/practice repositories' `watchChanges()`.
- [ ] **Step 1: Write failing tests:** prefs `default is none and grid`, `persists and reads back`, `an unknown stored value reads as the default`; pictures `a stale cover falls back to the best crop`.
- [ ] **Step 2 to 4:** run, implement, run.
- [ ] **Step 5: Commit** `feat(marine-life): species gallery providers and browse prefs`.

### Task 8: Picture widgets and the sharp hero

**Files:**
- Create: `lib/features/marine_life/presentation/widgets/species_picture_view.dart`, `species_hero.dart`
- Test: `test/features/marine_life/presentation/widgets/species_picture_view_test.dart`, `species_hero_test.dart`

**Interfaces:**
- Consumes: `SpeciesPicture` (Task 1), `IdentificationCrop` (`species_id/presentation/widgets/suggested_species_section.dart`), `MediaItemView`, `colorForSpeciesCategory`, `iconForSpeciesCategory`.
- Produces:
  - `SpeciesPictureView({required SpeciesPicture picture, required SpeciesCategory category, BoxFit fit = BoxFit.cover, Size? targetSize})`: crop draws `IdentificationCrop`; photo draws `MediaItemView(thumbnail: true)`; none draws the category tile (colour fill, white icon).
  - `SpeciesHero({required Species species, required SpeciesPicture picture, MediaItem? cropMedia, Widget? emptyAction})`: for a `CropPicture` whose `cropMedia` is a photo, draws `MediaItemView` at a target whose longer side is 1600 px, transformed so the box plus 15% margin fills the hero (`FittedBox` over a `ClipRect`, alignment from the box centre); while loading or on error, the stored crop. Video, missing media or a `PhotoPicture`/`NoPicture` draw `SpeciesPictureView`. Name, scientific name and category sit over a bottom fade. `emptyAction` sits under the names when the picture is `NoPicture`.
  - `Rect heroSourceRect(IdentificationBox box, {double margin = 0.15})`: the normalized rect to show, clamped to 0..1 (pure, tested).
- [ ] **Step 1: Write failing tests:** `heroSourceRect pads by 15% and clamps at the edges`; `no picture shows the category tile and the empty action`; `a crop on a video draws the stored crop`; `a photo crop that fails to load falls back to the stored crop` (resolver returns `UnavailableData`).
- [ ] **Step 2 to 4:** run, implement, run.
- [ ] **Step 5: Commit** `feat(marine-life): species picture view and sharp hero`.

### Task 9: The list page

**Files:**
- Create: `life_list_header.dart`, `species_card.dart`, `species_grouped_view.dart` (widgets folder)
- Modify: `lib/features/marine_life/presentation/pages/species_page.dart`
- Test: `test/features/marine_life/presentation/widgets/life_list_header_test.dart`, `species_card_test.dart`, `species_grouped_view_test.dart`; update `test/features/marine_life/presentation/pages/species_page_test.dart`

**Interfaces:**
- Consumes: Tasks 2, 7, 8.
- Produces:
  - `LifeListHeader({required LifeListSummary summary, required int withoutPhoto, required bool noPhotoFilterOn, required ValueChanged<bool> onNoPhotoFilter})`: three tiles (species, New in <year>, growth line drawn with `fl_chart` `LineChart`, no axes); the chip only when `withoutPhoto > 0`.
  - `SpeciesCard({required SeenSpecies entry, required SpeciesPicture picture, SpeciesRarity? rarity, bool firstSeenHere = false, VoidCallback? onTap})`: picture at 4:3, name (2 lines max, ellipsis), "<n> dives", badge pill.
  - `SpeciesGroupedView({required List<SpeciesGroup> groups, required SpeciesGroupBy by, required bool grid, ...})`: `none` a `SliverGrid` (max cross-axis extent 200, so 2 columns at 390 and 6 at 1280); `category` shelves (horizontal `ListView` per group, cards 160 wide, header "<category> · <n>" with See all calling `onSeeAllCategory(category)`); `firstSeen`, `trip`, `site` stacked sections with sticky collapsible headers (`collapsible_group_header.dart`). `grid == false` renders `SeenSpeciesTile` rows in the same groups.
  - App bar gains a Group by menu (`species_group_by_menu`), a grid/list toggle (`species_view_toggle`) and Practice (`species_practice`).
- Behaviour: the header always reads the whole `seenSpeciesProvider` list; the no-photo chip filters to species whose picture is `NoPicture`; See all sets the category filter and Group by `none`; the existing count line, search, query chips, category chips, sort, review banner, download prompt, map and manage actions stay.
- [ ] **Step 1: Write failing tests:** header `shows total, new this year and the growth line`, `hides the chip at zero`; card `shows the rarity badge`, `long names ellipsize at 2 lines` (a 90-character name at 160 px); grouped view `shelves per category with See all`, `trip sections include No trip`, `list mode renders tiles`; page `group by persists across rebuilds`, `no-photo chip filters`, `header ignores the search`, `600 species build without per-card queries` (assert the gallery repository fake is called once).
- [ ] **Step 2 to 4:** run, implement, run.
- [ ] **Step 5: Commit** `feat(marine-life): photo-first life list with grouping and rarity`.

### Task 10: Video start position in the media viewer

**Files:**
- Modify: `lib/features/media/presentation/pages/media_viewer_page.dart` (keep under 800 lines; move a helper to a part if needed), `media_viewer_launcher.dart`
- Test: `test/features/media/presentation/pages/media_viewer_start_position_test.dart`

**Interfaces:**
- Produces: `MediaViewerPage({..., Duration? initialVideoPosition})` and `openMediaViewer(..., Duration? initialVideoPosition)`; applied once, to the initial item only, after its controller initializes (`seekTo`).
- [ ] **Step 1: Write the failing test** `seeks the first video to the start position once` with the existing fake video controller harness used by the viewer tests.
- [ ] **Step 2 to 4:** run, implement, run.
- [ ] **Step 5: Commit** `feat(media): open a video in the viewer at a given moment`.

### Task 11: The species page

**Files:**
- Create: `species_crop_strip.dart`, `species_facts_row.dart`, `species_depth_season_section.dart`, `species_sightings_timeline.dart` (widgets); `lib/features/marine_life/presentation/pages/species_detail_page_layout.dart` (part of `species_detail_page.dart`)
- Modify: `species_detail_page.dart` (`_body` becomes the new order; stat cards removed), `species_detail_page_editing.dart` (Find photos)
- Test: one test file per new widget; update `species_detail_page_*` tests whose finders pointed at the stat cards.

**Interfaces:**
- Consumes: Tasks 5, 7, 8, 10; `SpeciesWhereSeenSection`, `SpeciesSightingsSection`, `SpeciesPhotosSection`, `speciesInsightsProvider`.
- Produces:
  - `SpeciesCropStrip({required String speciesId, required List<SpeciesCrop> crops, required List<MediaItem> uncropped, String? coverIdentificationId, String? coverMediaId})`: lazy horizontal `ListView.builder`, tiles 96 square, cover first; tap opens `openMediaViewer` over the species' media with `initialVideoPosition: Duration(milliseconds: bestMs)` for a video; long-press and secondary-click open a menu "Use as cover" / "Remove cover" writing through `SpeciesCoverRepository`.
  - `SpeciesFactsRow({required SpeciesInsights insights, SpeciesRarity? rarity})`: dives, sites, first seen, last seen (unit formatter dates), badge.
  - `SpeciesDepthSeasonSection({required List<double> photoDepths, double? minDiveDepth, double? maxDiveDepth, required List<int> monthCounts})`: vertical band with dots, label "Dive max depth" when `photoDepths` is empty; fl_chart `BarChart` of 12 months with localized one-letter month labels from `DateFormat.MMMMM(locale)`; hidden when there are no sightings.
  - `SpeciesSightingsTimeline({required List<SpeciesSightingRecord> records})`: one dot per dive on a year axis; tap pushes `/dives/<id>`; a single year still draws a usable axis.
  - Page order: hero, strip, facts row, description, Where seen, depth and season, timeline then sightings list, photos. At width >= `ResponsiveBreakpoints.masterDetail` two columns (left: hero, strip, facts, description; right: the rest). Header and description stay framed for in-place editing.
  - Find photos: shown under the hero when the picture is `NoPicture` and `speciesTagCandidatesProvider(id)` is non-empty; it calls `editController.unlock(shown)` and then the existing `_tagInSitting(session)`.
- [ ] **Step 1: Write failing tests:** strip `shows one tile per photo, cover first`, `tap opens the viewer at bestMs for a video`, `long-press sets and removes the cover`; facts `formats dates with the unit formatter`; depth `dots from photo depths in feet for an imperial diver`, `falls back to the dive max depth band with its label`; season `twelve bars with the counts`; timeline `a dot per dive and tap opens the dive`; page `order of sections`, `two columns at 1280`, `Find photos only with candidates`, `editing the description still works` (existing unlock tests stay green).
- [ ] **Step 2 to 4:** run, implement, run.
- [ ] **Step 5: Commit** `feat(marine-life): field-guide species page`.

### Task 12: Practice page

**Files:**
- Create: `lib/features/marine_life/presentation/pages/species_practice_page.dart` (+ `species_practice_round.dart` widget if over 400 lines)
- Modify: `lib/core/router/app_router.dart` (route `practice`, name `speciesPractice`, declared before `:speciesId`), `species_page.dart` (action enabled state)
- Test: `test/features/marine_life/presentation/pages/species_practice_page_test.dart`

**Interfaces:**
- Consumes: Task 3, `speciesPracticePoolProvider`, `speciesPracticeStatesProvider`, `SpeciesPracticeRepository.save`.
- Behaviour: fewer than 4 pool species shows an explanation and a way back; otherwise a session from `pickPracticeSession`; each round one random crop of the species from the pool, four shuffled choices (answer plus `pickDistractors`), a common/scientific switch (scientific falls back to common when missing); answering marks right/wrong, shows the correct name and Next, and saves `applyAnswer`'s state at once (leaving mid-session keeps answered rounds); the summary shows the score and the missed species, each pushing `/species/<id>`.
- [ ] **Step 1: Write failing tests:** `explains when fewer than 4 species have confirmed crops`; `a right answer saves box 2`; `a wrong answer saves box 1 and lists the species in the summary`; `scientific names switch`; `leaving mid-session keeps saved answers`.
- [ ] **Step 2 to 4:** run, implement, run.
- [ ] **Step 5: Commit** `feat(marine-life): species ID practice that remembers misses`.

### Task 13: Strings, translations and the user guide

**Files:**
- Modify: `lib/l10n/arb/app_*.arb` (11 files), generated `app_localizations*.dart`, `docs/user/marine-life-and-photos.md`

- [ ] **Step 1:** Confirm every string the earlier tasks added in `app_en.arb` (keys prefixed `marineLife_speciesPage_`, `marineLife_speciesDetail_`, `marineLife_practice_`) has a translation in all 10 locales, inserted beside neighbouring keys of the same group; plurals with the CLDR categories each locale needs (Arabic all six).
- [ ] **Step 2:** `flutter gen-l10n`, then `grep -A1 "get marineLife_practice_title" lib/l10n/arb/app_localizations_de.dart` shows German.
- [ ] **Step 3:** Update the user guide: life list header and badges, Group by, covers, Find photos, practice and how it schedules.
- [ ] **Step 4:** Run the l10n guard tests the repo has for plurals and sentence caps, by path.
- [ ] **Step 5: Commit** `i18n(marine-life): species revamp strings in every locale` and `docs(marine-life): user guide for the species revamp`.

Note for Tasks 8 to 12: add each new English string to `app_en.arb` as the task needs it, and fill the other locales in Task 13 before running `gen-l10n` for the last time.
