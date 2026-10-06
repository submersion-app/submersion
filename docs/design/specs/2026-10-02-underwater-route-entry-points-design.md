# Underwater Route entry points: design

Date: 2026-10-02
Builds on: `2026-09-10-underwater-nav-track-design.md`

## Goal

Move route linking and importing out of the dive detail page and the
dashboard, into the places a diver edits and manages data:

1. The dive detail "Underwater Route" card shows only when the dive has at
   least one linked route.
2. Linking an existing route, or importing a route file, for a dive happens on
   the Dive Edit page.
3. The dashboard's "Underwater Routes" quick action is removed.
4. The routes area (`NavTrackListPage`, `/nav-routes`) is reached from
   Settings > Manage, where its existing import action lives.

The name "Underwater Route(s)" is kept everywhere. It distinguishes these
measured routes from the GPS logger's surface tracks.

## Non-goals

- No change to the routes area page itself (map, list, import, Match now).
- No change to the route detail, align or 3D pages.
- No route linking in bulk edit.
- No schema, sync or repository API changes. Internal identifiers
  (`navTrack`, `/nav-routes`, `NavTrack*` classes) stay as they are.

## 1. Dive Edit: the Underwater Route row

### Placement and display

`TheDiveSection` gains an optional `routeRow` slot (the same mechanism as
`surfaceIntervalRow` and `siteExtras`), rendered directly under the Site row.
The row is labelled "Underwater Route" and its value reads:

- "None" when the draft holds no route;
- the route's display name (name, else source ref, else id, as the detail
  card does) when it holds one;
- "{first name} +N" when it holds several.

The row is hidden for planned dives (a planned dive has no recording) and is
absent from bulk edit.

### The route sheet

Tapping the row opens a bottom sheet titled "Underwater Route" containing:

- One line per route in the draft: display name, distance in the diver's
  units, a "primary" tag when the route is the dive's primary route, and a
  remove button. Removing changes the draft only.
- "Link existing route", shown when at least one candidate exists. It opens a
  picker of candidates: every unlinked route, plus routes this draft removed
  (still linked in the database until Save), minus routes already in the
  draft. Candidates are sorted by how close their recording start is to the
  form's current entry time.
- "Import file": the existing CSV file picker and parse-error snackbars, then
  the import review page in return mode (see section 2). The returned route id
  joins the draft.

"Make primary", "Open route" and "Open 3D seascape" stay on the dive detail
card only. When links are applied on Save, the repository's `link()` already
decides the primary route.

### The draft

A new pure-Dart value class, `DiveRouteLinkDraft`, in
`lib/features/nav_track/domain/`:

- built from the dive's currently linked route ids (empty for a new dive);
- `add(id)`, `remove(id)` return new instances (immutable);
- exposes the current linked ids, plus `toLink` (ids added and not originally
  linked) and `toUnlink` (ids originally linked and now removed);
- re-adding a removed id, or removing a just-added id, yields no net change.

The edit page holds the draft in its state. It is seeded once from
`navTracksForDiveProvider(diveId)` when editing an existing dive. Any draft
change marks the form dirty, so the existing unsaved-changes guard covers it.

### Save

In `_saveDive`, after the dive row is written and `savedDiveId` is known
(following the pattern used for buddies, sightings and course):

1. `unlink(id)` for each id in `toUnlink`;
2. `link(id, savedDiveId, linkMode: NavTrackLinkMode.manual)` for each id in
   `toLink`;
3. invalidate `navTracksForDiveProvider(savedDiveId)`.

A link or unlink failure is logged and reported in a snackbar. It does not
roll back the dive save, matching the other child writes.

Cancel writes nothing to links. A route imported during the edit session has
already been saved (unlinked) by the review page, and stays in the routes area
as an unlinked route.

### Code organisation

`dive_edit_page.dart` is far past the file-size limit, so new UI lives in its
own files: the row and sheet in
`lib/features/dive_log/presentation/widgets/edit_sections/route_row.dart`
(split further if it passes ~300 lines). The page only adds the draft field,
seeding, the dirty hook and the save step.

