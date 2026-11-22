# Unified editing: the media library

Issue: #4527 (the whole pattern). This note covers the part of the media
library that [the unified editing pattern](2026-11-14-unified-editing-pattern-design.md)
left for a later phase ("The photo viewer": "The rest of the media library is
not part of phase 1"). It does not repeat the pattern: the rule, the bar,
saving, cancelling, leaving and History apply as written there. It builds on
[phase 3](2026-11-18-unified-editing-phase-3-records-design.md) and
[phase 4](2026-11-22-unified-editing-phase-4-design.md), and on the choices
made for the photo viewer's lock in phase 1 (plan 10).

## Why

The rule is **nothing recorded changes without unlocking**. Every record page
and editor now follows it, and a photo opens locked in the viewer wherever it
is opened from. What is left is the Media screen itself: the Library tab, the
Gear tab, imports, sources and the media store pages. Unlike every page the
program has covered so far, the Library is not a page about one record. It is
a grid of many photos with a multi-select bar.

A survey of that screen found that per-photo edits already go through the
viewer's lock, and that what remains is a handful of bulk actions, three places
where a lock that has shipped can still be bypassed, a History label that
reads as the diver's when it was not, and a few one-tap writes with no
confirmation.

## Goals

- Every bulk write from the Library's and the Gear tab's selection bars is
  deliberate: it asks first, naming what it changes, and it is one labelled
  History entry. (The store actions on the info sheet stay one tap, as plan 10
  decided; see "Design: actions left as they are".)
- No path writes past a lock that has shipped: a locked site page shows no
  control that writes, and a picker opened from any sitting (dive, site, gear
  or species) holds everything it adds and offers nothing that cannot be
  held.
- History never files a background job as the diver's change.
- The few one-tap destructive writes on the Media screen and its settings ask
  first (decisions 3 and 4).

## Non-goals

- A lock, an Unlock or a sitting for the Library or the Gear tab (decision 1).
- Changing what the photo viewer locks. Its store actions (Re-upload, Back up,
  Retry upload, Check now) stay outside the rule, as plan 10 decided; only
  Re-upload gains a confirmation, for one case (decision 4).
- Imports, the repair wizard, Poll now and the verification sweeps. They are
  deliberate modes with their own commit, or derived data (pattern, "Outside
  the rule").
- The media store pages beyond the two confirmations below: their writes are
  transport and settings, never a diver's record.
- The Documents tab. Its list writes nothing; the document page is under the
  lock since phase 3.
- Caption, favourite and rating editing. No screen edits any of them today
  (media has no rating field at all), and adding one is not part of this
  program.
- The Lightroom suggestions row on a dive page. It is behind
  `lightroomUiEnabled`, which is off; see "Left for later".

## Anti-goals

Those of the pattern, plus:

- A bulk action that changes a dive's photos without saying which dive.
- A lock that guards nothing, or a lock with no Save (the reason decision 1
  rejected a library lock).
- A History entry labelled as the diver's for a change no one confirmed.

## Current state (for orientation)

The full inventory, with every handler's file and line, was gathered in four
local working notes outside the repository (`media-scope-inv-1` to `-4` in the
program's session notes folder). They are not needed to plan from: the tables
here carry every file and line a plan touches. This is the inventory's
shape. Paths are under `lib/features/media/presentation/` unless given in
full.

| Surface | Files | Writes today | Asks first | Under a lock |
| --- | --- | --- | --- | --- |
| Library selection bar | `widgets/media_selection_bar.dart` | Move to dive (`:102-110`), Edit tags (`:149-168`), Unlink (`:58-100`) | Edit tags and Unlink, not Move | No |
| Info sheet from the Library (right-click Info, a status badge) | `widgets/media_library_grid.dart:91-96`, `widgets/media_status_badge.dart:64-69`, `:173-178`, all `readOnly: true` | Check now (`widgets/media_info_panel.dart:514-568`), Back up and Retry upload (`:600-648`) | No | Outside the rule (plan 10); Edit tags, Set time and Locate are hidden |
| Smart albums | `widgets/media_library_active_filter_chips.dart:36-46`, `widgets/media_library_filter_sheet.dart:284-290`, `:320-329` | Save (name dialog), Delete | Save only | No |
| Gear tab | `pages/gear_gallery_view.dart:93-117`, `:176-183` | Remove (unlinks from gear, or deletes; clears covers) | Yes | No |
| Missing-files banner, repair wizard | `widgets/media_missing_banner.dart`, `pages/media_repair_wizard_page.dart` | Re-link N files | The review step | A deliberate mode; one `media_repair` History entry |
| Media screen opening | `pages/media_section_page.dart:98-101` | Once a day, with watched folders, relinks missing rows when auto-apply is on (default on, `providers/media_watcher_providers.dart:47-50`) | No | Files one History entry labelled as the diver's (`ChangeLogScope.bulk`, `data/services/repair/media_repair_service.dart:215-224`) |
| Media screen, Sources | `pages/media_sources_section_view.dart` | Add folder, Scan now, Remove folder (`:179-184`, one tap), auto-apply switch | No | Settings |
| Import (picker, review pages) | `pages/media_import_view.dart`, `widgets/files_tab.dart`, `widgets/url_tab.dart`, `widgets/manifest_mode_panel.dart` | Creates media rows on each tab's commit | The commit or review step | Deliberate mode; Files and URL tabs hold inside a sitting (`MediaHoldScope`), **Manifest mode does not** |
| Site page attachments | `widgets/site_media_section.dart` | Bulk Set category (`:170-206`, `:351-356`) | The category picker only | **Writes on a locked site page**; Unlink beside it is hidden (`:341`) |
| Photo viewer | `pages/media_viewer_page.dart` and parts | Re-upload (`features/media_store/presentation/widgets/media_reupload_menu.dart:50-63`); Analyse or Analyse again (`features/species_id/presentation/widgets/labels_menu.dart:176-216`) | No | Outside the rule (plan 10; identification results are derived) |
| Media store pages | `features/media_store/presentation/` | Transport and settings (uploads, Verify copies, Stop keeping copies, queue rows) | Stop keeping copies in Advanced (`photos_advanced_section.dart:260-279`), **not in the reconnect sheet** (`media_store_reconnect_sheet.dart:269-276`, `:340-358`) | Settings and transport |
| Documents tab | `features/documents/presentation/pages/documents_page.dart` | Nothing but Add (create) and Export | n/a | The document page is locked (phase 3) |

Facts that shaped the design:

- **The viewer is the same everywhere.** `MediaViewerPage` has no library,
  origin or read-only flag. Opened from the Library grid, the map, the Gear
  tab, a dive, a site, a trip or a species, it opens locked and offers the
  same actions; only `showGoToDive` and `captionFor` differ by caller.
- **Move to dive is unscoped.** `MediaRepository.reassignMediaToDive`
  (`features/media/data/repositories/media_repository.dart:2581-2601`) runs
  in a transaction but in no `ChangeLogScope`, so History gets
  trigger-logged rows with no operation label. It does not consult
  `openDiveSittingProvider`, unlike the window drop path
  (`helpers/media_drop_import.dart:65-75`).
- **Unlink never deletes a source file.** `MediaDeletionCoordinator`
  deletes the media rows (with their tag, people and identification rows),
  queues the cloud copy's delete for when no row still uses its hash, and
  clears this device's caches (`features/media_store/data/media_cache_purge.dart:13`).
  It is unscoped in History too.
- **Edit tags is already the model.** Its sheet confirms every change
  (`features/tags/presentation/widgets/bulk_tag_sheet.dart:254-286`), runs in
  one `ChangeLogScope.bulk` labelled `bulk_edit`, and offers Undo.
- **`ChangeLogScope.automatic` exists** for background jobs
  (`lib/core/services/change_log/change_log_scope.dart:131`); the
  watcher does not use it.
- **Two immediate paths are unreached today.** The PDF viewer's unlocked
  Edit details path (`pages/document_viewer_page.dart:146-160`) and the
  species tag picker without `chooseOnly`
  (`pages/species_tag_picker_page.dart:193-200`) write at once, but no
  current caller reaches them: the site callers take the PDF viewer's held
  path, its dive and gear callers its read-only path, and the species page
  passes `chooseOnly`.
- **The species page's picker has no hold scope.** Add photos on an unlocked
  species (`helpers/species_photo_import_helper.dart:137`) opens
  `showPhotoPicker` with no `onHold` and no target, so its Files, URL and
  Manifest tabs write their rows (linked to dives, not to the species) at
  once, and Cancel on the species leaves them. Only its Gallery tab hands its
  choice back to the sitting.

## Approaches

The question was how a page with no single record fits a rule written for
record pages.

1. **The library's Select is a deliberate bulk mode.** The pattern already
   puts bulk edit outside the rule because it is deliberate and has its own
   confirm. Select is entered on purpose, and two of its three writes already
   ask first. Move to dive gains a confirmation, and every bulk write becomes
   one labelled History entry. Smallest; reuses the Edit tags model.
2. **A library lock with no Save.** Select still works for Share; Move, Edit
   tags and Unlink appear only after an Unlock, and each still acts at once.
   A lock with no sitting is a new idea the rest of the program does not
   have, and it guards actions that already ask.
3. **A library sitting.** Unlock, Cancel and Save over the whole library;
   moves, tags and unlinks held until Save. The largest by far, and Cancel
   would have to undo moves across many dives and sites, for an action used
   occasionally (after an import lands photos on the wrong dive, or to tag a
   batch).

**Picked: 1**, by Eric (decision 1).

## Decisions

Made by Eric, in the order they were made:

1. The library's multi-select is a deliberate bulk mode with confirmations:
   Move to dive gains a confirmation naming the count and the dive, and every
   bulk write is one labelled History entry. Over a library lock with no Save,
   and over a library sitting with Cancel and Save.
2. In a picker opened from a sitting (a dive, site or gear item being
   edited), Manifest mode is hidden, with a one-line hint pointing to Media,
   Import. Over holding the manifest's subscription and rows until the
   sitting's Save.
3. Three one-tap writes gain a confirmation: deleting a smart album, "Stop
   keeping copies" in the reconnect sheet (matching the Advanced section's),
   and removing a watched folder. Over leaving them for a follow-up issue.
4. Re-upload asks first when it would switch an uploaded original to a
   compressed level, which drops the full-quality cloud copy. Other
   re-uploads stay one tap, and Re-upload stays outside the photo lock. Over
   leaving it as is.
5. The species page's Add photos picker, which carries no hold scope, shows
   its Gallery tab only, with the same hint as decision 2. Made after review
   found that its Files, URL and Manifest tabs write past the species'
   sitting.

## Design: the library's bulk mode

Select stays as it is: entered from the toolbar's Select button, ended by the
close button, Escape or a change of section. Share is unchanged. Everything
else in the selection bar, and the Gear tab's Remove, follows these rules:

- **It asks first, naming what changes.** Edit tags and Unlink already do.
- **It is one History entry.** The whole action runs in one
  `ChangeLogScope.bulk` operation with a label that names it, so it reads and
  reverts as one entry, as Edit tags does today.
- **It works whether or not any record is unlocked elsewhere,** with one
  exception: Move to dive refuses a dive held in an open sitting (below).

### Actions

| Action | Today | Media library phase |
| --- | --- | --- |
| Share | No record write | Unchanged |
| Move to dive | Picking the dive commits; no confirmation; unscoped | Picking the dive opens a confirmation naming the number of photos and the dive; Move writes in one labelled bulk operation |
| Edit tags | Confirms every change, one `bulk_edit` operation, Undo | Unchanged |
| Edit tags: a tag created or widened from inside the sheet | Written at once, survives Cancel | Unchanged: tags are a settings list (pattern, "Outside the rule"), and a tag created from a picker survives Cancel (pattern, "Not held") |
| Unlink | Confirms (with the caption and favourite warning); unscoped | Unchanged confirmation; the deletes run in one labelled bulk operation |
| Gear tab: Remove | Confirms; unscoped | Unchanged confirmation; one labelled bulk operation |
| Tile tap | Opens the viewer, locked | Unchanged |

- **Move to dive and an open sitting.** If the chosen dive, or the dive a
  selected photo is on now, is open for editing (`openDiveSittingProvider`
  names it), Move is refused with a one-line hint that the dive is open for
  editing and must be saved, cancelled or locked first, and nothing is
  written. The sitting may have no changes yet, so the hint does not speak
  of changes. This rarely comes up, since leaving a dive page with unsaved
  changes asks first. Move reads the same provider as the window drop path
  but answers the other way: `diveDropAnswer` (`features/dive_log/presentation/providers/open_dive_sitting_provider.dart:38-46`)
  holds a drop in an open sitting and refuses a locked dive, while Move,
  which belongs to no sitting, refuses an open dive and writes to a locked
  one. Do not reuse `diveDropAnswer`; the hint is a string of its own.
- **History placement.** Media is logged as a child of its dive. The builder
  confirms where a move's entry appears (the old dive, the new dive or both)
  and raises it if it appears under neither.

### The info sheet from the Library

Unchanged. It already opens with `readOnly: true`, which hides Edit tags, Set
time and Locate. Check now, Back up and Retry upload stay available, as in a
locked viewer (plan 10: store actions are outside the rule).

### Smart albums

Saved filters are configuration, like saved queries (phase 4, non-goals).
Save keeps its name dialog. Delete asks first (decision 3); the
confirmation names the album.

## Design: the leaks in shipped locks

These follow from rules already decided; nothing here is a new choice.

### Site page: bulk Set category

`site_media_section.dart` offers Set category whenever Select is offered,
gated only by the device's ability to attach media (`:384-399`), and writes
at once through `setSiteCategory`. Unlink beside it is hidden while the page
is read-only (`:341`).

- On a locked site page, Set category is not offered, like Unlink.
- In the open attachments card of an unlocked site page, Set category is held
  in the site's sitting and written with its Save, like the card's Unlink
  (`:129-133`) and the viewer's Edit details. Cancel discards it.

### Picker opened from a sitting: what it cannot hold

`url_tab.dart` shows the Link and Manifest switch in every picker
(`:164-173`), and `manifest_mode_panel.dart` never reads `MediaHoldScope`, so
Import then Confirm writes a subscription and its rows at once, including
rows matched to other dives, and Cancel on the sitting leaves them.

The rule is keyed on where the picker is opened from, not on whether it
carries a hold scope: a picker opened from a sitting offers only what that
sitting can hold.

- **Dive, site and gear sittings** (the picker carries `MediaHoldScope`): the
  URL tab shows single links only (held, as today) and a one-line hint that
  a feed of photos is imported from Media, Import (decision 2). The Files and
  Gallery tabs already hold.
- **A species sitting** (Add photos, no hold scope): the picker shows the
  Gallery tab only, with the same hint (decision 5). Files and URL rows would
  land on dives, not on the species, and only the Gallery choice is handed
  back to the sitting today, so nothing the species page can use is lost.
- Outside a sitting (Media, Import), every tab and Manifest mode are
  unchanged.

### Immediate paths no caller reaches

The PDF viewer's unlocked Edit details path and the species tag picker's
immediate `tagPhotos` path are removed, so no future caller can write past a
lock through them. Every caller today takes the held path or, for the PDF
viewer opened from a dive or gear item, the read-only one.

## Design: History for the folder watcher

The once-a-day watcher pass that runs when the Media screen opens relinks
missing photos through `MediaRepairService.apply` with
`source: RepairLogSource.watcher`, but `apply` always opens
`ChangeLogScope.bulk`, whose source is `manual`. Such a pass reads in History
as a repair the diver confirmed.

- `apply` opens `ChangeLogScope.automatic` when the source is the watcher,
  and `ChangeLogScope.bulk` otherwise. The label stays `media_repair`.
- Media, Sources, Scan now runs the same scanner with the same watcher
  source (`pages/media_sources_section_view.dart:66-71`), so its relinks file
  as automatic too. That is intended: the diver asked for a scan, but the
  relinks it applies are matched and written without review, like the daily
  pass. Only the repair wizard's Re-link, which the diver reviews, stays
  manual.
- The pass itself is unchanged: it runs on opening the screen, once a day,
  when there are watched folders, and it relinks only when auto-apply is on.
  A relink changes where a file is found, not a value the diver recorded
  (pattern, "Derived data that refreshes on viewing").

## Design: confirmations on storage and settings

| Action | Today | Media library phase |
| --- | --- | --- |
| Smart album: Delete | One tap, no Undo | Asks first (decision 3) |
| Reconnect sheet: Stop keeping copies here | The tile's text only | Asks first, with the same confirmation as Photos and videos, Advanced (decision 3) |
| Media, Sources: remove a watched folder | One tap | Asks first (decision 3); removing drops only that folder's index rows, which the confirmation says |
| Viewer: Re-upload at a compressed level, for a photo whose original is uploaded | The popup choice is the only step | Asks first, saying the full-quality cloud copy will be replaced and the photo on the device is kept (decision 4) |
| Viewer: any other Re-upload | One tap | Unchanged |

None of these is a record, so none gains a lock: each stays available while
everything is locked, as plan 10 decided for the store actions.

## Design: actions left as they are

Each is outside the rule for the reason given, and keeps its current
behaviour.

| Action | Where | Why it stays |
| --- | --- | --- |
| Check now, Back up, Retry upload | Info sheet (viewer and Library) | Store actions, outside the rule (plan 10); Check now writes availability facts, not a recorded value |
| Re-upload (other than a downgrade) | Viewer | Store action (plan 10) |
| Analyse, Analyse again | Viewer, marine life labels menu | Machine identification results, like analysis on opening a photo; confirming one into a species tag is held, as phase 1 built |
| Dive computer overlay and labels mode | Viewer | Display settings |
| Imports (Gallery, Files, URL, Manifest from Media, Import) | Picker and review pages | Deliberate mode with its own commit; creates records only |
| The Files tab's bookmark for a picked file | Files tab, also before a sitting's Save | An access grant on the device, not a record; Undo and Cancel leave it, harmless |
| Repair wizard: Re-link N files | Missing-files banner | Deliberate mode; one `media_repair` History entry |
| Scan now, add folder, auto-apply switch | Media, Sources | Settings and a deliberate scan |
| Re-verify local files, Check all media, Scan all network media | Settings, Media sources | Availability facts on existing rows, not recorded values |
| Poll now, subscription switch, edit, delete (confirmed) | Settings, Network sources | Deliberate sync-like mode and configuration. A poll overwrites a photo's caption with the feed's; no screen edits a caption, so the feed is its only writer |
| Credentials: test, edit, delete (confirmed) | Network sources | Account settings |
| Upload all, Verify copies, quality, upload switches, badge switches, cache | Photos and videos | Transport and settings; Verify deletes only cloud copies no row uses, under the orphan policy, never an original |
| Opening Uploads starts the queue; Clear completed; Retry; delete queue rows (confirmed) | Uploads | Transport bookkeeping |
| View mode, sort, thumbnail size, filters | Library toolbar | Display settings |
| Documents: Add, Export | Documents tab | Creates a record, or writes a file out |

## Left for later

- **Lightroom suggestions on a dive page.** Accept and Dismiss
  (`widgets/lightroom_suggestions_row.dart:20-39`) write at once and ignore
  the dive's sitting. They are behind `lightroomUiEnabled` (off). Before that
  flag is turned on, they must be held in the dive's Media card and hidden
  while the dive is locked. A one-line note on the flag says so.
- **A subscription's rows after it is deleted** keep a subscription id that
  no longer exists (`media.subscription_id` has no foreign key) and are never
  polled again. Deleting already says the rows are kept. Not an editing
  question; a separate issue if it matters.
- **Captions, favourites and ratings.** If one becomes editable, it is a
  held field in the photo's sitting, and Poll now must stop overwriting a
  caption the diver set.

## Calls made in this note

Eric has not explicitly confirmed these. Correct any of them:

- The Gear tab's Remove follows decision 1 like the Library's bulk actions
  (confirmation already there; one labelled History entry).
- Move to dive refuses a dive that is open for editing, with a hint of its
  own, reading the same provider as the window drop path.
- Unlink and the Gear tab's Remove become one labelled History entry each;
  today their deletes are unscoped.
- The info sheet opened from the Library stays as it is (read only, with
  Check now, Back up and Retry upload available).
- Smart albums are configuration, like saved queries; only Delete changes.
- The leaks (site Set category, Manifest in a sitting's picker, the species
  picker's Files and URL tabs) are fixed in this phase, as breaches of rules
  already decided.
- Scan now's auto-applied relinks file as automatic, like the daily pass.
- The two unreached immediate paths are removed rather than left for a
  future caller to find.
- The folder watcher's pass files under `ChangeLogScope.automatic`.
- Analyse and Analyse again stay outside the photo lock as derived data.
- Poll now keeps overwriting captions while no screen edits one.
- The Lightroom suggestions row is left until its flag is turned on, with a
  note on the flag.
- Each plan goes live as it merges, with no build switch, as in phase 4.

## Left to the builder

- The wording of every new confirmation and hint, and the History labels for
  Move, Unlink and Remove. Every new string goes into all locales.
- Whether Move to dive also offers Undo, as Edit tags does. The confirmation
  is required; Undo is optional.
- Where a move's History entry is filed (see "History placement"); raise it
  if the change log cannot show it under either dive.
- If a bulk write cannot run inside one `ChangeLogScope.bulk` operation (a
  repository that opens work it cannot nest), stop and raise it. Do not split
  the entry silently.

## Testing

- Move to dive: picking a dive asks, naming the count and the dive; Cancel
  writes nothing; Move writes one labelled change log operation; a dive held
  in an open sitting is refused with nothing written.
- Unlink and Gear tab Remove: one labelled operation each; source files are
  untouched (as today's coordinator tests pin).
- Site page: a locked page offers no Set category; in the open attachments
  card, Set category is held, written by Save, discarded by Cancel.
- Picker from a dive, site or gear sitting: no Manifest switch, the hint
  shows. Picker from a species sitting: Gallery tab only, the hint shows.
  From Media, Import, every tab and Manifest mode are unchanged.
- The daily watcher pass and Scan now file their relinks under the automatic
  source; the wizard's Re-link stays manual.
- Move to dive is refused for a dive open for editing with no changes, and
  allowed for a locked dive.
- Smart album delete, reconnect sheet Stop keeping copies, watched folder
  removal and Re-upload downgrade each ask, and Cancel writes nothing; a
  re-upload that is not a downgrade does not ask.
- The removed immediate paths: the PDF viewer and the species tag picker make
  no write except through their held paths.
- Each changed file's existing tests keep their cases.

## Design: the plans

Two plans in `docs/design/plans/`, each smaller than a phase 4 plan, each a
pull request that goes live as it merges:

1. **The library's bulk mode.** Move to dive's confirmation, its sitting
   check and its labelled operation; Unlink's and the Gear tab's labelled
   operations; the smart album delete confirmation. Files:
   `media_selection_bar.dart`, `gear_gallery_view.dart`,
   `media_library_filter_sheet.dart`, the media repository and unlink
   service where the scope is opened.
2. **Leaks, History and storage confirmations.** Site page Set category;
   Manifest hidden in a sitting's picker; the species picker reduced to its
   Gallery tab; the two unreached immediate paths
   removed; the watcher's automatic scope; the reconnect sheet, watched
   folder and Re-upload downgrade confirmations; the note on the Lightroom
   flag.

The two touch different source files and can be built in either order.
Both add strings to every locale file under `lib/l10n/arb/` (and its
generated output), so the second to merge takes main's locale files and adds
its own strings again. With both,
the media library follows the pattern, and nothing named by the pattern's
"The photo viewer" section is left open.

## Delivery

Two pull requests, each referring to #4527, each live as it merges. No table
or column is added and the change log policy does not change. Both change
what a diver sees (new confirmations, a hidden control, a hint), so each
carries before and after screenshots of the changed dialogs and controls,
light and dark, as the contributing guide requires.
