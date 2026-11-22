# Home Recent Outings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the sparse Activity calendar at the top of Home with a Recent outings panel of postcards, and fix the key number tiles (clipped trend lines, lone odd tile on a phone).

**Architecture:** A pure Dart grouping function turns dive summaries into outings and picks each outing's cover; two narrow repository reads feed it through one Home provider; a new L/tall panel renders one card per outing (photo cover or depth skyline) in a pager on a phone and a sideways row elsewhere. Presets change; there is no stored-layout migration.

**Tech Stack:** Flutter, Riverpod (`package:submersion/core/providers/provider.dart`), Drift custom selects, go_router, ARB localisation (11 files).

**Spec:** `docs/design/specs/2026-11-22-home-recent-outings-design.md` (issue #4898)

## Global Constraints

- Outings count the same dives as every other Home number: apply `DiveStatsScope.and(alias: 'd')` (no planned, draft or excluded dives).
- Decode stored dive times with `wallClockUtcFromMillis` (`lib/core/util/wall_clock_utc.dart`); a dive's local day is `DateTime(t.year, t.month, t.day)` from that wall clock, never `toLocal()`.
- Presentation code formats dates only through `UnitFormatter` (`formatDateRange`, `formatMonthYear`, ...), never a `DateFormat` constructor.
- Depths display in the diver's unit through `unitFormatterProvider`.
- No panel hard-codes a colour; use the theme's `colorScheme`.
- New strings go in all 11 ARB files under `lib/l10n/arb/`, then `flutter gen-l10n`.
- Home providers invalidate themselves on their repositories' change ticks and on `localDayChanges()`, and are not watched while their panel is hidden (#4251).
- Covers are existing media links shown through `MediaItemView(item:, thumbnail: true, targetSize:)`; nothing is copied.
- Up to 8 outings; trip-less dives join at a gap of 2 days or less; read at most the 300 most recent dives.
- Never use the em-dash character anywhere, including comments.
- Run only the test files you wrote or changed, by path; never a folder or the suite.

## Review Focus

- A trip-less dive on the same day as a trip's dives: it stays its own outing and its card opens exactly its dive, not the trip's (Task 3 test, Task 6 tap test).
- An outing whose only media are videos, or whose cover fails to load: the card still shows a picture (video thumbnail) or the skyline, never an empty box (Task 3 test, Task 6 test).
- A diver in a time zone east of UTC with a dive late in the evening: the outing's dates are the dive's own wall-clock day (Task 3 test under `Australia/Sydney` dates built from fields).
- Very long trip names and large text scale (1.6) on a phone card: one line, elided, no overflow (Task 6 test).
- Imperial units: max depth shows in feet on the card and in its semantics (Task 6 test).

---

### Task 1: Trend line fits its key number tile

**Files:**
- Modify: `lib/features/dashboard/presentation/panels/key_numbers_panel.dart` (`_Tile.build`, the `series` branch)
- Test: `test/features/dashboard/presentation/panels/key_numbers_panel_test.dart`

**Interfaces:**
- Produces: no new API; `_Tile` draws `HomeSparkline` in the height left under its text, at most 16.

- [ ] **Step 1: Write the failing test** `trend line lies inside the tile's content area`: pump `KeyNumbersPanel` with `pumpPanel` at width 390 (phone) and 1280 (desktop), text scale 1 and 1.6, `homeKeyNumbersProvider` overridden with `careerDives: 36`, `monthlySeries: [7, 0, 0, 0, 0, 15, 0, 0, 0, 0, 0, 0]`. For every `HomeSparkline`, find its ancestor `HomePanel` and assert `sparkRect.bottom <= panelRect.bottom - 10` (the panel's bottom padding is 10) and `sparkRect.height > 0`.
- [ ] **Step 2: Run it and see it fail** (phone, scale 1: spark bottom 194 > 191).
  Run: `flutter test test/features/dashboard/presentation/panels/key_numbers_panel_test.dart`
- [ ] **Step 3: Implement.** Replace the fixed `SizedBox(height: 16)` with a widget that takes the remaining height, capped at 16 (for example `Flexible` + `ConstrainedBox(maxHeight: 16)` with the column allowed to fill), and omit the line when less than 4 pixels remain.
- [ ] **Step 4: Run the test file; all pass.**
- [ ] **Step 5: Commit** `fix(dashboard): keep key number trend lines inside their tiles`

### Task 2: Headline first for an odd tile count on a phone

**Files:**
- Modify: `lib/features/dashboard/presentation/panels/key_numbers_panel.dart`
- Modify: `lib/l10n/arb/app_*.arb` (11 files): `dashboard_key_now` = "now"
- Test: `test/features/dashboard/presentation/panels/key_numbers_panel_test.dart`

**Interfaces:**
- Produces: `static bool KeyNumbersPanel.headlineFirst(HomeWidthTier tier, int tileCount)` (true only for `phone` with an odd count); `heightFor` accounts for it.

- [ ] **Step 1: Write the failing tests.**
  - `headlineFirst is phone-only and odd-only`: `headlineFirst(phone, 5)`, `(phone, 3)`, `(phone, 1)` true; `(phone, 4)`, `(tablet, 5)`, `(desktop, 5)` false.
  - `five tiles on a phone: a headline row then two pairs`: at width 390, the Dives tile's rect width equals the panel width (within 1), the other four tiles sit two per row, and `heightFor(context, phone, 5) == 3 * short + 2 * 8`.
  - `four tiles on a phone are unchanged`: two rows of two; height `2 * short + 8`.
  - `the headline shows the series start and now`: with Dives first and a 12-month series ending November 2026, texts `formatMonthYear(December 2025)` (through the test's `UnitFormatter`) and `now` are present.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement.** In `build`, when `headlineFirst`, render the first tile in its own row through a `_HeadlineTile` (value one type step larger, the sparkline beside the value filling the remaining width, start and "now" labels under it only when the tile has a series and it is the monthly series) and the rest two per row. Update `heightFor` to `headline ? 1 + (count - 1) / 2 rows : current rule`. Add `dashboard_key_now` to all 11 ARB files and run `flutter gen-l10n`.
- [ ] **Step 4: Run the test file; all pass.**
- [ ] **Step 5: Commit** `feat(dashboard): headline the first key number when a phone row would be lone`

### Task 3: Outings and their covers (pure domain)

**Files:**
- Create: `lib/features/dashboard/domain/home_outings.dart`
- Test: `test/features/dashboard/domain/home_outings_test.dart`

**Interfaces:**
- Produces:
  - `class OutingDive { String id; DateTime dateTime; String? tripId; String? tripName; String? siteName; double? maxDepth; Set<String> speciesIds; }` (`dateTime` is the wall clock flagged UTC).
  - `class Outing { String? tripId; String? name; DateTime firstDay; DateTime lastDay; List<String> diveIds; double? maxDepth; int speciesCount; List<double> depths; int get diveCount; }` (`name` null means "no site": the UI shows the localised fallback; `depths` in date order, a missing depth as 0).
  - `List<Outing> groupOutings(List<OutingDive> dives, {int limit = 8, int maxGapDays = 2})`, newest outing first by its last dive.
  - `class CoverCandidate { String mediaId; String diveId; bool isVideo; bool isFavorite; bool hasSpeciesTag; DateTime? takenAt; }`
  - `String? chooseOutingCover(Iterable<CoverCandidate> candidates)`: tiers favourite, species tag, any; within a tier photos before videos, then earliest `takenAt` (null last), then `mediaId` for a stable order.

- [ ] **Step 1: Write the failing tests** (dates built as `DateTime.utc(y, m, d, h)`, wall clock):
  - `trip dives form one outing named after the trip` (3 dives on trip t1 "Bonaire May 2026" over May 3 to 7: one outing, firstDay May 3, lastDay May 7, diveCount 3).
  - `trip-less dives 2 days apart join; 3 days apart split` (Sep 20, Sep 21, Sep 23 give one outing; Sep 20 and Sep 24 give two).
  - `a trip-less dive between trip dives is its own outing` (trip dives May 3 and May 5, trip-less May 4: two outings; the trip-less one has only its dive).
  - `trip-less outing is named after its most-dived site; ties go to the site dived first; no site gives a null name`.
  - `max depth, depths in date order, species counted once across dives` (species {a, b} and {b, c} give 3).
  - `newest first and capped at limit` (10 outings in, 8 out, the newest first).
  - `the day is the wall-clock day` (a dive at `DateTime.utc(2026, 5, 7, 23, 30)` has lastDay `DateTime(2026, 5, 7)`).
  - `cover: favourite beats species tag beats earliest; photo before video in a tier; none gives null`.
  - `cover: an outing with only videos picks the earliest video`.
- [ ] **Step 2: Run and see them fail** (`home_outings.dart` missing).
  Run: `flutter test test/features/dashboard/domain/home_outings_test.dart`
- [ ] **Step 3: Implement both functions** with immutable classes (`const` constructors, `copyWith` on `Outing`). Grouping: sort ascending by `dateTime`; trip dives bucket by `tripId`; trip-less dives chain while each dive's day is at most `maxGapDays` after the previous trip-less dive's day; then sort outings by last dive descending and take `limit`.
- [ ] **Step 4: Run; all pass.**
- [ ] **Step 5: Commit** `feat(dashboard): group dives into outings and choose each outing's cover`

### Task 4: Reads for outings and cover candidates

**Files:**
- Create: `lib/features/insights/data/repositories/insights_repository_outings.dart` (`part of 'insights_repository.dart'`; add the `part` line in `insights_repository.dart`)
- Create: `lib/features/media/data/repositories/outing_cover_repository.dart`
- Create: `lib/features/media/presentation/providers/outing_cover_providers.dart` (`outingCoverRepositoryProvider`)
- Test: `test/features/insights/data/repositories/insights_repository_outings_test.dart`, `test/features/media/data/repositories/outing_cover_repository_test.dart`

**Interfaces:**
- Consumes: `OutingDive`, `CoverCandidate` (Task 3).
- Produces:
  - `extension InsightsRepositoryOutings on InsightsRepository { Future<List<OutingDive>> getOutingDives({String? diverId, int limit = 300}); }`: one select over `dives d LEFT JOIN trips t LEFT JOIN dive_sites s`, species ids from `sightings` via `group_concat(DISTINCT species_id)`, `WHERE 1 = 1 <diver filter>${DiveStatsScope.and(alias: 'd')} ORDER BY d.dive_date_time DESC LIMIT ?`, times decoded with `wallClockUtcFromMillis`.
  - `class OutingCoverRepository { Future<List<CoverCandidate>> getCoverCandidates(List<String> diveIds); Future<List<MediaItem>> getMediaByIds(List<String> ids); }`: candidates are `media` rows with `dive_id IN (...)`, `file_type IN ('photo', 'video')`, `is_orphaned = 0`, with `hasSpeciesTag` from `EXISTS (SELECT 1 FROM media_species ms WHERE ms.media_id = m.id)`; `getMediaByIds` maps rows with `mediaItemFromJoinedRow` as `SiteDiveMediaRepository` does. Both return empty for an empty id list without querying.
  - `final outingCoverRepositoryProvider = Provider<OutingCoverRepository>((ref) => OutingCoverRepository());`

- [ ] **Step 1: Write the failing DB tests** with `setUpTestDatabase()` (pattern: `test/features/dashboard/presentation/providers/home_panel_providers_db_test.dart`):
  - `getOutingDives returns trip name, site name, depth and species, newest first`.
  - `getOutingDives leaves out planned, draft and excluded dives and other divers' dives`.
  - `getOutingDives decodes the wall clock` (stored `DateTime.utc(2026, 5, 7, 23, 30)` comes back with day 7).
  - `getCoverCandidates excludes signatures, documents, orphaned rows and site-only media; flags species tags and favourites`.
  - `getMediaByIds returns the requested items`.
- [ ] **Step 2: Run both files and see them fail.**
- [ ] **Step 3: Implement the two reads and the provider.**
- [ ] **Step 4: Run both files; all pass.**
- [ ] **Step 5: Commit** `feat(dashboard): read dives and cover candidates for Home outings`

### Task 5: The recent outings provider

**Files:**
- Create: `lib/features/dashboard/presentation/providers/home_outings_providers.dart`
- Test: `test/features/dashboard/presentation/providers/home_outings_providers_test.dart`

**Interfaces:**
- Consumes: Task 3 and Task 4 APIs; `insightsRepositoryProvider`, `mediaRepositoryProvider` (for `watchMediaChanges`), `currentDiverIdProvider`, `localDayChanges()`.
- Produces:
  - `class HomeOuting { Outing outing; MediaItem? cover; }`
  - `final homeRecentOutingsProvider = FutureProvider<List<HomeOuting>>(...)`: reads `getOutingDives`, groups, reads candidates for the kept outings' dives only, chooses one cover per outing, loads those items by id. Invalidates on `watchInsightsChanges()`, `watchMediaChanges()` and `localDayChanges()`.

- [ ] **Step 1: Write the failing test** with the repositories overridden by fakes: `pairs each outing with its chosen cover and leaves coverless outings null`; `reads candidates only for the kept outings' dives`; `rebuilds when the media tick fires`.
- [ ] **Step 2: Run and see it fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run; all pass.**
- [ ] **Step 5: Commit** `feat(dashboard): provide Home's recent outings with covers`

### Task 6: The Recent outings panel

**Files:**
- Modify: `lib/features/dashboard/presentation/home_panels.dart` (add `recentOutings` directly after `activityCalendar`; spec `HomePanelSpec(HomePanelWidth.l, HomePanelHeight.tall)`, not conditional)
- Modify: `lib/features/dashboard/presentation/home_panel_labels.dart` (`settings_homePanels_recentOutings`)
- Modify: `lib/features/dashboard/presentation/pages/dashboard_page.dart` (builder arm `HomePanelType.recentOutings => const RecentOutingsPanel()`)
- Create: `lib/features/dashboard/presentation/panels/recent_outings_panel.dart`
- Create: `lib/features/dashboard/presentation/widgets/outing_card.dart` (card plus `OutingSkyline` painter)
- Modify: 11 ARB files
- Test: `test/features/dashboard/presentation/panels/recent_outings_panel_test.dart`, `test/features/dashboard/presentation/home_panels_test.dart` (if it enumerates specs)

**Interfaces:**
- Consumes: `homeRecentOutingsProvider` (Task 5); `HomePanel`, `HomePanelAsync`, `homeWidthTierOf`, `openDiveList(context, ref, DiveFilterState(diveIds: ...))`, `unitFormatterProvider` (`formatDateRange`, depth conversion with the key numbers' one-decimal rule).
- Produces: `RecentOutingsPanel`, `OutingCard({required HomeOuting outing, required double skylineScaleMeters, required VoidCallback onTap})`, `OutingSkyline(depths, scaleMeters)`.

Strings (English; translate for the other 10 files):

| Key | English |
| --- | --- |
| `dashboard_panel_recentOutings` | Recent outings |
| `dashboard_outings_summary` | `{outings, plural, =1{1 outing} other{{outings} outings}} · {dives, plural, =1{1 dive} other{{dives} dives}}` |
| `dashboard_outings_dives` | `{count, plural, =1{1 dive} other{{count} dives}}` |
| `dashboard_outings_maxDepth` | `{depth} max` |
| `dashboard_outings_species` | `{count, plural, =1{1 species} other{{count} species}}` |
| `dashboard_outings_empty` | Your outings will show here once you log a dive |
| `dashboard_outings_unnamed` | Dives |
| `settings_homePanels_recentOutings` | Recent outings |

- [ ] **Step 1: Write the failing widget tests** (`pumpPanel`, override `homeRecentOutingsProvider`; covers left null except where noted, since `MediaItemView` needs platform access):
  - `phone shows one card at a time with page dots` (width 390, 3 outings: the first card's name visible, 3 dots).
  - `desktop shows cards side by side` (width 840: at least 4 cards laid out on one row when 5 outings exist).
  - `card shows name, dates, dives, max depth in feet and species; species omitted at zero`.
  - `a coverless card draws the skyline` (finds `OutingSkyline`).
  - `a trip card opens the trip` (`nav.location == '/trips/t1'`).
  - `a trip-less card opens exactly its dives` (override `openDiveList`'s filter provider and assert `diveIds` equals the outing's ids; follow the existing tag-link test for how to observe it).
  - `empty log shows the empty line`; `error shows the shared error state`; `loading shows placeholder cards at the final size`.
  - `a cover that cannot load falls back to the skyline` (drive whatever failure signal `MediaItemView` exposes; if it exposes none, wrap it with an `errorBuilder`-style fallback the card owns and test that).
  - `long name at text scale 1.6 on a phone does not overflow`.
  - `semantics label names the outing, dates, dives, depth with unit and species`.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement** the enum value, spec, label, builder arm, panel (pager with `PageView(controller: PageController(viewportFraction: 0.86))` on a phone; a horizontal `ListView` of cards at least 170 wide elsewhere), card and skyline painter (bars in `colorScheme.primary` on `colorScheme.primaryContainer`, the shared depth scale being the deepest dive among the outings shown), and the strings; run `flutter gen-l10n`. Panel tap opens `/trips`.
- [ ] **Step 4: Run the panel test file and `home_panels_test.dart`; all pass.**
- [ ] **Step 5: Commit** `feat(dashboard): Recent outings panel with photo and skyline postcards`

### Task 7: Presets

**Files:**
- Modify: `lib/features/dashboard/presentation/home_presets.dart`
- Test: `test/features/dashboard/presentation/home_presets_test.dart`, `test/features/dashboard/presentation/pages/dashboard_page_test.dart` (add the outings override to `pumpHome`)

**Interfaces:**
- Produces: Balanced `[keyNumbers, ...waiting, recentOutings, gearService, latestProfile, recentDives, depthMix, divesPerMonth, gasMix, photoRibbon, recentSitesMap, onThisDay]`; Logbook `[keyNumbers, ...waiting, recentOutings, latestVsAverage, latestProfile, recentDives, photoRibbon, recentSitesMap, speciesSeen, onThisDay]`; Ready and Trends unchanged.

- [ ] **Step 1: Write the failing tests:** `Balanced and Logbook lead with recent outings and no longer show the calendar in Balanced`; `on desktop the outings row is full in Balanced (with gear service) and Logbook (with latest vs average)` using `packHomeRows`; `a stored layout without recentOutings gains it hidden next to the calendar` (`resolveHomeLayout`).
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Update the two preset lists** and the `pumpHome` overrides.
- [ ] **Step 4: Run `home_presets_test.dart`, `home_layout_test.dart` and `dashboard_page_test.dart`; all pass.**
- [ ] **Step 5: Commit** `feat(dashboard): put recent outings in the Balanced and Logbook presets`

### Task 8: Checks and after screenshots

- [ ] `dart format .`, then `flutter analyze` (whole repo, no issues).
- [ ] Run each test file touched above, by path.
- [ ] Extend the uncommitted `test/_pr_shots/home_shots_test.dart` with `homeRecentOutingsProvider` overridden by the maintainer's five outings (two covers as `localFile` media items pointing at the two scratchpad photos), render `--dart-define=STAGE=after` for phone and desktop, light and dark, and compare with the before shots.
- [ ] Delete `test/_pr_shots/` before any push.
