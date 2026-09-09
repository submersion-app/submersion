# O2 Cell Linearity Checklist Item: Design

Date: 2026-09-08
Status: Approved pending user review
Issue: [#986](https://github.com/submersion-app/submersion/issues/986)
Feature branch: `ericgriffin/issue-986-brainstorm-245001`

## Summary

A new pre-dive checklist item type, `cellLinearity`, that records a CCR
oxygen cell's output in pure oxygen, reads back the cell's earlier air
reading from another item in the same checklist, and shows the resulting
linearity percentage.

CCR divers perform this check on every build, once per cell, so three times
for a typical unit and five for a Revo. Today the app can record the
millivolt readings as plain `value` items but cannot relate them, so the
diver notes the numbers, leaves the app, uses a calculator, and comes back to
type the answer in as a third recorded value.

The design implements the issue's stated ideal rather than its fallback: an
air reading recorded once, and a later item that refers back to it
automatically. That requires an item-to-item reference, which is the whole of
the difficulty and the whole of the interesting design work here.

## Domain background

A galvanic oxygen cell produces a current proportional to the partial
pressure of oxygen at its face. Its output is therefore expected to be
linear in ppO2, and the standard field check for that linearity is:

1. Read the cell in air, where the oxygen fraction is 0.209.
2. Divide by 0.209 to get the millivolts the cell *should* produce at a
   ppO2 of 1.0.
3. Flush the loop with pure oxygen and read the cell again.
4. Divide the measured figure by the expected figure. That ratio, as a
   percentage, is the linearity.

A cell that cannot reach its expected output in oxygen is current limited:
it will read plausibly at the surface and then under-report at depth,
exactly where under-reporting is dangerous. This is why the check is done on
every build and not merely at cell replacement.

### The 0.209 divisor needs no pressure or altitude input

Cell output is proportional to ppO2, so for some cell constant `k` and
ambient pressure `P`:

```
mV_air = k * 0.209 * P
mV_O2  = k * 1.000 * P
```

The ambient pressure term cancels in `mV_O2 / (mV_air / 0.209)`, provided
both readings are taken at the same ambient pressure, which they are, since
the diver is standing in one place with one unit. A diver checking at 2000 m
gets the same linearity figure as one at sea level.

The consequence for this design is a welcome one: the calculation takes two
numbers and a constant. It needs no altitude setting, no ambient pressure
sensor and no barometric plumbing. Nothing in this feature should acquire
any.

### Linearity alone cannot condemn a cell

A uniformly aged cell reads low in air *and* proportionally low in oxygen.
It scores close to 100% linear while being unfit for use. What catches that
is the absolute range on the air reading, which the built-in CCR template
already carries as an advisory 8.5-13.0 mV band.

The two checks are therefore complementary and this design keeps both: an
absolute band on the air half, a ratio on the linearity half. The linearity
item does not replace the air item and must not be designed as though it
could.

## Requirements

- Record the cell's millivolts in pure oxygen as a checklist item.
- Read the cell's air millivolts back automatically from an earlier item in
  the same checklist run, without the diver retyping it.
- Show the expected oxygen millivolts and the linearity percentage, both
  live during entry and afterwards in the item's own row.
- Warn, without blocking, when linearity falls below a threshold.
- Ship the check in the built-in CCR build template so a CCR diver gets it
  with no setup.
- Survive template cloning, item reordering, source deletion, and the
  session snapshot.

## Non-goals

- Any altitude or ambient-pressure input (see above).
- Tracking cell age, serial numbers, or a cell replacement history. That is
  equipment-domain work and a separate issue.
- Trending linearity across sessions or charting cell decay over time.
  Worth doing later; the per-session records this design writes are the
  necessary precondition for it, but nothing here consumes them that way.
- Reworking the `value` item type, which stays exactly as it is.
- Manual linking of checklist sessions to dives, mentioned in passing at the
  end of the issue. Already addressed by #1066; if the reporter still sees a
  gap on desktop it belongs in its own issue.

## Architecture

### The new item type

`PreDiveItemType` gains a fifth value, `cellLinearity`.

`PreDiveItemType.parse` falls back to `check` for an unrecognised name. An
older build that syncs a `cellLinearity` row from a newer one therefore
renders it as a plain tick-box rather than failing. That fallback is load-
bearing forward compatibility and must not be "corrected" into a throw.

### Schema

Three new nullable columns:

| Table | Column | Meaning |
|---|---|---|
| `pre_dive_checklist_template_items` | `source_item_id TEXT` | Template item this linearity row reads its air millivolts from |
| `pre_dive_session_items` | `source_item_id TEXT` | The same link, remapped to the *session* item id at compose time |
| `pre_dive_session_items` | `source_value_number REAL` | The air millivolts, frozen when the diver resolves the row |

Neither `source_item_id` is a SQL foreign key. This follows the reasoning
already documented on `equipment_id` in `PreDiveChecklistTemplateItems`:
these rows are seeded into isolated schema fixtures, and at every app start
for built-in templates, independently of what they reference. Referential
integrity is enforced at the application layer, and every read path
tolerates a dangling reference.

Migration takes the next free rung on the ladder. Verified against the tree
on 2026-09-08: `currentSchemaVersion` is 199 and the highest rung in
`onUpgrade` is `from < 199`, so the next free rung in main is **v200**.
Issue #1365 is expected to claim v200 as well, and the ladder is contested by
parallel branches generally, so **re-check the current maximum across sibling
branches immediately before taking the rung** rather than trusting any number
written here. `database.dart` already carries a worked example of this
renumbering, in the comment on the v199 rung.

The migration itself is the guarded pattern already used twice for this
feature: read `PRAGMA table_info`, and `ALTER TABLE ... ADD COLUMN` only
when absent (`database.dart:6231` and `:6263` are the models to copy).

Bumping `currentSchemaVersion` predictably breaks roughly nine assertions in
unrelated migration and vacuum suites that use the previous version as
shorthand for "the ladder ran to completion". Those get repointed at
`AppDatabase.currentSchemaVersion`; only the newest rung's own test pins a
literal.

### Sync

No per-column work. `sync_data_serializer.dart` round-trips both tables
through Drift's generated `fromJson(...).toCompanion(false)`, so new columns
are carried automatically. The round-trip test gains coverage of the new
fields; nothing else in sync changes.

Note that `source_item_id` on a session item references a row in the same
table, and both rows sync as independent HLC records. Order of arrival is
therefore not guaranteed, which is a further reason the reference is not a
SQL foreign key and why every reader must tolerate a dangling one.

### Excel export

`lib/core/services/export/excel/pre_dive_excel_export_service.dart` writes a
row per session item and switches exhaustively on `PreDiveItemType`, so the
new enum value is a compile error there until an arm is added. Its label is a
plain English data string like the four existing arms, not a localised one.

The items sheet also gains two columns after `Unit`, `Air Value` and
`Linearity %`, populated only for a `cellLinearity` row. Without them an
exported linearity item would carry its oxygen reading and nothing else, which
is precisely the incomplete record the issue is asking us to stop producing.

### The calculator

A new pure domain service,
`lib/features/pre_dive/domain/services/cell_linearity.dart`, owning the
constant and both derivations:

```dart
class CellLinearity {
  static const double airOxygenFraction = 0.209;

  /// Millivolts the cell should produce at a ppO2 of 1.0, or null when
  /// [airMillivolts] is absent or non-positive.
  static double? expectedO2Millivolts(double? airMillivolts);

  /// Measured over expected, as a percentage, or null when either input
  /// is missing or the expected value is not positive.
  static double? percent({double? airMillivolts, double? o2Millivolts});
}
```

Rounding: the percentage is computed from the exact expected value.
Rounding is presentation only: expected to one decimal place, percentage to
zero. Because the *displayed* expected value is rounded, a diver re-checking
the arithmetic from what is on screen can occasionally land one percent
away; the rounding of expected is worth at most about 0.1 percentage points,
so this only shows when the true figure sits within 0.1 of a rounding
boundary. Rounding once, at the end, is the right convention and this is the
accepted cost.

Non-positive and missing air readings yield null rather than an error or an
infinity. Nothing in this feature blocks on a missing number.

## The link and its remaps

Template item ids are minted or reassigned in four places. Two need no
change and two do.

**Unchanged.** `_PreDiveItemDialog._submit` already mints a uuid when an
item is created, so a reference to a brand-new sibling is stable before the
first save. `saveItems` preserves any non-empty id, so references survive an
ordinary template edit.

**`cloneTemplate` must remap.** It currently blanks every id
(`i.copyWith(id: '', ...)`) and lets `saveItems` mint fresh ones. It gains a
pre-pass that mints the new ids itself, builds an `oldId -> newId` map, and
rewrites `sourceItemId` through it. Without this, cloning the built-in CCR
template silently unlinks all three pairs, and cloning the built-in is the
single most likely way a diver first meets this feature.

**`SessionItemComposer.compose` must remap.** It also emits `id: ''` today,
with `startSession` minting one uuid per row inside its insert loop. The
composer therefore cannot currently know the ids it would need to link.
It starts minting its own ids, and `startSession` changes to
`item.id.isEmpty ? _uuid.v4() : item.id`, the same defensive shape
`saveItems` already uses, so a caller that does not set ids keeps working.
Compose can then build its template-id to session-id map in a single pass
and write the session-level link directly.

### Degradation

If `sourceItemId` is null or dangling when `compose` runs, the item is
emitted as a plain `value` item rather than a `cellLinearity` one. This
mirrors the existing precedent where an `equipmentSet` placeholder with no
set degrades to a `check` so the checklist stays runnable.

It degrades to `value` rather than `check` deliberately: the diver is
standing there with a meter in hand, and the oxygen reading is still worth
recording even when the app cannot compute the ratio.

A degraded item must also have its `valueMin` and `valueMax` cleared. On a
`cellLinearity` item those are percentages; carried over onto a `value`
item they would be read as millivolts, and a 95% minimum compared against a
48.0 mV reading would light amber on a perfectly healthy cell. Dropping the
thresholds is the honest outcome: the app can no longer evaluate the check,
so it should not pretend to.

## Threshold semantics

A `cellLinearity` item reuses the existing `valueMin` and `valueMax`
columns, interpreted as a **percentage** rather than millivolts. The
built-in rows ship with a 95% minimum and no maximum. Out-of-range renders
exactly as it does today for a `value` item: bold amber, advisory, never
blocking and never auto-resolving. The go/no-go call stays with the diver,
consistent with every other item in this feature.

This reuse has one wart worth stating plainly. On a `cellLinearity` item,
`valueUnit` describes `valueNumber` (millivolts) while `valueMin` and
`valueMax` describe the derived percentage. The alternative was a dedicated
pair of `linearity_min` / `linearity_max` columns; reuse was chosen for the
smaller schema and the unchanged editor plumbing. The columns get explicit
comments recording the overload.

The reuse has a direct consequence that must not be missed:
`PreDiveSessionItem.valueOutOfRange` currently compares the thresholds
against `valueNumber`. Left alone it would compare a 95% threshold against a
48.0 mV reading and light up amber on every healthy cell. It becomes
type-aware, comparing against the derived percentage for `cellLinearity`
items and against `valueNumber` for everything else.

## Recording and freezing

Resolving a linearity item writes three things: `valueNumber` (the oxygen
millivolts), `source_value_number` (the air millivolts, copied from the
sibling at that instant) and the item state.

The percentage is always derived from those two frozen numbers and is never
re-read from the sibling. A completed row therefore cannot be silently
rewritten by a later edit to the air reading. That is the same reasoning, and the
same shape, as the existing `overdueServices` freeze and the "stamped at tap
time, never backfilled" rule on `completedAt`. It also means a locked
session that has been linked to a dive continues to report exactly what the
diver saw when they made the call.

Where the sibling's current value no longer equals the frozen
`source_value_number`, the linearity row shows a quiet "air reading has
changed since" hint. It does not recompute, and it does not reset the item.
The diver can reset the row by hand if they want it redone.

If the air reading is missing or non-positive when the diver opens the
linearity item, the dialog still accepts the oxygen reading and the readout
says the air reading is needed. Nothing blocks.

## User interface

### Template editor

The item-type dropdown gains "Cell linearity". Selecting it reveals the
value fields plus a **source picker**: a dropdown of the other `value`-typed
items in the template, showing each one's title and value label.

The source is required in the editor. A validator blocks save without one.
Degradation exists for rows arriving from a clone, from sync, or from a
since-deleted source, not as a state the editor can author.

The threshold fields relabel to percentage when the type is cell linearity,
since the same two columns mean millivolts on a `value` item.

Two hazards the editor can produce, both handled in the page against its
in-memory `_items` list with no repository involvement:

- **Deleting a source item.** Any dependent rows have their `sourceItemId`
  cleared, and a snackbar names them. Non-blocking: the diver may be
  mid-restructure and about to add a replacement.
- **Dragging a linearity row above its source.** Allowed, with an inline
  warning on the row that it reads a value recorded later in the list. It
  only bites in a strict-order template, where the diver would reach the
  linearity item first, and the runner already handles a missing air
  reading gracefully.

### Runner

The entry dialog is the existing `_ValueEntryDialog` shape with a read-only
line added above the input:

```
Cell 1 in air        10.1 mV          (or: not yet recorded)
[ mV in O2                    48.0 ]
Expected 48.3 mV · Linearity 99%      (live, updates while typing)
[ Note                             ]
```

The tile subtitle carries the full working, so the results the issue asks
for are visible in the list without opening anything:

```
Cell 1: 48.0 mV
Air 10.1 mV · expected 48.3 mV · linearity 99%
```

The second line uses the existing out-of-range styling (bold amber) when
below the threshold. The "air reading has changed since" hint appears as a
further line only when the sibling has drifted.

`SessionItemTile`'s `onTap` routes `cellLinearity` items to `onEditValue`
alongside `value` items.

## Built-in CCR template

Three rows are added to the Cells section of `builtin-predive-ccr-build`,
immediately after the three existing air readings:

| Field | Value |
|---|---|
| id | `builtin-predive-ccr-cell1-linearity` (and cell2, cell3) |
| section | `Cells` |
| title | `Cell 1 mV in O2` |
| sort_order | 7, 8, 9 |
| item_type | `cellLinearity` |
| source_item_id | `builtin-predive-ccr-4` (and -5, -6) |
| value_label | `Cell 1` |
| value_unit | `mV` |
| value_min | 95 |
| value_max | NULL |
| is_required | 1 |

Descriptive ids are used rather than continuing the numeric run, because
these ids no longer track their position in the list.

The placement is load-bearing, not cosmetic: `builtin-predive-ccr-build` is
seeded with `strict_order = 1`, so the runner will not let the diver reach
an item before the ones above it. Each linearity row must therefore sort
after the air reading it sources, which is what the renumbering below
protects.

A companion idempotent `UPDATE ... WHERE id IN (...)` pushes the Gas,
Pre-breathe and Bailout rows from `sort_order` 7, 8, 9 down to 10, 11, 12.
`INSERT OR IGNORE` can add missing rows but can never renumber existing
ones. That is the lesson the GUE EDGE repair already records in
`database.dart`.
Both statements run beside the existing seed in
`_seedBuiltInPreDiveTemplates` at `beforeOpen`, on every launch, and are
idempotent by construction: the insert ignores existing ids, and the update
sets fixed values keyed by id.

This requires no schema bump of its own. Built-in reference data can be
repaired in place because built-ins are read-only in the UI, excluded from
sync export, and session items are independent snapshots with no foreign key
back to template items.

**Hard constraint.** `builtin-predive-ccr-4`, `-5` and `-6` must never be
renumbered or retired. The new rows point at those exact ids, and a future
tidy-up of the built-in item ids would silently unlink the pairs in every
database that has already seeded them.

Five-cell units are served by cloning the template and adding two more
pairs. A built-in cannot be parameterised by cell count, and shipping a
second five-cell built-in was considered and rejected as redundant with
cloning.

## Localisation

Approximately eight new ARB keys across all eleven locales
(`app_ar`, `app_de`, `app_en`, `app_es`, `app_fr`, `app_he`, `app_hu`,
`app_it`, `app_nl`, `app_pt`, `app_zh`): the item type label, the source
picker label, the air-reading line, the expected and linearity readouts, the
percentage threshold labels, the changed-since hint, and the
source-cleared snackbar.

The built-in seed titles are plain data strings in SQL and are not
localised, consistent with every existing built-in template item.

## Testing

Test-driven, per the project convention.

- **`CellLinearity` calculator.** The issue's own worked example as a
  vector: 10.1 mV in air gives an expected 48.3 mV, and 48.0 mV measured
  gives 99%. Plus null, zero and negative air readings, and a missing oxygen
  reading.
- **`SessionItemComposer`.** The link remapped from template ids to freshly
  minted session ids; ids minted stably; degradation to `value` on a null or
  dangling source.
- **`cloneTemplate`.** The link remapped across a clone. This is the
  regression that would otherwise ship silently.
- **`PreDiveSessionItem.valueOutOfRange`.** Percentage for linearity items,
  millivolts for value items. Written first, against the unfixed getter, so
  the amber-on-every-healthy-cell failure is actually observed.
- **Migration rung.** New columns present after migrating from the previous
  version; existing rows unaffected.
- **Sync round-trip.** The three new fields survive
  `fetchRecord`/`upsertRecord` for both record types.
- **Built-in seed.** The three rows exist, point at the right air rows, and
  the tail rows are renumbered. Re-running the seed is a no-op.
- **Widget tests.** The entry dialog's live readout, the tile's subtitle
  lines, out-of-range styling, and the changed-since hint. Pinned to
  `locale: const Locale('en')`, as this feature's existing tests are, and
  one `ProviderScope` pump per test.

## Risks and open points

- **Schema rung contention.** v201 is an estimate. Re-check against sibling
  branches before taking it.
- **Threshold value.** 95% is a common acceptance figure but agencies and
  manufacturers differ, and some divers work to 90%. It is advisory,
  editable on a cloned template, and never blocking, so a wrong default is
  cheap. It is still a default the app is asserting, and worth a second
  opinion before release.
- **The `valueMin`/`valueMax` overload** is the one piece of deliberate
  impurity in this design. If a third meaning for those columns ever
  appears, that is the signal to split them into typed threshold fields
  rather than overload them again.
