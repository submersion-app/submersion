# Site Dive Photos Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the photos from a site's dives in their own Site Details card, second by default, instead of a collapsed row at the bottom of Site Media.

**Architecture:** A new `SiteDetailSectionId.divePhotos` card, built by the page only when `mediaCountFromDivesAtSiteProvider` is non-zero. The card shows a one-row strip from a new capped newest-first query and swaps to the existing full chronological grid on "Show all". The old group leaves `SiteMediaSection`.

**Tech Stack:** Flutter, Riverpod (`FutureProvider.autoDispose.family`), Drift `customSelect`, ARB l10n (11 catalogs).

**Spec:** `docs/design/specs/2026-11-13-site-dive-photos-card-design.md`

## Global Constraints

- Card id `divePhotos`, declared directly after `description` in `SiteDetailSectionId` and `defaultSections`, visible by default.
- Card hidden (builder null) while the count is loading or zero.
- Strip: newest first, one row, as many tiles as fit; expanded grid: chronological, from `flatMediaFromDivesAtSiteProvider`, read only once expanded.
- Tap opens `SiteMediaViewerPage(scope: SiteViewerScope.divePhotos)`.
- Read-only: no selection, no add button.
- Every new string translated into all 10 non-en ARBs; `flutter gen-l10n` runs after the translations are in.
- Tiles reuse `MediaThumbnailTile` with the active diver's `UnitFormatterSettings`.

## Review Focus

1. Photos with no `taken_at`: the strip puts them after dated photos, not first (Task 1 test).
2. A saved layout from before this change: `divePhotos` lands right after the diver's own Description, wherever they moved it (Task 2 test).
3. A very wide card: the strip never shows more tiles than the query cap, and a phone width shows at least one (Task 3 test).
4. The last photo unlinked while the page is open: the count drops to zero and the card disappears (Task 4 test).
5. List layout, card folded: neither photo list provider is read (Task 4 test).

---

### Task 1: Newest-first capped query and provider

**Files:**
- Modify: `lib/features/media/data/repositories/site_dive_media_repository.dart`
- Modify: `lib/features/media/presentation/providers/site_media_providers.dart`
- Modify: `test/architecture/provider_tick_build_smoke_test.dart` (register the provider next to `flatMediaFromDivesAtSiteProvider`)
- Test: `test/features/media/data/repositories/site_dive_media_repository_test.dart`, `test/features/media/presentation/providers/site_dive_media_providers_test.dart`

**Interfaces:**
- Produces: `Future<List<MediaItem>> SiteDiveMediaRepository.getRecentMediaFromDivesAtSite(String siteId, {required int limit})`; `const int kSiteDivePhotoStripLimit = 12;` and `final recentMediaFromDivesAtSiteProvider = FutureProvider.autoDispose.family<List<MediaItem>, String>` (in `site_media_providers.dart`).

- [ ] **Step 1: Write failing repository tests**
  - `getRecentMediaFromDivesAtSite returns newest first, capped`: 5 photos at the site's dives with taken_at t1..t5, `limit: 3` gives ids `[p5, p4, p3]`.
  - `undated photos come after dated ones`: one null taken_at plus two dated, `limit: 10` gives `[newer, older, undated]`.
  - `excludes media on other sites' dives and site attachments`: same fixtures as the existing `getMediaFromDivesAtSite` exclusion test, result excludes them.
- [ ] **Step 2: Run, expect FAIL** (method not defined): `flutter test test/features/media/data/repositories/site_dive_media_repository_test.dart`
- [ ] **Step 3: Implement** the method: the `getMediaFromDivesAtSite` statement with `ORDER BY m.taken_at IS NULL, m.taken_at DESC, m.id DESC LIMIT ?`, same error logging, same `stats-scope-exempt` comment.
- [ ] **Step 4: Write failing provider test** in `site_dive_media_providers_test.dart`: `recentMediaFromDivesAtSiteProvider` returns the repository's list for the site and passes `limit: kSiteDivePhotoStripLimit`; it re-reads after a dives tick (mirror the existing flat-provider tick test).
- [ ] **Step 5: Implement the provider**: autoDispose family, `invalidateSelfWhen` on `mediaRepositoryProvider.watchMediaChanges()` and `diveRepositoryProvider.watchDivesChanges()`, as the flat provider does. Register it in the smoke test.
- [ ] **Step 6: Run both test files and `test/architecture/provider_tick_build_smoke_test.dart`, expect PASS.**
- [ ] **Step 7: Commit** `feat(media): read the newest photos from a site's dives`

### Task 2: Card id and strings

**Files:**
- Modify: `lib/core/constants/site_detail_sections.dart`
- Modify: `lib/l10n/arb/app_*.arb` (all 11), regenerate `lib/l10n/arb/app_localizations*.dart`
- Test: `test/core/constants/site_detail_sections_test.dart`

**Interfaces:**
- Produces: `SiteDetailSectionId.divePhotos` (icon `Icons.collections_outlined`); l10n getters `media_siteDivePhotos_title` ("Photos from dives"), `media_siteDivePhotos_titleWithCount(int count)` ("Photos from dives ({count})"), `media_siteDivePhotos_showAll` ("Show all"), `media_siteDivePhotos_showLess` ("Show less"), `siteDetailSection_divePhotos_description` ("Photos from the dives logged at this site"). `siteDetailSection_media_description` becomes "Maps, photos and documents attached to the site".

