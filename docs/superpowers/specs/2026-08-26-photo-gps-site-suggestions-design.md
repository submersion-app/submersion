# Photo GPS Site Suggestions: Design

Date: 2026-08-26
Branch: `worktree-photo-gps-site-suggestions`
Roadmap item: "GPS extraction from photos (suggest site creation)"
(`docs/FEATURE_ROADMAP.md`, Category 9, v2.0 tasks)

## Summary

Submersion already extracts GPS from photo EXIF on iOS and Android and shows a
"Create site" / "Add to site" banner on the dive edit page. This design closes
the gaps that keep that feature from being useful in practice:

1. Desktop imports carry no GPS at all (the pure-Dart fallback reader recovers
   only the capture time). Stills and video get GPS on every platform.
2. The banner offers to create a site without checking whether the diver
   already has one a few metres away. Photo GPS becomes a second point source
   for the existing site-matching subsystem, so nearby existing and bundled
   sites are offered first.
3. The banner appears only on the edit page. It also appears on the dive
   detail page, and multi-dive photo imports end with a prompt into the
   existing batch review page.
4. The "best" coordinate is the earliest linked photo. It becomes the photo
   nearest the dive's entry time.
5. Dismissal is a `setState` flag that resets on every page open. It becomes a
   synced per-dive column.

Two further changes fell out of the design and are in scope: the batch review
page learns a third apply mode (write coordinates onto a dive's existing site
that lacks them), and the quick-create dialog prefills country/region/city by
reverse geocoding.

## Current state (what exists today)

| Piece | Location |
| --- | --- |
| Native EXIF GPS (mobile only) | `lib/features/media/data/services/exif_extractor.dart:73-84` |
| Pure-Dart capture-time fallback (all platforms, no GPS) | `lib/features/media/data/services/capture_time_reader.dart` |
| Desktop gallery picker hardcodes `latitude: null` | `lib/features/media/data/services/photo_picker_service_desktop.dart:192` |
| `media.latitude/longitude/taken_at` columns | `lib/core/database/database.dart` (`Media` table) |
| Earliest-photo "best" query | `MediaRepository.getBestGpsFromDiveMedia` (`media_repository.dart:1056`) |
| Providers | `divePhotoGpsProvider`, `allDivePhotoGpsProvider` (`media_providers.dart:94,105`) |
| Banner (edit page only) | `lib/features/media/presentation/widgets/photo_gps_suggestion_banner.dart`, wired at `dive_edit_page.dart:2193` |
| Quick-create dialog (name only) | `lib/features/media/presentation/widgets/quick_site_from_gps_dialog.dart` |
| Site matcher (dive-computer GPS) | `lib/features/dive_sites/domain/matching/site_matcher.dart`, `match_thresholds.dart`, `site_match_sensitivity.dart` |
| Matching service (proposals + one-transaction apply) | `lib/features/dive_sites/data/services/site_matching_service.dart` |
| Batch review page | `lib/features/dive_sites/presentation/pages/site_match_review_page.dart`, `site_match_review_notifier.dart`, route `/dives/match-sites` |
| Eligibility for the import-wizard button | `eligibleImportedDivesProvider` over `DiveRepository.getDivesNeedingSiteMatch` |

Known defect fixed in passing: `getGpsFromDiveMedia` reads `taken_at` without
`isUtc: true`, producing a local `DateTime` for a wall-clock-UTC value (the same
class of bug as the taken-at hydration fix).

## Goals and non-goals

Goals:

- GPS from JPEG and HEIC stills on macOS, Windows and Linux.
- GPS from video: QuickTime `©xyz` / `com.apple.quicktime.location.ISO6709`
  (iPhone and most cameras) and GoPro GPMF telemetry.
- Nearest-existing-site before create, using the same matcher, thresholds and
  sensitivity setting as the dive-computer path.
- Banner on the detail page; prompt into batch review after multi-dive imports.
- Nearest-to-entry-time best point.
- Synced per-dive dismissal.
- Batch review can locate a dive's existing coordinate-less site.

Non-goals:

