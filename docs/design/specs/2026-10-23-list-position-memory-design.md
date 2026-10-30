# Lists return to the last-opened record

Issue: #3301 (Maintain position in dive list after navigating away and back)

## Why

A diver doing database hygiene hops between areas: they edit a dive, realise
a piece of equipment is missing, go to Equipment to add it, then go back to
Dives. Today every list comes back scrolled to the top, and on a wide window
the details pane comes back empty, so they have to find their place again by
hand. The same happens in every list, not only dives.

The reporter asked for the list to "remember the last dive selected, and
return to that position". The maintainer confirmed that the anchor is the
record the diver last opened, not a pixel offset.

## Goals

When the diver returns to any of the eight record lists, the list shows the
record they last opened:

| List | Section id | Remembered id provider |
| --- | --- | --- |
| Dives | `dives` | `highlightedDiveIdProvider` |
| Sites | `sites` | `highlightedSiteIdProvider` |
| Equipment | `equipment` | `highlightedEquipmentIdProvider` |
| Buddies | `buddies` | `highlightedBuddyIdProvider` |
| Trips | `trips` | `highlightedTripIdProvider` |
| Dive centers | `dive-centers` (table settings key `diveCenters`) | `highlightedDiveCenterIdProvider` |
| Certifications | `certifications` | `highlightedCertificationIdProvider` |
| Courses | `courses` | `highlightedCourseIdProvider` |

"Returns" covers every way the list page is rebuilt from scratch: a tap on
another nav destination and back, the overflow nav sheet, a `go()` to a
child route that rebuilt the list underneath, and a resize or view-mode
switch that remounts the list widget.

### Behaviour, per layout

- **Phone or narrow window (list only):** the list scrolls so the
  last-opened record is in view, and it is highlighted (the highlight already
  shows today; the scroll is new). If the record is in a collapsed group
  (a trip group in Dives, a site group in Sites), the group opens first, as
  `_scrollToSelectedItem` already does for wide windows.
- **Wide window (list and details side by side,
  `ResponsiveBreakpoints.isMasterDetail`):** the same scroll and highlight,
  and the details pane reopens that record in view mode.
- **Table view:** the table scrolls to and highlights that row. With the
  table's details pane showing, the pane reopens that record as in the wide
  window case.

### Rules

1. **What counts as "opened":** whatever already sets the list's
   `highlighted<X>IdProvider`: tapping a row, keyboard navigation in the
   list, previous/next in the details pane, and the post-merge and similar
   flows that set it today. This change adds no new writers of the
   highlight.
2. **Closed pane stays closed.** If the diver emptied the details pane
   before leaving, the pane stays closed when they return. The pane has no
   close button today; what empties it is the scaffold's deselect path
   (`onItemSelected(null)`), reached by tapping empty map in map view and by
   deleting the shown record. The rule is recorded on that path, so it also
   covers any close button added later (decided with the maintainer while
   building). The list still scrolls to and highlights
   the last-opened record. Opening any record in that list clears the
   "closed" state again.
3. **Edit and create come back as view.** Leaving a list while its pane is in
   edit mode (`?mode=edit`) or create mode (`?mode=new`) and returning shows
   the remembered record in view mode, never the form. Navigating away
   already discards an unsaved form today; this change does not try to keep
   one. A record just created and saved counts as opened (the scaffold's
   `_onSaved` selects it).
4. **Missing or hidden record:** if the remembered record was deleted, or the
   active filter, search or type tab hides it, the list starts at the top and
   the pane does not reopen, exactly as today. The memory is not cleared by a
   filter, so relaxing the filter later brings it back
   (`listedHighlightedDiveIdProvider` already behaves this way for dives).
5. **Lifetime:** the memory lasts while the app is running. A relaunch starts
   every list at the top with the pane empty. Nothing is persisted.
