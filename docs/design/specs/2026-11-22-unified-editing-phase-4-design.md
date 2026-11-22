# Unified editing, phase 4: editors with no read page

Issue: #4527 (the whole pattern). This note is phase 4, the last phase, of
[the unified editing pattern](2026-11-14-unified-editing-pattern-design.md),
which it does not repeat: the bar, saving, cancelling, leaving and History
apply as written there. It builds on
[phase 2](2026-11-17-unified-editing-phase-2-sites-design.md) and
[phase 3](2026-11-18-unified-editing-phase-3-records-design.md), and says
only what is different for editors that have no read page.

Phases 1 (dives), 2 (sites) and 3 (trips, gear, sets, buddies, centres,
certifications, courses, documents, species, tracks) are merged to main.

## Why

The rule is **nothing recorded changes without unlocking**. A record with a
page of its own now opens locked everywhere. What is left are records the
diver only ever sees through an editor: presets, configurations, templates,
rules, incidents, the diver's own profile. A row in their list opens the
editor directly; that tap is already the deliberate act, so there is nothing
to unlock (pattern, "Rollout", phase 4).

But these editors still do it each their own way. Eight of them have no
unsaved-changes check at all: Back throws the diver's edits away without a
word. Four save in two or three separate writes, so a failure halfway leaves
half a template behind. The diver profile pages each keep a private check,
and they fill their fields from the diver who was active when they opened
but save onto whoever is active at Save, so switching diver mid-edit and
saving writes one diver's details onto another.

Phase 4 gives every one of them the same Cancel and Save bar and the same
leave check as an unlocked record page, so that an edit behaves the same way
wherever it is made.

## Goals

- Every phase 4 editor shows the shared unlocked bar: Cancel, the editor's
  title, Save, tinted and underlined in the accent colour, with no back
  arrow.
- Leaving an editor with unsaved changes asks first, whichever way it is
  left: Back, Cancel, another tab, a row of a list pane, switching diver, a
  quit.
- One Save is one database transaction and one History entry. A Save that
  fails writes nothing.
- Nothing else about these editors changes: what opens them, their fields,
  their list pages.

## Non-goals

- Locking these editors or giving them read pages. A row opens the editor.
- Changing their list pages: deletes, reorders, switches and clones on a
  list stay as they are (decision 1), apart from the body weight delete,
  which gains a confirmation.
