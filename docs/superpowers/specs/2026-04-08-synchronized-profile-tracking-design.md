# Synchronized Profile Graph Tracking

## Problem

In table view mode, when both the profile panel (above the table) and the
details pane (side panel) are visible, dragging on any profile graph only
affects that single chart. The user expects all profile graphs showing the same
dive to track together: dragging in the profile panel should move the crosshair
in the detail page chart and vice versa, and the decompression section charts
(heat map, tissue area chart) should participate in the same synchronization.

## Solution

A shared Riverpod `StateProvider.family<int?, String>` keyed by dive ID holds
the currently-tracked profile point index. All profile graphs read from and
write to this provider.

## New Provider

**File:** `lib/features/dive_log/presentation/providers/profile_tracking_provider.dart`

```dart
final profileTrackingIndexProvider =
    StateProvider.family<int?, String>((ref, diveId) => null);
```

Stores a **profile point index** (not timestamp). This is what downstream
consumers (deco cards, O2 panel, tissue loading) already operate on.

## Changes by File

### 1. New: `profile_tracking_provider.dart`

Single `StateProvider.family<int?, String>` as described above.

### 2. `dive_profile_panel.dart`

- Make `_DiveProfilePanelContent` a `ConsumerStatefulWidget` (already is).
- In `onPointSelected`, write the index to
  `profileTrackingIndexProvider(diveId)`.
- Watch `profileTrackingIndexProvider(diveId)` and convert the index to a
  timestamp for the chart's `highlightedTimestamp` parameter.
- On pointer exit / touch end (when `onPointSelected` receives `null`), write
  `null` to the provider.

### 3. `dive_detail_page.dart`

- Replace `_selectedPointNotifier` (local `ValueNotifier<int?>`) with
  `profileTrackingIndexProvider(diveId)`.
- Replace `_heatMapHoverIndex` (local `int?`) with the same provider -- heat
  map hover writes to the provider instead of local state.
- The chart's `onPointSelected` writes to the shared provider.
- The chart's `highlightedTimestamp` reads from the shared provider (converted
  to timestamp via `dive.profile[index].timestamp`).
- All downstream consumers that previously read `_selectedPointNotifier` now
  read the shared provider:
  - `CompactDecoStatusCard` subtitle
  - `CompactTissueLoadingCard` selectedIndex
  - `CompactO2ToxicityPanel` selected values
  - SAC segments section
- The `onHeatMapHover` callback in `CompactTissueLoadingCard` writes to the
  shared provider.
- Remove `_selectedPointNotifier` and `_heatMapHoverIndex` fields entirely.

## Synchronization Behavior

| Source of drag/hover | Profile panel chart | Detail page chart | Heat map | Deco cards |
|---|---|---|---|---|
| Profile panel chart | Built-in touch spot | Dashed highlight line | Cursor line | Updated values |
| Detail page chart | Dashed highlight line | Built-in touch spot | Cursor line | Updated values |
| Heat map | Dashed highlight line | Dashed highlight line | Native hover | Updated values |

The `DiveProfileChart` widget already renders two visual indicators:
- **Built-in touch spot**: fl_chart's native touch response when the user is
  actively dragging on that chart instance.
- **`highlightedTimestamp` dashed line**: A subtle vertical line drawn at an
  externally-provided timestamp.

Both can coexist. The source chart shows its built-in touch spot; follower
charts show the dashed highlight line. No "am I the source?" flag is needed.

## Clearing

When the pointer exits any chart or a touch ends, `onPointSelected(null)` fires
and the provider is set to `null`. All followers clear their highlights.

## Edge Cases

- **Same dive guaranteed**: Profile panel and detail pane always show the
  highlighted dive, so both use the same dive ID key.
- **No profile data**: Charts with empty profiles do not write to the provider.
- **Detail pane closed**: Profile panel works standalone. Writes still go
  through the provider; there are simply no other listeners.
- **Dive changes**: When the highlighted dive changes, both charts rebuild with
  a new dive ID key. The old provider value is naturally abandoned.

## Testing

- Unit test: verify that writing to `profileTrackingIndexProvider` and reading
  it back works correctly (trivial provider test).
- Widget test: mount a `DiveProfilePanel` and a `DiveDetailPage` together,
  simulate a touch on one chart, verify the other chart receives a non-null
  `highlightedTimestamp`.
- Manual test: in table view with both profile and details visible, drag on the
  profile panel chart and confirm the detail page chart and deco section track
  together, and vice versa.
