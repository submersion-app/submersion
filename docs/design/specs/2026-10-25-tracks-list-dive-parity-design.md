# Tracks List: Dive-List Parity

Issues: #3634 (kind-badge/list styling), #3635 (post-import equipment editing)

## Problem

The Tracks list (`TracksListPane`) merges GPS and underwater tracks into one
list, but its rows read inconsistently with the rest of the app:

- The kind indicator (`TrackKindBadge`, "GPS"/"Underwater") is a filled pill
  buried in the subtitle/third line, instead of a compact badge in the title
  row the way `DiveModeBadge` (OC/CCR) sits next to the date in the dive list.
- Distance, max depth and duration are plain text joined with " · ", instead
  of the icon+accent-color stat treatment (`DiveCardStatRow` /
  `CompactDiveListTile`'s stat row) dives use for the same kind of figures.
- A linked underwater track shows its own file/import name as the title and
  a bare `Dive #<n>` chip for the link -- a diver has to open the track to
  learn which dive site it belongs to.
- The dive link itself is an outlined chip, not the filled, theme-token
  label style (`PlannedDiveChip`'s shape) used for comparable markers
  elsewhere in the dive list.
- A track's device/equipment can only be set once, in the import review
  screen (`nav_track_import_review_page.dart`). There is no way to add or
  change it afterwards, unlike a dive's or a dive site's equipment, which
  stays editable at any time.

## Solution

### A. Row styling (#3634)

Apply the dive list's visual language to `GpsTrackListTile` and
`NavTrackListRow`:

1. **Kind badge moves into the title row, styled like `DiveTypeBadge` --
   not `DiveModeBadge`.** The badge text stays the existing *localized* word
   (`tracks_kind_gps` / `tracks_badge_underwater`, e.g. French singular
   "Sous-marine" -- see `track_kind_badge_test.dart`'s existing locale case),
   not an abbreviation: `DiveModeBadge`'s short bare-outline style exists
   specifically for OC/CCR/SCR/GAUGE, fixed-width, unlocalized diving jargon
   (its own doc comment says so), which a translated, variable-length word
   is not. `DiveTypeBadge` is the right model instead: translucent fill,
   `outlineVariant` border, dynamically measured width, no forced uppercase.
   `TrackKindBadge` keeps its current `ValueKey('track-kind-badge-${kind.name}')`
   (asserted by `tracks_page_test.dart`) and keeps the GPS-vs-Underwater
   color distinction, now via `scheme.secondary`/`scheme.tertiary` for both
   border and text (not `onSecondaryContainer`/`onTertiaryContainer`, which
   are only guaranteed contrast against their matching `*Container` fill,
   not this badge's translucent `surface` background -- caught in review).
   It moves into the
   title row, after the title, before the row's own trailing control
   (chevron for the dive list's own tile; here, the delete icon).
2. **Distance / depth / duration become stats.** Both tiles gain a small
   stat row (new shared widget, `TrackStatRow`, modeled on
   `DiveCardStatRow`'s `_buildStat`: icon + bold text in the theme's accent
   color) under the existing detail line. Unlike `DiveCardStatRow`, it does
   **not** need fair-share width measurement: that logic exists only because
   the dive card's stats share one line with the type/mode badges, and here
   the kind badge has already moved to the title row, so stats never compete
   with another variable-width sibling. It still has to tolerate a narrow
   phone width on its own, though (three stats, each with a unit string
   whose length varies by locale/unit system) -- `Wrap`, not a rigid `Row`,
   so a cramped width wraps to a second line instead of overflowing.
   `NavTrackListRow` contributes distance, max depth and duration, each
   omitted when its value is null -- exactly mirroring
   `formatNavTrackDetailLine`'s existing optional-field handling, just
   rendered as stats instead of joined text, since that function joins its
   optional fields with a plain `' · '` and splitting them back out is
   purely mechanical. `GpsTrackListTile` gets **no** stat row: its duration
   is not a separable trailing value the way the underwater row's is -- the
   English ARB string is `"{count, plural, ...}, {duration}"`, a single ICU
   sentence per locale, and other locales are free to place `{duration}`
   anywhere in that sentence (grammar-dependent), so there is no safe,
   locale-independent way to carve it out without touching every ARB file's
   translation. GPS rows keep their existing detail line, duration included,
   unchanged. The existing formatter
   functions (`formatTrackDetailLine`, `formatNavTrackDetailLine`) are left
   **untouched**: `gps_track_info_card.dart` and `nav_track_info_card.dart`
   both call them for their own subtitle, expecting the full joined string
   including distance/depth/duration, and must keep working unchanged. New,
   separate helpers carry the split-out data for the list rows instead (see
   Plan, Task 3/4).
3. **Title row needs its own overflow guard.** Neither tile currently wraps
   its title in `Expanded` + ellipsis (unlike `CompactDiveListTile`, which
   does, because it already shares its line with several siblings). Adding
   the kind badge -- and, for a linked underwater track, promoting the dive
   site's name to the title (point 5 below), which can run considerably
   longer than a filename -- makes that guard mandatory, not optional: title
   wraps in `Expanded(child: Text(..., overflow: TextOverflow.ellipsis,
   maxLines: 1))`, the badge stays a fixed-size sibling next to it.
4. **Linked underwater track: site name as title.** When `route.diveId` is
   set, `NavTrackListRow` already watches `diveProvider(diveId)` for the
   link label; reuse that same `AsyncValue` rather than adding a second
   provider. When it has resolved to a dive whose `site` is non-null, the
   title becomes `dive.site!.name` (confirmed hydrated: `getDiveById` /
   `_mapRowToDive` populates `site` from `siteId`, not just the list query)
   instead of `route.name ?? route.sourceRef ?? route.id`. That former title
   demotes to a plain text line directly under the new title, in the same
   style as the date line, ahead of the existing date/device meta.
   Three states resolve for free from `AsyncValue.value` being nullable, no
   extra branching needed:
   - **Dive still loading:** `.value` is `null` -> falls back to the
     track's own name, same as unlinked. No flash of a blank title.
   - **Dive loaded but has no site:** `dive.site` is `null` -> same
     fallback. This already matches `_linkLabel`'s existing null-safe
     handling for the link text itself.
   - **`diveId` set but the dive no longer exists:** not actually a reachable
     steady state -- `normalizeAfterDiveDeletion` clears `diveId` back to
     `null` via the FK's `SET NULL` as part of deleting a dive (see
     `nav_track_repository.dart:678+`), so this could only be true for a
     brief transient window, which the loading-state fallback already
     covers safely.
   Unlinked rows are unaffected: there is no site to promote, so the title
   stays `name ?? sourceRef ?? id` as today.
5. **Dive link as a label.** Replace the outlined link chip
   (`NavTrackListRow._linkChip`) with `TagChip.unsaved` -- **revised again
   after the first revision**: the user's reference screenshot turned out to
   be a dive's own auto-generated `"{source} Import {date}"` tag, rendered
   through `TagChips`/`TagChip`, the one widget "every tag chip in the app
   renders through... in a dive list row, on a detail card, beside a site
   and beside a piece of equipment" (its own doc comment). `PlannedDiveChip`
   was the wrong model entirely; `TagChip.unsaved` (no backing `Tag` row
   needed) gives the exact look with no new widget. Color: `colorScheme
   .primary` when linked (no tag color to borrow), `colorScheme.outline`
   when not. It keeps its existing tap-to-open-the-dive behavior when
   linked, and incidentally fixes the earlier accessibility gap for free --
   `TagChip` is the already-reviewed, already-shipped interactive pattern
   used everywhere else in the app, not a bespoke one.

No change to `GpsTrackListTile`'s or `NavTrackListRow`'s leading icon
(`Icons.route` vs. shape thumbnail): out of scope, not requested by either
issue.

### B. Post-import equipment editing (#3635)

Add a context-menu entry "Change device" (`navTrack_detail_menuChangeDevice`)
to `NavTrackDetailPage`, between "Rename" and "Unlink"/"Delete", that opens
the same `NavTrackEquipmentPickerSheet` the import review screen already
uses, and persists the result.

`NavTrackRepository` has **no generic `update()`** -- only narrow, named
methods (`rename`, `unlink`, `updateCorrection`, `setPrimary`, ...), each
writing one `NavTracksCompanion`, then calling `_markPending(routeId, now)`
so the change reaches sync. (`nav_track_repository.dart:118/187` is actually
`insertImportedRoute`'s *insert*-time parameter list, not an update path --
initially misread as one.) This needs a **new** method, `setEquipment`,
following `rename`'s exact shape:

```dart
Future<void> setEquipment(
  String routeId, {
  String? equipmentId,
  String? deviceName,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await (_db.update(_db.navTracks)..where((t) => t.id.equals(routeId))).write(
    NavTracksCompanion(
      equipmentId: Value(equipmentId),
      deviceName: Value(deviceName),
      updatedAt: Value(now),
    ),
  );
  await _markPending(routeId, now);
}
```

Omitting `_markPending` would silently leave the change out of sync -- it is
the one part of this that is easy to copy-paste past without noticing.

## Out of scope

- Auto-filling a track's device from its linked dive's own equipment when
  the diver never picked one (a real gap, but a separate product decision --
  not requested here).
- Leading-icon treatment (`Icons.route` vs. real route shape) for anchored
  underwater tracks.
- Any change to the GPS-sweep matching logic.