- The settings lists edited through small dialogs (dive types, tags, site
  types, roles, service kinds, equipment locations, currency rules, saved
  queries, import presets). They are configuration (pattern, "Outside the
  rule").
- Deliberate modes and tools: the planner, the dive lab, the profile editor,
  species review, fix dive times, account and connection setup, bulk edit,
  the table editor.
- "Save as preset" and "Save as template" offered from a dive, a trip, the
  planner or bulk edit. They create another record at once, which is outside
  the rule (pattern, "Not held").
- Species. It joined phase 3 with the full lock (phase 3, decision 2) and is
  done: `species_edit_page.dart` is gone and the species page runs on
  `RecordEditHost`.

## Anti-goals

Those of the pattern, plus:

- An editor that loses edits on Back, Cancel or a switch of diver without
  asking.
- A Save that writes part of a record.
- A tinted bar on a view that cannot be saved (a built-in template, a rule
  from a newer version).
- Two looks for the same kind of editor once phase 4 is done.

## Current state (for orientation)

Every editor below is a full page in the main shell route, with no `onExit`,
no list pane and no table mode. None uses `EditFormScaffold`, `RecordEditBar`,
`RecordEditLeaveGuard` or `RecordSittingExitBlocker`. Every table named is a
tracked change log root, with its child tables logged under it
(`change_log_policy.dart`).

| Editor | Files (lines) | Opens from | Saves today | Leave check today |
| --- | --- | --- | --- | --- |
| Tank preset | `tank_preset_edit_page.dart` (425), list `tank_presets_page.dart` (365) | List FAB; the row's pencil (the row itself has no tap). Built-in presets are code constants with no editor | One row (`addPreset`, `updatePreset`); pop and snackbar | None. Close X, Save in the bar |
| Weight preset | `weight_preset_editor_page.dart` (327), list (129) | List FAB, row tap, pencil. New starts with one belt row | Preset and entries in one transaction; pop | None. Close X, Save in the bar |
| Cylinder configuration | `cylinder_config_edit_page.dart` (255), list (295), `cylinder_config_item_editor.dart` (566) | List FAB, row tap; a rebreather gear item's `UnitConfigurationsCard` (New, seeded with the unit; rows). The planner's Manage opens the list | Config row, then `saveItems`: two or three writes, no transaction, no try/catch (a throw leaves `_saving` set) | None. Back arrow, Save in the bar |
| Transmitter key | `transmitter_edit_page.dart` (808) | Only under a gear item: `/equipment/:id/transmitter` and `.../transmitter/:transmitterId`, from the item page's Transmitter card (Add key, a key row, Set up). `/transmitters` lists items, not keys | `saveTransmitterKey` (or `takeOverKey`), then `saveSetup` updates each sibling key, one write each; findings refresh; copies the key's serial onto the item if it has none; a snackbar whose Apply rewrites dives | None. Close X, Save in the bar |
| Checklist template | `checklist_template_edit_page.dart` (559, item dialog inline), list (108) | List FAB, row tap, edit icon (Settings, Manage) | Template row, `saveSections` (diff), `saveItems` (delete all, reinsert): three writes, no transaction | None. Save in the bar |
| Pre-dive template | `pre_dive_template_edit_page.dart` (505), `pre_dive_item_dialog.dart` (325), `pre_dive_editable_item.dart` (103), list (210) | List FAB, row tap; a built-in's View opens it read only | Same three-write shape as checklist templates | None. Save in the bar, hidden when read only |
| Rule | `rule_edit_page.dart` (407) and widgets | `/rules/new`, `/rules/:id`, from the FAB, the empty state, a row. Read only when saved by a newer version or holding an unknown action | One row; condition and actions are JSON columns | None. Save in the bar |
| Incident | `incident_edit_page.dart` (703), list (103) | List FAB and rows; a dive's "Log a near-miss" (seeded with the dive); a check-in's near-miss action (seeded with the check-in) | One row, then a findings refresh; try/catch | None. Save is a button at the bottom of the form; the bar holds Delete |
| Diver profile | Hub `diver_profile_hub_page.dart` (499); `personal_info_edit_page.dart` (380, also the new-diver page), `medical_info_edit_page.dart` (328), `emergency_contacts_edit_page.dart` (283), `notes_edit_page.dart` (176), `prior_experience_edit_page.dart` (314); `body_weight_edit_page.dart` (102) | The hub (Settings, Diver profile); new diver from the hub and the diver switcher | Each edit page writes the whole `divers` row (`updateDiver`) from `copyWith` on the diver active at Save; new diver through `addDiver` | Each edit page has its own `PopScope` and discard dialog. Body weight is a list with no Save |
| Chamber (decision 4) | `add_chamber_page.dart` (103) | The emergency card's Add | `createChamber`, one row | None. Save is a button in the body |

## Approaches

The bar and the leave check already exist for record pages. The question was
how an editor with no lock and no cards takes them on.

1. **A sitting with no cards, on the existing controller.** The editor opens
   a `RecordEditController` already unlocked over the stored record, or a
   seed for a new one. The form hands its current record to the sitting as
   one whole value; "changed" means it differs from what was stored. Bar,
   leave guard, exit blocker, route check, shortcuts and the operation gate
   come unchanged. Save runs the editor's existing writes inside
   `runRecordSitting`: one transaction, one History entry. Cost: each form
   needs a function giving its current record, and `Rule` needs value
   equality.
2. **A plain dirty flag.** The leave guard and exit blocker are widened to
   take anything that says dirty, busy and end; each editor flips a flag
   from its field listeners, as the profile pages do today. A second idea of
   a sitting in shared code; a field touched and put back still asks; partial
   saves stay partial.
3. **Field-by-field sittings, as on record pages.** Every field an
   `EditField`. These editors have no cards, so nothing visible is gained,
   for the most work by far.

**Picked: 1**, by Eric (decision 5). Planning plan 1 refined what the
sitting holds: a draft of the form as shown, not the record (see "What is
generalised"), so `Rule` needs no equality of its own.

## Decisions

Made by Eric, in the order they were made:

1. Phase 4 adopts the shared bar and the leave check, as the pattern says,
   plus two safety fixes: the transmitter editor's snackbar Apply asks the
   same confirmation as the gear page's Apply before it rewrites dives, and
   deleting a body weight entry asks first. List switches, list deletes and
   the profile avatar stay as they are. Over the bar and the check only, and
   over also holding each editor's own immediate writes until Save.
2. Every phase 4 editor shows the shared tinted bar (`RecordEditBar`): Cancel,
   title, Save, no back arrow, Save disabled until something changes. Over a
   plain untinted Cancel and Save bar, and over today's bars with only the
   leave check added.
3. An editor's Delete goes in a menu in the bar, as on record pages: it asks,
   acts at once, and is disabled with "Save or cancel your changes first"
   while there are unsaved changes. Over a button at the end of the form and
   over a trash icon in the bar.
4. The chamber form (`add_chamber_page.dart`) joins phase 4, over leaving it
   out.
5. Build approach 1: a sitting with no cards on the existing controller, with
   one-transaction saves. Over a plain dirty flag and over field-by-field
   sittings.
6. Each phase 4 plan goes live as it merges, with no build switch, over one
   switch for all of phase 4.
7. Every phase 4 editor closes when the active diver changes under it (the
   diver switcher, the misplaced logbook banner, a deleted diver's
   replacement), whether or not it had changes; a profile page returns to the
   hub, which shows the new diver. Over profile pages reloading with the new
   diver while other editors close, and over leaving the editor open on a
   fresh sitting.

## Design: what is reused unchanged

From `lib/shared/widgets/record_editing/` and the change log services:

- `RecordEditController<T>` and `EditSession<T>`, with `creating` for a new
  record.
- `RecordEditBar`, with its `actions` slot for the menu (decision 3).
- `RecordEditLeaveGuard` and `cancelSitting`.
- `RecordSittingExitBlocker` on `appExitGuardProvider`, and
  `confirmLeaveRecordSitting` as each editor route's `onExit`.
- `RecordEditShortcuts`: Cmd or Ctrl+S saves, Escape cancels. There is no
  unlock key to answer.
- The operation gate (`record_operation_gate.dart`) and `runOperation`, for
  Delete and the transmitter's Remove key.
- `runRecordSitting` (`lib/core/services/change_log/record_sitting_writer.dart`),
  for a new record as for a stored one, with sync
  told once after the commit, and `RecordSittingRefusal` for a write the
  database refuses.

## Design: what is generalised

One shared piece, built by the first plan: **an editor host with no cards**
(name the builder's). It is to an editor what `RecordEditHost` is to a record
page, and holds what every phase 4 editor shares:

- It opens the controller unlocked as the page first builds: over the stored
  record when editing, over a seed when creating (`creating: true`).
- It shows `RecordEditBar` in place of the editor's own bar, with the
  editor's title and, where the editor has whole-record operations, a menu
  in `actions`.
- It wraps the page in `RecordEditLeaveGuard`, holds a
  `RecordSittingExitBlocker` for as long as the page is shown, and registers
  the editor's shortcuts.
- **Cancel** with no changes closes the page at once. With changes it asks
  (`showDiscardDialog`) and closes. **Save** writes, then closes the page as
  the editor does today (pop, with its result where a caller waits for one),
  with today's snackbars. There is no locked state to fall back to: the
  sitting ends when the page goes.
- The sitting holds one value under one card id: a **draft** of the form,
  its fields as they read on screen (text as typed, choices as picked). The
  editor's form keeps its own text controllers and widgets; on each change
  it gives the sitting its draft. Dirty means the draft differs from the one
  the form was filled with, by value. The History entry names no card, so
  it reads "Edited" (or "Added").
- A draft compares what the diver sees, never values converted back: a
  pressure shown in psi or a volume in cubic feet and converted back to bar
  or litres can drift, and an untouched editor would read as changed. Nor
  does a draft carry anything the save stamps (`updatedAt`) or encodes
  (`Rule`'s `conditionJson` and `actionsJson`), so neither can make a
  change the diver never made. Save parses the form as it does today.
- It watches the active diver as the app resolves it
  (`validatedCurrentDiverIdProvider`, the diver a new record is written
  under), noted as the page starts. When it changes under the page, before
  or after the record has loaded, the sitting ends without a word and the
  page closes (decision 7). With unsaved changes the switcher has already
  asked, through the exit guard; the paths that switch without asking (the
  misplaced logbook banner, a deleted diver's replacement) discard as a
  switch the diver allowed. The first diver known is the editor's, not a
  switch, and a repair of the raw id that resolves to the same diver
  changes nothing. A new record is therefore always created under the
  diver it was opened for.
- Save resolves that diver first, showing the save in progress (Cancel
  disabled), then validates the form, as today, so what is checked is what
  is written. A form that fails stays open with its errors and nothing is
  written.
- A stored record deleted elsewhere while it was edited is refused at Save
  with the editor's "no longer exists" message, and nothing is written.
- An editor writes only the values whose text changed since the form was
  filled (`editorStartDraft`), on top of the record as stored at Save
  (read inside the sitting), never the copy the page loaded; the rest keep
  their stored values, including any synced in meanwhile.
- Save runs the editor's save function inside `runRecordSitting` on that
  editor's table and id, for a new record as for a stored one: one
  transaction, one change log operation, labelled with the record. The
  editors create through their repositories' own creates, so
  `createRecordSitting` is not needed. Writes that need the network or
  schedule work (findings refresh) run after the commit, best effort, as
  today.
- A new record's id is chosen when the sitting opens, as on record pages.
  Three repositories mint their own id today and gain a caller-supplied
  one: `WeightPresetRepository.createPreset`,
  `CylinderConfigRepository.createConfig` and
  `EmergencyChamberRepository.createChamber`.
- A failed Save leaves the page open with the diver's values and shows the
  error, as on record pages.

## Design: rules every phase 4 editor follows

- **Read-only views get no sitting.** A built-in pre-dive template and a rule
  saved by a newer version open as today, read only, with a plain bar and a
  back arrow and no Save. The tinted bar means something can be saved.
- **A new record** opens with `creating`. Seeds are changes, as on record
  pages: an incident from a dive or a check-in, a cylinder configuration
  from a unit, a new transmitter key prefilled with the item's serial and
  its sibling keys' setup. A downloaded transmitter key that is not yet set
  up opens with its prefilled setup as a seed too, so confirming it stays
  one tap on Save, as today. Defaults are not seeds: a new weight preset's first belt row
  and a new tank preset's default values are the starting record. So Save
  is enabled at once for a seeded record and once something is entered for
  the rest; Cancel on an untouched new record closes without asking.
- **Delete and other whole-record operations** live in the bar's menu
  (decision 3) and run through the operation gate: never on a new record,
  disabled with "Save or cancel your changes first" while there are
  unsaved changes, each with its confirmation as today, each its own
  History entry. After a delete the page closes.
- **Records created from a picker** during a sitting are created at once and
  survive Cancel, as everywhere (pattern, "Not held"): the incident's new
  check-in, the medical page's clearance documents.
- **Units** in every editor follow the active diver's unit settings, as
  today. Validation rules do not change.
- **Routes.** Each editor route gets `onExit: confirmLeaveRecordSitting`, so
  a `go` away asks as Back does.

## Design: actions each editor performs in place

For each editor, every action that writes, and what it becomes. "Held"
means written by the editor's Save, in its one transaction. Held items
marked "already" are held today; phase 4 moves them into the transaction.

### Tank presets

| Action | Today | Phase 4 |
| --- | --- | --- |
| Name, volume, pressure, material and the other fields | Held | Held |
| List: delete (resets the default to AL80 when it was the default) | Immediate, confirmed | Unchanged |
| List: default star, built-in show switch, apply-to-imports switch, default start pressure | Immediate (settings) | Unchanged |
| A dive's tank "Save as preset" | Creates a preset at once | Unchanged (creates another record) |

The editor has no Delete; it stays on the list. The list row keeps opening
the editor only from its pencil; giving the row itself a tap is not part of
this phase.

### Weight presets

| Action | Today | Phase 4 |
| --- | --- | --- |
| Name, weight rows (add, edit, remove) | Held | Held |
| List: delete (also unlinks the preset from equipment sets) | Immediate, confirmed | Unchanged |
| A dive's weights card and bulk edit "Save as preset" | Creates a preset at once | Unchanged |

### Cylinder configurations

| Action | Today | Phase 4 |
| --- | --- | --- |
| Name, unit, cylinders (add, edit, remove, reorder) | Held, saved in two or three writes | Held, in one transaction |
| List: bulk delete | Immediate, confirmed | Unchanged |
| The planner's "Save tank" | Creates a configuration at once | Unchanged |

Opened from a rebreather's gear item page, the editor is a different record
from the item (phase 3, gear items): it opens over a locked or unlocked item
alike and does not touch the item's sitting.

### Transmitter keys

| Action | Today | Phase 4 |
| --- | --- | --- |
| Serial, channel, role, cylinder, preset and the other fields | Held | Held |
| Sibling keys' setup (`saveSetup`) | Written after the key, one write each | Held, in the same transaction |
| Copying the key's serial onto a gear item that has none | Written after the key, outside any sitting | Unchanged, after the commit, best effort (phase 3, "Calls made") |
| Remove key | Button at the end of the form, confirmed, immediate | Whole-record operation in the bar's menu (decision 3) |
| The snackbar's Apply after a first setup or a takeover | Rewrites dives at once, no confirmation | Runs the gear page's Apply flow (decision 1): the dry-run counts, slot matching (#4347) and its confirmation, through the item page's operation gate when that page is unlocked |
| A takeover's fold of the placeholder gear item | Inside `saveTransmitterKey`, its own bulk History entry | After the commit, its own History entry, as today |
| The gear item page's "Apply to existing dives" | Whole-record operation on the item (phase 3) | Unchanged |

- The editor stays where it is, under the gear item's routes. It is not
  covered by the item's lock (phase 3, non-goals).
- The snackbar's Apply is the Transmitter card's Apply
  (`applyTransmitterSetupToExistingDives`), not a second copy of it. The
  snackbar shows over the item page the editor returns to; when that page
  holds unsaved changes, Apply is refused with "Save or cancel your changes
  first", as the card's is.
- A takeover saves over the unclaimed downloaded key's row, so the row
  written has that key's id, not the one the editor opened with. The sitting
  is labelled with the id actually written; the fold that may follow runs
  after the commit.

### Checklist templates

| Action | Today | Phase 4 |
| --- | --- | --- |
| Name, description, items and sections (add, edit, rename, reorder, move, delete) | Held, saved in three writes | Held, in one transaction |
| List: delete | Immediate, confirmed | Unchanged |
| A trip checklist's "Save as template" | Creates a template at once | Unchanged |

### Pre-dive templates

| Action | Today | Phase 4 |
| --- | --- | --- |
| Name, items and sections, item links (removing a source clears the items that read from it) | Held, saved in three writes | Held, in one transaction |
| Built-in template's View | Read only | Read only, no sitting |
| List: clone | Immediate, no confirmation | Unchanged (creates another record) |
| List: delete | Immediate, confirmed | Unchanged |
| List: built-in Show switch | Immediate (a setting) | Unchanged |
| Start-session sheet: equipment for a template item | Immediate | Unchanged (the session runner is outside the program) |

### Rules

| Action | Today | Phase 4 |
| --- | --- | --- |
| Name, subject (new rules only), condition, actions (add, edit, remove) | Held, one row | Held |
| Read-only rule (newer version, unknown action) | Read only | Read only, no sitting |
| List: reorder, enabled switch | Immediate | Unchanged |
| List: run on all, duplicate, delete; history page undo, delete run, clear | Immediate, with today's confirmations | Unchanged |

The rule's draft holds its condition and actions as the editor shows them,
compared by value (`QueryNode` and `RuleAction` already define `==`), so a
changed rule can be told from a stored one without comparing re-encoded JSON.

### Incidents

| Action | Today | Phase 4 |
| --- | --- | --- |
| Every field, the dive and check-in links | Held, one row | Held |
| Save | Button at the bottom of the form | In the bar; the bottom button goes |
| Delete | Trash icon in the bar, confirmed, immediate | Whole-record operation in the bar's menu (decision 3) |
| "Add check-in" from the check-in picker | Creates an equipment check-in at once | Unchanged; it survives Cancel |
| Findings refresh after saving | Scheduled after the write | After the commit |

An incident whose record will not load keeps today's error page, with no
sitting.

### Diver profile

| Action | Today | Phase 4 |
| --- | --- | --- |
| Personal, medical, emergency contacts, notes, prior experience | Held; each page writes the whole diver row onto the diver active at Save | Held; each page is a sitting on the diver it opened with |
| New diver (the personal page in new mode) | `addDiver`, then becomes active if the app may leave | A new-record sitting; once it has ended, the new diver becomes active if the app may leave, so the page's own sitting is not asked about |
| Hub: avatar | Immediate | Unchanged (decision 1) |
| Hub: delete diver | Immediate, confirmed | Unchanged |
| Body weight: add an entry | Dialog, then immediate | Unchanged |
| Body weight: delete an entry | Immediate, no confirmation | Asks first (decision 1) |
| Medical: add or open a clearance document | Pushes the document's page | Unchanged; the sitting stays underneath |

- **The switch-diver bug closes, on every path.** Each page's sitting is
  pinned to the id of the diver it opened with, so its Save can only write
  that diver. The diver switcher already asks the app's exit guard before it
  switches, so a switch with unsaved changes asks; any switch then closes the
  page back to the hub (decision 7). The switches that do not ask (the
  misplaced logbook banner, a deleted diver's replacement) close it too.
- **Each page writes only what it owns.** Save applies the page's fields to
  the diver row as stored at that moment, never a copy taken when the page
  opened, so two profile pages, a sync, or the hub's avatar change never
  overwrite each other's values.
- The hub is a page of links with summaries, not an editor, and gains
  nothing. The body weight page is a list with no Save, and gains only the
  delete confirmation.

### Chamber

| Action | Today | Phase 4 |
| --- | --- | --- |
| Name, country, phone, city, position, notes | Held, one row | Held, as a new-record sitting |
| Save | Button in the body | In the bar; the body button goes |

The chamber form is create only. Editing and deleting a chamber stay on its
tile in the emergency card, as today.

## Design: the plans

Plans live in `docs/design/plans/` and are written one at a time, each
against the names the previous one shipped. Each goes live as it merges
(decision 6). A likely order, sized like phase 3's:

1. **The shared editor host, tank presets and weight presets.** The host,
   its tests on a small fake record, and the two simplest editors (one row,
   or one row and its entries already in a transaction).
2. **Cylinder configurations and transmitter keys.** Two saves become one
   transaction; `createConfig` takes the sitting's id; Remove key moves to
   the menu; the snackbar Apply becomes the card's Apply flow; seeded and
   downloaded keys; the takeover's fold after the commit.
3. **Checklist templates and pre-dive templates.** Three-write saves become
   one transaction; the pre-dive built-in stays read only.
4. **Rules and incidents.** The rule's draft; the incident's Save moves to the
   bar and its Delete to the menu; seeded new incidents.
5. **The diver profile and the chamber form.** Five edit pages, the new-diver
   page, the switch-diver fix with its test, the body weight delete
   confirmation, the chamber form (`createChamber` takes the sitting's id).

With plan 5, every editor named by the pattern is on the shared pieces.

## Calls made in this note

Eric has not explicitly confirmed these. Correct any of them:

- Read-only views (a built-in pre-dive template, a rule from a newer
  version) get no sitting and keep a plain bar with a back arrow.
- Save closes the editor, as today; there is no locked state to return to.
- Cancel on an untouched editor closes at once, without asking.
- Seeds (an incident from a dive or a check-in, a configuration from a unit,
  a transmitter key's prefill, a downloaded key not yet set up) count as
  changes; a new weight preset's first belt row and a new tank preset's
  defaults do not.
- The transmitter key's serial copy onto its gear item stays outside the
  transaction, after the commit, as phase 3 left it; so does a takeover's
  fold of the placeholder item.
- The snackbar's Apply is the Transmitter card's whole Apply flow (counts,
  slot matching, confirmation, the item page's gate), which is how this
  note reads decision 1's "the same confirmation".
- The tank preset list's row keeps opening the editor only from its pencil.
- The sitting holds a draft of the form as shown, not the record, so a value
  converted for display never reads as a change (made while planning plan 1).
- The hub and the body weight list are not editors and gain no bar.
- Equipment locations stay a settings list (as phase 3 said), and so do
  currency rules, saved queries and import presets.
- The last phase 4 pull request closes #4527 if nothing else in the program
  is open by then; otherwise it refers to it.

## Left to the builder

- Names and file layout of the editor host, and the card id the sitting
  uses.
- How each form hands its draft to the sitting (a listener on its
  controllers, or a rebuild hook), as long as dirty means "differs from
  what the form was filled with".
- The wording of the bar titles and of any new strings. Every new string goes
  into all locales.
- The confirmation text reused for the transmitter's snackbar Apply, taken
  from the gear page's.
- If a write listed as held cannot run inside the transaction (a repository
  that opens work it cannot nest), stop and raise it. Do not split the Save
  silently.

## Testing

- The editor host is tested alone with a small fake record: opens unlocked,
  Save disabled until a change, a change put back is not a change, Cancel
  closes at once when clean and asks when dirty, Back asks, a tab switch and
  a quit ask through the exit guard, the menu's operations are disabled
  while dirty, Cmd or Ctrl+S and Escape work.
- Each editor: Back with unsaved changes asks and keeps them on "keep
  editing"; Save writes one change log operation; a Save that fails partway
  writes nothing (for the four editors that save in several writes today,
  with a repository that throws on its second write).
- Each editor: a value changed in storage during the sitting, in a field the
  diver did not touch, survives Save where the editor writes field by field
  (the diver pages).
- The switch-diver case: unsaved medical changes, switch diver, the switcher
  asks; discarding leaves both divers unchanged and closes the page; a
  switch from the misplaced logbook banner closes it too; no path writes
  one diver's fields onto the other.
- An editor of any kind closes when the active diver changes under it, and
  a new record is never created under a diver other than the one it opened
  for.
- An untouched form is not dirty: no timestamp or JSON re-encode makes it
  look changed.
- The transmitter's snackbar Apply asks before it rewrites; the body weight
  delete asks before it deletes.
- Read-only views show no tinted bar and no Save.
- Each editor's existing test file keeps its cases, retargeted to the bar.

## Delivery

Five pull requests, each referring to #4527, each live as it merges
(decision 6). No table or column is added and the change log policy does not
change: every table is already tracked. Every pull request changes what a
diver sees, so each carries before and after screenshots of its editors,
light and dark, phone and desktop, as the contributing guide requires.
