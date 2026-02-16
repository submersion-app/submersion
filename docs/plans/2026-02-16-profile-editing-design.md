# Profile Editing Design

## Overview

Add profile editing capabilities to Submersion: outlier detection/removal, smoothing, manual profile drawing via waypoints, and range-based segment editing. All edits are non-destructive -- original profiles are preserved alongside edited versions.

## Requirements

- Non-destructive editing: keep original profile, store edited copy using existing `isPrimary`/`computerId` columns
- Waypoint-based manual profile drawing for dives without a computer
- Outlier detection with suggestion badges on dive detail (manual trigger to apply)
- Range-based segment operations (shift depth, shift time, delete, smooth)
- In-memory undo stack (session-only)

## Architecture

Separate Profile Editor Page with shared pure-Dart service layer.

### Layer Breakdown

| Layer | Component | Purpose |
|-------|-----------|---------|
| Presentation | `ProfileEditorPage` | Full-screen editor at `/dives/:diveId/edit-profile` |
| Presentation | `ProfileEditorChart` | Simplified fl_chart widget for editing (no overlays) |
| Presentation | `EditorToolbar` | Mode selector: Select, Smooth, Outlier, Draw |
| Presentation | `EditorContextPanel` | Mode-specific controls (sliders, buttons, lists) |
| Presentation | `ProfileEditorNotifier` | StateNotifier managing edit session state |
| Presentation | `outlierSuggestionProvider` | FutureProvider detecting outliers for badge display |
| Domain | `ProfileEditingService` | Pure Dart algorithms (outlier, smooth, shift, interpolate) |
| Domain | `OutlierResult` | Entity for detected outlier points |
| Domain | `ProfileWaypoint` | Entity for manual drawing waypoints |
| Data | `DiveRepositoryImpl` | New methods: `saveEditedProfile`, `getProfilesBySource`, `restoreOriginalProfile` |

### File Structure

```
lib/features/dive_log/
  data/
    services/
      profile_editing_service.dart        # Pure Dart algorithms
    repositories/
      dive_repository_impl.dart           # New methods added
  domain/
    entities/
      outlier_result.dart                 # Outlier detection result
      profile_waypoint.dart               # Manual drawing waypoint
  presentation/
    pages/
      profile_editor_page.dart            # Editor page
    widgets/
      profile_editor_chart.dart           # Simplified chart for editing
      editor_toolbar.dart                 # Mode selector toolbar
      editor_context_panel.dart           # Mode-specific controls
    providers/
      profile_editor_provider.dart        # StateNotifier + state class
      outlier_suggestion_provider.dart    # Background outlier detection
```

## Algorithms

### Outlier Detection

Z-score on depth deltas with sliding window:

1. For each point, compute `delta = depth[i] - depth[i-1]`
2. Over a sliding window (default 10 points), calculate mean and stddev of deltas
3. If `|delta - mean| > threshold * stddev` (default threshold: 3.0), flag as outlier
4. Physical impossibility check: any depth change exceeding 3m/second flagged regardless

Why z-score: adapts to local dive context (fast descent vs safety stop have different normal rates).

### Smoothing

Weighted moving average with triangular kernel:

- Window sizes: Small (3), Medium (5), Large (7) -- user selectable
- Triangular weights: center-heavy to preserve peak shapes
- First/last points unchanged (no padding artifacts)

### Range Operations

- **Shift depth**: Add constant to all points in range; clamp depths >= 0
- **Shift time**: Add seconds to all timestamps in range; reject if overlap with adjacent
- **Delete segment**: Remove points in range, optionally interpolate gap
- **Smooth segment**: Apply smoothing only to selected range

### Waypoint Interpolation

- User places waypoints as (timestamp, depth) pairs
- Linear interpolation between consecutive waypoints
- Generate points at configurable interval (default: 4 seconds)

## Service API

```dart
class ProfileEditingService {
  List<OutlierResult> detectOutliers(
    List<DiveProfilePoint> profile, {
    int windowSize = 10,
    double zScoreThreshold = 3.0,
    double maxRateMetersPerSecond = 3.0,
  });

  List<DiveProfilePoint> smoothProfile(
    List<DiveProfilePoint> profile, {
    int windowSize = 5,
  });

  List<DiveProfilePoint> removeOutliers(
    List<DiveProfilePoint> profile,
    List<OutlierResult> outliers,
  );

  List<DiveProfilePoint> shiftSegmentDepth(
    List<DiveProfilePoint> profile, {
    required int startTimestamp,
    required int endTimestamp,
    required double depthDelta,
  });

  List<DiveProfilePoint> shiftSegmentTime(
    List<DiveProfilePoint> profile, {
    required int startTimestamp,
    required int endTimestamp,
    required int timeDelta,
  });

  List<DiveProfilePoint> deleteSegment(
    List<DiveProfilePoint> profile, {
    required int startTimestamp,
    required int endTimestamp,
    bool interpolateGap = true,
  });

  List<DiveProfilePoint> interpolateWaypoints(
    List<ProfileWaypoint> waypoints, {
    int intervalSeconds = 4,
  });
}
```

## UI Design

### Page Layout