- [ ] **Step 1: Update failing tests**: the declared-order expectation gains `divePhotos` second; the display-name map gains `divePhotos: 'Photos from dives'`; new test `a saved layout without divePhotos gets it right after Description`: `sectionsFromJson` of the 18 old ids with `description` moved last gives `divePhotos` at the index after `description`, visible.
- [ ] **Step 2: Run, expect FAIL**: `flutter test test/core/constants/site_detail_sections_test.dart`
- [ ] **Step 3: Add the id** to the enum, `defaultSections`, `icon`, `localizedDisplayName` (`media_siteDivePhotos_title`), `localizedDescription`.
- [ ] **Step 4: Add the strings** to `app_en.arb` next to the `media_siteMediaSection_*` group (and the description next to `siteDetailSection_media_description`), with `@` metadata for the `count` placeholder (int). Translate into ar, de, es, fr, he, hu, it, nl, pt, zh, anchored on the same neighbouring keys. Reword the media description in every locale.
- [ ] **Step 5: `flutter gen-l10n`**, then run the test file, expect PASS (including `every card has a description in every locale`).
- [ ] **Step 6: Commit** `feat(dive-sites): add the dive photos card id` (ARBs and generated Dart together).

### Task 3: `SiteDivePhotosCard` widget

**Files:**
- Create: `lib/features/media/presentation/widgets/site_dive_photos_card.dart`
- Test: `test/features/media/presentation/widgets/site_dive_photos_card_test.dart`

**Interfaces:**
- Consumes: `recentMediaFromDivesAtSiteProvider`, `kSiteDivePhotoStripLimit` (Task 1); strings (Task 2).
- Produces: `class SiteDivePhotosCard extends ConsumerStatefulWidget { const SiteDivePhotosCard({super.key, required String siteId, required int count}); }`

Layout: a `Card` with 16 padding; header row of `Icons.collections_outlined`, `media_siteDivePhotos_titleWithCount(count)` in `titleMedium`, then a `TextButton` ("Show all" / "Show less") only when `count` exceeds the tiles that fit. Strip tiles are 88 square with 8 spacing: `fit = max(1, ((width + 8) ~/ 96))`, shown `min(fit, recent.length)`. Expanded: the old grid (4 columns, 8 spacing, `NeverScrollableScrollPhysics`, shrinkWrap). Tile semantics label `media_siteMediaSection_divePhotoLabel`. Loading: 88-high centered spinner; error: `media_diveMediaSection_errorLoading` in `colorScheme.error`.

- [ ] **Step 1: Write failing widget tests** (overrides for both list providers counting reads, `unitFormatterProvider` as in `site_media_section_test.dart`):
  - `shows the title with the count`: count 23 shows "Photos from dives (23)".
  - `strip shows as many newest photos as fit`: 400 wide card, 10 recent items: 4 `MediaThumbnailTile`s, the first being the first list item.
  - `strip never exceeds the query cap`: 2000 wide, `kSiteDivePhotoStripLimit` items: exactly that many tiles.
  - `a narrow card shows one tile`: 80 wide content shows 1.
  - `Show all hidden when everything fits`: count 3, 3 items, 400 wide: no "Show all".
  - `Show all reads the full list only when tapped`: flat reads 0 before the tap, 1 after; the grid shows every flat item; "Show less" returns to the strip.
  - `tapping a photo opens the viewer in divePhotos scope at that photo`.
  - `a failed read shows the error text`.
- [ ] **Step 2: Run, expect FAIL** (file missing).
- [ ] **Step 3: Implement** the widget as above.
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(media): add the site dive photos card`

### Task 4: Wire the card in, remove the old group

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (`_sectionCards`)
- Modify: `lib/features/media/presentation/widgets/site_media_section.dart` (delete `_DivePhotosGroup`, `_DivePhotosGrid`, their call, and the dive-photo lines of the class doc)
- Modify: ARBs: remove `media_siteMediaSection_divePhotosGroup` (and its `@` entry) from all 11, `flutter gen-l10n`
- Test: `test/features/dive_sites/presentation/pages/site_detail_page_test.dart`, `test/features/media/presentation/widgets/site_media_section_test.dart`

**Interfaces:**
- Consumes: `SiteDivePhotosCard` (Task 3), `SiteDetailSectionId.divePhotos` (Task 2), `mediaCountFromDivesAtSiteProvider`.

- [ ] **Step 1: Write failing page tests** (override `mediaCountFromDivesAtSiteProvider` and the recent provider):
  - `dive photos card shows right after Description when the site has dive photos`: count 3, `SiteDivePhotosCard` found and its top below Description's and above Depth's.
  - `no dive photos card when the site has none`: count 0, not found.
  - `the card leaves when the count drops to zero`: a `StreamController`-backed count override 2 then 0, card found then not.
  - `folded in the list layout, the card reads no photos`: list layout, recent and flat read counters both 0.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Add the card** to `_sectionCards`: `divePhotos: () { final count = ref.watch(mediaCountFromDivesAtSiteProvider(site.id)).value ?? 0; return count == 0 ? null : (_) => SiteDivePhotosCard(siteId: site.id, count: count); }`, placed after the description entry, with a one-line comment.
- [ ] **Step 4: Update `site_media_section_test.dart`**: delete the "Photos from dives here" tests (their behaviour now lives in Task 3's tests) and the now-unused `divePhotos*` host parameters; add `does not show photos from dives` (count override 5, no "Photos from dives" text, flat provider never read).
- [ ] **Step 5: Remove the old group and its ARB key**, `flutter gen-l10n`.
- [ ] **Step 6: Run** both test files, `test/features/media/`, `test/features/dive_sites/`, and `test/architecture/`, expect PASS. `dart format .` and `flutter analyze` clean.
- [ ] **Step 7: Commit** `feat(dive-sites): show photos from dives in their own Site Details card`
