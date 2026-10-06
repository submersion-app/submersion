# Buddy profile dive linking and planned-dive fill

Date: 2026-09-15
Issue: #2002

## Problem

Two people who keep Submersion profiles on the same library and dive
together enter the same dive twice. The date, site, conditions and group are
identical, only the profile data and gear differ. Nothing connects a buddy
record to the local profile that buddy owns, so the app cannot offer to help.

Separately, a diver cannot plan a dive in advance, fill in its details, and
later merge the dive computer download into that entry. The download lands
as a new dive and the pre-entered one becomes a duplicate. The pieces for a
planned lifecycle already exist (`dives.is_planned`, `getPlannedDives`,
`createPlannedDive`, `convertPlanToActualDive`) but no UI reaches them, and
the planner's convert-to-dive leaves an unnumbered planned dive in the log by
accident rather than by design.

## Goals

- A buddy can be linked to a local diver profile, explicitly, with a
  one-time suggestion when a name or email matches.
- Saving a dive with a linked buddy offers to log the same dive in that
  buddy's profile. The mirrored dive is a planned dive holding the shared
  facts and the group, and the two dives stay linked as siblings.
- A planned-dive lifecycle a diver can drive by hand: plan, mark as logged,
  see which dives are still planned.
- The dive computer download review recognizes a same-day planned dive and
  offers to fill it: measured facts from the computer, human facts from the
  plan. Filling promotes the dive and records a data source so a re-download
  is recognized.

## Non-goals

- Propagating later edits between sibling dives. The link is for navigation
  and de-duplication only. A follow-up can add offered propagation.
- Automatic buddy-to-profile matching without confirmation.
- One shared dive record seen by several profiles (the Team Dive Fusion
  direction).
- A per-buddy "always mirror" policy. Every mirror is confirmed.
- Exporting the sibling link. UDDF has no home for it.
- Mirroring trips, tags, custom dive types, custom roles or dive centers
  into the target profile's lists. They are matched when present and
  otherwise dropped (rules below).

## Decisions taken during brainstorming

| Question | Choice |
| --- | --- |
| What is the mirrored dive | Linked sibling: its own `dives` row, tied to the source by a shared outing id |
| How a buddy becomes a profile | Explicit `linked_diver_id` on the buddy, with a one-time suggestion prompt |
| When the offer is made | Once, at save time, plus a detail-page action |
| State of the mirrored dive | Planned, unnumbered, awaiting the buddy's own download |
| How a download finds a planned dive | Same-day automatic suggestion, overridable in the review step |
| Which side wins on fill | Computer for measured facts, plan for human facts |
| What the sibling link does | Navigation and de-duplication only |
| Buddies on the mirrored dive | Whole group copied; matched by link, then name, else created |
| Planning by hand | "Plan a dive" in the add menu and a planned switch on the edit page |
| Storage approach | Columns on existing tables, no outings table |

## Data model

Schema version 220 (written as 219 while the spec was drafted; equipment tags took 219 first), one migration rung, no data backfill.

### `buddies.linked_diver_id`

Nullable text, references `divers.id`, `ON DELETE SET NULL`. Meaning: this
buddy is that local profile. It is distinct from `buddies.diver_id`, which
says which profile's contact list the buddy belongs to and is consumed as an
ownership scope by every buddy query.

Rules enforced in `BuddyRepository`, not the schema:

- At most one buddy per (`diver_id`, `linked_diver_id`) pair.
- A buddy may not link to its own owner.

Sync: an ordinary column under last-writer-wins. Merge: the buddy merge
repository carries a single non-null link onto the survivor and refuses to
merge two buddies whose links differ, with a message naming both profiles.
The legacy text-to-buddy conversion is untouched; it creates unlinked buddies
that the suggestion prompt picks up later.

The guard test that enumerates references to `divers` gains the new column.
The diver delete flow already runs inside a deferred-FK transaction; SET
NULL needs no new step.

### `dives.outing_id`

Nullable text, no foreign key. Every dive created by one mirror action shares
the source dive's outing id, minted at that moment and stamped on the source
as well. Siblings of a dive are the dives with the same outing id and a
different id. Deleting a sibling needs no cleanup; a lone dive with an outing
id is valid.

A shared group id beats a pairwise sibling pointer for two reasons. Sync
applies last-writer-wins per row, so a symmetric pointer written on two rows
can half-apply after a conflict, while a group id is written once per row.
And a non-FK id adds no delete path to guard, after PR #1949 untangled the
plan links that did.

