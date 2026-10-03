# Tracks: one navigation entry for GPS and underwater tracks

Date: 2026-10-02
Status: approved
Supersedes: #2398 (Underwater Routes under Settings > Manage)
Resolves: #2397 (remove the Underwater Routes quick action; done first by #2804)
Tracking issue: #2833

## Problem

Submersion records two kinds of "where I went" data:

- **GPS tracks** (`lib/features/gps_log/`, table `gps_tracks`): surface
  lat/lon fixes recorded on the phone or imported from GPX, KML, CSV or FIT.
  Reached from a top-level nav destination, `gps-log` at `/gps-log`.
- **Underwater routes** (`lib/features/nav_track/`, table `nav_tracks`):
  dead-reckoned paths from navigation consoles such as the Seacraft ENC,
  optionally anchored to a GPS fix. Reached only from a home-page quick
  action (`/nav-routes`) or a dive's "Underwater Route" section.

Underwater routes have no real home, and the two features present one
concept to the diver (the path they took on a dive) as two unrelated
areas with different vocabulary.

## Goals

1. **Findability.** Underwater tracks get a first-class home without adding
   a nav slot.
2. **One mental model.** Both kinds live in one list and one map, under one
   name, with one vocabulary.
3. **Tidier navigation.** The nav keeps its current destination count; the
   home quick actions lose an entry.

## Non-goals

- No schema, sync or repository changes. `gps_tracks` and `nav_tracks` stay
  separate tables with separate entities.
- No renaming of Dart identifiers (`NavTrack`, `nav_track/`, providers).
  The vocabulary change is user-facing strings only.
- No change to the detail, alignment, 3D or import review pages beyond their
  paths and wording.
- No handling of the underwater sweep's `needsChoice` result on the landing
  page; it keeps today's behaviour (resolved from the track's detail page).

## Decisions

