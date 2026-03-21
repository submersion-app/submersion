# Consolidation Comparison Card Redesign

## Problem

When downloading dives from a second computer, the app detects potential duplicate dives and presents a comparison card with Skip/Import as New/Consolidate actions. The current card has two problems:

1. **The side-by-side columns show redundant matching data** -- the user sees the same date, same depth repeated on both sides, making it hard to spot what actually differs.
2. **The action buttons lack explanation** -- "Consolidate", "Import as New", and "Skip" give no indication of what each action does to the dive log.

## Design: Hybrid Card

Replace the current side-by-side `_buildCandidateCard` with a hybrid layout that shows shared data once, overlays profiles for instant visual comparison, and highlights only differences.

### Card Sections (top to bottom)

#### 1. Match Header

A compact bar containing:
- **Match percentage badge** (e.g., "98%") with color coding based on `DuplicateConfidence`: green for exact/likely, amber for possible
- **Shared dive data shown once**: date/time and max depth (when they match)

This immediately answers "when was this dive?" without the user scanning two columns.

#### 2. Overlaid Profile Charts

Both dive profiles rendered on a **single chart** using `DiveProfileMiniChart`-style rendering:
- **Existing dive profile**: solid line in `colorScheme.primary`
- **Downloaded dive profile**: dashed line in `colorScheme.secondary`
- **Legend** below the chart identifying each line with computer name and serial (truncated)

The chart should use the same scale for both profiles (shared min/max depth and time range) so shape differences are immediately visible. Height: ~80px (taller than the list tile mini charts for better comparison).

Data sources:
- Existing dive profile: fetch via `diveProfileProvider(diveId)` -- returns `List<DiveProfilePoint>`
- Downloaded dive profile: convert `DownloadedDive.profile` (`List<ProfileSample>`) to `List<DiveProfilePoint>` via mapping `timeSeconds` -> `timestamp`, `depth` -> `depth`

Implementation: Create a new `OverlaidProfileChart` widget that accepts two `List<DiveProfilePoint>` lists and renders them on a single `LineChart` (from fl_chart) with shared axes. This is a variation of the existing `DiveProfileMiniChart` but with two `LineChartBarData` entries instead of one.

**Empty profile handling**: If only one profile is available, render a single-line chart for that profile. If both are empty, show a "No profile data" text placeholder instead of the chart. The legend should only show entries for profiles that are present.

#### 3. Same Fields Summary

A compact single-line row with a green checkmark listing fields that match:
- "Same: date/time, max depth (2.2m)"

Fields to compare: time (within ~60s tolerance), `maxDepth` (within 0.5m), `avgDepth` (within 0.5m), `duration` (within 60s), `waterTemp` (within 1C).

**Field mapping note**: The existing `Dive` entity uses `effectiveEntryTime` (getter returning `entryTime ?? dateTime`) for comparison against `DownloadedDive.startTime`. Duration comparison maps `Dive.duration?.inSeconds` against `DownloadedDive.durationSeconds`. Temperature maps `Dive.waterTemp` against `DownloadedDive.minTemperature`.

Only list fields that both dives have values for AND that match within tolerance. If all comparable fields match, show "Same: all fields".

#### 4. Differences Table

A grid showing **only rows where values differ**, with three columns:
- Field label (left)
- Existing dive value (center)
- Downloaded dive value (right, with highlighting)

Column headers: blank | "Existing (#N)" | "Downloaded"

**Always-shown rows** (since they differ by definition):
- Computer: model + truncated serial

**Conditionally-shown rows** (only when values differ beyond tolerance):
- Duration: show delta in parentheses, e.g., "1 min (+1)"
- Max depth: show delta
- Avg depth: show delta
- Water temp: show delta or "not recorded" if one side is null

Styling:
- Changed values in amber/warning color
- Missing values in italic secondary text: "not recorded"
- Delta values shown in parentheses next to the downloaded value
- All depth and temperature values formatted through `UnitFormatter` to respect the active diver's unit settings (metric/imperial)

If no fields differ beyond the computer identity, collapse this section to just the computer row.

#### 5. Action Buttons with Subtitles

Three buttons in a row, each with a primary label and a one-line description below:

| Button | Label | Subtitle | Style |
|--------|-------|----------|-------|
| Skip | Skip | "Discard this download" | Text only (de-emphasized) |
| Import as New | Import as New | "Save as separate dive" | Outlined |
| Consolidate | Consolidate | "Add as 2nd computer reading" | Filled tonal (subtle highlight) |

Skip is de-emphasized since it's the least common action for high-confidence matches. Consolidate gets a subtle highlight as the most common action.

### Comparison Logic

The card needs a helper that compares the existing `Dive` with the `DownloadedDive` and produces:
- `sameFields`: list of field names + values that match within tolerance
- `diffFields`: list of `{field, existingValue, downloadedValue, delta?}` entries

This can be a pure function or a small class: `DiveComparisonResult compareForConsolidation(Dive existing, DownloadedDive downloaded)`.

Tolerances:
- Time: 60 seconds
- Depth: 0.5m
- Temperature: 1.0C
- Duration: 60 seconds

### Files to Modify

| File | Change |
|------|--------|
| `lib/features/dive_computer/presentation/widgets/summary_step_widget.dart` | Replace `_buildCandidateCard`, `_buildExistingDiveColumn`, `_buildImportedDiveColumn` with the new hybrid card layout |
| (none -- `dive_profile_chart.dart` is already 3000+ lines, so the new chart goes in its own file) | |

### New Files

| File | Purpose |
|------|---------|
| `lib/features/dive_computer/presentation/widgets/dive_comparison_helpers.dart` | `DiveComparisonResult` class and `compareForConsolidation()` function |
| `lib/features/dive_computer/presentation/widgets/overlaid_profile_chart.dart` | `OverlaidProfileChart` widget (two-line variant of `DiveProfileMiniChart`) |

### What Does NOT Change

- The `DuplicateCandidate` data model
- The `DownloadNotifier` actions (consolidateDive, importCandidateAsNew, skipConsolidation)
- The "Consolidate All" button behavior
- The "Potential Matches (N)" section header
- The gating logic (downloaded dives / action buttons hidden until matches resolved)

## Testing

- Unit test for `compareForConsolidation()` with cases: all fields same, some differ, missing fields on one side, edge cases at tolerance boundaries
- Widget test for the new card rendering with mock dive data