Sync: an ordinary column. Not in the stats scope. Not exported.

### `dives.is_planned`

Reused unchanged. Its semantics tighten in code: a planned dive holds no
dive number and no primary data source. `convertPlanToActualDive` remains
the single promotion path. It already leaves the date alone when no actual
date is passed, which is what the fill needs, since the download has set
the entry time before promotion.

### `dive_data_sources`

No new columns. The attach-to-existing-dive branch of
`DiveComputerRepository.importProfile` starts inserting the primary source
row (fingerprint, source UUID, descriptor, summary numbers) when the dive
has none. Today that insert lives only in the new-dive branch, so a profile
attached to an existing dive is invisible to the fingerprint pass and a
re-download lands as a duplicate. This feature depends on the fix, so it is
in scope.

## Linking a buddy to a profile

### Buddy edit page

A "Linked profile" field below the contact details: a picker over the other
local divers, excluding the buddy's owner, with a clear action. Saving writes
`linkedDiverId`. When another buddy in the same owner's list already links to
that profile, the save is refused with a message naming that buddy and a
button that opens it.

### Suggestion

When the page opens for a buddy with no link, and exactly one other local
profile has the same trimmed, case-folded name or the same email, an inline
prompt reads "Chris has a profile here. Link this buddy to it?" with Link and
Not now. Not now hides the prompt for the session only. There is no
persistent dismissal, since the prompt is cheap and the link is expected.

### Display

The buddy list and detail show a small profile marker on linked buddies, and
use the profile's photo when the buddy has none.

### Reciprocal buddy

`BuddyProfileLinkRepository.ensureReciprocalBuddy(ownerDiverId,
linkedDiverId)` returns the buddy in the owner's list linked to that profile,
creating one when none exists with name, email, phone and photo copied from
the profile. The mirror flow uses it. The buddy edit page never creates a
reciprocal on its own: linking Chris in your list says nothing about whether
Chris wants you in theirs.

## The mirror flow

### Trigger

After a dive save succeeds and its buddies are written, the edit page asks
`DiveMirrorService.candidates(diveId)`: the linked buddies on the dive whose
profile owns no dive with this dive's outing id. When there are any, a dialog
lists them as checked boxes, "Also log this dive in Chris's profile?", with
Log and Not now. The dialog does not fire for a dive being filled by a
download or created by a mirror.

Not now is not persisted. The candidate check itself suppresses repeats once
a sibling exists, and the detail-page action covers the declined case.

### Creation

`DiveMirrorService.mirror(sourceDiveId, targetDiverIds)` runs in one
transaction:

1. Mint an outing id if the source has none and stamp the source.
2. For each target diver, insert a dive owned by the target with
   `isPlanned` true, no dive number, the outing id, and the shared facts
   below.
3. Resolve people and references as described below.
4. Mark every new row pending for sync.

Copied from the source: date, entry and exit time, site, dive type,
conditions (water and air temperature, visibility, current direction and
strength, swell, water type, altitude, surface pressure, entry and exit
method), boat name, captain, operator, surface conditions, dive center.

Not copied: notes, rating, favorite, tanks, weights, gear, profile, computer
model, serial and firmware, deco settings, CNS and OTU, exclusion flags,
custom fields, media.

A census-style test lists every `dives` column as copied or not copied, so
a new column fails the test until it is classified.

### Cross-profile references

Sites and trips carry an `is_shared` flag and are visible to a profile when
owned or shared. Dive types, tags, dive centers, roles and equipment are
owned per profile; built-in types and roles are unowned.

- Site: set `is_shared` on the site when it is not already, since two
  profiles now hold dives at it.
- Trip: copied only when already shared, otherwise omitted.
- Dive type and role: built-in ids copied; custom ones matched by name in
  the target's list and dropped when absent.
- Tags: matched by name in the target's list, dropped when absent.
- Dive center: copied when shared or unowned, otherwise omitted.

### People

- The target's own `diverRole` on the new dive is the role its buddy held
  on the source dive.
- The source diver is added as a buddy on the new dive through
  `ensureReciprocalBuddy`, with the source dive's `diverRole` (the default
  buddy role when unset).
- Every other buddy on the source dive is added with its role: matched in
  the target's list by `linkedDiverId` first, then by exact trimmed name,
  else created there with name, email, phone and photo copied. Roles follow
  the built-in or by-name rule above.

