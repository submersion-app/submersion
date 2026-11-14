# Unified editing pattern: unlock to edit, in place

Issue: #4527 tracks the whole pattern. Phase 1 also resolves #1906 (edit from
each panel of dive details) and #1570 (Notes easier to reach, edit order
matching the reading order), and depends on #4477 (restoring a whole dive from
History fails).

Mockup of the chosen look:
[assets/2026-11-14-unified-editing-pattern-mockup.html](assets/2026-11-14-unified-editing-pattern-mockup.html).

## Why

The dive log should feel like an archive: something that is not easily
changed. But when a diver is browsing old dives and remembers something, adding
a note or fixing a detail should be quick. Edits should never happen casually
or by accident, and a deliberate edit should never be frustrating.

Today there is no single rule:

- Most dive fields sit behind the Edit button, on a separate page whose six
  fixed groups do not match the dive page's own sections or their order.
- The dive page itself writes in many places without that page: attaching
  photos and documents, adding, moving and removing profile annotations,
  splitting data sources, favourite, set primary source, re-parse, resync,
  dismissing safety findings, mark logged, and more. Several are one tap with
  no confirmation and no undo.
- Notes, the most personal field, is in the sixth group of the edit page,
  closed by default: two taps and a scroll after tapping Edit.
- Other record types each do it their own way. Only dive and site edit use the
  shared form parts. About eleven edit pages have no unsaved-changes check, and
  five keep a private copy of one.

## The rule

**Nothing recorded changes without unlocking.**

- A **record** is anything the diver logs or keeps: a dive, a site, a trip, a
  piece of equipment, a buddy, a dive center, a certification, a course, a
  document, a track.
- A record's page opens **locked**. A locked page shows no control that writes.
- **Unlock**, in the top bar, starts a **sitting**. During a sitting any card
  can be edited where it sits.
- **Save** writes the whole sitting as one History entry and locks the record.
  **Cancel** discards the whole sitting and locks it. Leaving the page during a
  sitting with unsaved changes asks first.
- The lock is never stored and cannot be switched off. Every visit starts
  locked.

A change means any change: a field, a photo attached, an annotation, a tag, a
favourite, a checklist tick, a service logged against a piece of gear.

Outside the rule:

- **Derived data that refreshes on viewing** (tide record refresh, media detail
  backfill, the first safety review). These are not values the diver recorded.
- **Display settings** (section order, hidden sections, folded sections).
- **Creating a new record.** A new record opens already unlocked.
- **Modes that are already deliberate and have their own Save or confirm**:
  bulk edit, the table editor, import, download, sync, merge.
- **Settings lists** edited through small dialogs (dive types, tags, site
  types, dive roles, service kinds, equipment locations, certification
  agencies). They are configuration, not records.

## Goals

- One rule, stated in one sentence, that holds on every record page.
- No accidental change: a locked page cannot be changed by any tap.
- A quick deliberate edit is short. A note on an old dive is: unlock, tap the
  Notes card, type, Save.
- One set of cards per record type serves reading, editing and creating, so
  their order and grouping can never drift apart.
- The lock, top bar, strip, card states and leave check are shared pieces that
  any record type can adopt.
- A sitting is one History entry that reads and reverts as a unit.

## Non-goals

- Marks on the page showing that a value was changed by hand. History is the
  record of changes (see "History"). Per-field provenance stored with the
  record and synced is a possible later project.
- Protecting hand-edited values from re-parse and resync. Both overwrite a
  fixed list of dive columns without checking for hand edits
  (`reparse_service.dart`). This design puts them behind the unlock and a
  confirmation; the rest is a follow-up issue.
- Changing what bulk edit or the table editor do.
- Changing the settings lists.
- A starter set that learns which cards a diver fills in.
- Changing how a dive is written to the database.
- Redesigning the read layout of any detail page.

## Anti-goals

- A control that writes, visible on a locked page.
- The page jumping when it is unlocked, so the diver loses their place.
- Two ways to edit the same record (an old edit page surviving beside the new
  one in a release).
