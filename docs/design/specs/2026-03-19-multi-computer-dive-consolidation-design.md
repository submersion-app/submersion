# Multi-Computer Dive Consolidation

## Overview

Divers often wear two or more dive computers for redundancy. Each computer records its own dive data independently. Submersion should import data from multiple computers for the same dive, consolidate them into a single dive record, and allow the user to visualize and compare each computer's data.

## Goals

- Import dive data from multiple computers and associate them with the same dive record
- Preserve all metadata from each computer without data loss
- Overlay multiple computers' depth profiles on the dive profile chart with per-computer toggles
- Allow users to switch which computer is the "primary" source of truth for dive metadata
- Support consolidation both during import (auto-detected) and post-import (manual merge)
- Support reversing a consolidation (unlinking a computer back to a standalone dive)
- Zero impact on existing single-computer dives

## Data Model

### New Table: `dive_computer_data`

A junction table storing per-computer metadata snapshots for each dive. Only populated for multi-computer dives -- back-filled on first consolidation.

| Column | Type | Description |
|--------|------|-------------|
| `id` | text (PK) | UUID |
| `diveId` | text (FK -> dives) | Cascade delete |
| `computerId` | text (nullable, FK -> dive_computers) | References `DiveComputers.id`. Nullable for imports where no paired device exists in the app. |
| `isPrimary` | boolean | Which computer's data populates the `dives` record |
| `computerModel` | text (nullable) | e.g., "Shearwater Perdix". Denormalized snapshot -- preserved even if the `DiveComputers` record is later deleted or modified. Also serves imports where no `DiveComputers` record exists. |
| `computerSerial` | text (nullable) | Serial number. Denormalized snapshot, same rationale as `computerModel`. |
| `sourceFormat` | text (nullable) | Import format (UDDF, FIT, CSV, etc.) |
| `maxDepth` | real (nullable) | This computer's max depth reading |
| `avgDepth` | real (nullable) | Average depth |
| `duration` | integer (nullable) | Duration in seconds |
| `waterTemp` | real (nullable) | Water temperature |
| `entryTime` | dateTime (nullable) | When this computer recorded dive start |
| `exitTime` | dateTime (nullable) | When this computer recorded dive end |
| `maxAscentRate` | real (nullable) | Max ascent rate recorded |
| `maxDescentRate` | real (nullable) | Max descent rate recorded |
| `surfaceInterval` | integer (nullable) | Surface interval in minutes |
| `cns` | real (nullable) | CNS % at end of dive |
| `otu` | real (nullable) | OTU accumulated |
| `decoAlgorithm` | text (nullable) | Algorithm used (Buhlmann, VPM-B, etc.) |
| `gradientFactorLow` | integer (nullable) | GF low setting |
| `gradientFactorHigh` | integer (nullable) | GF high setting |
| `importedAt` | dateTime | When this computer's data was added |
| `createdAt` | dateTime | Row creation time |

### Relationships

```
dives (1) ---- (*) dive_computer_data   (metadata per computer)
dives (1) ---- (*) dive_profiles        (time-series per computer, already exists)
```

The `computerId` field ties `dive_computer_data` rows to their corresponding `dive_profiles` rows -- same computer ID in both tables for a given dive.

### Domain Entity: `DiveComputerReading`

A new clean Dart entity with `copyWith`, mapping to/from the `dive_computer_data` table. Loaded alongside dive detail (not in list views).

### Single-Computer Dive Behavior

Dives with a single computer have no `dive_computer_data` rows. The `dives` table remains the sole source of metadata. No migration of existing data is needed. The `dive_computer_data` table is only populated on first consolidation, at which point rows are back-filled for both the existing primary computer and the new secondary computer.

## Import Consolidation Flow

### During-Import Consolidation

The existing `ImportDuplicateChecker` detects potential duplicates using time/depth matching with confidence levels (`exact`, `likely`, `possible`, `none`). This is extended with a new resolution option:

**Current flow:**
```
Import file -> Parse -> Duplicate check -> Skip / Replace / Import as New
```

**Extended flow:**
```
Import file -> Parse -> Duplicate check -> Skip / Replace / Import as New / Consolidate
```

When a match is detected with `likely` or `exact` confidence, the "Consolidate as additional computer" option appears. The UI shows:

1. The matched existing dive (date, site, depth, duration)
2. The new import's dive data alongside it
3. A "Consolidate as additional computer" button

**On consolidate:**

- The new computer's profile data is inserted into `dive_profiles` with `isPrimary = false` and the new computer's ID
- A new `dive_computer_data` row is created with the new computer's metadata
- If this is the first consolidation for this dive, a `dive_computer_data` row is also back-filled for the existing primary computer (extracting its metadata from the `dives` record)
- The `dives` record itself is unchanged -- primary computer's values stay

### Post-Import Merge (from Dive Detail)

A "Merge with another dive" action available from the dive detail screen overflow menu:

1. User taps the action on a dive
2. App shows a filtered list of candidate dives within the same calendar day, sorted by time proximity, excluding already-merged computers
3. User selects the dive to merge
4. Confirmation screen shows both dives side-by-side: "Keep [Dive A] as primary, add [Dive B]'s computer data?"
5. On confirm:
   - Dive B's profile data gets re-parented to Dive A (update `diveId` on its `dive_profiles` rows, set `isPrimary = false`)
   - A `dive_computer_data` row is created from Dive B's metadata
   - Back-fill primary computer's `dive_computer_data` row if needed
   - The confirmation screen warns the user what data from Dive B will be discarded (tanks, equipment links, notes, buddy, rating, etc.). The user must acknowledge before proceeding.
   - Dive B is deleted after acknowledgment