### Feedback

A snackbar "Logged for Chris" with Undo and View. Undo deletes the created
dives and clears the outing id from the source when this action minted it;
created buddy records stay. View opens the sibling.

### Detail page

- An overflow action "Log for a buddy's profile" appears when candidates
  exist and opens the same dialog.
- A "Logged with" row lists the siblings with each owner's name and photo
  and opens the sibling on tap. The detail route loads by id, so a sibling
  opens in any active profile.

## The planned-dive lifecycle

### Creating

- The dive list's add menu gains "Plan a dive", which opens the edit page
  with the planned switch on.
- The edit page gains a "Planned dive, awaiting dive computer" switch near
  the top. It is available on any dive without a primary data source; a
  dive that already holds downloaded data cannot be marked planned. While
  the switch is on, the dive number field is hidden and the save writes no
  number.
- The planner's convert-to-dive goes through `createPlannedDive`, so its
  dive is planned and unnumbered on purpose.

### Promoting

`convertPlanToActualDive` clears the flag and assigns the next dive number
for the owning diver. Callers: turning the edit-page switch off on an
existing planned dive, a "Mark as logged" action on the detail page, and
the download fill.

### Displaying

- A "Planned" chip on the dive list tile.
- A banner on the detail page: "Awaiting dive computer data. Mark as logged
  if you dived without one."
- Planned dives stay excluded from statistics by the existing stats scope
  and sort in date order with the rest.

### Numbering

Planned dives hold no number, so the edit page's next-number suggestion and
the importers' clash reporting are unaffected. Promotion takes the next
number at promotion time. A planned dive promoted late can sit out of date
order; the existing renumber tool covers that, as for any late import.

### Sync and export

Nothing new. `isPlanned` already round-trips through sync and UDDF.

## Filling a planned dive from a download

### Detection

`DiveImportService.detectDuplicate` gains a planned pass, run after the
fingerprint pass and before the fuzzy pass. The fuzzy and contained-segment
passes stop considering planned dives.

Candidates are the unfilled planned dives owned by the import's target
profile (the active diver, or the mapped profile of a multi-diver import)
whose date falls on the same local calendar day as the incoming start. When
a day holds several downloads and several planned dives, they are paired in
start-time order, nearest first, so no planned dive is suggested twice. A
hit yields `DuplicateAction.fillPlanned` pre-selected, with the candidate
carried on the match result.

### Review card

The row reads "Fills planned dive: Blue Hole, 09:30" with a Change action
that opens a picker over every unfilled planned dive of that profile, plus
"Import as new". When the planned dive holds a profile series, the card
notes that it will be replaced. The bulk-apply guard treats fill like
consolidate and never applies it across rows.

### Fill

`PlannedDiveFillService.fill(plannedDiveId, downloadedDive)` runs in one
transaction:

1. Snapshot the dive row, tanks and profile series using the consolidation
   snapshot machinery.
2. Remove any profile series the planned dive holds (the planner's synthetic
   curve or a hand-sketched one). A planned dive has no data source, so
   nothing else is attached.
3. Attach the download through the attach-to-existing-dive branch of
   `importProfile`, with the data-source insert fixed, which adds the
   profile, tank pressure series, gas switches, events and gear links.
4. Apply the measured facts from the computer: entry and exit time,
   duration, bottom time and runtime, max and average depth, water
   temperature, CNS and OTU, deco algorithm and gradient factors, computer
   model, serial and firmware, and the computer attribution.
5. Match tanks by transmitter serial first, then gas mix, as consolidation
   does. Matched planned tanks receive start and end pressures; unmatched
   downloaded tanks are added.
6. Promote through `convertPlanToActualDive` without restamping the date.
7. Mark the dive pending for sync.

Kept from the plan: site, buddies and roles, notes, rating, dive type,
conditions, trip, gear, weights, tags, custom fields.

A census-style test classifies every `dives` column as measured (computer
wins) or human (plan wins).

### Undo

The wizard summary offers Undo for filled dives. It restores the snapshot
and re-marks the dive planned.

### Re-download

The data-source row carries the fingerprint and source UUID, so a later
download of the same dive is caught by the fingerprint pass and pre-selected
skip.

### Mirror interaction

A filled dive already has any outing id it was created with, so no mirror
prompt fires on fill. Chris's mirrored planned dive is filled when Chris's
computer is downloaded with Chris as the target profile.