| Topic | Decision |
| --- | --- |
| Name | Nav entry "Tracks"; kinds "GPS" and "Underwater" |
| Landing | One merged list and one overview map, with a kind filter |
| Import | One Import action, auto-detecting ENC CSV vs every other format |
| Recording | Record card stays at the top of the list on record-capable devices, under every filter |
| URLs | Everything under `/tracks`; old paths redirect |
| Shared tools | Date filter and summary strip cover both kinds; Match is the GPS sweep (underwater tracks are only suggested since #2819) |
| Vocabulary | User-facing "route" becomes "underwater track" everywhere, all locales |
| Quick actions | Underwater Routes action removed; GPS action keeps its label, opens `/tracks` |
| Architecture | New `lib/features/tracks/` composes the two features (approach A) |
| Delivery | Two stacked PRs (see "Delivery") |

## Architecture

A new feature module, `lib/features/tracks/`, owns the landing page and the
providers that combine both kinds. `gps_log` and `nav_track` keep their data
layers, detail pages, polyline layers, thumbnails and import review pages.
`tracks` depends on both; neither depends on `tracks` or on each other's
presentation layer.

Rejected alternatives:

- **Grow `GpsLoggerPage` into the hub.** Couples `gps_log` to `nav_track`
  presentation and grows a page that is already 499 lines.
- **Domain-level `Track` interface with a unified repository.** The two
  models differ in kind (absolute fixes vs reckoned points with an optional
  anchor and non-destructive corrections); a shared interface would be a
  lowest common denominator and would touch sync for no user-visible gain.

### Module layout

```text
lib/features/tracks/
  domain/track_list_item.dart            # sealed TrackListItem: GpsTrackItem | UnderwaterTrackItem
  domain/track_kind.dart                 # enum TrackKind { gps, underwater }, TrackKindFilter { all, gps, underwater }
  domain/tracks_query.dart               # pure: merge, date bound, combined overview cap
  domain/tracks_summary.dart             # pure: counts, recorded time, dives covered (deduplicated)
  application/tracks_match_controller.dart   # the GPS sweep; underwater tracks are only ever suggested
  presentation/providers/tracks_providers.dart
  presentation/tracks_import.dart            # one Import action: detect ENC, route to the right review page
  presentation/track_item_location.dart      # detail path for a TrackListItem
  presentation/pages/tracks_page.dart        # landing: MapListScaffold (wide) / column (narrow)
  presentation/pages/tracks_map_page.dart    # phone full-screen map (was GpsTrackMapPage)
  presentation/widgets/track_kind_badge.dart
  presentation/widgets/track_kind_filter_control.dart
  presentation/widgets/tracks_list_header.dart
  presentation/widgets/tracks_list_pane.dart
  presentation/widgets/tracks_map_pane.dart
  presentation/widgets/tracks_match_snackbar.dart
  presentation/widgets/tracks_pending_choice_banner.dart
  presentation/widgets/tracks_overview_map.dart
  presentation/widgets/tracks_summary_strip.dart
  presentation/widgets/tracks_empty_state.dart

lib/core/router/track_locations.dart     # every Tracks path, shared by the router and all callers

test/features/tracks/...                 # mirrors lib
```

`GpsLoggerPage` (`gps_log/presentation/pages/gps_logger_page.dart`) and
`NavTrackListPage` (`nav_track/presentation/pages/nav_track_list_page.dart`)
are deleted. Pieces still needed are extracted, not duplicated:

- `_RecordCard` becomes a public `GpsRecordCard` widget in `gps_log`.
- `NavTrackListRow` stays in `nav_track` (moved to its own widget file).
- `GpsTrackListTile`, `GpsTrackInfoCard`, `GpsTrackPolylineLayer`,
  `NavTrackPolylineLayer` and `NavTrackShapeThumbnail` are reused unchanged.
- `GpsTrackMapPage` is replaced by `TracksMapPage`, which draws the same
  overview set as the landing page's map pane.

## Navigation and routing

### Nav destination

The `gps-log` destination in `kNavDestinations` becomes:

- id `tracks`, route `/tracks`
- icon `Icons.route_outlined`, selected icon `Icons.route`
- label `nav_tracks` ("Tracks")
- subtitle `nav_tracksSubtitle` ("GPS and underwater tracks")

It keeps GPS Log's position in the canonical order, so the destination count
stays 17 and no default slot moves.

`kRenamedNavIds` gains `'gps-log': 'tracks'`. `normalizeNavOrder` then reads
a stored or synced `gps-log` as `tracks`, keeping a customised slot, and
`withLegacyNavIds` writes `gps-log` right after `tracks` so a device on an
older build keeps the slot too. This is the mechanism the Statistics to
Insights rename used.

The `gps-log` key in `feature_accent_colors.dart` becomes `tracks`, same
colour. `FeatureAppBarTitle(featureId: ...)` call sites follow.

### Routes

All are top-level siblings. Detail pages must not be children of `/tracks`:
go_router builds one page per matched segment, so nesting would stack the
landing page under a detail pushed from dive detail and need two Back
presses (the reason `/gps-log/:id` and `/nav-routes/:id` are siblings today).

| Path | Name | Page |
| --- | --- | --- |
| `/tracks` | `tracks` | `TracksPage` (`NoTransitionPage`) |
| `/tracks/map` | `tracksMap` | `TracksMapPage` |
| `/tracks/gps/:id` | `gpsTrackDetail` | `GpsTrackDetailPage` |
| `/tracks/underwater/:id` | `underwaterTrackDetail` | `NavTrackDetailPage` |
| `/tracks/underwater/:id/align` | `underwaterTrackAlign` | `NavTrackAlignPage` |
| `/tracks/underwater/:id/3d` | `underwaterTrackSeascape` | `NavTrackSeascapePage` |

`/tracks/map` is declared before the parameterised routes.

`/tracks` reads `?kind=gps|underwater` once to seed the kind filter. Changing
the filter on the page updates the provider only; the URL is not rewritten.

### Redirects

| Old | New |
| --- | --- |
| `/gps-log` | `/tracks` |
| `/gps-log/map` | `/tracks/map` |
| `/gps-log/:id` | `/tracks/gps/:id` |
| `/nav-routes` | `/tracks?kind=underwater` |
| `/nav-routes/:id` | `/tracks/underwater/:id` |
| `/nav-routes/:id/align` | `/tracks/underwater/:id/align` |
| `/nav-routes/:id/3d` | `/tracks/underwater/:id/3d` |
| `/planning/gps-logger` | `/tracks` |

`/gps-log/map` is declared before `/gps-log/:id` so `map` is not read as an
id. Redirects exist for stale links only; every internal `push`/`go` call
site moves to the new paths.

### Nav highlight

`MainScaffold._calculateSelectedIndex` matches by
`location.startsWith(destination.route)`. Because every page in the area
lives under `/tracks`, the Tracks destination stays highlighted on detail,
alignment, 3D and map pages without changes to that function.

### Other entry points

- `GpsRecordingStrip` taps go to `/tracks`.
- Home Quick Actions: the GPS action keeps its label and opens `/tracks`; the
  Underwater Routes action, its button and `dashboard_quickActions_navRoutes`
  are removed (resolves #2397).
- Dive detail: `SurfaceGpsSection` pushes `/tracks/gps/:id`; `NavTrackSection`
  pushes `/tracks/underwater/:id` and `/tracks/underwater/:id/3d`.
- `NavTrackImportReviewPage` (after commit), `NavTrackDetailPage` and
  `NavTrackAlignPage` push the new underwater paths.

## The Tracks landing page

### Data

```dart
sealed class TrackListItem {
  String get id;
  TrackKind get kind;
  int get startTime;        // wall-clock-as-UTC epoch ms; GPS uses effectiveStartTime (trim-aware)
  int? get endTime;         // GPS: effectiveEndTime (null while recording)
  bool get isMappable;
  Duration? get recordedTime; // what the summary counts
  String get selectionKey;  // '${kind.name}:$id'
}

final class GpsTrackItem extends TrackListItem { final GpsTrack track; ... }
final class UnderwaterTrackItem extends TrackListItem { final NavTrack track; ... }
```

- `isMappable` is always true for GPS; for underwater it is
  `track.anchor != null`.
- `selectionKey` prefixes the kind so `mapListSelectionProvider` can never
  resolve a restored selection against the wrong table.

Providers (`tracks_providers.dart`):

- `trackKindFilterProvider`: `TrackKindFilter`, default `all`, seeded from
  `?kind=`.
- `tracksListProvider`: merges `gpsTracksProvider` and
  `allNavTracksProvider` (which stays point-free, so list rows never decode
  blobs), applies the existing `trackDateFilterProvider` to both kinds (its
  range is read as calendar days: the picker returns local midnights while
  track times are wall-clock-as-UTC, so each bound is rebuilt with
  `DateTime.utc(y, m, d)`) and
  the kind filter, sorts by `startTime` descending, breaking ties by
  `selectionKey` (`List.sort` is not stable).
- `tracksOverviewProvider`: the newest `kTracksOverviewLimit` (40, in
  `tracks_query.dart`, replacing the GPS-only `kOverviewTrackLimit`) mappable
  items. The cap is now combined across kinds, so the map never hydrates
  more than 40 point blobs whatever the mix.
- `tracksOverviewTruncatedProvider`: true when mappable items exceed the cap;
  drives the existing "showing the newest 40" notice.
- `tracksSummaryProvider`: replaces `gpsLogSummaryProvider` on this page.
  Figures follow the active filters:
  - tracks: item count
  - recorded time: GPS `effectiveEndTime - effectiveStartTime` (trim-aware,
    skipping a track still recording, as `gpsLogSummaryProvider` does today)
    plus underwater `durationSeconds`, falling back to
    `endTime - startTime` when it is null
  - dives covered: the size of the union of two dive-id sets. GPS coverage
    is by time window, as today: a dive whose `effectiveEntryTime` falls
    inside a filtered GPS track (`GpsTrackMatcher.trackCovering`).
    Underwater coverage is by link: the `diveId` of each filtered
    underwater track. A dive in both sets counts once.

`trackDateFilterProvider` stays where it is in `gps_log` for PR 1 (it is
read by GPS detail code); moving it is not required.

### Layout

Wide screens (`ResponsiveBreakpoints.isMasterDetail`): `MapListScaffold`
with `sectionKey: kTracksSectionKey`.

- **App bar:** title "Tracks" (`FeatureAppBarTitle(featureId: 'tracks')`)
  and Import.
- **List pane,** top to bottom, the same header on both widths:
  `GpsRecordCard` (record-capable devices only, every filter),
  `TracksSummaryStrip`, the kind filter (segmented All / GPS / Underwater),
  the date filter, the "Match dives to GPS logs" button (where GPS Log had
  its match button), then rows. The list is never capped, so it carries no
  cap notice.
- **Rows:** a `switch` over `TrackListItem` renders `GpsTrackListTile` or
  `NavTrackListRow`, each with a `TrackKindBadge` ("GPS" / "Underwater") on
  the subtitle line, below the status text, so the title keeps the full row
  width (the #2692 hazard). Rows are keyed by `selectionKey`.
- **Map pane:** one `FlutterMap` drawing GPS polylines and anchored
  underwater polylines with their existing layers and distinct styling.
  Camera framing uses the union of both sets, with the framing-signature
  latch both pages use today. The map draws the capped overview plus the
  selected track when the cap left it out (one extra blob at most), so a
  row picked further down the list is still drawn and framed. When the cap
  drops tracks, the "showing the newest 40" notice sits over the map, the
  only surface it limits, on desktop and on the phone map page alike. Loading, error and empty keep the three-way
  split from `GpsLoggerPage`.
- **Info card:** `GpsTrackInfoCard` for GPS, a `NavTrackInfoCard` (new, same
  shape: name and the row's detail line, Details, Close) for
  underwater.
- Unanchored underwater tracks appear only in the list, with their shape
  thumbnail as today.

Narrow screens: `Scaffold` whose body is the same list pane, a builder list
(rows carry live map thumbnails, so it must be lazily built).

- **App bar:** title, map button to `/tracks/map`, Import.
- **Body:** the header above, then rows; tapping a row pushes its detail
  path.

### Empty states

- No tracks of either kind: one message covering both kinds, pointing to
  Record (when available) and Import.
- Tracks exist but filters hide all of them: "No tracks match these
  filters", with a clear-filters action.

## Import

`importTrackFile` (`tracks_import.dart`) takes over `GpsLoggerPage._importTrack` unchanged
in behaviour:

1. Pick a file, `allowedExtensions: ['gpx', 'kml', 'csv', 'fit']`, read
   bytes through the handle (file_picker 12, Android SAF).
2. For `.csv`, read headers; if `looksLikeSeacraftEnc(headers)`, call
   `navigateToNavTrackReview`.
3. Otherwise `trackImportServiceProvider.prepare(...)` and push
   `TrackImportReviewPage`.
4. Parse errors: localized snackbar (`trackParseErrorText` /
   `navTrackParseErrorText`), English detail to the log only. Other errors:
   logged with stack trace, generic localized snackbar.

The underwater-only `csv` picker from `NavTrackListPage` is removed.
Drag-and-drop and share-sheet handling (`handleIncomingFile`) are unchanged.

## Match

Since #2819 an underwater sweep never links anything: it only suggests a
dive, and linking always goes through the diver's choice on the track's
detail page (#2394). So the Tracks page's Match action is the GPS sweep
alone, exactly the GPS log's old action: `TracksMatchController.matchAll()`
runs `GpsTrackMatchService.sweep()` and returns
`TracksMatchOutcome(positionedDiveIds, failed)`.

Snackbar, with the GPS log's own strings ("Match dives to GPS logs"):

- dives positioned: "{count} dives positioned", with the "Review site
  matches" action that hands their ids to the site review
- nothing positioned: "No dives matched a recorded track"
- the sweep failed: the generic "try again" message (failure logged)

Underwater tracks waiting for that choice are counted by
`navTrackPendingChoiceCountProvider` and shown as a "N underwater tracks
need your choice" hint under the summary strip (PR 1 shipped it as "N routes
need your choice"; PR 2 rewords it).

The list also takes #2819's first-load states: a spinner while the first
load runs and a "try again" message if it fails, both only before any data
has arrived, since the list re-enters loading on every track change.

#2819's card redesign of the underwater rows is not carried over: in the
merged list the two kinds keep one row style, and a follow-up issue gives
both kinds the dive list's card design together.

## Vocabulary (PR 2)

User-facing "route" becomes "track": the full "underwater track" wherever a
string can be seen outside an underwater-only screen, plain "track" inside
one. Every key whose value changes is renamed, and the old key is deleted
from all 11 locales. Out of scope: the dive planner's route, a trip's voyage
route, the emergency card and the startup recovery text, which use "route" in
another sense.

Each locale uses one word for a track, the same word its Tracks destination
uses, for GPS and underwater tracks alike. Hungarian says "nyomvonal" (the
nav label reads "Nyomvonalak"), chosen on 2026-10-03 over the "útvonal" the
PR 2 plan's table lists; "útvonal" stays where it means a route or a path.
Arabic and Hebrew use one word for route and track, so only their key names
change. `test/l10n/underwater_track_vocabulary_test.dart` enforces the rule.

The strings it covers, in every locale:

- dive detail section heading and actions (`NavTrackSection`)
- detail, alignment and 3D page titles and dialogs
- import review page and `NavTrackHandoffCard`
- dive-choice and equipment picker sheets
- match, empty and error strings

Rules:

- A key whose meaning changes gets a new name; the old key is deleted, not
  reworded, so no stale translation keeps the old wording.
- All 11 locales get translations in the same PR; none fall back to English.
- Dart identifiers and storage are untouched.
- l10n keys used only by the deleted pages are removed in PR 1. No
  automated check finds unused keys, so each removed key is first grepped
  for live users.

## Testing

TDD: tests are written before the code they cover.

Unit:

- `TrackListItem` getters, including `isMappable` for anchored and
  unanchored underwater tracks and `selectionKey`.
- `tracksListProvider`: merge, sort by `startTime` descending, kind filter,
  date filter applied to both kinds.
- `tracksOverviewProvider`: the combined cap of 40 over a mixed set;
  unanchored items excluded; truncation flag.
- `tracksSummary`: a dive covered by a GPS track's window and linked to an
  underwater track counts once; trim-aware GPS duration; a recording GPS
  track contributes no time; underwater falls back to `endTime - startTime`
  when `durationSeconds` is null.
- `TracksMatchController`: reports the dives the GPS sweep positioned; a
  throwing sweep is reported as failed, not thrown.
- `importTrackFile`: ENC CSV routes to underwater review; GPX and a
  non-ENC CSV route to GPS review; parse error shows the localized message.

Nav:

- `gps-log` alias in `normalizeNavOrder` and `withLegacyNavIds`.
- Destination count stays 17; `tracks` occupies GPS Log's canonical position.
- Accent colour resolves for `tracks`.

Router (`test/core/router/app_router_test.dart`):

- Every redirect in the table above, with ids preserved.
- `/tracks/map` is not matched as an id; `/gps-log/map` is not matched as an
  id.
- Pushing `/tracks/gps/:id` from a dive detail page leaves the dive detail
  directly underneath (one Back press).
- Tracks destination is selected on `/tracks/underwater/:id/3d`.

Widget:

- `TracksPage` at phone width and at master-detail width.
- Record card shown only when recording is possible, under every filter.
- Kind badges; filtered-empty vs truly empty states.
- Quick Actions card has no underwater action; the GPS action opens
  `/tracks`.

Existing tests referencing old ids or paths (about 19 files across nav,
main scaffold, settings nav customisation, dashboard, dive sections and the
nav_track pages) are updated, not deleted. Behaviour covered by the deleted
pages' tests (`gps_logger_page_test.dart` and the list page coverage) moves
into `tracks` tests.

Run `test/architecture/` after adding `lib/features/tracks/`.

## Screenshots

Required (touches `presentation/` and `lib/shared/widgets/`):

- nav rail and bottom bar, before and after
- Tracks landing page, phone and desktop, light and dark
- Quick Actions card, before and after
- PR 2: dive detail underwater section and underwater detail page, before
  and after

## Delivery

Two stacked PRs, each with its own worktree and green checks:

**PR 1: Tracks nav entry and merged landing page.** Nav destination and
alias, accent key, `/tracks` routes and redirects, `lib/features/tracks/`,
combined import, match and summary, deletion of `GpsLoggerPage` and
`NavTrackListPage`, Quick Actions change, new `tracks_*` and `nav_tracks*`
strings in all locales, test updates.
Body: `Closes #2833, closes #2397`.

**PR 2: Underwater track vocabulary.** The "route" to "underwater track"
string pass across all locales, stacked on PR 1.
Body: `Refs #2833`.

After PR 1 merges, #2398 is closed as superseded with a comment pointing to
#2833.

While PR 1 was in progress, main merged #2804, which removed the Underwater
Routes quick action (resolving #2397 first) and added a Settings > Manage >
Underwater Routes tile (the #2398 entry point). PR 1 removes that tile and
its string: Tracks in the nav is the one way in, and a guard test keeps the
tile from coming back. #2804's other entry points (linking and importing a
route from dive edit) stay as they are: the sheet opens the import review
page and takes its result back, with no route path involved, and a review
saved from anywhere else still lands on the new underwater track path.

## Risks

- **Synced nav order across mixed builds.** Covered by the alias plus
  legacy write; tested in `nav_id_alias_test.dart`.
- **Map cost with a large library.** The combined 40-item cap bounds blob
  hydration; unchanged from today's GPS-only bound.
- **Stale external links** (notes, desktop bookmarks, an older build's
  deep link). Covered by the redirects, which are cheap and kept
  indefinitely, like the existing `/planning/gps-logger` redirect.