- RAW image formats.
- Using photo GPS as a signal inside `DivePhotoMatcher` (time-window
  matching is unchanged).
- Writing photo GPS onto `dives.entry_latitude/longitude`. Photo fixes are
  inferred surface positions, not measured entry points, and must not be
  confused with dive-computer GPS in attribution or consolidation.
- An "un-dismiss" control. Assigning a site or coordinates makes the
  suggestion moot; a dismissed dive stays dismissed.

## Section 1: Domain and data flow

### Best-point selection

`lib/features/media/domain/services/photo_gps_point_selector.dart` (pure):

```dart
PhotoGpsPoint? selectBestPhotoGps(
  List<PhotoGpsSample> samples,   // location, takenAt, mediaId
  DateTime entryTimeWallClockUtc,
)
```

Returns the sample whose `takenAt` is nearest to the entry time; ties resolve
to the earlier sample; empty input returns null. Every linked photo is
eligible. A manually linked photo is the user asserting it belongs to the
dive, so there is no window filter. Both timestamps are wall-clock-UTC and
compare directly.

### One query, no dive hydration

`MediaRepository.getBestPhotoGpsForDives(List<String> diveIds)` returns
`Map<String, PhotoGpsPoint>` from one SQL join of `media` to `dives`
(`entry_time`, `dive_datetime`) filtered to non-null, non-zero coordinates,
selected in Dart by the selector above. It reads `taken_at` with
`isUtc: true`. `divePhotoGpsProvider` becomes a thin wrapper over it;
`allDivePhotoGpsProvider` keeps its shape and gains the `isUtc` fix.

### Photo GPS as a second point source

`SiteMatchingService._pointFor(dive)` becomes an async resolver:
`entry ?? exit ?? photo`, with the photo map fetched once per
`computeProposals` call. `MatchProposal` gains
`pointSource` (`PointSource.diveComputer | PointSource.photo`).
`applyConfirmed`, the 100 m coincidence guard, and bundled-site
materialisation are unchanged.

### Third apply mode: locate the current site

`_CandidateRef` gains `currentSite(DiveSite)` beside `existing` and
`bundled`. In `computeProposals`, a dive whose site exists but has no
coordinates gets a synthetic candidate at the top of its list
(`MatchCandidateView.isCurrentSite = true`, the site's own name, no
distance). Decision rule for those dives:

- No user site with coordinates within the inner radius: status `clear`,
  recommended candidate = current site.
- A user site with coordinates within the inner radius: status `review`,
  candidates = current site plus the nearby ones (probable duplicate; the user
  decides between locating the current site and relinking the dive).

`_applyOne` for `currentSite` calls
`siteRepository.updateSite(site.copyWith(location: point))` inside the
existing single transaction (bumps the site HLC, so it syncs). `ApplyResult`
gains `sitesLocated`. This mode works for dive-computer GPS as well as photos.

### Post-commit altitude pass

After the apply transaction commits, a best-effort pass fetches elevation via
`elevationServiceProvider` for every site that just gained coordinates
(located current sites and created sites) and updates `altitude` when it was
null. Network calls never run inside the DB transaction; failures are ignored.

### Eligibility

`DiveRepository.getDivesNeedingSiteMatch(diverId, limitToIds)` becomes one
predicate:

```
(site_id IS NULL OR the site has NULL latitude/longitude)
AND (entry/exit GPS present OR EXISTS media row with GPS for the dive)
AND site_suggestion_dismissed_at IS NULL
```

The import-wizard button and the new post-import prompt share it. Consequence:
the wizard button now also counts dive-computer dives whose site lacks
coordinates.

### Dismissal

`dives.site_suggestion_dismissed_at` (nullable integer, epoch millis). Named
source-agnostically because it gates the whole suggestion for the dive,
banner and batch alike, regardless of point source.

## Section 2: Desktop GPS extraction, stills and video

### Shared plumbing

- `lib/features/media/data/services/isobmff_boxes.dart`: `_findBox`,
  `_BoxRange`, and the big-endian readers move here from
  `capture_time_reader.dart`.