The time-proximity sort currently private to `NavTrackSection._linkRoute`
moves to a shared helper in `lib/features/nav_track/domain/` and is used by
the sheet.

## 2. Import review page: return mode

Today the review page, after saving, pops itself, pops the root navigator to
its first route and pushes `/nav-routes/<id>`. Launched from the edit page
that would discard the diver's unsaved form.

`navigateToNavTrackReview` and `NavTrackImportReviewPage` gain a return mode
(for example `returnRouteId: true`, returning `Future<String?>`):

- the "Link to dive" picker is hidden;
- the route is committed with `dive: null` and no site of its own unless the
  diver picks one, so when it is linked on Save it takes the dive's final
  site (the form's site can still change before Save);
- a ticked "replace duplicate" is not applied at import: the page returns
  the duplicate's id, and the Dive Edit page replaces it on Save after
  linking the new route, so the new route inherits the primary role and a
  cancelled edit keeps the original;
- on success the page pops with the new route id (and the replaced id, if
  any) and performs no other navigation.

All existing callers keep today's behaviour. The doc comment listing entry
points is updated (the dive detail section is no longer one; the dive edit
page is).

## 3. Dive Details card

- The `DiveDetailSectionId.navTrack` builder in `dive_detail_page.dart`
  returns `[]` when `navTracksForDiveProvider(dive.id)` has no routes, and
  also while it is loading or errored, so the card never flashes an empty
  state. The comment explaining why the section always rendered is replaced.
- `NavTrackSection` loses its empty state, `_linkRoute`, `_importFile` and its
  watch of `unlinkedNavTracksProvider`. It keeps the collapsible card, the
  route rows and their menu (Open, 3D, Unlink, Make primary). Unlinking the
  last route hides the card.
- The strings used only by the removed empty state
  (`navTrack_section_noRouteLinked`, `navTrack_section_linkButton`,
  `navTrack_section_importButton`) are reused by the edit sheet where they fit,
  and deleted otherwise.

## 4. Settings > Manage and the dashboard

- Settings > Manage gets an "Underwater Routes" tile (icon `Icons.route`, a
  short subtitle such as "Import, align and link recorded routes"), placed
  directly after Incidents, pushing `/nav-routes`.
- `/nav-routes` switches from `NoTransitionPage` to a normal page transition,
  so it slides in like the other Manage pages.
- The "Underwater Routes" button is removed from `quick_actions_card.dart`,
  and `dashboard_quickActions_navRoutes` is deleted from all locales.

## 5. Localisation

All 11 locales. Existing "Underwater Route(s)" strings are unchanged. New keys
cover the edit row label and its value formats ("None", "{name} +{count}"),
the sheet title and actions, and the Manage tile title and subtitle. One key
is deleted (`dashboard_quickActions_navRoutes`), plus any empty-state key not
reused.

## 6. Testing

Tests are written first.

Unit:

- `DiveRouteLinkDraft`: add, remove, re-add a removed id, remove a just-added
  id, `toLink` and `toUnlink`, and inputs never mutated.
- The shared time-proximity sort: ordering, an empty list, ties.

Widget:

- Dive detail: no card with zero routes or while loading; card shown with one
  route; unlinking the last route hides it; no Link or Import buttons exist.
- Dive edit: row value for none, one and several routes; hidden for planned
  dives and absent in bulk edit; a sheet change marks the form dirty; Save
  calls `unlink` and `link` with the saved dive id, including a new dive whose
  id exists only after insert; Cancel writes nothing.
- Review page, return mode: dive picker hidden, commit with `dive: null`, pops
  with the id, no push to `/nav-routes/<id>`; default mode unchanged.
- Settings > Manage: tile present and navigates to `/nav-routes`.
- Dashboard: the quick action is gone.

Checks: `test/architecture/` (new `lib/` files, the ListTile trailing guard),
`flutter analyze`, the l10n staleness check, `dart format .`.

## 7. Pull request

A UI change: before and after screenshots of the dive detail page without a
route, the edit row and its sheet, the Manage tile, and the dashboard, at phone
and desktop widths. The description links the tracking issue.