- A record left unlocked by mistake.
- A field that can no longer be reached because its card is empty or hidden.
- A Cancel that leaves something changed.
- A partial save, where some cards are written and others are not.
- Saving each field as the diver leaves it.

## Current state (for orientation)

- **Dive edit page.** `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
  is 6,989 lines with three part files: one `Form`, 26 text controllers, 143
  `setState` calls. It also serves create, bulk edit (`_buildBulkScaffold`) and
  the embedded master-detail pane. Its sections are `FormSection` wrappers in
  `widgets/edit_sections/`. A closed section does not build its fields, so Save
  forces every section open before validating (:6413-6438).
- **Saving.** `_saveDive` (:6392) builds one whole `Dive` and calls
  `paginatedDiveListProvider.notifier.updateDive` or `addDive`. `updateDive`
  writes every column it knows unconditionally, with no merge against the
  stored row, so a field the form does not carry is reset (issue #1392);
  `dive_edit_save_field_census_test.dart` guards that. Sightings, buddies,
  weather and tides are written after the dive.
- **Dive page.** `dive_detail_page.dart` plus `dive_detail_page_actions.dart`.
  A fixed header block, then `DiveDetailSectionList`
  (`widgets/dive_detail/dive_detail_section_list.dart`), which builds one
  widget per `DiveDetailSectionId` (`lib/core/constants/dive_detail_sections.dart`).
  The diver can reorder and hide sections (`settings.diveDetailSections`).
  A section returns nothing when it has no data (tanks, equipment, tags, custom
  fields, altitude and others), so the page leaves it out.
- **Wide screens.** `lib/shared/widgets/master_detail/master_detail_scaffold.dart`
  drives the pane from the URL: `?selected=id` reads, `&mode=edit` edits,
  `?mode=new` creates, at 1100 px and wider. Selecting another list row while
  a form is open does not check for unsaved changes.
- **Shared form parts.** `lib/shared/widgets/forms/`: `EditFormScaffold`
  (Save in the bar, leave check), `FormSection`, `FormRow`, `FormOverline`,
  `showDiscardDialog`, and about fifteen more. Used by dive and site edit only.
- **History.** The change log (issue #3922) records every field change with old
  value, new value, time and a source label, grouped into operations
  (`lib/core/database/tables/change_log_tables.dart`,
  `lib/core/services/change_log/change_log_scope.dart`). It is per device,
  never synced, and kept 12 months by default. A dive's menu has a History item
  and one field can be reverted from it.

## Approaches

Three ways to build it were considered.

1. **One working copy per record, with a small editor per card.** On unlock
   the page takes a working copy of the record. Each card's editor reads and
   writes that copy. Save hands the copy to the existing writer. The edit page
   is taken apart card by card and deleted. The lock, top bar, strip and card
   states are shared pieces. Cost: the largest refactor, and the edit page's
   tests move to card-level tests.
2. **Lift the edit page's state as it is and mount its sections inside the
   cards.** Fastest to a working unlocked dive. Cost: one very large state
   object stays, the six form groups do not line up with the cards, and no
   other record type can reuse any of it.
3. **Self-contained card editors and a list of pending changes, with no
   central copy.** Cards are fully independent. Cost: a dive's fields depend on
   each other across cards, and the writer expects one whole dive, so saving
   would have to be rewritten as partial writes.

Dropped earlier: swapping the existing form in on unlock (the "open fields"
look below, which was turned down), and saving field by field.

**Picked: 1**, by Eric. It is the only one where the shared pieces are real,
which the rollout to other record types needs, and it keeps the writer's
whole-record contract, so the riskiest code changes least.

## Design: the pattern

Everything in this section applies to every record type. The dive specifics
follow in the next section.

### States and the top bar

```
Locked:    <  Dive 214          [favourite, shown only] [history] [lock] [menu]
Unlocked:  Cancel      Editing dive 214          [menu]  Save
```

- **Locked.** The page as it reads today, minus every control that writes. The
  lock button unlocks. Favourite is shown as a state, not a button.
- **Unlocked, no changes.** The bar is tinted with the accent colour. Save is
  disabled. Cancel locks at once.
- **Unlocked, with changes.** Save is enabled. Cancel asks to discard
  (`showDiscardDialog`), then locks.
- **Saving.** Save shows progress; the page does not accept input.

### Cards when unlocked

Unlocking does not move or resize anything on the page.

- A card the diver can change gains a pencil in its header. This includes the
  header block.
- A card whose content is calculated from other data fades back and shows the
  word "Calculated" in its header. It has no pencil. It keeps showing the
  stored values until the sitting is saved.
- The pencil opens that card's editor in place. The card gets an accent
  outline and a "Done" action in its header. Its fields appear, including
  fields that have no value yet (shown with a dashed outline and an "Add"
  placeholder).
- Where a page has a layout in which a header row already folds and unfolds
  its section (the dive page's `DiveDetailLayout.list`), the header row keeps
  doing that and only the pencil opens the editor. Opening the editor of a
  folded section unfolds it for the sitting; that unfold is not saved as a
  display setting. In every other layout the whole header row acts as the
  pencil.
- "Done" collapses the card back to its read layout, now showing the working
  copy's values. Any number of cards may be open at once.
- A card with unsaved changes carries a dot beside its title, open or closed.
- Reading interactions inside a card body (scrubbing the chart, opening a
  photo, following a link to a site) keep working while unlocked.

### The Add strip

A locked page leaves out cards that have nothing to show, and the diver can
hide cards. The old edit pages showed every field regardless, so an unlocked
page needs a way to reach those cards.

- A strip of chips is pinned under the top bar while unlocked, one chip per
  card that is absent because it is empty or hidden by the diver. Hidden cards
  have a dashed chip. Chips follow the diver's section order.
- Tapping a chip adds the card at its place in the section order, already
  open, and scrolls to it. The chip leaves the strip.
- If the card is closed with nothing entered, it returns to the strip.
- A hidden card that is edited this way is saved like any other, then is
  hidden again once the record locks. The diver's display settings are not
  touched.
- Calculated cards that are absent for lack of data are not in the strip.
- The strip is not shown when there is nothing to add.

### Saving, cancelling, leaving

- **Save** validates the whole working copy, not only the open cards. If a
  card fails, the first failing card opens, scrolls into view and shows its
  error, and nothing is written.
- A successful Save writes everything in one change log operation with the
  source "manual" and a label naming the changed cards (for example "Edited:
  Notes, Details"), then locks the page.
- **Save is all or nothing.** The sitting's database writes run inside one
  database transaction. If any of them fails, all are rolled back, the page
  stays unlocked with the working copy and the changed dots intact, and the
  error is shown. A file copied for the sitting (an attached document) is
  copied before the transaction and removed again if it fails.
- Steps that need the network (the weather fetch for a new dive, the tide
  record) run after the transaction. They are best effort, as today, and are
  not part of the sitting's History entry.
- **A value the diver did not change is never written back over a newer
  stored value.** The stored record can change during a sitting (a sync
  arriving, a download, a refresh triggered by viewing). Cards the diver has
  not touched keep following the stored record. At Save, only what changed
  during the sitting is applied, on top of the record as it is stored at that
  moment: field by field for single values, and collection by collection for
  lists such as tanks or sightings. If the same value changed in both places,
  the diver's value wins.
- **Cancel** discards the working copy. No change to this record made during
  the sitting survives it. Other records created along the way from a picker
  (a new site, a new buddy) remain, as they do today.
- **Leaving** means the page is closed or replaced: back, previous or next
  record, selecting another row in the list pane, following a link that
  replaces the page, switching tabs. With unsaved changes it asks (discard, or
  keep editing). With none it locks and goes. A page pushed on top that
  returns to this one (a picker, the fullscreen profile, the photo viewer)
  does not end the sitting.
- If the app is killed during a sitting, the sitting is lost, as an edit page
  is today.

### Whole-record operations

Some actions cannot be held until Save, because they act on the record as a
whole: delete, and for a dive re-parse, resync, split or remove a data source,
separate a combined dive, set primary source, mark logged, mark complete, and
the profile editor, which saves on its own page.

- They need the record unlocked.
- Each acts at once, keeps its own confirmation, and is its own History entry.
- In the menu of a locked page they are listed but disabled, under one caption
  line: "Unlock to use these".
- While the sitting has unsaved changes they are disabled, with the caption
  "Save or cancel your changes first".
- After one completes, the page stays unlocked with no changes, and the
  working copy is taken again from the stored record.

Menu items that do not change the record (History, export, display options,
open full page) and items that create a different record (log for buddy, log a
near-miss, plan a repetitive dive) work while locked.

### Pages opened from a record's page

- A page opened from a record that edits that record's own data obeys the
  record's lock. Opened from a locked page it shows no control that writes.
  Opened during a sitting, its edits go into the working copy and are saved
  or discarded with it. For a dive this is the fullscreen profile, which
  places, moves and removes annotations.
- A file dropped on the window while a record is locked is refused with a
  one-line hint. During a sitting it is held like any other attachment.
- A page that creates or edits a different record is not covered by this
  record's lock. For a dive this is a saved what-if in the dive lab, which is
  a record of its own; creating one works while the dive is locked.
- A photo is a record of its own with its own lock. See "The photo viewer".

### A new record

A new record has nothing to read, so there is no separate form.

- The page opens unlocked with an empty working copy.
- The record's essential card and a short fixed **starter set** of cards are
  laid out open. Every other card is a chip in the strip.
- Cards holding prefilled values (from a scan, a plan, a trip) are also laid
  out open.
- Cancel leaves without creating anything, asking first if anything was
  entered. Save creates the record and shows it locked.

### History

- No marks are added to the page.
- A sitting appears in the record's History as one entry, labelled with the
  cards it changed, showing old and new values, with revert.
- **Every change made in a sitting is in that entry and is undone by
  reverting it.** The change log does not cover all of them today, so phase 1
  extends it (`lib/core/database/change_log/change_log_policy.dart`):
  - `dive_safety_findings` and `tank_pressure_series` log only deletes
    (`ChangeLogClass.deleteCopyOnly`). A dismissed finding and a reassigned
    pressure series must be logged as edits.
  - Documents, plan links (`dive_plans.linkedDiveId`) and route links are
    logged under their own record. When changed in a dive's sitting they must
    also appear in the dive's History, which filters by root record
    (`lib/features/change_log/data/repositories/change_log_repository.dart`).
  - The exceptions are the best-effort steps that run after Save (the tide
    record and the weather fetch for a new dive).
- History is easier to reach from a locked page: an icon beside the lock where
  the bar has room (the same width at which favourite is shown in the bar),
  and the first menu item otherwise.

### Wide screens and keyboard

- In the master-detail pane the embedded header carries the same lock, and the
  same Cancel and Save when unlocked. The pane no longer swaps to a separate
  edit widget.
- `MasterDetailScaffold` asks before changing selection during a sitting with
  unsaved changes. This closes a gap that exists today.
- Cards that pair side by side keep their slots; an open card edits within its
  slot.
- Shortcuts: unlock, Save, and Escape for Cancel.

### Shared pieces

These live under `lib/shared/widgets/` beside the existing `forms/` parts and
build on them (`FormRow`, `FormOverline`, `showDiscardDialog`). Names are the
builder's to choose. What each must do:

- **Edit session.** Holds the stored record, the working copy, which cards
  have changes, and validation errors. Exposes save and cancel. Has no
  dependency on any widget, so it can be tested alone.
- **Lockable page scaffold.** Owns locked or unlocked, swaps the top bar,
  shows the strip, and runs the leave check. Works as a full page and embedded
  in the master-detail pane.
- **Card frame.** Wraps one card and draws its state: locked, marked,
  open, changed, calculated.
- **Add strip.**
- **Card description.** What a record type supplies per card: an id, a title,
  whether it is recorded or calculated, whether it is empty for a given
  record, whether the diver has hidden it, a read widget, an editor widget,
  a validation function over the working copy, and which values the card
  owns, so that Save can apply only what changed.

A card editor owns its text controllers only while it is open and writes each
change through to the working copy. Validation is a function of the working
copy, so a closed card is still validated. This removes the "closed section
un-mounts its fields" constraint the current form works around.

## Design: phase 1, the dive page and the photo viewer

### Cards

A field is edited on the card that shows it. A field no card shows today is
edited on the card it belongs with. Where a value shows on two cards, one of
them is named below as the place it is edited.

Section ids are `DiveDetailSectionId` values. The header block is the fixed
part above the sections (`DiveDetailHeroSection`, the banners,
`SiteSuggestionCard`).

| Card | Its editor holds |
| --- | --- |
| Header block | Name, number, site (with the suggestion card), entry and exit date and time, runtime, bottom time, max depth, average depth, water temperature, rating, favourite, the planned switch, and the four "from profile" suggestions |
| `profile` | Annotations: add, move, change time, remove. "Edit profile" is a whole-record operation |
| `tanks` | Dive mode, rebreather settings (setpoints, diluent, scrubber, loop volume, the semi-closed values), tanks, apply configuration, gas switches |
| `details` | Dive types, trip, dive center, operator, boat, captain, training courses, visibility, water type, the two statistics exclusion switches |
| `environment` | Air temperature, weather fields and the weather fetch, surface conditions, current, swell, entry method, exit method |
| `altitude` | Altitude, surface pressure |
| `navTrack` | Route links |
| `weights` | Weights, apply a weight preset, weighting feedback |
| `buddies` | Buddies with roles, the diver's own role |
| `signatures` | Capture, delete |
| `equipment` | Gear, use a set, scan, sort |
| `sightings` | Sightings, with the site's species suggestions |
| `media` | Add photos, scan gallery, unlink, replace a link |
| `documents` | Attach, remove |
| `tags` | Tags |
| `notes` | Notes, and annotation pins placed from the notes |
| `customFields` | Key and value pairs |
| `safetyReview` | Dismiss and restore findings |
| `diveLab` | Link a plan |
| `dataSources` | No held edits. Its whole-record operations (set primary, split, remove, separate) are buttons on the card |

Cards with nothing to edit fade back when unlocked. Their label says why:
"Calculated" for `decoStatus`, `tissueLoading`, `sacSegments`, `tide` and
`buoyancy`; "Imported" for `health` and `surfaceGps`.

Notes on that table:

- Rows that are calculated inside a mixed card (surface interval, air
  consumption, gradient factors and the computer name on `details`) stay
  read-only inside an open editor.
- Dive mode shows on the header block and on `details`, and is edited on
  `tanks`. A gauge dive has no tanks card, so "Tanks" is in the Add strip and
  its editor shows the mode selector alone.
- Dive types show on the header block and on `details`, and are edited on
  `details`. Surface pressure shows on `environment` and `altitude`, and is
  edited on `altitude`.
- Four things are editable today and shown nowhere on the dive page: the two
  statistics exclusion switches, the rebreather settings other than setpoints
  and diluent, and weighting feedback. They are editable in the editors named
  above. The read layout of `details` gains one row when a statistics switch
  is on, so that an exclusion is never invisible. The others stay as they are.

### Rules that span cards

The edit page keeps these in widget code. They move into the edit session as
functions of the working copy, and each keeps its current behaviour. When a
rule changes a value on another card, that card gets the changed dot.

| Change | Effect |
| --- | --- |
| Entry, exit, runtime | Linked as today (`dive_edit_page_linked_times.dart`); entry date fills the exit date |
| Bottom time or runtime | Limits gas-switch and annotation times |
| Dive mode | Gauge hides tanks and gas switches; closed-circuit seeds setpoints; Save drops rebreather values that do not fit the mode |
| Site | Snaps water type, entry and exit method, altitude and dive types; re-checks geofenced equipment; enables the weather fetch; feeds species suggestions; orders the dive-center picker |
| Exit method | Mirrors entry method until edited directly |
| Trip | Clears tank slot links and suggests slots again |
| Tanks | Removing a tank drops gas switches that pointed at it |
| Dive center | Applying rental memory replaces weights and tanks |
| Weather fetch | Fills air temperature and surface pressure when they are empty |
| Planned switch | Clears and hides the number, hides the route and gas switches; suggests a number again when switched off |

### What is held, and what is not

Held until Save, as the edit page already does: every scalar field, tanks,
apply configuration, gear, use a set, weights, sightings, buddies, tags,
courses, dive types, gas switches, annotations, route links, the fetched
weather values.

Newly held (written at once today):

- Everything in the table under "What a locked dive page no longer shows"
  that is marked as held.
- Assigning a suggested site, which today writes at once from the dive page.
- Writes the dive editor makes to a different record: copying an auto-filled
  altitude back to the site, and adding a location to a site from the
  suggestion card. They are written with the sitting, in the same History
  entry.

Not held, and unaffected by Cancel, as today:

- A record created from a picker during the sitting: a new site, buddy, role,
  trip, dive center, course or tag. Creating a record is outside the rule.
- "Save as set" and "Save weights as preset", which create other records.
- A tank tag scan importing that cylinder's fill history.

Written with the sitting, in the same transaction and History entry: the
scanned logbook photo, plan promotion, and stretching the trip's dates to
cover the dive. After it, best effort and outside the entry: the tide record
and the weather fetch for a new dive.

### The working copy

- The working copy is a `Dive` (immutable, `copyWith`) plus the child
  collections the edit page holds in memory today.
- It starts as the stored dive, and at Save the changed values are applied to
  the dive as stored at that moment, so a field no card touches is carried
  through by construction. `dive_edit_save_field_census_test.dart` is
  retargeted to assert that.
- The save service builds on the current `_saveDive`: the same call to
  `updateDive` or `addDive`, then the same child writes. Today those are
  separate awaited writes with no enclosing transaction; the service wraps
  them in one transaction and one change log operation. The repositories
  already open their own transactions, which nest inside it.
- Units in every editor follow the active diver's unit settings, as the
  current fields do.

### A new dive

- Essential card: the header block's editor (the "Dive" card in the mockup).
- Starter set: Tanks, Buddies, Notes. Tanks is seeded with the default tank
  from settings as today, and stays hidden for a gauge dive.
- Routes: `/dives/new` and the pane's `?mode=new` open this page.

### What happens to the edit page

- Bulk edit is not a separate page today. `bulk_dive_edit_page.dart` wraps
  the same `DiveEditPage` with `bulkDiveIds`, and `_buildBulkScaffold` reuses
  the page's controllers, state and builders (`_weightChild`,
  `_sightingsChild`, `_visibilityInput`, `TankRow`, the pickers). Bulk edit
  must keep working, unchanged in behaviour, throughout phase 1.
- The field widgets and pickers that both bulk edit and the card editors need
  are extracted to files of their own, so neither depends on the other.
- When the last card has moved, the single-dive code is deleted. What is left
  is the bulk edit page, holding only what bulk edit uses.
- `/dives/:diveId/edit` and the pane's `&mode=edit` stay as addresses and open
  the dive page already unlocked.
- The rows on the dive page that link to the edit page today
  (`details_section.dart:269`, `altitude_section.dart:29`) lose that link.

### What a locked dive page no longer shows

Every control below is hidden while locked and appears when unlocked.

| Today | When unlocked |
| --- | --- |
| Favourite toggle in the bar | A field in the header block's editor |
| Add photos, scan gallery, add document, unlink media | Media and Documents card editors, held until Save |
| Annotation pin, move, edit time, remove | Profile card editor, held until Save |
| Dismiss or restore a safety finding | Safety review card editor, held until Save |
| Signature capture and delete | Signatures card editor, held until Save |
| Site suggestion: assign, add location | Buttons on the suggestion card, held until Save |
| Site suggestion: create site | Button on the suggestion card. Creating the site is immediate; assigning it is held |
| "Edit profile" | Whole-record operation on the Profile card |
| Tank pressure series reassign | Tanks card editor, held until Save |
| Nav track unlink, set primary | Nav track card editor, held until Save |
| Link a plan | Dive lab card editor, held until Save |
| Link or unlink a pre-dive checklist | Whole-record operation |
| Set primary source, split, remove source, separate | Whole-record operations on the Data sources card |
| Mark logged, mark complete, "surfaced" on the draft banner | Whole-record operations |
| Add heart rate, re-parse, resync, delete | Whole-record operations in the menu |

Planned dives and drafts follow the same rule as logged dives.

### The photo viewer

The photo viewer (`lib/features/media/presentation/pages/media_viewer_page.dart`)
changes a photo's own data at once today, and is opened both from a dive and
from the media library. A photo is a record, so the viewer gets its own lock
in phase 1, wherever it is opened from.

- The viewer opens locked. Its controls that write are hidden: tag species,
  tag people, set the time in the dive, adjust colour.
- Unlock sits in the viewer's bar. Unlocked, the bar shows Cancel and Save,
  and those controls appear. Their changes are held until Save.
- "Write metadata to the photo" changes the file itself, so it is a
  whole-record operation: it needs the unlock, keeps its confirmation, acts at
  once, and is unavailable while there are unsaved changes.
- Stepping to the previous or next photo during a sitting with unsaved changes
  asks first. Every photo opens locked.
- Reading controls (show info, the dive computer overlay, play and pause) are
  unaffected.
- The viewer has no cards and no Add strip. It uses the shared edit session
  and the same bar; the card frame does not apply.
- The viewer's lock is separate from the dive's. Opening a photo from a dive
  that is being edited does not end the dive's sitting.
- The rest of the media library is not part of phase 1.

## Rollout to other record types

Each phase after the first reuses the shared pieces. Each gets a short design
note of its own when its turn comes, listing its cards and saying, for each
action its page performs in place today, whether it becomes a held card edit
or a whole-record operation.

- **Phase 1: the shared pieces, the dive page and the photo viewer.** Described
  above.
- **Phase 2: sites.** Already on the shared form parts. Merge and duplicate
  stay as their own deliberate forms. For a library reader, unlock reads
  "Suggest changes" and Save submits the suggestion.
- **Phase 3: record types with a detail page.** Trips, equipment, equipment
  sets, buddies, dive centers, certifications, courses, documents, GPS and
  underwater tracks. Their in-place actions go behind the unlock: logging a
  service or a fill, moving gear, returning gear, ticking a checklist item or
  a course requirement, marking a course complete, renaming a track. One-tap
  toggles on list rows (the buddy favourite) show state only.
- **Phase 4: editors with no read page.** Species, tank presets, weight
  presets, cylinder configurations, transmitters, checklist templates,
  pre-dive templates, rules, incidents, and the diver profile pages. A row in
  their list opens the editor directly, and that tap is the deliberate act.
  They adopt the shared Cancel and Save bar and the leave check, and nothing
  else changes.
- **Unchanged.** The settings lists, the planner canvas, the table editor,
  bulk edit.

## Decisions

Made by Eric, in the order they were made:

1. Unlocking the details page replaces the Edit page for an existing record.
2. A locked record allows no change at all, adding included.
3. One Save per unlock.
4. Day-to-day logging on gear, trips and courses needs the unlock too.
5. Unlocked look: marked cards (pencil on editable cards, calculated cards
   faded), over "quiet" and "open fields".
6. Absent and hidden cards are reached from a strip under the top bar, over
   rows in place and a card at the end.
7. A new dive opens unlocked with a starter set, over essentials only and
   every card laid out.
8. History only, over marks on the page.
9. Build approach 1.
10. History is extended so that every change in a sitting is in its entry and
    reverts with it, over shipping with named exceptions.
11. The photo viewer gets its own lock in phase 1, over leaving it for a later
    phase or making it read-only only when opened from a locked dive.
12. Phase 1 lands as a series of pull requests, hidden until complete, over
    one long-lived branch.
13. A tracking issue for the whole pattern (#4527).

Calls made in this design that Eric has not explicitly confirmed. Correct any
of them:

- Favourite needs the unlock.
- Writes that happen from viewing a record are outside the rule.
- Bulk edit, the table editor, import, download, sync and merge count as
  deliberate modes.
- Settings lists keep their dialogs.
- Everything done on a card is held until Save, photos and annotations
  included, so Cancel means nothing happened.
- Whole-record operations act at once, need the unlock, and are disabled
  while there are unsaved changes.
- Whole-record operations are listed but disabled in a locked page's menu.
- The lock is never stored and has no setting.
- The left button reads "Cancel" whether or not there are changes.
- Any number of cards can be open. The pencil opens an editor; the header row
  acts as the pencil except in the dive page's folding list layout.
- Save is one database transaction, and a failure leaves the page unlocked
  with nothing written.
- Only what changed during a sitting is written, on top of the record as
  stored at Save, so a sync that lands mid-sitting is not overwritten.
- The fullscreen profile obeys the dive's lock; a dropped file is refused
  while locked; a saved what-if is a record of its own.
- A page pushed on top of a record's page (a picker, the fullscreen profile,
  the photo viewer) does not end the sitting.
- In the photo viewer: "Write metadata to the photo" is a whole-record
  operation, stepping to another photo with unsaved changes asks first, and
  the rest of the media library is left for a later phase.
- A hidden card edited through the strip stays hidden afterwards.
- Planned dives and drafts lock like logged dives.
- The starter set is fixed: Tanks, Buddies, Notes.
- Which card each dive field is edited on (the table under "Cards"),
  including dive mode on Tanks and the statistics switches on Details.
- The read layout of Details gains a row when a statistics switch is on.
- Cards with nothing to edit are labelled "Calculated" or "Imported".
- The profile editor is a whole-record operation, so it is unavailable while
  the sitting has unsaved changes. Today it can be opened mid-edit.
- Writes the dive editor makes to a site (altitude copied back, a location
  added) are held and written with the sitting.
- A record created from a picker during a sitting survives Cancel.
- Editors with no read page (phase 4) only adopt the bar and the leave check.
- One-tap toggles on list rows show state only.
- The re-parse and resync overwrite gap is a follow-up issue.

## Left to the builder

- Names and file layout of the shared pieces.
- The exact pencil, dot, fade and outline styling, taken from the theme. No
  card title may differ in size from another, and sub-headings inside a card
  use the one `FormOverline` style.
- How an open card behaves inside a side-by-side pair.
- The shortcut keys.
- The order in which cards move from the edit page to card editors.
- Wording of new strings. Every new string is added to all locales.
- If an action listed as "held until Save" turns out to be impossible to hold,
  stop and raise it. Do not make it immediate silently.

## Testing

- The edit session is tested without widgets: changes, validation, save,
  cancel.
- Each card editor has its own widget tests. Each existing `dive_edit_*` test
  file moves to the card that owns the behaviour it covers; none is dropped
  without a replacement.
- The lockable scaffold is tested for: no write control present while locked,
  the bar swap, the strip, the leave check in full-page and pane modes.
- A locked dive page is tested to make no repository write on any tap.
- A sitting that changes several cards produces exactly one change log
  operation, and reverting it restores every value (needs #4477). The test
  covers a dismissed safety finding, a reassigned pressure series, a document,
  a plan link and a route link.
- A Save that fails partway writes nothing and leaves the page unlocked.
- A value changed in storage during a sitting, on a card the diver did not
  touch, survives the Save.
- The photo viewer makes no write while locked, from a dive and from the
  media library.

## Delivery

- Phase 1 lands as a series of pull requests. The unlocked page is built
  beside the existing edit page and is not reachable in the app until it has
  every card. The last pull request switches the Edit button to the lock and
  deletes the single-dive edit page, so no release has two ways to edit a dive.
- No table or column is added for the pattern itself, and there is no new
  setting. Extending the change log changes its policy and its generated
  triggers, which is a database step. It follows the existing conventions:
  tables under `lib/core/database/tables/`, migrations under
  `lib/core/database/migrations/`, nothing new in `database.dart`.
- Every pull request refers to #4527. The last phase 1 pull request closes
  #1906 and #1570.
- Pull requests that change anything visible carry screenshots, as the
  contributing guide requires. While the new page is unreachable in the app,
  screenshots come from widget tests or a development-only entry point.