6. The merge is reversible via an "Unlink computer" action (though user-entered contextual data from the deleted Dive B is not recoverable)

## Profile Visualization

### Dual-Control Architecture

Two independent, orthogonal controls determine what appears on the chart:

1. **Data type toggles (top bar)**: Existing toggle pills controlling which data types are visible (Depth, Ceiling, NDL, SAC, CNS, TTS, Temp, Pressure, ppO2, Ascent Rate, RBT, Deco Type, Setpoint). These control WHAT to show.

2. **Computer checkboxes (bottom legend bar)**: Per-computer toggle checkboxes. These control WHOSE data to show.

The two controls compose: if Ceiling is toggled on and both computers are checked, two ceiling curves appear (one per computer in their assigned colors). If only one computer is checked, only that computer's ceiling curve appears. If Ceiling is toggled off, no ceiling curves appear regardless of computer selection.

### Visual Encoding

- **Primary computer**: Solid line, full opacity
- **Secondary computer(s)**: Dashed line
- **Color palette**: Cyan (primary), orange, green, magenta (supports up to 4 computers). If a fifth+ computer is added, colors cycle from the beginning with reduced opacity to differentiate.
- **Max depth markers**: Shown per visible computer in its assigned color
- **Timestamp cursor**: Shows readings from all visible computers simultaneously

### Data Type Categorization

All data types from `dive_profiles` follow the same toggle model:

**Observed data** (direct sensor readings):
- Depth, temperature, pressure, heart rate

**Calculated/algorithm-dependent data**:
- Ceiling, NDL, ascent rate, CNS, TTS, RBT, deco type, setpoint, ppO2

Both observed and calculated data types are controlled by the same two orthogonal controls (data type toggles x computer checkboxes).

### Single-Computer Dives

No computer toggle bar is shown. Chart behavior is identical to current implementation.

## Dive Detail -- Computer Metadata Comparison

### Multi-Computer Dive Detail

When a dive has multiple computers, a "Computers" section appears on the dive detail screen showing a compact card per computer:

```
+---------------------------------------------+
|  Computers (2)                              |
+---------------------------------------------+
|  * Shearwater Perdix (primary)              |
|  Max: 30.2m  Avg: 18.4m  Duration: 42:15   |
|  Temp: 26.1C  CNS: 12%  GF: 30/70          |
+---------------------------------------------+
|  Garmin Descent Mk3                         |
|  Max: 29.8m  Avg: 18.1m  Duration: 41:58   |
|  Temp: 26.3C  CNS: 14%                     |
+---------------------------------------------+
```

### Actions

- **Set as primary**: Tapping a secondary computer card offers to promote it to primary. This updates the `dives` record with that computer's metadata values and swaps the `isPrimary` flags on the `dive_computer_data` rows.
- **Unlink computer**: Available from the card's overflow menu. Reverses a consolidation by reconstructing a standalone dive from the detached computer's data.

### Single-Computer Dives

No "Computers" section is shown. Dive detail behavior is identical to current implementation.

## Profile Editing with Multiple Computers

Edits create a new "user-edited" profile layer. Original computer profiles remain untouched.

### Flow

1. User opens the profile editor on a multi-computer dive
2. User chooses which computer's profile to start editing from (or the existing user-edited layer if one exists)
3. The edited profile is saved as a new `dive_profiles` entry with `computerId = null` and `isPrimary = true`
4. All original computer profiles retain `isPrimary = false` and remain untouched
5. In the chart, the user-edited profile appears as its own entry in the computer toggles:

```
Computers:  [x] User edited (primary)
            [x] Shearwater Perdix
            [ ] Garmin Descent Mk3
```

### Revert

"Revert to original" removes the user-edited layer and restores the previous primary computer's `isPrimary = true` flag. This is consistent with how `saveEditedProfile()` already works.

## Unlink Computer (Merge Reversal)

When a user unlinks a secondary computer from a consolidated dive:

1. A new `dives` record is created, populated from the `dive_computer_data` row for that computer
2. The detached computer's `dive_profiles` rows get their `diveId` updated to the new dive
3. The `dive_computer_data` row is moved to the new dive and marked `isPrimary = true`
4. If the unlinked computer was the primary, the next computer in the list is auto-promoted to primary on the original dive, and its metadata repopulates the `dives` record
5. If only one computer remains on the original dive after unlinking, the remaining `dive_computer_data` row is cleaned up (deleted), restoring the dive to standard single-computer behavior where the `dives` table is the sole source of metadata

### Edge Cases

- User-edited fields on the consolidated dive (notes, buddy, site, rating, etc.) stay on the original dive. The unlinked dive gets only what came from the computer data -- the user may need to re-add contextual info.
- If a user-edited profile layer exists and the computer it was based on is unlinked, the user-edited layer stays on the original dive.

## Testing Strategy

- Unit tests for `DiveComputerReading` entity and its `copyWith`
- Unit tests for back-fill logic (extracting metadata from `dives` record into `dive_computer_data`)
- Unit tests for merge and unlink operations in the repository layer
- Integration tests for import consolidation flow (time-window matching + consolidation resolution)
- Integration tests for post-import merge from dive detail
- Widget tests for the computer toggle bar in the profile chart
- Widget tests for the "Computers" section in dive detail
- Widget tests for "Set as primary" and "Unlink computer" actions
