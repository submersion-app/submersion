# Consolidation Comparison Card Redesign

## Problem

Two separate import flows detect potential duplicate dives and present resolution options, but both have UX problems:

**1. Dive computer download** (`summary_step_widget.dart`): Shows a side-by-side comparison card with Skip/Import as New/Consolidate actions. The columns show redundant matching data, and the buttons lack explanation of what each action does.

**2. File import** (`import_dive_card.dart`): Shows a compact card with ChoiceChip resolution options but no comparison detail at all -- the user sees a match percentage badge but has no way to compare the existing dive with the imported one to make an informed decision.

Both flows need the same thing: a clear, detailed comparison that highlights differences and explains actions.

## Design: Hybrid Card

Replace the current side-by-side `_buildCandidateCard` with a hybrid layout that shows shared data once, overlays profiles for instant visual comparison, and highlights only differences.

### Card Sections (top to bottom)

#### 1. Match Header

A compact bar containing:
- **Match percentage badge** (e.g., "98%") with color coding derived from score thresholds: green for >= 0.9 (high confidence), amber for >= 0.7, red-ish for < 0.7 (since the file import flow uses `DiveMatchResult` which has no `DuplicateConfidence` enum, score-based thresholds work for both flows)
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

The card needs a helper that compares the existing `Dive` with the incoming dive data and produces:
- `sameFields`: list of field names + values that match within tolerance
- `diffFields`: list of `{field, existingValue, downloadedValue, delta?}` entries

#### Unified incoming dive data model

The two import flows use different data types for incoming dives:

- **Dive computer download**: `DownloadedDive` with typed fields and `List<ProfileSample>`
- **File import**: `Map<String, dynamic>` with typed values (see mapping table below)

To avoid duplicating comparison logic, introduce a lightweight `IncomingDiveData` class that normalizes both sources:

```dart
class IncomingDiveData {
  final DateTime? startTime;
  final double? maxDepth;
  final double? avgDepth;
  final int? durationSeconds;
  final double? waterTemp;
  final String? computerModel;
  final String? computerSerial;
  final List<DiveProfilePoint> profile;
  final String? siteName;

  factory IncomingDiveData.fromDownloadedDive(DownloadedDive dive, {DiveComputer? computer});
  factory IncomingDiveData.fromImportMap(Map<String, dynamic> data);
}
```

**`fromImportMap` field mapping** (import map key -> `IncomingDiveData` field):

| Import map key | Type | IncomingDiveData field | Notes |
|----------------|------|----------------------|-------|
| `dateTime` | `DateTime?` | `startTime` | |
| `maxDepth` | `double?` | `maxDepth` | |
| `avgDepth` | `double?` | `avgDepth` | |
| `runtime` | `Duration?` | `durationSeconds` | Prefer `runtime` over `duration`; convert via `.inSeconds` |
| `duration` | `Duration?` | `durationSeconds` | Fallback if `runtime` is null |
| `waterTemp` | `double?` | `waterTemp` | |
| `diveComputerModel` | `String?` | `computerModel` | Only populated by UDDF parsers; may be null for CSV/FIT/Subsurface |
| `diveComputerSerial` | `String?` | `computerSerial` | Only populated by UDDF parsers |
| `siteName` | `String?` | `siteName` | |
| `profile` | `List<Map>?` | `profile` | Each map has `timestamp` (int) and `depth` (double) keys; convert to `DiveProfilePoint` |

**`fromDownloadedDive` field mapping**: Direct typed access on `DownloadedDive` fields. Computer model/serial come from the optional `DiveComputer` parameter. Profile converts `ProfileSample.timeSeconds` -> `DiveProfilePoint.timestamp`, `ProfileSample.depth` -> `DiveProfilePoint.depth`.

The comparison function then works with this normalized type:
`DiveComparisonResult compareForConsolidation(Dive existing, IncomingDiveData incoming)`

**Unit formatting**: `IncomingDiveData` stores raw metric values (meters, Celsius). Conversion to the user's preferred units happens at the widget rendering layer via `UnitFormatter`, consistent with the rest of the codebase.

Tolerances:
- Time: 60 seconds
- Depth: 0.5m
- Temperature: 1.0C
- Duration: 60 seconds

### Shared Comparison Card Widget