6. **Diver switch:** switching the active diver forgets every list's memory
   (a record id from one diver's log is meaningless in another's, and a site
   or trip shared between profiles would otherwise bring the previous
   diver's place back). The highlight providers are not reset on a switch
   elsewhere, so a listener around the app shell resets all eight, and the
   closed-pane memory, when the diver changes. The first diver id loaded at
   startup resets nothing.
7. **An explicit selection wins.** A route that arrives with `?selected=` (a
   deep link, "open in list" from another screen, the map's details tap)
   shows that record, not the remembered one, and becomes the new memory.

## Non-goals

- Restoring the exact pixel offset. The anchor is the record.
- Keeping pages alive across tab switches (the Training host's
  shared-page-key approach). Too broad a change for this issue.
- Persisting the memory across app launches.
- Map views. The map's camera is out of scope; returning to a list whose map
  view was showing behaves as today apart from the pane rule above.
- Menu-style master-detail screens (Settings, Planning, Insights, Transfer,
  Gas calculators, Documents). They are not lists of the diver's records.
- Equipment sets (`equipment_set_list_content.dart`), unless it shares the
  Equipment scaffold's memory for free.
- Keeping an unsaved edit form across navigation.

## Anti-goals

- The pane must never reopen a record the diver closed, or a deleted record
  (a pane showing "not found" is worse than today).
- Returning must not fight the diver: once they scroll or tap, the restore is
  done. No late jump after they have started interacting.
- No visible flash of the top of the list followed by a jump, where it can be
  avoided (a jump within the first frames after load is acceptable).
- No regression to the existing selection behaviour: double-tap to push
  (#2982), prev/next in the pane, the merge and split flows, bulk selection
  clearing the highlight.

## Design decisions already made

- **One record memory, plus a "pane closed" flag.**
  - *Highlight* (existing, per list): the record the diver last opened, by
    any route (wide pane, phone push, the full dive page's previous/next, a
    table-mode map marker). It is the only record memory: it drives the
    scroll, the row highlight, and which record the pane reopens. Closing the
    pane does not clear it (unchanged).
  - *Pane closed* (new, in `MasterDetailScaffold`, keyed by `sectionId`): set
    when the diver closes the pane, cleared when the section's highlight
    next moves to a record (any way of opening one). It only decides whether
    the pane reopens; it never names a record. So the scroll and the pane can
    never point at different records. A record opened only on the phone or
    the full page, then returned to on a wide window, reopens in the pane:
    it is the record last opened.
- **The pane-closed flag lives in the shared scaffold**, in an app-wide
  (non-autoDispose) provider keyed by `sectionId`, so all eight lists and
  `TableModeLayout` (which wraps `MasterDetailScaffold`) get it from one
  place. Each page hands the scaffold its remembered id (the highlight,
  filtered to what the list currently shows). When the scaffold mounts
  without `?selected=`, the flag is clear, and that id is present, it puts
  the id into the address with `goInPlace`, so the URL stays the single
  source of truth for what the pane shows.
- **Pushed lists are not a return.** `openDiveList` and `openTripList` push
  `/dives` or `/trips` with a temporary filter (#2784, #3292). Such a pushed
  list starts as it does today: no restore on mount. What the diver opens in
  it must not leak into the tab's memory, so `DiveListReturn` and
  `TripListReturn` save and put back the section's pane-closed flag along
  with the filter and highlight they already restore. The pushed list is
  recognised the way those classes already are, by its route `extra`.
- **Each list page tells the scaffold whether an id is still listed**, since
  only the page knows its filtered data. Until the list data has loaded,
  the scaffold waits rather than guessing.
- **Scrolling on mount uses each list's existing `_scrollToSelectedItem`**
  with the remembered highlight as a fallback when there is no
  `selectedId` (the phone case). Equipment and Courses have no
  `_scrollToSelectedItem` today and need one modelled on the others.
- **Table view:** `EntityTableView` already scrolls to the highlighted row on
  `didUpdateWidget`; it also does so once after its first load.
- **Dives beyond the loaded pages:** the dive list loads 50 at a time
  (`PaginatedDiveListNotifier`). If the remembered dive is not among the
  loaded rows, the list loads further pages until it is found or the list
  ends, then scrolls. If the list ends without it, rule 4 applies. The other
  lists are not paginated.

## Left to the builder

- Names, file layout, and whether the "scroll to remembered on mount" logic
  is shared in a mixin or helper or kept per list (the eight
  `_scrollToSelectedItem` copies differ in grouping, so a shared helper may
  not fit all of them).
- Exactly how the scaffold sets and clears the pane-closed flag (at the
  close button's call site, or by watching the highlight), as long as rules
  2, 3 and 4 hold.
- The mechanism for "the restore is done once the diver interacts".
- How the dive list pages forward to the remembered dive without blocking the
  UI, and whether a cap on pages is needed.
- Whether delete handlers (for example `_leaveDeletedSite`) should also clear
  the highlight in lists that do not do so today, so a deleted record is not
  scrolled to. Rule 4 must hold either way.

## Testing

Widget tests per layout for at least Dives and one simple list (Sites), and
a lighter check per remaining list:

- phone: open a record, navigate away and back, the record's row is on
  screen;
- wide: the pane reopens the remembered record; with the pane closed first,
  it stays closed while the row is still scrolled to and highlighted;
- edit mode then away and back shows view mode;
- remembered record deleted or filtered out: list at top, pane empty;
- explicit `?selected=` wins over the memory;
- a record opened at phone width, then the window widened and the list
  returned to, reopens in the pane;
- a pushed "dives at this site" list neither restores on mount nor changes
  the Dives tab's memory or pane-closed flag once it is closed;
- table view: highlighted row scrolled into view on mount;
- dives: a remembered dive past the first page is reached.

Tests restore any provider overrides or global state they set (CI bundles
test files in one isolate).