```
AppBar: "Edit Profile"                    [Undo] [Save]
+--------------------------------------------------+
|                                                  |
|            ProfileEditorChart                    |
|  - Original profile: faded/dashed line           |
|  - Edited profile: bold line                     |
|  - Outliers: red circles (outlier mode)          |
|  - Waypoints: draggable dots (draw mode)         |
|  - Range handles (select mode)                   |
|                                                  |
+--------------------------------------------------+
|  EditorToolbar                                   |
|  [Select] [Smooth] [Outlier] [Draw]              |
+--------------------------------------------------+
|  ContextPanel (varies by mode)                   |
|                                                  |
|  Select:  Shift Depth / Shift Time / Delete      |
|  Smooth:  Window size slider + Apply buttons     |
|  Outlier: Count badge + Remove buttons           |
|  Draw:    Clear / Generate Profile               |
+--------------------------------------------------+
```

### ProfileEditorChart

New purpose-built chart widget. Shows depth vs time only.

Shows: depth line (original faded + edited bold), outlier markers, waypoints, range selection.

Does NOT show: temperature, pressure, ceiling, NDL, SAC, ppO2, gas coloring, event markers, playback cursor, legend panel.

Interactions: zoom/pan, tap-to-place (draw mode), drag waypoints, range handles.

### State Management

```dart
class ProfileEditorState {
  final List<DiveProfilePoint> originalProfile;
  final List<DiveProfilePoint> editedProfile;
  final List<List<DiveProfilePoint>> undoStack;
  final EditorMode mode;  // select, smooth, outlier, draw
  final List<OutlierResult>? detectedOutliers;
  final List<ProfileWaypoint>? waypoints;
  final (int start, int end)? selectedRange;
  final bool hasChanges;
}

enum EditorMode { select, smooth, outlier, draw }
```

## Data Persistence

### Storage

No schema changes. Uses existing `DiveProfiles` table columns:

| Column | Original | Edited |
|--------|----------|--------|
| `computerId` | actual ID or null | `'user-edited'` |
| `isPrimary` | `true` -> `false` | `true` |

### Repository Methods

```dart
Future<void> saveEditedProfile(
  String diveId,
  List<DiveProfilePoint> editedPoints,
);

Future<Map<String?, List<DiveProfilePoint>>> getProfilesBySource(
  String diveId,
);

Future<void> restoreOriginalProfile(String diveId);
```

### Existing Code Changes

- `getDiveProfile(diveId)`: Add filter `isPrimary = true` so detail page auto-shows edited version
- `ProfileSelectorWidget`: Extend to display `'user-edited'` as a selectable source
- `DiveDetailPage`: Add "Edit Profile" action button, show outlier suggestion badge

### Dive Stats Recalculation

After saving edited profile, recalculate from new points:
- `maxDepth` -> max of edited depths
- `avgDepth` -> mean of edited depths
- `duration` -> last timestamp - first timestamp

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Empty profile input | Return empty list (no-op) |
| Window > profile length | Clamp window to profile length |
| Range start > end | Swap silently |
| Time shift causes overlap | Reject, return error |
| Depth shift below 0 | Clamp to 0 |
| Save failure | Transaction rollback, snackbar error, state preserved |
| No original to demote | Just insert edited (manual-draw-from-scratch) |
| Back with unsaved changes | Confirmation dialog |
| Profile >10K points | Downsample for display, edit full dataset |

## Testing Strategy

### Unit Tests (ProfileEditingService)

| Test | Validates |
|------|-----------|
| detectOutliers clean profile | Returns empty |
| detectOutliers known spike | Detects spike |
| detectOutliers fast descent | Does NOT flag normal descent |
| detectOutliers physical impossibility | Flags >3m/s |
| smoothProfile preserves endpoints | First/last unchanged |
| smoothProfile reduces noise | Stddev reduced |
| smoothProfile preserves shape | Max depth within tolerance |
| removeOutliers interpolates | Gaps filled |
| shiftSegmentDepth +/- | Range shifted, others unchanged |
| shiftSegmentDepth clamp | No negative depths |
| shiftSegmentTime no overlap | Adjacent segments safe |
| deleteSegment interpolate | Gap filled linearly |
| deleteSegment no interpolate | Points removed |
| interpolateWaypoints 2 pts | Linear between them |
| interpolateWaypoints interval | Correct spacing |

### Integration Tests (Repository)

| Test | Validates |
|------|-----------|
| saveEditedProfile + getDiveProfile | Edited returned as primary |
| saveEditedProfile demotes original | isPrimary = false |
| restoreOriginalProfile | Original restored, edited deleted |
| getProfilesBySource | Both sources returned |
| Save + recalculate stats | maxDepth/avgDepth updated |

### Widget Tests (ProfileEditorPage)

| Test | Validates |
|------|-----------|
| Initial load | Shows original profile |
| Mode switching | Toolbar changes context panel |
| Undo button state | Disabled when empty, enabled after edit |
| Save confirmation | Dialog appears |
| Back with changes | Unsaved changes dialog |

## Route

`/dives/:diveId/edit-profile` -- child of existing `/dives/:diveId` route.

## Entry Points

1. Dive detail page: overflow menu or action bar "Edit Profile" button
2. Outlier suggestion badge: taps navigate to editor in outlier mode
