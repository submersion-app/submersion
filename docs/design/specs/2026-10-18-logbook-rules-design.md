# Logbook rules: optional, user-defined automation for dives and sites

Status: design, awaiting approval. Target release: v1.8.3. One PR.

Origin: discussion #2316 ("Dive types vs. dive facts"). The community settled
that the app must not classify dives on its own (#1438/#1439 auto-set
Technical from deco in the profile; #2226 removed that), because every diver
draws the lines differently ("deep" is 18 m for one diver and 80 m for
another). Schtibal proposed diver-defined rules instead ("CRITERIA: depth >=
40 m, ACTION: add dive type Deep"), and the maintainer agreed: no automatic
classification by default, plus an optional rules system that reuses the
query language.

## Intent

A diver writes their own rules, each "if this condition, then do these
things", and the app applies them to new dives and sites, or to existing
ones when the diver asks. Dive types were the starting point, but a rule can
change almost any attribute: set a field, add or remove types, tags, gear,
buddies or courses, append to notes.

Examples the maintainer gave, all expressible in today's query language:

| If | Then |
| --- | --- |
| `entryMethod = boat OR exitMethod = boat` | add dive type Boat |
| `depth > 60ft` | add dive type Deep |
| `trip.tripType = liveaboard` | add dive type Liveaboard |
| `gear.name = "Drysuit"` | add equipment Undergarment, Hood, Gloves |
| (site) `country = "Egypt" AND waterType:none` | set water type Salt, add site tag Red Sea |

## Goals

- Optional: a fresh install has no rules and behaves exactly as today.
- The condition is a query in the existing query language (#2365), edited
  with the existing `QueryEditor` (typed syntax and rule builder).
- Actions cover every scalar field bulk edit can set, plus the collection
  memberships, for dives; and the simple fields, tags and types for sites.
- Transparency: every change a rule makes is visible in detail (before and
  after per field), previewed before a manual run, and undoable later from a
  lasting history.
- Rules and their run history sync between the diver's devices.

## Non-goals (this release)

- Actions that add tanks, weights or sightings (multi-value records with
  their own editors). The action format must leave room for them.
- Rules for other entities (trips, equipment, buddies). The rule format
  names its subject so they can be added without a redesign.
- Clearing a field as an action (a "set" action always carries a value).
- Re-running rules when a dive or site is edited later.
- Exporting, importing or sharing rules between divers.
- A "set only if empty" option on actions: the condition expresses that
  (`waterType:none AND ...`). Decided by the maintainer.

## Anti-goals (a failure even if it works)

- Any change the diver did not ask for: no built-in or default rules, and
  nothing runs on data arriving through sync, backup restore or undo.
- A silent change. Every automatic change appears in the import results or a
  snackbar, and in the history.
- A rule editing a shared club library site (it would edit the club's copy
  for everyone, and library rows never enter personal sync, so their prior
  values must not land in the synced history).
- Undo that destroys a later manual edit.

## The rule

A rule belongs to one diver (`diver_id`, the active diver when created) and
has:

- **Name.**
- **Enabled** switch. Off means it never runs automatically; it can still be
  run by hand from its row menu.
- **Subject:** dives or sites. Fixed once created (the condition and actions
  are subject-specific).
- **Triggers** (when it runs automatically), multi-select:
  - Dives: *after an import*, *after logging a dive by hand*.
  - Sites: *after an import*, *after creating a site by hand*.
  - A new rule starts with *after an import* ticked.
  - Running on demand is always possible and is not a trigger.
- **Condition:** a query AST for the subject, serialized with the existing
  versioned query JSON (`queryNodeToJson`, `kQueryJsonVersion`). An empty
  condition matches everything (the editor warns "matches every dive").
- **Actions:** an ordered list, at least one, serialized as versioned JSON
  (`version: 1`, one object per action with a `kind` and its parameters).
- **Position** in the subject's list (`sort_order`). Rules run top to bottom.

### Action catalogue

Values are stored canonical (metric, enum `.name`, entity ids) and shown in
the active diver's units, like everything else in the app.

**Dive actions**

| Kind | Parameters | Effect |
| --- | --- | --- |
| Set field | field (one `BulkField` scalar), value | Write the column(s), with the same side effects as bulk edit's `buildScalarCompanion` (visibility clears the legacy bucket, diluent sets O2 and He). Covers every `BulkField` scalar, including those bulk edit has no row for yet (surface interval, GF low/high, deco algorithm, conservatism, computer model, diluent). Dive center and trip are set by picking one. |
| Add / remove dive types | type ids | Membership change. |
| Add / remove tags | tag ids | Membership change. |
| Add / remove equipment | equipment ids | Membership change, through the same gear provenance bulk edit uses. |
| Add / remove buddies | buddies (with role on add) | Membership change. |
| Add / remove courses | course ids | Membership change. |
| Append to notes | text | Appended on a new line, as bulk edit's append. |

**Site actions**

| Kind | Parameters | Effect |
| --- | --- | --- |
| Set field | one of: water type, difficulty, country, region, city, island, body of water, min depth, max depth, altitude, entry method, exit method, hazards, access notes, mooring number, parking info | Partial column write. |
| Add / remove site tags | tag ids | Membership change (a `removeTags` does not exist yet and is added). |
| Add / remove site types | site type ids | Membership change. (Builder's call to include, see the list at the end.) |
| Append to description | text | Appended on a new line. |

An action whose target no longer exists (deleted tag, gear, type, buddy,
course, trip, center) is shown as broken in the editor and on the rule's
row, and is skipped when the rule runs; the run's results say so. A rule
whose condition no longer loads (the saved-query problems: unreadable,
invalid, unresolved reference) is shown with the problem and skipped whole.
A rule saved by a newer app version with an action kind this version does
not know is shown read-only ("made by a newer version") and never runs.

## When rules run

### After an import

One pass after the import has written everything, in
`ImportWizardNotifier.performImport()` beside `_applyImportTags`. Every live
source passes through there (dive computer, Garmin, Suunto cloud and file,
HealthKit, and every universal file format including divelogs.de). Sync,
backup restore, undo, merge and buddy mirroring do not, which is the point.

- Targets: the dives the import created (the adapter's `importedDiveIds`
  after consolidation; for multi-diver imports each `diverOutcomes` entry),
  and the sites it created (universal imports only; the created ids are not
  returned today and must be threaded out of `UddfEntityImporter` into
  `UnifiedImportResult`).
- A planned dive that a download filled counts as imported (it received the
  import's data). Builder's call, listed at the end.
- Each diver's enabled rules with the *after an import* trigger apply to that
  diver's dives.
- Dive rules run first, then site rules.
- A failure in the rules pass never fails the import; it is reported on the
  summary (as `_applyImportTags` treats failures).
- Skipped when the import was cancelled.

### After creating by hand

- **Dive:** on the first save of a new dive in `DiveEditPage._saveDive`
  (the `!isEditing` branch), after buddies, sightings and the other child
  saves, so the rule sees the complete dive. Logging a planner plan as a
  dive and converting a planned dive count as logging by hand. OCR prefill
  is still a hand-logged dive.
- **Site:** on the first save of a new site in `SiteEditPage._saveSite`
  (create branch, after expected species), and for sites added from the
  external site search, the built-in site map, and the import summary's
  "Match sites" flow (all hand-confirmed creations).
- A snackbar reports the result ("Rules changed this dive: Deep, Boat") with
  a Details action opening the change list. Undo lives in the history.
- Later edits never trigger rules.

### On demand

- **Rules page:** "Run all..." runs every enabled rule of the subject over
  all of the diver's dives (or sites). Each row's menu has "Run on all
  dives/sites", which runs that one rule, enabled or not.
- **Selection:** "Apply rules" is a bulk action in the dive list and the
  site list selection bars; it runs the enabled rules of that subject over
  the selected items.
- Every on-demand run shows the **preview** first and changes nothing until
  the diver presses Apply.

### Evaluation semantics (all triggers)

- For a target set T, rules run in list order. For each rule: the matching
  ids are the condition's query restricted to T (`QueryIdSetRunner.ids` with
  an `r0.id IN (...)` scope, diver-scoped), evaluated against the database
  *as the previous rules left it*. So a rule that adds a drysuit makes a
  later "if drysuit" rule match. One pass, no loops, no re-evaluation of
  earlier rules.
- Within a rule, actions apply in their listed order.
- "Set" means set: it overwrites what the import or the diver wrote. To fill
  only empty fields, the condition says so.
- An action that changes nothing (the type is already there, the field
  already has the value) records nothing; a dive or site no action changed
  is "unchanged".
- **Whose data a rule may change:** only what the diver could change by
  hand on the edit page. Dives: the diver's own (`diver_id` = the rule's
  diver). Sites: those the active diver owns; another profile's shared site
  (which that profile may only hide) and library sites (`shared_library_id`
  not null) are never targets. This filter applies to every trigger,
  including the sites an import created, to the editor's live match count,
  and to a selection (selected items outside it are left out and the preview
  says how many).
- **Planned dives** that have not been dived (`is_planned`) are never
  targets: rules describe logged dives. A plan becomes a target when it is
  logged or filled (see "After creating by hand" and "After an import").
- The preview must be computed with the same code that applies, so the
  preview and the result cannot disagree (a suggested approach: run the
  whole pass in a transaction, collect the changes, and roll back for a
  preview).
- All writes of one run happen in one transaction, bump `updatedAt`, mark
  records pending for sync, and notify once.

## The change list

One component, used in three places (approved as mocked up):

1. **Preview** before an on-demand run: "Apply 3 rules to 42 selected
   dives? 12 dives will change." Group by dive (default) or by rule. Per
   dive: one line per change, "Rule: field  before → after"; for
   memberships, the added and removed items ("Gloves already on the dive"
   when an add was a no-op is a nice touch, not required). Cancel / Apply to
   N dives.
2. **Import results:** a box on the import summary, "Rules changed 9 of
   these dives", per-rule counts, "See changes" (the change list) and "Undo
   rule changes" (keeps the imported dives).
3. **History** entry detail.

Dives are identified as on the dive list (number, site, date); sites by name
and location.

## History

Settings > Manage > Rules > History. One entry per run **that changed
something**, newest first: when, what started it (import with its source
name, logged by hand, run by hand on all dives, run on a selection), how
many items changed and by which rules, and the device it ran on. Opening an
entry shows its change list. Entries are kept until the diver deletes them
(per entry, or "clear history"). History belongs to the diver and syncs.

### Undo

Available from the import results, the history entry, and (for the hand-run
case) the snackbar after Apply. Undo restores only what is still as the run
left it and reports what it skipped:

- **Field:** if the current value equals the run's "after", restore the
  "before"; otherwise skip.
- **Membership:** for each item the run added, remove it if it is still
  there; for each item it removed, add it back if it is still absent.
  Items the diver added or removed by hand since are untouched. (This is
  finer than "leave the whole collection alone", see the list at the end.)
- **Append:** remove the appended text if the notes or description still
  end with it; otherwise skip.
- A dive or site deleted since is skipped.
- If every change would be skipped because the current values are not yet
  the run's "after" values on this device (history can arrive through sync
  before the dive edits it describes), undo changes nothing, does NOT mark
  the entry undone, and says "Nothing to undo on this device yet; try again
  after syncing."
- Otherwise the entry is marked undone (date) and cannot be undone twice. The result
  says "Undone. 2 dives were edited after this run; those changes were left
  alone."
- Undo is a normal local write (bump `updatedAt`, mark pending), so it wins
  last-writer-wins like bulk edit's undo.

## Pages

- **Settings > Manage > Rules** (after Saved queries). Two sections, Dive
  rules and Site rules, each a reorderable list (drag handle). Row: name,
  condition printed with `QueryPrinter`, a one-line action summary, the
  triggers, an on/off switch, and a menu (Run on all, Duplicate, Delete).
  Problems (broken action, unloadable condition, newer version) show on the
  row. Top actions: History, Run all..., New rule.
- **Rule editor:** name; Dives or Sites (new rules only); triggers as
  checkboxes with the note "you can always run it yourself"; condition in
  `QueryEditor` with a live "matches N of your dives" count; "Then" as a
  list of action cards with "+ Add action" opening a searchable picker of
  the catalogue. Each card edits its parameters: a value input chosen by the
  field's type (enum dropdown, number in the diver's units, text, toggle,
  rating, entity picker), or a membership picker reusing the existing
  pickers. Bulk edit has no reusable per-field widget factory today (its
  rows are inline in `DiveEditPage`), so the editor builds its own small
  set from the shared form widgets.
- **History** list and entry detail, as above.
- **Selection bars:** "Apply rules" in the dive list and site list.
- **Import summary:** the rules box.

Mockups shown during the design conversation: the rules list, the editor's
top half, option A for actions (chosen over embedding the bulk edit form),
and the change list in its three places.

## Data and sync

Three new tables (one schema rung; next free number at merge time: written as
292, shipped as 301 after main took 292 and 294 to 300), each in its own library under
`lib/core/database/tables/`, migrations in a helper part file, a backstop,
and indexes, following `saved_queries`:

- `rules`: id, diver_id, subject, name, enabled, triggers, condition_json,
  actions_json, sort_order, created_at, updated_at, hlc.
- `rule_runs`: id, diver_id, trigger, source_label, device_label, ran_at,
  changed_count, undone_at, created_at, updated_at, hlc. A run has no single
  subject: an import that changes dives and sites is ONE run (one history
  entry, one undo that reverts both), matching the single rules box on the
  import summary.
- `rule_run_changes`: id, run_id, subject, target_id, rule_id (nullable, the
  rule may be deleted), rule_name (snapshot), field, before_json,
  after_json, sort_order, plus sync columns. One row per field change.

A multi-diver import produces one run per diver (history belongs to a
diver). The import summary's "Undo rule changes" undoes every run that
import produced; each diver's history shows only their own run.

All three sync, are diver-owned (cleared on diver delete), and satisfy the
sync guard tests listed in the saved-queries precedent (hlc targets, base
tables order, record ids, batch upsert coverage, parent refs, tick
streams). The builder decides the exact column types and whether the
change rows are a clockless child of the run (see the child-sync design
#1769).

## Constraints

- One PR, release v1.8.3.
- New tables never go in `database.dart`; files stay under 800 lines.
- Every string localised (ARB); units follow the active diver.
- TDD; tests restore global state; paths platform-agnostic.
- Screenshots for every new or changed screen in the PR.

## Decided by the maintainer during design

- Optional, no default rules; the query language is the condition.
- Actions go wider than dive types: any attribute, dives and sites.
- Triggers per rule; after an import means after the import has written
  everything; hand-logged dives are a trigger option; never on later edits.
- On demand over all items or a selection.
- "Set" overwrites; the condition handles "only if empty".
- Actions are added one at a time from a picker (option A).
- Detailed change list, a preview before manual runs, undo.
- A lasting history; undo skips what was edited since.
- One PR.

## Calls made by the designer (check these)

1. Rules run top to bottom, each seeing earlier rules' changes; one pass.
2. Sync, restore, undo, merge and mirror never trigger rules.
3. Rules and history belong to the active diver and sync between devices;
   history is kept until deleted.
4. A new rule starts with *after an import* ticked; run-on-demand is always
   available; a disabled rule can still be run by hand from its menu.
5. Tanks, weights and sightings actions are left for later; no "clear field"
   action.
6. Library sites are never touched by rules.
7. Broken actions and unloadable conditions are skipped and reported, not
   fatal.
8. Undo on memberships works per item (removes what the run added if still
   there, re-adds what it removed if still absent) rather than skipping the
   whole collection when the diver touched it.
9. A planned dive filled by a download counts as imported; logging a plan
   counts as logging by hand; Match sites, site search and map adds count as
   creating a site by hand.
10. Site types are in the site action catalogue alongside site tags.
11. History records only runs that changed something.
12. The hand-logged dive snackbar shows Details; its undo is in the history.
13. A rule may change only what the diver could change by hand: their own
    dives, and sites they own (never another profile's shared site).
14. Unlogged planned dives are never targets.
15. One import is one history entry covering its dive and site changes; a
    multi-diver import makes one entry per diver, and the summary's undo
    reverts them all.
16. Undo that finds nothing undoable yet (edits not synced to this device)
    leaves the entry undoable and says so.

## Left to the builder

Table column types and indexes; whether the change rows sync as a clockless
child; the action JSON shape; how the preview dry-runs; the exact route
names; how the device label is obtained; how the change list paginates for
large runs; localisation of the other locales per the repo's l10n practice.
