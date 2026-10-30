# Tracks List: Dive-List Parity Implementation Plan

**Goal:** Style the Tracks list rows like the dive list (kind badge in the
title row, icon+accent stats for distance/depth/duration, linked dive's site
as title with a filled link label) and let a diver change an underwater
track's device/equipment after it has been saved.

**Spec:** `docs/design/specs/2026-10-25-tracks-list-dive-parity-design.md`

**Issues:** Closes #3634, Closes #3635

> Revised after a cross-examination pass (see spec for the full reasoning):
> the kind badge keeps its localized text (no "UW" abbreviation -- that
> would silently break every non-English locale), `TrackStatRow` uses
> `Wrap` not a rigid `Row`, the existing `formatTrackDetailLine`/
> `formatNavTrackDetailLine` are left untouched because two info-card
> widgets still need their full joined output, and Task 5 adds a genuinely
> new `NavTrackRepository.setEquipment` method -- there is no existing
> `update()` to call.

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `lib/features/tracks/presentation/widgets/track_stat_row.dart` | Icon+accent-color stat row (distance/depth/duration) in a `Wrap`, modeled on `DiveCardStatRow`'s `_buildStat` rendering but without its fair-share width measurement (nothing else shares this row) |
| `test/features/tracks/presentation/widgets/track_stat_row_test.dart` | Widget tests: renders provided stats in order, empty list renders nothing, wraps instead of overflowing at phone width |
| `lib/features/nav_track/presentation/widgets/nav_track_row_stats.dart` | New, narrow helper(s) returning distance/maxDepth/duration as `List<TrackStat>`, separate from `formatNavTrackDetailLine`'s own (unchanged) joined string |
| `lib/features/nav_track/presentation/widgets/nav_track_link_label.dart` | Filled label (shape/tokens from `PlannedDiveChip`) replacing the outlined link chip; same tap-to-open behavior when linked |
| `test/features/nav_track/presentation/widgets/nav_track_link_label_test.dart` | Widget tests: linked vs. unlinked colors/text, tap opens the dive |

### Modified Files

