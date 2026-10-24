# Several regulators on one tank

Issue: #3375. Release: v1.8.3.
Mockup: [assets/2026-10-24-tank-extra-regulators-mockup.html](assets/2026-10-24-tank-extra-regulators-mockup.html).

## Intent

Some divers breathe from a cylinder that carries more than one regulator: a
single tank with a twin (Y or H) valve for cold water, or a manifolded twin
set. Today a tank on a dive names one regulator (`dive_tanks.regulator_equipment_id`,
v202), so the other regulators were never on the dive at all: they gain no
service progress (dives and hours on their service clocks) and no high-O2
contact time.

The reporter rejected the workaround suggested on the issue (an assembly
called "Twin Reg Set"): separate regulators should stay separate items.

## Goals

- A tank on a dive names any number of regulators. There is no cap (the
  maintainer: "no limit").
- Every regulator on a tank counts the same way the single regulator counts
  today: the dive is a dive on that regulator, and the tank's gas is high-O2
  contact for it.
- The tank editor shows the extra regulators only when the diver adds them.
- A regulator on a tank, the first one and every extra, counts as a dive on
  that regulator everywhere the app lists or counts an item's dives: the
  equipment page's Dives row, the dive list filtered by that gear, and the
  query language in both directions. Today none of those see a tank
  regulator, not even the single one (the maintainer chose to fix that here).

## Non-goals

- No primary or backup role. The regulators are equals; the first is first
  only because it was entered first. (The maintainer considered a primary and
  dropped it: "there should just be a 'regulator' and 'second regulator'".)
- No change to twin cylinders as one unit. That is a separate request in the
  issue thread and is not built here.
- No regulator on the dive detail page. The tank regulator is not shown there
  today and this feature does not start showing it.
- No UDDF or CSV export of tank regulators. They are not exported today.

## Anti-goals

- A tank with one regulator, or none, must behave exactly as it does today in
  every screen, query, sync and backup, with one deliberate exception: the
  dive counts and gear filters above now include its regulator.
- An existing dive must not change. Its single regulator stays where it is.
- The same regulator must never be counted twice for one tank.

## Behaviour

### Tank editor

Option C from the mockup.

1. **No regulator:** the "Regulator" picker exactly as today. No add link.
2. **One regulator:** an "+ Add regulator" text button appears under the
   picker.
3. **Several:** each added regulator is its own picker labelled "Regulator 2",
   "Regulator 3", and so on, each with a remove button (an X). The add button
   stays under the last one.

Rules every picker on the tank follows, the same as today's picker:

