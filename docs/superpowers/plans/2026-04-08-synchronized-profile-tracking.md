# Synchronized Profile Graph Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When dragging on any dive profile graph in table view, all other profile graphs for the same dive synchronize their crosshair/tracking position.

**Architecture:** A shared Riverpod `StateProvider.family<int?, String>` keyed by dive ID stores the currently-tracked profile point index. The profile panel chart, detail page chart, and decompression section all read from and write to this single provider, replacing the detail page's local `_selectedPointNotifier` and `_heatMapHoverIndex`.

**Tech Stack:** Flutter, Riverpod (StateProvider.family), fl_chart (DiveProfileChart)

---

### Task 1: Create the shared profile tracking provider

**Files:**
- Create: `lib/features/dive_log/presentation/providers/profile_tracking_provider.dart`

- [ ] **Step 1: Create provider file**

```dart
import 'package:submersion/core/providers/provider.dart';

/// Currently tracked profile point index, shared across all profile charts
/// for the same dive. Written by whichever chart the user is interacting
/// with; read by all charts to show a synchronized highlight cursor.
///
/// Keyed by dive ID so that each dive has independent tracking state.
final profileTrackingIndexProvider =
    StateProvider.family<int?, String>((ref, diveId) => null);
```

- [ ] **Step 2: Verify it compiles**

Run: `dart analyze lib/features/dive_log/presentation/providers/profile_tracking_provider.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```
feat: add shared profile tracking index provider
```

---

### Task 2: Wire the profile panel to the shared provider

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_panel.dart`

- [ ] **Step 1: Add import**

Add this import at the top of the file (after the existing imports):

```dart
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
```

- [ ] **Step 2: Wire `onPointSelected` to write to the shared provider**

In `_buildProfileContent`, replace:

```dart
                onPointSelected: (_) {},
```

with:

```dart
                onPointSelected: (index) {
                  ref
                      .read(profileTrackingIndexProvider(widget.diveId).notifier)
                      .state = index;
                },
```

- [ ] **Step 3: Watch the provider and feed `highlightedTimestamp`**

In `_buildProfileContent`, add a watch at the top of the method (after the existing `final colorScheme = ...` line):

```dart
    final trackingIndex = ref.watch(profileTrackingIndexProvider(widget.diveId));
```

Then in the `DiveProfileChart` constructor call, add the `highlightedTimestamp` parameter (after `tooltipBelow: true,`):

```dart
                highlightedTimestamp: trackingIndex != null &&
                        trackingIndex < dive.profile.length
                    ? dive.profile[trackingIndex].timestamp
                    : null,
```

- [ ] **Step 4: Verify it compiles**

Run: `dart analyze lib/features/dive_log/presentation/widgets/dive_profile_panel.dart`
Expected: No issues found.

- [ ] **Step 5: Commit**

```
feat: wire profile panel chart to shared tracking provider
```

---

### Task 3: Wire the detail page chart to the shared provider

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`

This task replaces the local `_selectedPointNotifier` and `_heatMapHoverIndex` with the shared provider so the detail page chart participates in synchronized tracking.

- [ ] **Step 1: Add import**

Add this import at the top of the file (with the other provider imports):

```dart
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
```

- [ ] **Step 2: Remove `_selectedPointNotifier` field and its disposal**

In `_DiveDetailPageState`, remove:

```dart
  /// Currently selected point index on the profile timeline
  final ValueNotifier<int?> _selectedPointNotifier = ValueNotifier<int?>(null);
```

And in `dispose()`, remove:

```dart
    _selectedPointNotifier.dispose();
```

- [ ] **Step 3: Remove `_heatMapHoverIndex` field**

In `_DiveDetailPageState`, remove:

```dart
  /// Non-null when the selection came from heat map hover (drives chart cursor)
  int? _heatMapHoverIndex;
```

- [ ] **Step 4: Replace `ValueListenableBuilder` usages with provider watches**

In the `_sectionBuilders` method (around line 247), the `decoO2` section currently uses:

```dart
          ValueListenableBuilder<int?>(
            valueListenable: _selectedPointNotifier,
            builder: (context, selectedPointIndex, _) {
              return _buildDecoO2Panel(context, ref, dive, selectedPointIndex);
            },
          ),
```

Replace with:

```dart
          Builder(
            builder: (context) {
              final selectedPointIndex = ref.watch(
                profileTrackingIndexProvider(diveId),
              );
              return _buildDecoO2Panel(
                context,
                ref,
                dive,
                selectedPointIndex,
              );
            },
          ),