| File | Change |
|------|--------|
| `lib/features/tracks/presentation/widgets/track_kind_badge.dart` | Restyle to `DiveTypeBadge`'s translucent-fill/bordered look; **keep** the existing localized text and `ValueKey`; no new strings |
| `lib/features/gps_log/presentation/widgets/gps_track_list_tile.dart` | Wrap title in `Expanded`+ellipsis; move `kindBadge` into that title row; add a duration `TrackStatRow` under the (still unchanged) detail line |
| `lib/features/nav_track/presentation/widgets/nav_track_list_row.dart` | Wrap title in `Expanded`+ellipsis; move `kindBadge` into the title row; site-name-as-title when the already-watched linked dive has one; `TrackStatRow` for distance/maxDepth/duration; replace `_linkChip` with `NavTrackLinkLabel` |
| `lib/features/nav_track/data/repositories/nav_track_repository.dart` | **Add** `setEquipment(routeId, {equipmentId, deviceName})`, mirroring `rename`'s shape (single `NavTracksCompanion` write + `_markPending`) -- there is no generic `update()` to reuse |
| `lib/features/nav_track/presentation/pages/nav_track_detail_page.dart` | Add "Change device" context-menu entry opening `NavTrackEquipmentPickerSheet`; persist via the new `setEquipment` |
| `lib/l10n/arb/app_en.arb` (+ `app_de.arb` and the other locale files) | One new string: `navTrack_detail_menuChangeDevice`. (No badge-abbreviation strings -- reverted, see above.) |
| `test/features/tracks/presentation/widgets/track_kind_badge_test.dart` | **Existing file** -- update its shape/color assertions for the restyle; its two locale assertions (`'GPS'`, `'Sous-marine'`) and both `ValueKey` checks stay as-is, since the text and keys do not change |
| `test/features/tracks/presentation/pages/tracks_page_test.dart` | No change expected -- it only asserts the two `ValueKey`s exist, which this plan keeps; confirm after Task 1 instead of guessing |
| `test/features/gps_log/gps_track_list_tile_badge_test.dart` | Update expectations for the new title-row badge position (its actual path -- the earlier guessed `presentation/widgets/..._test.dart` path doesn't exist) |
| `test/features/nav_track/presentation/widgets/nav_track_list_row_test.dart` | Update expectations for badge/stat position; add cases for site-as-title (linked+has site, linked+loading, linked+no site, unlinked) and the new link label |
| `test/features/nav_track/data/repositories/nav_track_repository_test.dart` | Add case: `setEquipment` writes both fields and marks the row pending for sync |
| `test/features/nav_track/presentation/pages/nav_track_detail_page_test.dart` | Add case: "Change device" opens the picker and persists the choice through `setEquipment` |

**Explicitly not touched** (confirmed by grep, listed so nothing looks
missed): `lib/features/gps_log/presentation/widgets/gps_track_info_card.dart`,
`lib/features/nav_track/presentation/widgets/nav_track_info_card.dart` (both
keep using the original joined-string formatters as-is), and
`lib/features/nav_track/presentation/widgets/nav_track_section.dart` (its
`_RouteRow` builds its own inline string independently of either formatter
and is a different screen -- the dive detail page's route list -- not the
Tracks list this issue covers).

---

## Task 1: Restyle `TrackKindBadge`

- [ ] Change `TrackKindBadge` to `DiveTypeBadge`'s shape: translucent fill
      (`colorScheme.surface` at low alpha), `outlineVariant`-toned border,
      dynamically sized to its (localized) text -- no fixed `widthOf()`,
      unlike `DiveModeBadge`. Keep the GPS-accent / `onTertiaryContainer`
      color distinction the current pill uses. Keep the existing
      `ValueKey('track-kind-badge-${kind.name}')` and the existing
      `l10n.tracks_kind_gps` / `l10n.tracks_badge_underwater` strings
      unchanged -- do not add an abbreviation.
- [ ] Update `track_kind_badge_test.dart`'s shape/color expectations only;
      its text and `ValueKey` assertions need no change.
- [ ] `dart format . && flutter analyze`.

## Task 2: `TrackStatRow`

- [ ] Create `TrackStatRow` taking `List<TrackStat>` (`icon`, `text`),
      rendered as a `Wrap(spacing: 16, runSpacing: 4)` of icon+bold-text
      pairs in the theme's accent color (14px icon, `bodySmall` bold text).
      `Wrap` rather than `Row`: on a narrow phone width, three localized
      stats (distance/depth/duration, whose formatted length varies by
      locale and unit system) must wrap to a second line instead of
      overflowing, since nothing here does the dive card's fair-share
      shrinking (there is nothing else on this line to shrink against).
- [ ] Widget test: given 1-3 stats, each icon+text pair renders in order;
      an empty list renders `SizedBox.shrink()`; a constrained width that
      cannot fit all stats wraps instead of overflowing (`tester.takeException()`
      stays null).

## Task 3: GPS track row

**No stat row for GPS** -- revised during implementation. GPS duration is
not a separable trailing value: `gpsLogger_trackSubtitle` is one ICU
sentence per locale (`"{count, plural, ...}, {duration}"` in English), and a
translation is free to place `{duration}` anywhere in its own sentence, so
there is no locale-safe way to carve it out of the existing string without
editing every ARB file's translation -- out of scope here. `GpsTrackListTile`
keeps its existing detail line (`formatTrackDetailLine`, unchanged,
duration included) and only gets the title-row/badge change:

- [ ] In `GpsTrackListTile`, wrap the title in
      `Expanded(child: Text(..., overflow: TextOverflow.ellipsis, maxLines: 1))`
      and place `kindBadge` as a fixed-size sibling after it, inside the
      `title:` row (currently a bare `Text`, needs to become a `Row`).
- [ ] Update `gps_track_list_tile_test.dart` for the new title-row structure
      (no stat-row assertions to add here).

## Task 4: Underwater track row

- [ ] In `NavTrackListRow`, reuse the dive the row's `_linkLabel` already
      watches (`route.diveId` through `ref.watch(diveProvider(diveId))`) --
      do not add a second provider for this. When `diveId != null` and the
      resolved dive's `site` is non-null, the title is `dive!.site!.name`;
      in every other case (no `diveId`, dive still loading, dive loaded with
      no site) the title stays `route.name ?? route.sourceRef ?? route.id`
      exactly as today. `getDiveById`/`_mapRowToDive` is confirmed to
      hydrate `site` (not just the bulk list query), so no change needed
      there. A `diveId` that outlives its dive is not a reachable steady
      state (the FK's `SET NULL` clears it on delete via
      `normalizeAfterDiveDeletion`), so no extra handling beyond the
      null-fallback above.
- [ ] When the site-as-title path is taken, render the former title as a
      `Text` in the date line's own style (not the title style), directly
      above the existing date/device meta line.
- [ ] Add a small helper (e.g. `navTrackStats(units, route)` in the new
      `nav_track_row_stats.dart`) returning distance/maxDepth/duration as
      `List<TrackStat>`, each entry present only when its source value is
      non-null. **Do not** modify `formatNavTrackDetailLine` -- it is still
      used verbatim by `nav_track_info_card.dart`.
- [ ] Wrap the title the same way as Task 3 and move `kindBadge` into that
      row; add the new `TrackStatRow` under the (unchanged) detail line.
- [ ] Replace the `_linkChip` call with `NavTrackLinkLabel` (new file):
      filled `Container`, `secondaryContainer`/`onSecondaryContainer` when
      `route.diveId != null`, a neutral surface tone otherwise; same
      tap-to-open behavior (push `/dives/$diveId`) only when linked.
- [ ] Update `nav_track_list_row_test.dart`: existing cases for the new
      badge/stat positions, plus new cases for (a) linked + dive has a site
      -> title is the site, former title demoted, (b) linked + dive still
      loading -> title is still the track's own name, (c) linked + dive has
      no site -> same fallback, (d) unlinked -> unaffected.

## Task 5: Equipment editing after import (#3635)

- [ ] Add `setEquipment` to `NavTrackRepository`, mirroring `rename`
      exactly (single `(_db.update(_db.navTracks)..where(...)).write(...)`
      with `NavTracksCompanion(equipmentId: Value(...), deviceName:
      Value(...), updatedAt: Value(now))`, then `await _markPending(routeId,
      now)` -- easy to forget, and sync silently misses the change without
      it).
- [ ] Add `navTrack_detail_menuChangeDevice` to `app_en.arb`/`app_de.arb`
      (other locales can lag; English/German are this repo's maintained
      pair per existing PRs).
- [ ] In `NavTrackDetailPage`, add a `'changeDevice'` entry to the
      `PopupMenuButton` between `'rename'` and `'unlink'`/`'delete'`.
- [ ] Handler opens `NavTrackEquipmentPickerSheet` (same call shape as
      `nav_track_import_review_page.dart`'s `_pickEquipment`) and, on a
      result, calls `ref.read(navTrackRepositoryProvider).setEquipment(
      route.id, equipmentId: item?.id, deviceName: item?.name)` -- `null`
      clears both, matching the import screen's "no equipment chosen" path.
- [ ] `nav_track_repository_test.dart`: `setEquipment` writes both fields
      and marks the row pending.
- [ ] `nav_track_detail_page_test.dart`: opening the sheet and choosing an
      item calls `setEquipment` with the chosen id/name; choosing "no
      equipment" calls it with both `null`.

## Task 6: Verification

- [ ] `dart format .`
- [ ] `flutter analyze`
- [ ] `/code-review` on the full diff before pushing.
- [ ] Grep for any other reference to `_linkChip` or the old filled-pill
      look to confirm nothing was missed (none expected per the File
      Structure section above, but confirm rather than assume).

## Addendum: changes made during the user's own review

Found while the user tested the Hot Build, fixed in the same branch since
they touch files this plan already modifies:

- **Dive link label restyled again**, to `TagChip.unsaved` -- see the
  revised spec section 5. `PlannedDiveChip` (the first revision) was also
  wrong; the user's reference turned out to be a dive's own auto-generated
  import tag.
- **"Change device" moved from the overflow menu to its own row**
  (`_EquipmentCard`, mirroring `_SiteCard` exactly), per explicit feedback:
  "ich bleibe hier beim Tauchplatz... ich möchte auch so ein Feld haben".
  The popup menu entry is gone; `_StatsCard`'s inline equipment/device line
  moved into this new row too, so equipment has exactly one display place
  the way site already does.
- **Speed stats fixed to m/s.** `_StatsCard` was feeding max/avg speed
  through `UnitFormatter.formatSpeed`, which is wind-speed formatting
  (km/h or knots, driven by the diver's weather-unit setting) -- a
  mismatched reuse that made a DPV's speed read in the wrong unit entirely
  for the diving context. New `formatMetersPerSecond` in
  `nav_track_row_stats.dart` formats directly in m/s, the diving/DPV
  convention, independent of the diver's wind-speed preference.
- **Battery start reading fixed.** `_StatsCard` read
  `route.points.first.batteryVolts` unfiltered; confirmed against a real
  Seacraft ENC log (018.DAT.csv, user-provided) that a fresh recording's
  very first sample can read an implausible 0.00V before the sensor
  settles (row 1: `BattV=0`; row 2, one second later: the real `3.9`). New
  `_firstBattery`/`_lastBattery` skip exact-zero samples from both ends.

## Open design decisions (flag for review, do not block on)

- Exact wording for `navTrack_detail_menuChangeDevice` (`"Change device"`
  draft) vs. "Change equipment", to match `navTrack_detail_equipment`'s
  existing terminology.
- Whether `TrackStatRow`'s icons should reuse `Icons.straighten`/
  `Icons.arrow_downward`/`Icons.schedule` or dedicated custom icons; the
  dive list's own stat icons are plain Material icons, so this plan
  defaults to the same family for visual consistency.