The hybrid card should be a reusable `ConsumerWidget` (`DiveComparisonCard`) used by both flows. It must be a `ConsumerWidget` because it fetches the existing dive and its profile via Riverpod providers (`diveProvider`, `diveProfileProvider`).

It accepts:

- `IncomingDiveData incoming` -- the normalized incoming dive
- `String existingDiveId` -- ID of the matched existing dive (fetches `Dive` and profile via providers)
- `double matchScore` -- 0.0 to 1.0
- `String existingLabel` -- e.g., "Existing (#7)" or "Existing Dive"
- `String incomingLabel` -- e.g., "Downloaded" or "Imported"
- Action callbacks: `onSkip`, `onImportAsNew`, `onConsolidate`

#### Integration: Dive Computer Download

In `summary_step_widget.dart`, replace `_buildCandidateCard` / `_buildExistingDiveColumn` / `_buildImportedDiveColumn` with `DiveComparisonCard`:

```dart
DiveComparisonCard(
  incoming: IncomingDiveData.fromDownloadedDive(candidate.dive, computer: computer),
  existingDiveId: candidate.matchedDiveId,
  matchScore: candidate.matchScore,
  incomingLabel: 'Downloaded',
  onSkip: () => notifier.skipConsolidation(candidate),
  onImportAsNew: () => notifier.importCandidateAsNew(candidate),
  onConsolidate: () => notifier.consolidateDive(candidate),
)
```

#### Integration: File Import

In `import_dive_card.dart`, when a match is detected (`matchResult != null && matchResult.score >= 0.5`), replace the inline `ChoiceChip` resolution row with an expandable `DiveComparisonCard`. The card appears when the user taps to expand the match details.

`ImportDiveCard` must become a `StatefulWidget` to manage the expanded/collapsed toggle state. It keeps its existing layout (checkbox, title, match badge) but replaces `_buildResolutionRow` with a collapsible section that shows the full `DiveComparisonCard`:

```dart
DiveComparisonCard(
  incoming: IncomingDiveData.fromImportMap(diveData),
  existingDiveId: matchResult!.diveId,
  matchScore: matchResult!.score,
  incomingLabel: 'Imported',
  onSkip: () => onResolutionChanged?.call(DiveDuplicateResolution.skip),
  onImportAsNew: () => onResolutionChanged?.call(DiveDuplicateResolution.importAsNew),
  onConsolidate: () => onResolutionChanged?.call(DiveDuplicateResolution.consolidate),
)
```

### Files to Modify

| File | Change |
|------|--------|
| `lib/features/dive_computer/presentation/widgets/summary_step_widget.dart` | Replace `_buildCandidateCard`, `_buildExistingDiveColumn`, `_buildImportedDiveColumn` with `DiveComparisonCard` |
| `lib/features/universal_import/presentation/widgets/import_dive_card.dart` | Replace `_buildResolutionRow` ChoiceChips with expandable `DiveComparisonCard` |

### New Files

| File | Purpose |
|------|---------|
| `lib/core/presentation/widgets/dive_comparison_card.dart` | Shared `DiveComparisonCard` widget used by both import flows |
| `lib/core/presentation/widgets/overlaid_profile_chart.dart` | `OverlaidProfileChart` widget (two-line variant of `DiveProfileMiniChart`) |
| `lib/core/domain/models/incoming_dive_data.dart` | `IncomingDiveData` normalized data class with factory constructors |
| `lib/core/domain/models/dive_comparison_result.dart` | `DiveComparisonResult` class and `compareForConsolidation()` function |

Note: These files live in `core/` rather than `dive_computer/` because they are shared between the dive computer download and universal import features.

### What Does NOT Change

- The `DuplicateCandidate` data model
- The `DiveMatchResult` data model
- The `DownloadNotifier` actions (consolidateDive, importCandidateAsNew, skipConsolidation)
- The `DiveDuplicateResolution` enum and `setDiveResolution` notifier method
- The "Consolidate All" button behavior
- The "Potential Matches (N)" section header
- The gating logic (downloaded dives / action buttons hidden until matches resolved)

## Testing

- Unit test for `compareForConsolidation()` with cases: all fields same, some differ, missing fields on one side, edge cases at tolerance boundaries
- Unit test for `IncomingDiveData.fromDownloadedDive()` and `IncomingDiveData.fromImportMap()` factory constructors
- Widget test for `DiveComparisonCard` rendering with mock dive data
- Widget test for `ImportDiveCard` expansion to show comparison card when match detected
