# Bulk membership editing (tri-state) + gear bug fixes

Date: 2026-07-06
Status: Approved design, pending implementation plan
Branch: worktree-gear-multi-dive-edit

## Origin

A user report (r/submersion) raised two problems on the "gear" surface:

1. **Bulk gear edit wipes data.** Selecting multiple dives and adding one gear
   item wiped all existing gear on every selected dive, replacing it with the
   single added item; removing/replacing gear in bulk "didn't function."
2. **"Save as Set" doesn't save.** Editing gear on a single dive and choosing
   "Save as Set" appeared to do nothing.

## Investigation summary (root causes)

### Bug 1 — bulk gear wipe: already fixed in shipped code

The full current chain is correct on `main`:

- Bulk mode renders `_buildBulkCollectionsSection` with Add/Remove/Replace mode
  chips per collection (`dive_edit_page.dart`).
- `_collectCollectionOps` builds `EquipmentOp(mode, ids)` from the chosen mode.
- `BulkDiveEditService._applyOp` dispatches add/remove/replace to
  `bulkAddEquipment` / `bulkRemoveEquipment` / `bulkReplaceEquipment`.
- `bulkAddEquipment` uses `insertOnConflictUpdate` (a true merge; never deletes
  existing rows).

The "add wipes everything" symptom is the pre-fix behavior, resolved by commit
`30da9f93835` (2026-06-23, "bulk form collections … with Add/Remove/Replace"),
released in **v1.5.9.113**. The reporter was on an older build. Existing bulk
tests pass (+16).

Residual issue: the Add/Remove/Replace chip model is confusing and unsafe — the
editor is hidden until a mode is chosen, never shows the dives' current gear,
makes "remove" mean "add the item to a list to remove it," and lets "Replace"
silently wipe. That UX is what this design replaces.

### Bug 2 — "Save as Set" orphaned by null diverId: real, current bug

`_saveEquipmentAsSet` (`dive_edit_page.dart`) builds an `EquipmentSet` with **no
`diverId`** and calls `EquipmentSetRepository.createSet()` **directly**,
bypassing `EquipmentSetListNotifier.addSet()` — the only code that stamps the
active diver's id. The row is inserted (a success snackbar even shows) with
`diverId = NULL`. Every read path filters `WHERE diverId = <current diver>`
(`equipment_set_repository_impl.dart`), and SQL `NULL = '<id>'` is never true, so
the set is orphaned and invisible in both the sets list and the picker. The
standalone "New Set" page (`equipment_set_edit_page.dart`) does it correctly:
resolves `diverId` and routes through `notifier.addSet`.

## Goals

- Make bulk editing of id-based "reference" collections (Tags, Dive Types,
  Buddies, Equipment) clear, safe, and grounded in the dives' current state.
- Never silently destroy membership; heterogeneous selections default to
  "no change."
- Fix Bug 2 so sets saved from dive-edit are visible to the current diver.
- Add a regression test locking in Bug 1's correct "add merges" behavior.

## Non-goals

- No change to owned collections (Tanks, Weights, Sightings) — they keep their
  current editors (rich per-item cards; add/replace only).
- No change to `BulkDiveEditService`, the sealed op types, the `bulkAdd*` /
  `bulkRemove*` / `bulkReplace*` repo writes, or the undo snapshot mechanism.
- No redesign of single-dive gear editing (only the Bug 2 save path changes).
- No per-dive role editing for buddies inside the bulk list.

## Design

### Interaction model

In bulk mode, each reference collection renders a **membership list**: every item
present on any selected dive, each with a tri-state checkbox, plus an "＋ Add…"
affordance that opens that collection's existing picker to bring in items not yet
on any dive.

```
Equipment · on these 3 dives
──────────────────────────────────────
  [x]  Regulator            on all 3
  [-]  Wetsuit 5mm          on 2 of 3
  [x]  Dive computer        on all 3
  [x]  Camera               just added -> all 3
                                + Add gear    Use set
```

Checkbox semantics at save:

| State | Meaning |
| ----- | ------- |
| checked | Ensure on **all** selected dives (add to those missing it) |
| empty | Ensure on **none** (remove from all that have it) |
| dash (indeterminate) | **Leave as-is** — no change |

Tap-cycling:

- Item initially on all: toggles checked <-> empty.
- Item initially on some: cycles dash -> checked -> empty -> dash (add-to-all,
  remove-from-all, or leave the mix untouched).
