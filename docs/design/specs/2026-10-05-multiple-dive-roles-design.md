# Multiple roles per person on a dive (issue #1221)

## Problem

A dive records one role for the diver (`dives.diver_role`, the "Me" chip) and
one role per buddy (`dive_buddies.role`). Real dives often carry two: a
divemaster who is also the guide, an instructor who is also the safety diver.
Dive types already allow several per dive; roles should too.

## Decisions (approved 2026-10-05)

| Question | Decision |
| --- | --- |
| Whose roles become multi-select | The diver's own AND every buddy's |
| Storage | Junction tables, modelled on `dive_dive_types` |
| Solo | Exclusive: Solo cannot sit beside any other role |
| Bulk edit | Replace semantics: the picked set becomes the set on every selected dive; "Mixed" when they differ |

## 1. Data model and sync

### New tables (schema v272)

Main shipped v261 through v267 and v269 through v271 while this was open
(#2985, #2991, #3004, #3005, #3009, #3001, #3011, #3007, #2999, #3020), and
an open branch holds 268 (#3043), so the rung is v272.

Both live in `lib/core/database/tables/buddy_tables.dart` and are created by a
new rung in `lib/core/database/migrations/ladder/rungs_v231_onward.dart`, with
the matching `before_open.dart` backstop.

- `dive_diver_roles`: `id` (uuid PK), `dive_id` (FK dives, cascade),
  `role_id` (text, no FK), `created_at`, `hlc`.
  Unique index `(dive_id, role_id)`.
- `dive_buddy_roles`: `id` (uuid PK), `dive_id` (FK dives, cascade),
  `buddy_id` (FK buddies, cascade), `role_id` (text, no FK), `created_at`,
  `hlc`. Unique index `(dive_id, buddy_id, role_id)`.

Surrogate uuid primary keys, never composite (the #347 sync data-loss rule).
`role_id` has no foreign key for the same reason as
`dive_dive_types.dive_type_id`: a custom role can arrive by sync before its
`dive_roles` row.

`dive_buddy_roles` is keyed on the (dive, buddy) pair, NOT on
`dive_buddies.id`. Older builds save a dive's buddies by deleting every
`dive_buddies` row and re-inserting with fresh ids; a junction hanging off the
row id would lose its roles on every such save. Keyed on the pair, it is
untouched.

### Primary-role mirror

`dives.diver_role` and `dive_buddies.role` stay. Every write sets them to the
FIRST role of the set in canonical order, or null / `'buddy'` for an empty
set. Canonical order needs no database, so every device agrees on the
primary role: built-in ids in seed order (`DiveRole.builtInIds`), then any
other id ascending, with the generic Buddy role last of all, so a set that
names anything more specific keeps that as the primary older versions show. Older app versions keep showing and
editing a sensible single role.

### Read rule (self-healing)

One pure function resolves a person's roles on a dive from
`(scalar, junctionRoleIds)`:

1. Scalar null: `[]` for the diver (an older peer cleared the role; any
   junction rows are stale); `['buddy']` for a buddy (a buddy link always
   carries a role).
2. Junction empty, scalar set: `[scalar]` (legacy data, rows written by an
   older peer).
3. The junction's own primary role equals the scalar: the junction set.
4. Otherwise (the scalar is missing from the junction, or is a member but
   not its primary): an older peer changed the role after the junction was
   written, so the junction is stale and the result is `[scalar]`. The stale
   rows are replaced on the next save.

Every write keeps the scalar equal to the junction's primary, so rule 3 is
the normal case. Requiring the primary (not mere membership) means an older
peer that narrows Divemaster + Dive Guide down to Dive Guide alone is
honoured even though Dive Guide was already a member.

Result order is canonical order. No data backfill: existing dives resolve
through rule 1, which avoids minting per-device random ids the fleet would
union (the #1360 trap).

### Writes

Saving a person's role set normalizes it (dedupe, Solo exclusivity: if Solo
sits beside other roles, Solo is dropped), writes the scalar mirror, deletes
junction rows not in the set (with deletion-log tombstones) and inserts the
missing ones (marked pending). Unchanged rows are left alone so their ids and
clocks are stable.

### Sync

- Two new parent-gated child entities, `diveDiverRoles` and `diveBuddyRoles`,
  registered everywhere `diveDiveTypes` is: serializer payload fields,
  export (rows of dives whose HLC changed plus pending children), apply with
  `DoNothing` on the unique index (single and batch), table map,
  `sync_repository` pk map, deletion handling, `hasUpdatedAt: false`, and
  parent dependencies (`diveId -> dives`; `buddyId -> buddies` for buddy
  roles).
- The sync compatibility floor is NOT raised. Older peers ignore both tables;
  the read rule covers what they write.
- Backup census / table coverage tests and any per-table registries that
  enumerate synced tables include both tables.

## 2. UI

### Role picker

`showDiveRoleSelector` (`dive_role_selector_sheet.dart`) gains a multi-select
mode returning a `Set`/ordered list of role ids:

- Each row has a checkbox; a Done button returns the set; dismissing returns
  null (no change).
- Credential-backed roles stay first; "Add custom role..." creates and ticks.
- Ticking Solo unticks the rest; ticking anything else unticks Solo.
- Me: an empty set means no role (the "No role" row becomes a Clear action).
- Buddy: an empty set falls back to Buddy.

### Chips and detail

- The Me chip and each buddy chip in `buddy_picker.dart` show the roles joined
  in role-list order ("Divemaster, Dive Guide"), ellipsized, full text in a
  tooltip.
- Dive detail: the "Me" tile and each buddy tile use the joined label. The
  buddy count still counts people.

### Bulk edit

- The gated "My role" field opens the multi-select picker; its value is the
  joined label, or "Mixed" when the selected dives' sets differ.
- Each buddy row's role control does the same for that buddy across the
  selected dives, with replace semantics. A long label moves to the row's
  detail line; the trailing control stays short.
- Undo restores the prior junction rows.

### Other surfaces

- Detailed PDF: one line per person with joined roles; it also prints the
  diver's own roles.
- Buddy list "usual role" chip and connections "usual role" subtitle: counted
  per role across the buddy's dives; the connections subtitle stays only when
  one role is held on every dive.
- Signature cards: the joined label.

## 3. Import/export, merge, stats

### UDDF

- `<diverrole>` is written once per role in `informationbeforedive`. Older
  readers take the first element and get the primary role.
- `<buddyroles>` writes one `<buddy ref role>` per non-Buddy role.
- `<divemaster>` lists anyone with ANY leader role; the inline `<buddy>` list
  holds everyone else except Solo.
- Import collects every role per person (full and dives-only paths, and the
  universal payload slice).

### Shared importer rule

The shared buddy-linking step accumulates a person's roles across buddy,
guide and exact-role sources. Generic Buddy is kept only when the person has
no other role. This reaches UDDF, Subsurface, MacDive, Diving Log, CSV and the
other mappers that feed the same keys.

### CSV / Excel / PADI PDF

Anyone with any guide role goes in the Guide column, everyone else in Buddy;
nobody is listed twice.

### Merge, consolidation, mirror, split, uncombine

- Dive merge and consolidation union the roles per person (diver and each
  buddy), then Solo-normalize. Snapshots and undo carry the new rows.
- Buddy merge unions the two buddies' roles on a shared dive, replacing the
  rank-and-discard `_roleRank`.
- Mirror maps every role: the target's own roles come from their linked
  buddy's roles on the source; the source owner's roles become their buddy
  roles.
- Split copies the diver's roles with the dive; uncombine clears them on the
  restored dives (today's behaviour for the scalar).
- Legacy buddy-text conversion uses the accumulate rule.
- Planned-dive fill keeps the diver's role set as a human field.

### Stats and SQL

- Insights solo detection keeps reading `dives.diver_role`: Solo is exclusive
  and always primary when present, so the scalar stays exact, including rows
  an older peer edited.
- `isDiveRoleInUse` also checks both junction tables.
- "Usual role" queries count resolved roles per dive.
- The query language gains no role field (out of scope).

## Testing

TDD throughout:

- Read rule: rules 1 to 4.
- Repository round trips for diver and buddy role sets, including Solo
  normalization and minimal-diff writes.
- Migration rung and backstop; unique indexes.
- Sync: export, apply, duplicate arrival, parent dependencies, tombstones.
- UDDF round trip with several roles; an old-format reader sees the primary.
- Picker widget tests: multi-select, Solo exclusivity, empty-set behaviour.
- Bulk edit replace with "Mixed"; dive merge, consolidation and buddy-merge
  unions; mirror mapping; importer accumulate rule.

## Out of scope

- A role field in the query language.
- Raising the sync compatibility floor.