## Error handling and edge cases

- A mirror failure rolls back its transaction. The source save has already
  succeeded, so the snackbar reports "Could not log for Chris" and the
  detail-page action remains for a retry.
- Two devices mirroring the same dive offline produce two siblings in the
  target's log with the same outing id. Once sync lands they are visible as
  two siblings and the existing combine flow merges them. No new conflict
  type.
- Removing a buddy link after mirroring leaves the siblings linked. The
  link only gates new offers.
- Deleting a profile tombstones its dives through the existing diver delete;
  the survivor's "Logged with" row lists nothing.
- A planned dive moved to another day before the download is missed by the
  same-day pass and reachable through the picker.
- A multi-diver import mapped to a new profile has no planned candidates.

## Components

New files:

- `lib/features/buddies/data/repositories/buddy_profile_link_repository.dart`:
  link validation, suggestion lookup, `ensureReciprocalBuddy`.
- `lib/features/buddies/presentation/widgets/linked_profile_field.dart` and
  `linked_profile_suggestion.dart`.
- `lib/features/dive_log/data/services/dive_mirror_service.dart` and its
  field classification `dive_mirror_fields.dart`.
- `lib/features/dive_log/presentation/widgets/mirror_dive_dialog.dart`,
  `logged_with_section.dart`, `planned_dive_banner.dart`.
- `lib/features/dive_log/presentation/providers/sibling_dives_provider.dart`.
- `lib/features/dive_computer/data/services/planned_dive_fill_service.dart`
  and `planned_dive_fill_fields.dart`.
- `lib/features/dive_computer/domain/services/planned_dive_matcher.dart`
  (same-day pairing).
- `lib/features/import_wizard/presentation/widgets/planned_dive_picker_sheet.dart`.

Touched:

- `lib/core/database/database.dart`: two columns, v219 rung.
- `lib/features/buddies/domain/entities/buddy.dart`, `buddy_repository.dart`,
  `buddy_merge_repository.dart`, `buddy_edit_page.dart`, list and detail
  tiles.
- `lib/features/dive_log/domain/entities/dive.dart` (`outingId`),
  `dive_repository_impl.dart` (column round trip, `convertPlanToActualDive`
  restamp flag, planned-dive queries), `dive_edit_page.dart` (switch, number
  field, post-save prompt), `dive_detail_page.dart` (banner, row, actions),
  dive list tile and add menu.
- `lib/features/planner/presentation/pages/plan_canvas_page.dart`
  (convert through `createPlannedDive`).
- `lib/features/dive_computer/data/repositories/dive_computer_repository_impl.dart`
  (data-source insert on the existing-dive branch),
  `dive_import_service.dart` (planned pass, exclusions),
  `lib/features/import_wizard/domain/models/duplicate_action.dart`,
  `import_wizard_providers.dart` (pre-selection, bulk guard),
  `review_step.dart` and `duplicate_action_card.dart`,
  `dive_computer_adapter.dart` (fill action, undo).
- Sync serializer: no code change expected; the columns ride along in
  `toJson`. A test asserts both columns round-trip.
- ARB files: every new string in all locales.

## Testing

TDD throughout.

- Migration rung test for v219 on the schema ladder; the `divers` reference
  census gains `buddies.linked_diver_id`.
- Repository: link uniqueness, self-link refusal, `ensureReciprocalBuddy`
  idempotence, merge carry and refusal, suggestion lookup (exact one match
  only).
- `DiveMirrorService` on an in-memory database: the column census, site
  sharing flip, unshared trip omitted, built-in versus custom type and role
  resolution, tag matching, buddy resolution order (link, name, create),
  outing id minting and reuse, candidate suppression once a sibling exists,
  undo.
- `PlannedDiveFillService`: the measured-versus-human census, tank matching
  by serial then mix, synthetic series removal, data-source row with
  fingerprint, promotion assigns the number and keeps the date, snapshot
  undo restores the planned state.
- Detection: same-day pairing in time order, no double suggestion, planned
  dives excluded from fuzzy and contained passes, fingerprint pass wins on
  re-download.
- Sync: both columns round-trip through the serializer.
- Widgets: linked profile field and suggestion prompt, mirror dialog after
  save, planned switch hides the number field, "Mark as logged" action,
  review card and picker.
- Architecture guards run after adding files under `lib/`.