```

Similarly, the `sacSegments` section (around line 263) uses:

```dart
          ValueListenableBuilder<int?>(
            valueListenable: _selectedPointNotifier,
            builder: (context, selectedPointIndex, _) {
              return _buildSacSegmentsSection(
                context,
                ref,
                dive,
```

Replace the `ValueListenableBuilder<int?>` with:

```dart
          Builder(
            builder: (context) {
              final selectedPointIndex = ref.watch(
                profileTrackingIndexProvider(diveId),
              );
              return _buildSacSegmentsSection(
                context,
                ref,
                dive,
```

And change the closing from `},\n          ),` (ValueListenableBuilder) to `},\n          ),` (Builder) -- same structure, just the wrapper class changed.

- [ ] **Step 5: Update the chart's `MouseRegion.onExit` callback**

Around line 1207, replace:

```dart
                    MouseRegion(
                      onExit: (_) {
                        _selectedPointNotifier.value = null;
                        if (_heatMapHoverIndex != null) {
                          setState(() {
                            _heatMapHoverIndex = null;
                          });
                        }
                      },
```

with:

```dart
                    MouseRegion(
                      onExit: (_) {
                        ref
                            .read(
                              profileTrackingIndexProvider(diveId).notifier,
                            )
                            .state = null;
                      },
```

- [ ] **Step 6: Update `highlightedTimestamp` on the chart**

Around line 1258, replace the `highlightedTimestamp` computation:

```dart
                        highlightedTimestamp:
                            _heatMapHoverIndex != null &&
                                _heatMapHoverIndex! < dive.profile.length
                            ? dive.profile[_heatMapHoverIndex!].timestamp
                            : null,
```

with a provider-based version. First, read the tracking index near the top of the build method for the chart section (inside the `LayoutBuilder` builder, before the `Stack`):

```dart
                final trackingIndex = ref.watch(
                  profileTrackingIndexProvider(diveId),
                );
```

Then use it:

```dart
                        highlightedTimestamp: trackingIndex != null &&
                                trackingIndex < dive.profile.length
                            ? dive.profile[trackingIndex].timestamp
                            : null,
```

- [ ] **Step 7: Update `onPointSelected` on the chart**

Around line 1263, replace:

```dart
                        onPointSelected: (index) {
                          if (index == null) {
                            _selectedPointNotifier.value = null;
                            return;
                          }
                          _selectedPointNotifier.value = index;
                          if (_heatMapHoverIndex != null) {
                            setState(() {
                              _heatMapHoverIndex = null;
                            });
                          }
                        },
```

with:

```dart
                        onPointSelected: (index) {
                          ref
                              .read(
                                profileTrackingIndexProvider(diveId).notifier,
                              )
                              .state = index;
                        },
```

- [ ] **Step 8: Update `onHeatMapHover` in `_buildDecoO2Panel`**

Around line 1424, replace:

```dart
        onHeatMapHover: (index) {
          _selectedPointNotifier.value = index;
          setState(() {
            _heatMapHoverIndex = index;
          });
        },
```

with:

```dart
        onHeatMapHover: (index) {
          ref
              .read(profileTrackingIndexProvider(diveId).notifier)
              .state = index;
        },
```

- [ ] **Step 9: Verify it compiles**

Run: `flutter analyze`
Expected: No issues found. (There should be no remaining references to `_selectedPointNotifier` or `_heatMapHoverIndex`.)

- [ ] **Step 10: Run tests**

Run: `flutter test test/features/dive_log/`
Expected: All tests pass.

- [ ] **Step 11: Commit**

```
feat: wire detail page to shared profile tracking provider

Replace local _selectedPointNotifier and _heatMapHoverIndex with
the shared profileTrackingIndexProvider so the detail page chart,
deco section, and profile panel all track together.
```

---

### Task 4: Format and final verification

**Files:**
- All modified files

- [ ] **Step 1: Format**

Run: `dart format lib/features/dive_log/presentation/providers/profile_tracking_provider.dart lib/features/dive_log/presentation/widgets/dive_profile_panel.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart`
Expected: No changes needed (or formatting applied).

- [ ] **Step 2: Full analyze**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 3: Run full test suite**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 4: Commit if formatting changed anything**

```
style: format synchronized profile tracking files
```