- Freshly added item: starts checked.

The dash state is the safety net: for a heterogeneous selection the default is
"don't touch," so nothing is silently wiped. The Add/Remove/Replace chips and the
destructive Replace are removed for these four collections.

### Architecture

All new logic is in the presentation layer plus one read query per collection.
The service and repo writes are unchanged; a tri-state toggle decomposes into an
existing AddOp (checked items) and RemoveOp (unchecked items).

- **`BulkMembershipEditor` (new, reusable widget).** One responsibility: given the
  current items with per-item dive counts and the total dive count, render
  tri-state rows and report the resulting `(addIds, removeIds)`. Generic over the
  item type via a small view-model (id, label, icon). Owns its own toggle state;
  reports changes up via a callback. Testable in isolation. Replaces the four
  `_collectionEntry` mode-chip blocks in the bulk form.
- **Op generation.** `_collectCollectionOps` reads each editor's `(addIds,
  removeIds)` and emits `…Op(mode: add, ids: addIds)` and
  `…Op(mode: remove, ids: removeIds)`, each only when non-empty. Empty deltas emit
  no ops, so opening and closing the editor writes nothing. The service already
  applies multiple ops per collection type and the undo snapshot already captures
  add/remove, so undo keeps working unchanged.

### Data layer — count queries

Each collection needs "how many of the selected dives have each item":
`SELECT itemId, COUNT(DISTINCT diveId) FROM <junction> WHERE diveId IN (…)
GROUP BY itemId`, returning `Map<String, int>`. Combined with
`diveIds.length` this classifies each item as all / some / none.

- `DiveRepository.equipmentCountsForDives(diveIds)`
- `DiveRepository.tagCountsForDives(diveIds)`
- `DiveRepository.diveTypeCountsForDives(diveIds)`
- `BuddyRepository.buddyCountsForDives(diveIds)`

Item display data (names, icons) comes from the existing per-collection
fetch-by-ids paths.

### Per-collection wrinkles

- **Buddies** carry a per-dive role. Tri-state governs **membership only**:
  checking adds the buddy to all dives with a **default role**; existing buddies'
  roles are never modified (add/remove only). Role refinement stays in
  single-dive edit.
- **Dive types**: membership only; the dive's representative-type column is
  unaffected. Removing a dive's last type already falls back to `recreational` in
  the repo.
- **Tags**: the "＋ Add" affordance is the existing tag input (including
  create-new); added tags appear as checked rows.
- **Equipment**: keeps "Use set" as an add-source. **"Save as Set" is hidden in
  bulk mode** (ambiguous whose gear it would save); it remains on single-dive
  edit, where Bug 2 is fixed.

### Bug 2 fix

`_saveEquipmentAsSet` routes through
`ref.read(equipmentSetListNotifierProvider.notifier).addSet(set)` (which stamps
the active `diverId` and refreshes) instead of calling `repository.createSet()`
directly.

## Testing (TDD — tests first)

- `BulkMembershipEditor` widget tests: renders checked/dash/empty for
  all/some/none; each tap-cycle yields the correct `(addIds, removeIds)`; added
  items produce adds; unchecking an "all" item produces a remove; leaving a
  "some" item as dash produces nothing.
- Service test: one `BulkEditRequest` carrying both an AddOp and a RemoveOp for
  the same collection applies both, and undo restores prior membership.
- Count-query tests: all/some/none counts across a 3-dive selection per
  collection.
- Bug 2 widget test: seed a diver + a dive with gear, tap Save as Set, assert the
  set is visible to the current diver (fails pre-fix, passes post-fix).
- Bug 1 regression test: dive has gear A; bulk-add B -> {A, B}; multi-dive
  variant (d1={A}, d2={B}; add C -> d1={A,C}, d2={B,C}).

## Safety & undo

Add/Remove ops are already captured by the existing per-dive snapshot, so bulk
Undo works unchanged. There is no destructive replace path from this UI, and
empty deltas emit no ops.

## Approximate change surface

- New: `bulk_membership_editor.dart` (widget) + view-model.
- New: 4 count-query methods (`DiveRepository` x3, `BuddyRepository` x1).
- Edit: `dive_edit_page.dart` — replace the four reference-collection
  `_collectionEntry` blocks; update `_collectCollectionOps`; hide "Save as Set" in
  bulk; fix `_saveEquipmentAsSet`.
- New/updated tests as above.
- l10n additions for any new strings, translated into all locales.
