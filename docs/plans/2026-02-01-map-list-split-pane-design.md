# Map View Split-Pane Design

## Overview

On desktop/wide window mode (≥1100px), Map View in Dives/Sites/Dive Centers shows the map on the right pane while keeping the list visible in the middle pane.

## Layout Architecture

### Desktop Split-Pane (≥1100px)

```
┌──────────────────────────────────────────────────────────────┐
│  AppBar: [Back] "Sites Map"           [Heat Map] [Collapse]  │
├─────────────────┬────────────────────────────────────────────┤
│                 │                                            │
│   List Pane     │                                            │
│   (440px)       │         Map Pane                           │
│                 │        (Expanded)                          │
│  ┌───────────┐  │                                            │
│  │ Site 1    │◄─┼── Selected item highlighted                │
│  ├───────────┤  │                                            │
│  │ Site 2    │  │         markers                            │
│  ├───────────┤  │                                            │
│  │ Site 3    │  │                                            │
│  └───────────┘  │  ┌─────────────────────────┐               │
│                 │  │ Site 1          [→]     │ ← Info card   │
│                 │  │ 15 dives • ★★★★☆       │               │
│                 │  └─────────────────────────┘               │
└─────────────────┴────────────────────────────────────────────┘
```

### Mobile (<1100px)

Unchanged — navigates to full-screen map page as it does today.

## Interaction Flow

### Selection Behavior

| Action | Result |
|--------|--------|
| Tap list item | Map pans/zooms to location, marker highlights, info card appears |
| Tap map marker | Same as above — selects item, scrolls list to it, shows info card |
| Tap info card "→" button | Navigates to full detail page |
| Tap elsewhere on map | Deselects item, hides info card |
| Tap cluster on map | Zooms in to show individual markers (existing behavior) |

### Collapse/Expand Toggle

| State | Button Location | Behavior |
|-------|-----------------|----------|
| Expanded (split) | Right edge of list pane header | Shows `«` icon, clicking collapses list |
| Collapsed (map only) | Left edge of map header | Shows `»` icon, clicking expands list |

### State Persistence

- Collapse state persists during the session (not across app restarts)
- Selected item preserved when toggling collapse state
- When returning from detail view, previous selection and map position restored

### Animation

- List pane slides in/out (200ms, easeInOut)
- Map smoothly pans to selected location (800ms, existing animation)
- Info card fades in from bottom (150ms)

## Component Architecture

### New Widgets

```
lib/shared/widgets/map_list_layout/
├── map_list_scaffold.dart        # Main split-pane layout
├── map_info_card.dart            # Bottom info card overlay
└── collapsible_list_pane.dart    # Animated collapsible container
```

### Widget Hierarchy

```dart
MapListScaffold(
  listPane: SiteListContent(
    showAppBar: false,          // AppBar handled by scaffold
    onItemTap: (site) => ...,   // Pan map, don't navigate
    selectedId: selectedSiteId,
  ),
  mapPane: FlutterMap(...),
  infoCard: MapInfoCard(
    item: selectedSite,
    onDetailsTap: () => context.push('/sites/${site.id}'),
  ),
  isCollapsed: isCollapsed,
  onCollapseToggle: () => ...,
)
```

### Modified Existing Widgets

| Widget | Change |
|--------|--------|
| `SiteListContent` | Add `onItemTap` callback, `selectedId` prop, `showAppBar` control |
| `DiveListContent` | Same changes |
| `DiveCenterListContent` | Same changes |
| `SiteMapPage` | Use `MapListScaffold` on desktop, existing layout on mobile |
| `DiveActivityMapPage` | Same pattern |
| `DiveCenterMapPage` | Same pattern |

### State Management (Riverpod)

```dart
// New provider for map-list selection state
final mapListSelectionProvider = StateNotifierProvider.family<
  MapListSelectionNotifier,
  MapListSelectionState,
  String  // 'sites' | 'dives' | 'dive-centers'
>(...);
```

## Info Card Design

### Visual Layout

```
┌─────────────────────────────────────────────────────────┐
│  ┌──────┐                                               │
│  │ IMG  │  Site Name                          [→]      │
│  │ 48px │  Location • 15 dives • ★★★★☆               │
│  └──────┘                                               │
└─────────────────────────────────────────────────────────┘
```

### Content by Entity Type

| Entity | Line 1 | Line 2 |
|--------|--------|--------|
| **Dive Site** | Site name | Location • dive count • rating stars |
| **Dive Center** | Center name | Location • rating stars |
| **Dive** | Site name + date | Max depth • duration • dive number |

### Styling

- Background: `surfaceContainerHigh` (Material 3)
- Corner radius: 16px top corners only
- Shadow: elevation 4
- Max width: 400px (centered on map pane)
- Padding: 12px horizontal, 16px vertical
- Image: 48x48 rounded thumbnail (or placeholder icon if no image)

### Behavior

- Appears 16px from bottom of map pane
- Swipe down to dismiss (mobile gesture, works on desktop too)
- Arrow button navigates to detail page
- Entire card is tappable as alternative to arrow button

## Implementation Plan

### Files to Create (4 new files)

| File | Purpose |
|------|---------|
| `lib/shared/widgets/map_list_layout/map_list_scaffold.dart` | Main split-pane scaffold |
| `lib/shared/widgets/map_list_layout/map_info_card.dart` | Bottom overlay card |
| `lib/shared/widgets/map_list_layout/collapsible_list_pane.dart` | Animated collapse container |
| `lib/shared/providers/map_list_selection_provider.dart` | Selection state management |

### Files to Modify (6 files)

| File | Changes |
|------|---------|
| `site_list_content.dart` | Add `onItemTap`, `selectedId`, `showAppBar` params |
| `dive_list_content.dart` | Same changes |
| `dive_center_list_content.dart` | Same changes |
| `site_map_page.dart` | Use `MapListScaffold` on desktop breakpoint |
| `dive_activity_map_page.dart` | Same pattern |
| `dive_center_map_page.dart` | Same pattern |

### No Changes Needed

- Router configuration (routes stay the same)
- Mobile behavior (unchanged, still full-screen)
- Existing map components (FlutterMap, markers, heatmap)

### Testing Considerations

- Widget tests for `MapListScaffold` collapse/expand
- Widget tests for `MapInfoCard` rendering each entity type
- Integration test for selection sync between list and map
