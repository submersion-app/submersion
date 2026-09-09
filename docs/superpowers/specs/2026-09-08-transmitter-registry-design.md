# Transmitter registry and per-dive series reassignment

Issues: [#1365](https://github.com/submersion-app/submersion/issues/1365)
(link AI transmitter channels to cylinders) and
[#1314](https://github.com/submersion-app/submersion/issues/1314) (let the
diver reassign a transmitter's pressure series to a different tank).

Date: 2026-09-08. Status: approved design, awaiting implementation plan.

## Problem

Air-integrated dive computers report tank pressure per transmitter but almost
never the cylinder's size, and none report a role. Submersion fills the gap
with one global default preset, so a CCR diver's 2 L oxygen and 3 L diluent
both import as an AL80 and every download needs hand correction. Wrong sizes
silently produce wrong SAC. Divers with fixed setups know exactly which
transmitter sits on which cylinder, and that pairing is stable on the device,
but there is nowhere to tell the app.

Separately, when the parser attaches a pressure series to the wrong tank row,
the diver can move it (two quality-inbox repairs exist) but the next re-parse
rebuilds tanks and series from the raw record and discards the correction.

## What already exists

- PR #1634 (2026-09-07) carries the transmitter serial from the
  libdivecomputer fork (`dc_tank_t.serial`, Shearwater and Halcyon Symbios
  parsers) through pigeon into `dive_tanks.transmitter_serial`. Every
  consumer compares serials through `normalizeTransmitterSerial`
  (`lib/features/dive_log/domain/services/transmitter_serial.dart`).
- `resolveParsedTanks` (`parsed_tank_resolver.dart`) is the one function both
  the download and re-parse paths pass every tank through. It mints the
  serial and infers the role from `dc_tank_t.usage`.
- `applyDefaultPresetToTanks` (`downloaded_tank_defaults.dart`) fills size
  from the default preset for back-gas tanks with no volume. It is called
  only from `dive_import_service.dart`, through an injected loader.
- `dive_tanks.equipment_id` exists, is synced, feeds equipment service
  clocks, and is written by nothing.
- Equipment cylinders (`EquipmentType.tank`) keep `volume_l`,
  `working_pressure_bar` and `tank_material` as attributes in
  `equipment_attributes`.
- `CylinderConfigItems` sets the snapshot rule: spec columns are copied at
  edit time with no FK to presets, so a later preset edit cannot change the
  meaning of a saved row.
- `swapTankPressureSeries` and `reassignTankPressureSeries`
  (`tank_pressure_repository.dart`) move packed series rows between tank ids
  and are invoked by the quality-inbox repairs.
- Re-parse (`reparse_service.dart`, `_carryOverTanks`) matches existing tank
  rows to parsed tanks by `tankOrder` and preserves user-authored columns on
  existing rows.

## Decisions

Each of these was chosen explicitly during design review.

| Decision | Choice |
| --- | --- |
| Registry key | Transmitter serial first; `(dive computer, channel index)` as the fallback for parsers that report no serial |
| Mapping target | Snapshot spec (role, volume, working pressure, material, preset name) plus an optional equipment cylinder link |
| UI home | Settings > Manage > Transmitters page, a count row on the dive computer detail page, and a caption or chip on the dive's cylinders card |
| Precedence | The entry always sets role, label, preset name and gear link; it fills volume, working pressure and material only when the computer reported none; gas mix is never touched |
| Existing dives | Download and re-parse apply the registry to newly inserted tank rows only; an explicit "Apply to existing dives" action per entry is the retroactive path |
| Unknown transmitter | An import summary notice with an action button, plus an info-severity data-quality finding with a navigation repair |
| Series reassignment (#1314) | A persisted `dive_tanks.source_tank_index` that re-parse keys on; swap and move-to from the cylinders card; existing inbox repairs become re-parse-proof |
| Uniqueness | Enforced in the repository, not by a database index, because sync can land two devices' rows before either sees the other |

## Section 1: Data model, schema, sync

### `transmitters` table (new, synced)

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text PK | UUID |
| `diver_id` | text, nullable FK divers | Same convention as `cylinder_configs` |
| `transmitter_serial` | text, nullable | Stored normalized via `normalizeTransmitterSerial` |
| `dive_computer_id` | text, nullable FK dive_computers, set null on delete | Fallback key, part 1 |
| `channel_index` | int, nullable | Fallback key, part 2; the libdivecomputer tank index |
| `label` | text | Free text shown to the diver ("O2", "S2", "T1") |
| `tank_role` | text | `TankRole.name` |
| `volume_l` | real, nullable | Snapshot |
| `working_pressure_bar` | real, nullable | Snapshot |
| `tank_material` | text, nullable | `TankMaterial.name`, snapshot |
| `preset_name` | text, nullable | Snapshot of the preset the specs came from |
| `equipment_id` | text, nullable FK equipment, set null on delete | Optional gear cylinder |
| `created_at`, `updated_at` | int | Epoch millis |
| `hlc` | text, nullable | Required by the sync guard tests |

Invariants, enforced by the repository:

- An entry carries a serial, or a computer plus channel index, or both.
- At most one entry per normalized serial per diver.
- At most one entry per `(dive_computer_id, channel_index)`.
- When sync lands a duplicate anyway, the matcher takes the most recently
  updated entry. The manage page shows both so the diver can delete one.

### `dive_tanks.source_tank_index` (new column)

Nullable int. The parsed tank index whose computer-reported data (pressure
series, transmitter serial, start and end pressure, gas mix) this row holds.
Download and re-parse inserts write it equal to the index. Null on legacy
rows means "same as `tankOrder`". No data rewrite in the migration.
`dive_tanks` syncs whole-row, so no serializer work.

### Schema and sync registration

- One rung, v200 (main shipped v199 on 2026-09-08 for certifications), creating `transmitters` and adding
  `dive_tanks.source_tank_index`. Rescan open PR diffs and worktree scalars
  for `currentSchemaVersion` immediately before taking the rung and again
  after every merge of main.
- `_assertTransmitterTables()` with `CREATE TABLE IF NOT EXISTS`, called from
  the rung and from the `beforeOpen` backstop, like weight presets (#1623).
- Sync follows the weight-presets commit exactly: `hlcTargets` in
  `sync_repository.dart`; the seven `sync_data_serializer.dart` edits and the
  seven `case` arms; `mergeOrder` after `equipment` and `diveComputers`;
  `entityHasUpdatedAt`; `parentRefs` with `equipmentId` and `diveComputerId`
  both nullable.
- `migration_v200_transmitters_test.dart` pins the rung (fresh database and
  stranded-at-199 cases) and hands the "relax to greaterThanOrEqualTo"
  instruction forward; `migration_v199_*` is relaxed if it pins equality.

### Domain

- `Transmitter` entity with `copyWith`, in
  `lib/features/transmitters/domain/entities/`.
- `TransmitterRepository` (Drift) in `lib/features/transmitters/data/`:
  CRUD, `getForDiver`, `getUnassignedSerials(diverId)` (distinct
  `dive_tanks.transmitter_serial` on the diver's dives with no entry, with
  dive counts), and `applyToExistingDives(entryId)`.
- `TankData` and `DownloadedTank` gain `equipmentId` and `tankName`;
  `importProfile` writes both into `DiveTanksCompanion`, which today writes
  neither.
- `EquipmentItem` gains typed getters `volumeL`, `workingPressureBar`,
  `tankMaterial`; the tank attribute keys in `equipment_attribute_catalog`
  become constants.

## Section 2: Matching and pipeline integration

### Matcher

`lib/features/dive_computer/data/services/transmitter_registry_matcher.dart`:

```
class TransmitterMatcher {
  factory TransmitterMatcher.fromEntries(List<Transmitter> entries);
  Transmitter? match({String? serial, String? computerId, required int index});
}

List<DownloadedTank> applyTransmitterRegistry(
  List<DownloadedTank> tanks,
  TransmitterMatcher matcher, {
  required String? computerId,
});
```

Per tank, in order:

1. The tank's normalized serial is in the serial map: apply that entry.
2. `(computerId, tank.index)` is in the fallback map: apply that entry.
3. Otherwise the tank is returned unchanged.

Applying an entry always sets `role`, `equipmentId`, `presetName` and
`tankName` (from `label`), and sets `volumeLiters`, `workingPressure` and
`material` only when the tank has none (null or zero means unreported
throughout the tank code). Gas mix, pressures and serial are untouched. The
function is pure and returns a new list.

### Call sites

- Download: `dive_import_service.dart` gets a second injected loader,
  `TransmitterMatcherLoader`, beside `DefaultTankPresetLoader`, wired in
  `download_providers.dart`. Inside `_importNewDive` the order is registry
  first, then `applyDefaultPresetToTanks`, so the default preset only fills
  back-gas tanks the registry did not claim. All three entry points (batch,
  single as new, conflict resolution) share the seam.
- Re-parse: `ReparseService` takes the matcher the way it takes
  `trimTankPressureAtSurfacing` (constructor, provided by
  `reparse_providers.dart`) and applies it only in the branch of
  `_carryOverTanks` that inserts a new row. Existing rows keep the rule that
  user-authored columns are not touched.
- Consolidation: no hook. Secondary tanks are copied row for row, so
  registry-applied fields ride along.

### Error handling

A registry load failure is logged and degrades to an empty matcher; a
download never fails because of the registry. An entry whose equipment item
was deleted still applies its snapshot specs; the FK is already null via set
null.

## Section 3: Manage page, editor, detail surfaces

### Settings > Manage > Transmitters

Follows `dive_roles_page.dart`: lower-right extended FAB to add, inline edit
and delete icons per row, no app-bar plus, no row overflow menu. Route
`/settings/manage/transmitters`, with an optional `serial` query parameter
that opens the editor prefilled.

Two lists:

- Entries: label, serial or "Computer name, channel N", role, volume in the
  diver's volume unit, working pressure in the diver's pressure unit, linked
  gear name when set. Each row has "Apply to existing dives" (Section 5).
- Seen in downloads, not assigned: from `getUnassignedSerials`, each with a
  dive count and an Assign button that opens the editor with the serial
  prefilled. The provider ticks on `dive_tanks` and `transmitters` changes.

### Editor (full-screen form page)

Fields: label, serial (text, normalized on save), optional computer plus
channel picker for the fallback key, role dropdown, equipment cylinder picker
filtered to `EquipmentType.tank`, tank preset dropdown, volume, working
pressure and material in the active diver's units.

Picking gear copies its three attributes into the spec fields; picking a
preset copies the preset and stores `preset_name`. The spec fields stay
editable afterward (snapshot rule).

Validation: a serial or a computer plus channel is required; volume and
pressure must be positive when set; a duplicate serial for this diver is
refused with a message naming the existing entry.

### Dive computer detail page

A Transmitters row in the info card after the linked gear row: "3 known,
1 unassigned" for serials seen on that computer's dives, tapping through to
the manage page. Hidden when the computer's dives carry no serials.

### Cylinders card on the dive detail page

Each tank tile gets a caption under the source badge, "Transmitter 180777",
when the tank carries a serial. When that serial has no entry the caption is
a tappable "Assign transmitter" chip that opens the editor prefilled. This
also closes the PR #1634 follow-up to show the serial.

## Section 4: Import notice and data-quality finding

### Import summary notice

`ImportNoticeKind.unknownTransmitter`. `DiveComputerAdapter.performImport`,
which emits no notices today, counts distinct unmatched serials and reports
one grouped notice. The summary card follows the existing `noTankPressure`
card but adds an action button that opens the manage page. All locales get
the strings.

### Data-quality finding

Detector `unknown_transmitter`, version 1, category `tank`, severity `info`:

- `DiveQualityContext` gains `knownTransmitterSerials` (a set), loaded once
  per scan batch by `QualityContextBuilder` through the transmitter
  repository, cached per diver like `ppO2MaxBar`.
- Fires once per dive per downloaded tank whose normalized serial is not in
  the set. Params: `tankId`, `serial`. Discriminator is the serial, so the
  finding is stable across rescans.
- Repairs: a new navigation-only `AssignTransmitterRepair(serial)` that opens
  the editor prefilled, plus `GoToDiveRepair`. No executor work.
- Once an entry exists the next scan no longer produces the finding and the
  scan service's resolve-on-absence handling closes it. If that handling
  turns out not to resolve absent findings, the plan adds it.
- Registered in `quality_detector_registry` with a toggle like the others.

The finding and the manage page's unassigned list derive from the same
repository query, so they cannot disagree.

## Section 5: Retroactive apply, error handling, testing

### "Apply to existing dives"

Offered on each entry row and once as a snackbar action after saving an
entry from an Assign flow. One repository transaction over the diver's
`dive_tanks` rows whose normalized serial matches (or, for a fallback entry,
tanks on that computer's dives at that index):

- fills `volume`, `working_pressure`, `tank_material`, `preset_name`,
  `equipment_id` and `tank_name` only where empty;
- sets `tank_role` only when the row is still `backGas`, the uninformed
  default; a role inferred as oxygen or diluent, or one the diver changed,
  is left alone;
- reports "Updated N cylinders on M dives"; SAC recomputation follows the
  existing metrics path.

A confirmation dialog states the counts before writing. Editing an entry
later never runs this automatically.

### Error handling

Registry load failures degrade to no mapping. Editor validation rejects a
missing key, non-positive specs and duplicate serials. The batch action runs
in one transaction. Every repository call uses try/catch with logged errors.

## Section 6: Per-dive series reassignment (#1314)

### Re-parse replays the assignment

`_carryOverTanks` matches existing rows by
`(computerId, source_tank_index ?? tankOrder)` instead of `tankOrder` alone,
so a swapped row keeps receiving the swapped transmitter's series, serial and
pressures on every future re-parse. Consolidation carries tank rows
verbatim, so the column rides along per computer.

### Swap and reassign

One repository operation in `tank_pressure_repository.dart` updates
`source_tank_index` on the affected rows and moves the series rows in the
same transaction:

- Swap exchanges the two rows' indices and series.
- Reassign moves the index and series from the source row to the target
  row. The target's previous series, if any, moves back to the source so
  nothing is orphaned.

The existing `swapPressureSeries` and `reassignPressureSeries` executor
methods call the new operation, so the quality-inbox repairs become
re-parse-proof with their undo closures unchanged.

### UI

The cylinders card gains a "Reassign pressure series" action, shown only when
the dive has two or more tanks with series from one computer. It opens a
sheet listing each series against its tank: tank label, start to end
pressure in the diver's pressure unit, sample count, transmitter serial. Two
tanks get a Swap button; more get a per-row "Move to" using the existing
`showReassignTankPicker`. The change applies with an undo snackbar reusing
the executor's `RepairResult` undo closure.

### Registry interplay

A swap also exchanges the rows' serials, so an entry's "Apply to existing
dives" still targets the right cylinder afterward. The registry decides size
and role at import; the reassignment decides which row a series lands on.
They are independent.

## Testing (TDD throughout)

- Matcher: serial match, fallback match, no match, computer-reported volume
  preserved, role overridden, Teric twin (two tanks, one serial, one entry),
  normalized serial comparison, most-recent entry wins on duplicates.
- Repository: CRUD, uniqueness refusal, unassigned-serial query, batch apply
  fills only empty fields and changes role only from `backGas`.
- Migration v200 fresh and stranded cases; the four sync guard suites
  (`sync_base_streaming_parity_test`, `sync_hlc_target_registration_test`,
  `hlc_column_test`, `sync_parent_refs_completeness_test`).
- Import service and re-parse: registry before preset; new rows only on
  re-parse; `source_tank_index` written on insert.
- Series reassignment: swap, three-tank move, re-parse of a swapped dive
  yields the same assignment, consolidation copies the column.
- Detector, `repairOptionsFor` mapping, notice grouping.
- Widgets, each with a locale host: manage page (FAB, inline icons,
  unassigned list, Assign prefill), editor (validation, gear and preset
  copy, units), computer detail row, cylinders card caption and chip,
  summary notice card, reassignment sheet.

## Out of scope

- FIT `sensorId` feeding `transmitter_serial`.
- A `usage` versus registry role conflict finding.
- Role-aware statistics (#771 gains role data from imports without changes).
- Extending the fork's serial coverage to more brands.
- Automatic re-application when an entry is edited.

## Sequencing hint for the plan

1. Schema rung, entity, repository, sync registration (guard tests green).
2. Matcher and pipeline integration (download, re-parse).
3. `source_tank_index` and the swap or reassign rewrite (#1314 core).
4. Manage page and editor.
5. Detail surfaces: computer row, cylinders card caption, reassignment sheet.
6. Import notice and data-quality finding.
7. Apply to existing dives.
8. l10n for every locale, `dart format .`, full analyze and test run.