- Spare regulators are not offered, except one this tank already uses (#1803).
- Retired and sold regulators are offered only through the "Show retired and
  sold" item, except one this tank already uses (#3210).
- Regulators sharing a name are disambiguated by `equipmentRowLabelsOf`.

New rules:

- A regulator already chosen in another picker on the same tank is not
  offered. (A different tank on the same dive may use it: that is today's
  behaviour for the single picker and is not changed.)
- Setting the first picker to None moves Regulator 2 up into the first
  place, and the rest move up with it. When there are no extras, None clears
  the tank's regulator as today.
- Tapping the add button adds an empty picker. A picker left empty when the
  editor is saved is dropped. (Builder's call.)
- The add button is hidden when no regulator is left to offer. (Builder's
  call.)

### Cylinder preset prefill

Choosing a preset today fills the regulator from the newest dive whose tank of
that preset names one, if the tank has no regulator yet
(`getLastRegulatorForPreset`). It now fills the whole list from that same
tank: the first regulator and its extras, in order, keeping only regulators
still in the kit by today's test (active, not retired, sold or wanted). Still
only when the tank has no regulator yet. (Builder's call: the diver who hangs
two regulators on that cylinder hangs both again.)

### What an extra regulator counts toward

Every reader that today asks "is this item the regulator of this tank" must
also accept an extra regulator of that tank. Known readers:

- `diveGearUsageSql` (`dive_gear_usage_sql.dart`, issue #2853): the
  `tankRegulator` branch. Through it: the data-quality shared gear overlap,
  shared gear notes, quality prefilters.
- O2 contact and exposure samples in `equipment_repository_impl.dart` (the
  single-item query around line 1183 and the batched one around line 1563),
  including the `via_parent` branches, so an extra regulator that is an
  assembly reaches its components exactly as the first does.
- `getLastRegulatorForPreset` (see above).
- `equipment_transfer_service.dart`: the diver lookup that finds dives using
  the items.

The builder should grep for `regulator_equipment_id` and `regulatorEquipmentId`
to find any reader this list misses.

### Dive counts and the gear filter

These read only `dive_equipment` and `dive_tanks.equipment_id` today, so a
tank regulator (single or extra) is missing from them. Each gains both tank
regulator links:

- `getDiveCountForEquipment` (`equipment_repository_impl.dart`): the
  equipment page's Dives row (through `equipment_providers.dart`) and the
  assembly history dialog.
- `kDiveGearJoinSql` (`dive_query_entity.dart`): the dives `gear` relation,
  which the Dives row opens and which typed search and Explore use. Its
  `tables` list stays accurate.
- `_gearDiveLink` and the `dives` relation in `equipment_query_entity.dart`,
  so the equipment side of the query language agrees with the dive side.
- Explore's per-item dive counts (`explore_repository.dart`) and the
  Insights most-used gear ranking (`insights_repository.dart`), which read
  the same gear union.

These definitions should agree with one another and with the `tankRegulator`
branch of `diveGearUsageSql`; one shared SQL fragment for "the regulators of
a tank" is the builder's call. Existing counts for regulators that were only
ever on tanks go up; that is intended. The trip count
(`getTripCountForEquipment`) reads only the gear list, ignores tank
cylinders too, and is not changed here.

## Data

### Storage

A new nullable TEXT column on `dive_tanks`, `extra_regulator_ids`: a JSON
array of equipment ids, the regulators after the first, in order. This
follows the precedent of `dive_tanks.shared_computer_ids` (v260) and was
chosen by the maintainer over a child table: the extras travel with the tank
row, so sync never shows a tank with half its regulators, and no new synced
table is needed.

`regulator_equipment_id` keeps its meaning: the first regulator. Old rows need
no migration.

Invariants the repository keeps on every write (normalise, do not reject):

- null or `[]` means no extras. (Builder picks one stored form for "none" and
  keeps it; there is no "never recorded" distinction as there is for shared
  computers.)
- No id appears twice, and none equals `regulator_equipment_id`.
- If `regulator_equipment_id` is null, the list is empty: the first extra is
  promoted into the column instead.

SQL readers use `json_each(dive_tanks.extra_regulator_ids)`. Performance: the
existing readers use an index on `regulator_equipment_id`; the JSON branch has
none. The builder should measure the batched exposure query on a large library
(see the counting-queries test pattern) and say what it found in the PR.

### Domain

`DiveTank` gains the extras (for example `List<String> extraRegulatorIds`,
default empty), carried by `copyWith`, equality and every path that rebuilds a
tank field by field.

### Write and rebuild paths

Every path that copies `regulatorEquipmentId` today carries the extras too. A
tank column added without them is wiped on that path (see the dive_tanks
rebuild-path rule from #1722). Known paths:

- `dive_repository_impl.dart`: create, update (both the update and insert
  branches), bulk replace, the row mappers (around lines 4328, 4784, 7346).
- `bulk_dive_edit_service.dart`: `_tanksFromRows` (bulk undo).
- `sequential_tank_merge.dart`: `_fold`. The merged tank takes the earlier
  half's list when it has a regulator, otherwise the later half's. (Builder's
  call, matching today's `earlier ?? later` for the single field.)
- `plan_tank_list.dart` (dive planner): carries the extras the way it carries
  the regulator today.
- Duplicate dive, dive split, dive consolidation: wherever a tank is copied.

### Deleting a regulator

`clearCylinderGearLinks` (`cylinder_gear_links.dart`) clears tank links to
deleted gear inside the deleting transaction and stages each tank for sync.
It must also remove deleted ids from `extra_regulator_ids` (promoting an
extra into the first place when the first is deleted), stamp the hlc and
stage the tank, exactly as it does for the first regulator. The schema
cannot do this: a JSON column has no foreign key.

The same applies wherever the first regulator is cleared for another reason
(diver delete, equipment transfer): the extras follow.

### Sync

The column rides on the `diveTanks` record. Conflict resolution is
whole-field last-writer-wins on the tank row, like `shared_computer_ids`.

- Add the field to the conflict catalogue (`dive_log_fields.dart`) with a
  localized label, and resolve its ids to equipment names in the conflict
  UI, as `regulatorEquipmentId` is resolved today
  (`conflict_reference.dart`, `conflict_reference_labels.dart`). The builder
  decides how a list renders there.
- Sync does not normalise incoming rows. The single field is cleared when
  it names an equipment id this device does not have (`SyncService`'s parent
  references); the extras are not, and an older peer's edit or a remote
  equipment delete can leave a tank whose extras break the invariants above.
  Every SQL reader and the editor tolerate that (a dangling id shows as an
  empty, removable picker), and the next local save normalises the row.
  (Builder's call: stripping the list inside the sync merge was judged
  riskier than the state it would prevent.)

### Schema

One new rung on the ladder (`lib/core/database/migrations/`, never in
`database.dart`), adding the column. Built as v310 and renumbered to v312
when #3611 and #2151 shipped v310 and v311 first; renumber again on merge
if main moves. A `beforeOpen` backstop for the column follows the existing
pattern for `dive_tanks` columns.

## Text

New ARB strings, translated into every locale the app ships:

- "Add regulator" (the add button).
- "Regulator {number}" (the label of each extra picker).
- A tooltip or semantic label for the remove button ("Remove regulator").
- The conflict field label.

## Tests

TDD per the repo. At minimum:

- Repository round trip: create and update a tank with extras; invariants
  normalised on write.
- Every rebuild path keeps the extras (the census style used for #1722).
- Gear usage, exposure (single and batched), last-regulator prefill and
  transfer lookup each see an extra regulator.
- The Dives count, the dives `gear` relation and the equipment `dives`
  relation each count a dive whose tank names the item as its first
  regulator, and one where it is an extra, once each (a regulator on two
  tanks of one dive is still one dive).
- Deleting a regulator removes it from the extras, promotes when needed, and
  stages the tank.
- Tank editor widget tests: add, remove, promote on None, a chosen regulator
  not offered twice, prefill fills the list.
- Migration test for the new rung.

## Screenshots

The tank editor changes, so the PR carries before and after of the tank
editor (one regulator before; one, and three, after), at phone and desktop
widths.

## Left to the builder

Calls already marked "Builder's call" above, plus: widget structure inside the
tank editor, the exact Dart names, the stored form of "no extras", and how a
list of regulators renders in the conflict UI.