- `lib/features/media/data/services/local_exif_loader.dart`:
  `img.ExifData? readLocalExif(File file, String mime)`. JPEG via
  `decodeJpgExif`; HEIC via the existing `meta > iinf > iloc` walk and TIFF
  header search. One parse per file, shared by the date and GPS readers.
- `capture_time_reader.dart` keeps the MP4 `mvhd` reader and becomes a thin
  consumer of the loader for stills.

### Still images

`lib/features/media/data/services/local_gps_reader.dart`:

- `({double latitude, double longitude})? gpsFromExif(img.ExifData exif)`
  reads `exif.gpsIfd` tags 0x1 (`GPSLatitudeRef`), 0x2 (`GPSLatitude`,
  three rationals: degrees, minutes, seconds), 0x3, 0x4. `S` and `W` negate.
  Returns null unless both axes parse; rejects `(0, 0)`, NaN, and
  out-of-range values.
- `readLocalGps(File file, String mime)` dispatches: images to the EXIF
  reader, `video/mp4` and `video/quicktime` to the video chain below.

### Video

Tried in order, first hit wins:

1. QuickTime style: `moov > udta > ©xyz` holding an ISO 6709 string such as
   `+12.3456-098.7654+010.000/`, then `moov > meta > keys / ilst` entry
   `com.apple.quicktime.location.ISO6709`. ISO 6709 parses with one regex.
2. GoPro GPMF (`lib/features/media/data/services/gpmf_gps_reader.dart`):
   find the `trak` whose `hdlr` handler type is `meta` and whose `stsd`
   entry is `gpmd`; chunk offsets from `stco` / `co64`, sizes from `stsz`;
   read one telemetry sample at a time (a few KB), never the surrounding
   `mdat`. Parse the KLV tree (`DEVC > STRM`); prefer `GPS9` (HERO11+,
   per-sample fix and DOP) over `GPS5` (sibling `GPSF` fix, `GPSP`
   precision); apply `SCAL`; return the first sample with a 2D or 3D fix.
   Cold-start clips have no fix at first, so the reader walks forward up to
   a hard cap of 30 samples and then returns null.

### Wiring

- `exif_extractor.dart`: after the `native_exif` block, `lat ??=` /
  `lon ??=` from `readLocalGps`, mirroring the existing `takenAt ??=`. Covers
  the Files tab, `LocalFileResolver`, and `TripMediaScanner` on every
  platform. `native_exif` throws for video on mobile too, so video GPS lands
  there through the same fallback.
- `photo_picker_service_desktop.dart`: replace the hardcoded
  `latitude: null, longitude: null` with `readLocalGps`.

### Validation requirement

GPMF is a binary telemetry format. The GoPro reader is not done on synthetic
fixtures alone: the plan includes a `--dart-define`-gated real-data test in
the style of the existing import-sample tests, and needs one real GoPro clip
and one real iPhone `.MOV` with location in the "submersion data" samples
folder. No such samples are on disk as of this writing.

## Section 3: Single-dive UI (edit page and detail page)

### Provider

`siteSuggestionForDiveProvider(diveId)` builds a `SiteMatchingService` with
the diver's sensitivity thresholds and runs `computeProposals([dive])`. Yields
null when the dive has a located site, is dismissed, or has no point;
otherwise `SiteSuggestion { GeoPoint point, PointSource pointSource,
MatchProposal proposal }`. Invalidates on media, site and dive changes.

### Banner

`PhotoGpsSuggestionBanner` becomes `SiteSuggestionBanner` in
`lib/features/dive_log/presentation/widgets/`. Title: "Location found in
photos" or "Location from dive computer" by source; coordinate line as today.
Actions in an `OverflowBar`:

| Dive state | Proposal | Primary | Secondary |
| --- | --- | --- | --- |
| No site | clear | Assign {site} · {distance} | Create site |
| No site | review | Choose nearby site ({n}) | Create site |
| No site | none | Create site | |
| Site without coordinates | clear | Add location to {site} | |
| Site without coordinates | review | Add location to {site} | Choose nearby site ({n}) |

