# Cylinder passports: fleet phase

Date: 2026-10-12
Issue: #2650 (follows #2333; non-goal in section 4 and follow-up in section 18
of [the passports spec](2026-09-25-smart-cylinder-passports-design.md))

## 1. Problem

A dive tank built from a scanned cylinder tag is a copy: `tankFromPassport`
and the tank editor fill the spec and mix, and nothing on the tank remembers
which physical cylinder it was. So a rental cylinder scanned at the same shop a
year later looks brand new, and an owned cylinder's passport cannot say how
often it has been dived.

## 2. Decisions

Made during brainstorming on 2026-10-12.

| Question | Decision |
| --- | --- |
| Storage | A nullable `passport_id` column on `dive_tanks`, not a link table |
| What "recognise" shows | A count, the last-used date and the dives themselves (date, site), each opening the dive. Derived from `dive_tanks`; no per-cylinder notes, no new table |
| Which tanks are stamped | Every tank identified by a tag: foreign scans and "Use on a dive", and the diver's own cylinders whether scanned, picked from "My cylinders" or chosen in the preset dropdown, when the cylinder has a passport id |
| When it changes | A newer cylinder choice replaces or clears it: another scan, another own cylinder, a preset, a trip slot. Typing volume, pressure or mix by hand keeps it. Copies for a new dive never carry it |
| Visible link on the tank | None: no "from tag" chip and no unlink control |

## 3. Goals

- A dive tank records the passport id of the cylinder it was filled from, and
  every path that rewrites tank rows keeps it.
- The foreign passport of a cylinder the diver has used before says so:
  "You have used this cylinder N times", the last date, and the dives.
- The diver's own passport shows the same card, as "Used on N dives".
- A scan in the tank editor of a foreign cylinder used before says how often.

## 4. Non-goals

- Backfilling existing dives. Nothing records which tag an old tank came from;
  counts start with this release.
