# Custom names for weights (issue #956)

## Problem

Every weight row on a dive reads as one of six fixed placements (Weight Belt,
Integrated, Ankle, Trim, Backplate, Mixed). A diver who spreads lead across
the spine pockets of a sidemount wing, or who wants to record that a light
canister or an O2 bottle changed their weighting, cannot tell those rows
apart: two "Trim Weights 1 kg" rows look identical. The workarounds (custom
fields, or reusing an unrelated preset name such as "Ankle Weights" for a light
canister) put the information in the wrong place or make it hard to remember.

## Goal

Each weight row can carry an optional free-text name ("Top pocket",
"2nd pocket", "Light canister"), entered beside the placement type in the dive
editor and the weight preset editor, saved with the dive and with weight
presets, synced, and shown wherever individual weight rows are listed.

Success: a diver records "Top pocket, Trim, 2 kg" and "2nd pocket, Trim, 1 kg"
on a dive, saves that as a weight preset, applies it to a later dive, and sees
both names on the dive detail page and on any other device.

## Non-goals

- The placement type stays a fixed enum. The buoyancy predictor and the
  weight planner key their placement maths off `WeightType.name`; a name sits
  beside the type and never replaces it.
- No library of reusable named weights. Reuse goes through the existing
  weight presets (rigs, issue #1609), which now carry each entry's name.
- No rewrite of existing data. Weight `notes` already filled by past Subsurface
  imports stay where they are.
- No per-row weight breakdown in the PDF logbook (it shows only the total
  today), and no change to the preset list and picker (they show an entry
  count only).

## Decisions

| Question | Decision |
| --- | --- |
| Where the name is stored | A new `label` column, separate from the existing (hidden) `notes` column |
| Subsurface weight descriptions | The importer writes them to `label` from now on, except Subsurface's stock placement names; existing rows untouched |
| Editor layout | An optional Name field on a second line under each Type / amount / delete row |
| Read-only display | Name first, then the type muted: `Top pocket · Trim Weights`; unnamed rows unchanged |
| Maximum length | 256 characters |

## Design

### 1. Data model, migration, sync

- **Column.** `label TEXT NOT NULL DEFAULT ''` on `dive_weights` and on
  `weight_preset_entries`, declared in `lib/core/database/tables/dive_tables.dart`
  and `lib/core/database/tables/weight_tables.dart` as
  `text().withDefault(const Constant(''))()`, mirroring `notes`. An empty
  string means "no name".
- **Why not nullable.** A child-table value going to `null` reaches peers only
  through `clearChildColumns` with a newer clock (#2644). With a non-null
  empty default, clearing a name is an ordinary value change, exactly as
  `notes` behaves today. It also keeps `copyWith` able to clear the name by
  passing `''`.
- **Migration.** One new schema rung: the next free version when the PR merges
  (shipped as v270: written as v261, renumbered as rungs 261 through 269 shipped first; 268 is held by #3043). The rung adds the column to both tables with
  `ALTER TABLE ... ADD COLUMN`, guarded by a column-existence check so the rung
  is idempotent and safe to renumber or to re-run from a `beforeOpen`
  backstop. Existing rows get `''`; nothing is rewritten. Per the database
  split, the rung lives under `lib/core/database/migrations/`, not in
  `database.dart`.
- **Domain.** `DiveWeight.label`, `WeightPresetEntry.label` and the
  `WeightEntryDraft` record gain `String label` (default `''`), included in
  `copyWith` and `props`.
- **Validation.** Writers store `label.trim()`, truncated to 256 characters.
  The text fields enforce the same limit with `maxLength: 256`.
- **Sync.** No per-field code: `dive_weights` and `weight_preset_entries` are
  serialized by table (`sync_data_serializer.dart`), so the column travels
  once it exists, and each row's own `hlc` already guards stale overwrites. A
  row from a peer that predates the column (no `label` key) takes the default.

### 2. Every writer and copier carries `label`

Paths that build weight rows field by field, each of which would otherwise
drop the name:

- **Dive save and load.** `dive_repository_impl.dart`: `_weightCompanion`, the
  insert paths that build `DiveWeightsCompanion` directly, and the
  row-to-domain mapping.
- **Weight presets.** `weight_preset_repository.dart` create, update and row
  mapping. "Save weights as preset" in the dive editor copies each row's label
  into the preset; "Use preset" copies it back (`WeightPreset.toDiveWeights`).
  The preset editor writes the row's label instead of a hard-coded empty value.
- **Other copiers.** Bulk edit (`bulk_dive_edit_service.dart`, `WeightsOp`),
  dive merge (`dive_merge_builder.dart`), rental memory
  (`rental_memory_resolver.dart`), and the dive editor's "Apply last dive"
  and legacy single-weight paths. Consolidation, uncombine and the merge
  snapshot copy whole domain objects or rows; they get regression tests, and
  any that turn out to copy field by field get the field.
- **Subsurface import.** `<weightsystem description="...">` goes to `label`;
  `notes` is left empty. A description that is only one of Subsurface's
  stock placement names (`integrated`, `belt`, `ankle`, `backplate`,
  `backplate weight`, `clip-on`; compared trimmed and case-insensitively)
  sets the type alone and leaves `label` empty, so a stock row never reads
  `belt · Weight Belt`.
- **UDDF.** Export writes `<label>` beside `<notes>` inside the app-specific
  `<weights><weight>` block; import reads it back, so a Submersion to
  Submersion round trip keeps names. A file without `<label>` imports as `''`.
- **No name source.** Garmin Cloud and the UDDF scalar-weight fallback leave
  `label` empty.

### 3. UI

- **Dive editor weight rows** (Gas & Gear section, and the bulk-edit weights
  editor, which reuses the same widget). Under each `Type | amount | delete`
  row, an optional Name `TextFormField` with the hint "e.g. Top pocket" and
  `maxLength: 256`; the counter shows only near the limit. Each row is keyed
  with `ValueKey(weight.id)`, so deleting a middle row no longer lets its text
  field state slide onto the next row (a latent hazard the amount field
  already has, fixed by the same key).
- **Weight preset editor.** The same second-line Name field per row; the
  editor's row model gains a label controller.
- **Dive detail weight card.** A named row reads `Top pocket · Trim Weights`
  with `· Trim Weights` in `onSurfaceVariant`; an unnamed row is unchanged. A
  long name wraps inside an `Expanded`, with the amount right-aligned on the
  first line.
- **Rental memory card** (dive centers). Each remembered weight shows its name
  before the type in the same way.
- **Query language.** `weights.label` joins `weights.notes` as a text field on
  the weights query entity.
- **Localization.** New ARB keys for the editor field label, its hint and the
  query field name, translated into every shipped locale.

### 4. Testing

- **Migration.** A ladder test opens a database at the previous version with
  weight and preset-entry rows, upgrades it, and checks both tables have
  `label`, existing rows read `''`, and `notes` is untouched. The rung re-runs
  without error. Schema-version literal tests are bumped.
- **Repository.** Dive save, load and update round-trip `label`, including
  clearing it to `''`; trimming and the 256-character cap are enforced.
  Preset create, update and mapping round-trip it.
- **Copiers.** Preset save and apply, bulk edit `WeightsOp`, dive merge
  builder, rental memory resolver; regression tests for consolidation and
  uncombine.
- **Import and export.** Subsurface description lands in `label` with `notes`
  empty; UDDF export then import keeps `label`; UDDF without `<label>` gives
  `''`; the sync serializer round-trips `label` and accepts a row without the
  key.
- **Widgets.** Dive editor: a typed name is saved, and deleting a middle row
  keeps the other rows' names and amounts. Preset editor saves names. Detail
  card shows `name · type` for named rows and is unchanged for unnamed rows.
  Rental memory card shows the name.
- **Query.** A `weights.label` contains filter matches.
- **Guards.** `test/architecture/` and the generated-l10n staleness check.