"Choose nearby site" pushes `/dives/match-sites` with `[diveId]`. The dismiss
control writes the new column.

### One write path

`lib/features/dive_log/presentation/helpers/site_suggestion_actions.dart`
is used by both pages and routes every action through `SiteMatchingService`:

- `assign(candidateId)` and `addLocation()` call `applyConfirmed` with the
  chosen candidate id.
- `createSite()` shows `QuickSiteFromGpsDialog`, then
  `SiteMatchingService.createAndLink(diveId, site)` (also used by the review
  page's "Create site here"). `createAndLink` creates the site and sets the
  dive's `site_id` to it; a previous coordinate-less site on the dive is left
  untouched, not deleted or located.
- `dismiss()` calls `DiveRepository.setSiteSuggestionDismissed(diveId, true)`.

Each action returns the resulting `DiveSite?`. `_createSiteFromPhotoGps` and
`_updateSiteWithPhotoGps` in `dive_edit_page.dart` are deleted; the edit page
feeds the returned site into `_assignSite` so unsaved form state stays in
step.

### Quick-create dialog

`QuickSiteFromGpsDialog` calls `locationServiceProvider.reverseGeocode` on
open, best-effort, and prefills editable Country / Region / City fields; the
name stays empty with the locality as hint text. This is the explicit-capture
fill-empty pattern the site edit page uses for "Use my location". No
save-time geocoding is added.

### Detail page placement

The banner slots directly under the site header in both the compact and wide
layouts of `dive_detail_page.dart`. It renders `SizedBox.shrink()` when there
is nothing to suggest, so placement is unconditional.

## Section 4: Batch review page and post-import prompt

### Review page

- Each proposal tile shows a source chip ("photo" / "dive computer") from
  `MatchProposal.pointSource`.
- The current-site candidate renders as the first `_CandidateCard` labelled
  "Add location to this site", no distance, preselected when `clear`.
- `ProposalStatus.none` tiles get a "Create site here" button; other tiles
  offer it as a secondary action. It opens `QuickSiteFromGpsDialog` and calls
  `createAndLink` immediately, then refreshes that proposal out of the list.
  Immediate, not deferred to Confirm: a created site is a named user object
  and deferring would require an undo path for a dialog the user already
  completed.
- The confirm snackbar reports linked, created and located counts.

### Post-import prompt

`offerSiteReviewAfterImport(context, ref, diveIds)` runs after each
multi-dive linking flow: trip scan (`trip_scan_actions.dart`), Files-tab
`_commit` (`files_tab.dart`, which derives dive ids from the committed rows),
the Lightroom scan helper, and `media_import_view.dart`. It reads
`eligibleImportedDivesProvider(ImportedDiveIds(ids))` and, when non-empty,
replaces the plain success snackbar with one carrying a "Review sites ({n})"
action that pushes `/dives/match-sites` with those ids. The single-dive
`photo_import_helper` path does not prompt; the detail banner covers it.
Dismissed dives never count.

### Files-tab l10n debt

`_commit`'s snackbar strings are hardcoded (`TODO(media): l10n`). The plan
localises them in all locales rather than adding a second hardcoded string.

## Section 5: Schema, sync, error handling, testing

### Schema

`dives.site_suggestion_dismissed_at INTEGER NULL` at the next free ladder
rung, expected v169 (main at v164; 165 to 168 claimed by open PRs as of
2026-08-26). The plan's first step re-runs the open-PR diff scan for
`currentSchemaVersion` before committing to the number. House pattern:
scalar, `migrationVersions` entry, `if (from < N)` guard plus
`reportProgress()` twin, `_assertSiteSuggestionDismissedAtColumn()` backstop
in `beforeOpen`, and `migration_vN_site_suggestion_dismissed_test.dart`.

### Sync

The dives export is table-generic (`sync_data_serializer.dart` exports
`_db.dives` rows via `toJson()`), so the column rides along with no serializer
change; nullable means older peers that omit the key deserialise to null.
`DiveRepository.setSiteSuggestionDismissed(diveId, bool)` writes the column
and `markRecordPending('dives', diveId)` in one transaction, then
`SyncEventBus.notifyLocalChange()`. The dive row carries its own HLC, so this
is not the stranded-child case that bit `dive_safety_findings`. Backups
include the column automatically.

### Error handling

- Readers (EXIF GPS, ISO 6709, GPMF) return null on malformed input and never
  throw out of `extract`; failures log at debug. The GPMF walk stops at the
  30-sample cap or the first out-of-range offset.
- A failed photo-map query degrades to "no photo point" for that batch,
  logged at error; the review still runs for dive-computer points.
- Reverse geocode and elevation are best-effort; a failure leaves fields
  empty and the create or locate completes. Elevation runs after commit.
- `applyConfirmed` / `createAndLink` failures surface through the existing
  `siteMatchReview_applyError` snackbar on the review page; the banner shows
  an error snackbar and stays visible for retry.

### Testing (TDD)

Pure:
- `photo_gps_point_selector_test`: nearest to entry, tie to earlier, empty.
- `local_gps_reader_test`: hemispheres, missing axis, `(0, 0)`, rational
  edge cases, JPEG and synthetic HEIC.
- `iso6709_test`; `gpmf_gps_reader_test` on a hand-built `gpmd` track (GPS5
  with GPSF, GPS9, cold-start walk, cap); the gated real-sample test.

Data:
- `media_repository_test`: `getBestPhotoGpsForDives` (join, `isUtc`,
  per-dive selection).
- `dive_repository_impl_test`: unified eligibility predicate;
  `setSiteSuggestionDismissed` including an export-since-watermark
  regression.
- `site_matching_service_test`: photo fallback, `pointSource`, current-site
  candidate and duplicate-aware rule, `createAndLink`, `sitesLocated`,
  post-commit altitude pass.

Extractor and picker: desktop-path tests in `exif_extractor_test` and the
desktop picker test for stills and video.

Widgets:
- `site_suggestion_banner_test`: all five action cases; dismiss persistence.
- `site_match_review_page_test`: source chip, current-site card, Create site
  here.
- `quick_site_from_gps_dialog_test`: geocode prefill via the fakeable
  `locationServiceProvider`.
- Post-import helper: prompt, no prompt, dismissed excluded.

l10n: every new key in all 11 locales; banner and review page get a
German-locale overflow test at 360 dp.

## Files touched (expected)

New:
- `lib/features/media/domain/services/photo_gps_point_selector.dart`
- `lib/features/media/data/services/isobmff_boxes.dart`
- `lib/features/media/data/services/local_exif_loader.dart`
- `lib/features/media/data/services/local_gps_reader.dart`
- `lib/features/media/data/services/gpmf_gps_reader.dart`
- `lib/features/dive_log/presentation/widgets/site_suggestion_banner.dart`
- `lib/features/dive_log/presentation/helpers/site_suggestion_actions.dart`
- `lib/features/media/presentation/helpers/offer_site_review_after_import.dart`
- migration test for the new column

Modified:
- `capture_time_reader.dart`, `exif_extractor.dart`,
  `photo_picker_service_desktop.dart`
- `media_repository.dart`, `media_providers.dart`
- `site_matching_service.dart` (`_CandidateRef.currentSite`,
  `MatchCandidateView.isCurrentSite`, `MatchProposal.pointSource`,
  `createAndLink`), `site_match_review_page.dart`,
  `site_match_review_notifier.dart`
- `dive_repository.dart`, `dive_repository_impl.dart`
- `database.dart` (column, migration, backstop)
- `dive_edit_page.dart`, `dive_detail_page.dart`
- `quick_site_from_gps_dialog.dart`
- `trip_scan_actions.dart`, `files_tab.dart`, `lightroom_scan_helper.dart`,
  `media_import_view.dart`
- `lib/l10n/arb/*.arb` (11 locales)
- `docs/FEATURE_ROADMAP.md`, `docs/REMAINING_TASKS.md` (tick the item)

Deleted:
- `lib/features/media/presentation/widgets/photo_gps_suggestion_banner.dart`
  (replaced by `site_suggestion_banner.dart`)