- Notes kept on a rental cylinder. The dive center gear notes (rental gear
  memory, #2075) already cover per-operator quirks.
- Showing the link on the dive detail page or the tanks card.
- Writing `dive_tanks.equipment_id`, which stays the transmitter registry's.
- UDDF or CSV export of the column. The `.db` backup and sync carry it.

## 5. Data

### 5.1 Column

`dive_tanks.passport_id TEXT NULL`, rung 287 (284, 285 and 286 went to
#3012, #3306 and #3319 on main; 282 is held by open PR #3133). No foreign key: a rental's
passport id has no `equipment` row, and an owned cylinder's id is an
attribute value, not a key. No backfill.

Index, asserted in the migration helper and in `performance_indexes.dart`:

```
CREATE INDEX IF NOT EXISTS idx_dive_tanks_passport_id
  ON dive_tanks(passport_id)
```

The migration follows the ladder convention: the column in
`lib/core/database/tables/dive_tables.dart`, an idempotent add-column helper
in `lib/core/database/migrations/`, `if (from < 287)` in `onUpgrade`, the
`currentSchemaVersion` constant and the `migrationVersions` list. Nothing goes
into `database.dart` beyond the version constant and the ladder call.

### 5.2 Entity

`DiveTank.passportId` (`String?`), with `copyWith(passportId:)`,
`clearPassportId`, and `props`. Every mapper between rows and the entity
reads and writes it.

### 5.3 Paths that keep it

The rule: `passport_id` travels wherever `tripCylinderId` travels today.
That includes:

- `DiveRepository` create and update (`dive_repository_impl.dart`), and
  `_tankCompanion`, which bulk add and bulk replace share.
- `BulkDiveEditService._tanksFromRows` (bulk-edit undo).
- `sequential_tank_merge.dart`: the earlier tank's id, else the later one's.
- Paths that copy a whole row (`row.toCompanion(false)`), such as the merge
  undo in `dive_merge_service.dart` and `dive_uncombine_service.dart`, carry
  it with no change; a test pins one of them.
- Sync: `dive_tanks` rows sync as whole Drift JSON objects, so the column
  rides along; a round-trip test pins it.

The plan walks every `DiveTanksCompanion(` and `de.DiveTank(` construction
site in `lib/` and classifies each as keep (5.3) or drop (5.4).

### 5.4 Paths that drop it

- "Apply last dive" (`RentalMemory.tanksForNewDive`): a new dive's tank is
  whichever cylinder the shop hands over this time.
- Planner conversions (`dive_to_plan_converter.dart`, the plan file codec).
- Computer download, re-parse and re-import never write it. They update
  existing tank rows with partial companions that name only computer-owned
  columns, so the user-authored `passport_id` survives, as `tripCylinderId`
  and `regulatorEquipmentId` do.

### 5.5 Usage query

`PassportUsageRepository.usageFor(passportId, {required diverId,
excludeDiveId})` in `lib/features/cylinder_passports/data/repositories/`
returns `PassportUsage`: the distinct dives owned by `diverId` with a tank
whose `passport_id` matches, as `(diveId, diveDateTime, diveNumber,
siteName)`, newest first. A dive with two tanks from one tag counts once.
A planned dive (`is_planned`) does not count: it has not happened yet
(review, 2026-10-12).
`excludeDiveId` leaves out the dive being edited (section 6.4).

## 6. Stamping

### 6.1 Tank editor

`tank_editor.dart` already bumps `_specChoice` on every cylinder choice. Each
choice sets the passport id together with the spec:

| Choice | `passportId` |
| --- | --- |
| Scan, foreign cylinder | the tag's id |
| Scan, own cylinder | the tag's id |
| "My cylinders" pick, or a cylinder chosen in the preset dropdown | the cylinder's `passport_id` attribute, or cleared when it has none |
| A preset | cleared |
| The None preset | cleared |
| A trip cylinder slot | cleared |
| The None slot | kept: it unlinks the slot, it is not a cylinder choice (decided at plan time, 2026-10-12) |
| Volume, working pressure, material, mix or pressures typed by hand | kept |

A scan or pick that loses the `_specChoice` race changes nothing, passport id
included.

### 6.2 Foreign passport

"Use on a dive" builds its `DivePrefill` tank with `tankFromPassport`, which
sets `passportId: tag.passportId`.

### 6.3 Not stamped

The dive edit page's gear scan (`scan_owned_item.dart`) adds an item to the
dive's gear list, not a tank, so it stamps nothing.

### 6.4 Scan feedback

When a scan in the tank editor resolves to a foreign cylinder with earlier
uses (the dive being edited excluded), the snack bar "Filled from <name>"
becomes "Filled from <name>. Used on N earlier dives." Own cylinders keep
today's message.

## 7. UI

### 7.1 `PassportUsageCard`

In `lib/features/cylinder_passports/presentation/widgets/`, fed by
`passportUsageProvider(passportId)`, a family that watches the active diver.

- Header: "You have used this cylinder N times" on the foreign page, "Used on
  N dives" on the own page (ICU plurals), then "Last used <date>".
- Rows: newest first; date, site name ("No site" when none) and the dive
  number when the dive has one. A tap pushes `/dives/:id`.
- The first five rows show; "Show all N" expands the card in place.
- Zero uses: the card is not shown.
- A load error is logged and the card shows one line, "Could not load your
  dives with this cylinder". The page around it still renders.
- Dates go through `UnitFormatter` in the diver's settings.

### 7.2 Placement

- `ForeignPassportPage`: directly below the "Not in your gear" info card,
  above the spec rows.
- `PassportPage`: after Fill history, before Tag, only when the cylinder has a
  passport id.

### 7.3 Strings

New keys under `passport_usage_*` in every ARB file, plus the scan snack bar
variant. Generated l10n files are committed.

## 8. Error handling

- The usage query is read-only; a failure degrades to the error line in 7.1.
- Stamping adds no new failure mode: the passport id is set in the same
  `setState` and `onChanged` as the spec it came with.

## 9. Testing

- Migration: a v286 database upgrades to 287 with the column and index; a
  fresh database has both.
- Repository round trips: create, update, bulk replace then undo, and a
  sequential merge all keep `passport_id`.
- Sync: a serializer round trip of a `dive_tanks` row keeps the column.
- Usage repository: active-diver filter, one count per dive for two matching
  tanks, newest first, `excludeDiveId`.
- Tank editor: one test per row of the table in 6.1, and a lost race leaves
  the id alone.
- `tankFromPassport` sets the id; `tanksForNewDive` drops it.
- `PassportUsageCard`: hidden at zero, five-row cap with Show all, a tap
  navigates, the error line; shown on both pages in the right place.
- The scan snack bar names the earlier-use count and excludes the current
  dive.

## 10. Delivery

One PR, closing #2650.
