# Dive Highlight & Profile Panel Design

## Summary

Add a highlight-without-navigate interaction model to the dive list (all view
modes) and an optional profile chart preview panel that auto-updates when the
highlighted dive changes.

**Key behaviors:**

- Single tap highlights a dive (no navigation)
- Double tap opens dive details (current single-tap behavior)
- Long press enters bulk selection mode (unchanged)
- Toggle button in the toolbar shows/hides a fixed-height profile chart panel
  above the list
- Profile chart auto-updates as the highlighted dive changes

## Interaction Model

### Gesture mapping

Gestures differ by view mode:

**Table mode:**

| Gesture    | Action                                                      |
| ---------- | ----------------------------------------------------------- |
| Single tap | Highlights the dive. Updates `highlightedDiveIdProvider`.    |
| Double tap | Opens dive details (route navigation or master-detail pane). |
| Long press | Enters bulk selection mode (unchanged).                      |

**Card modes (detailed, compact, dense):**

| Gesture    | Action                                                                        |
| ---------- | ----------------------------------------------------------------------------- |
| Single tap | Highlights the dive AND navigates to dive details (existing behavior retained). |
| Long press | Enters bulk selection mode (unchanged).                                        |

### Highlight visuals

- **Table view:** Left border accent + `primaryContainer` background on the row
  (extends existing `_tableHighlightedId` styling).
- **Card views (compact/dense/detailed):** Subtle `primaryContainer` tint with
  left border accent, consistent with the table highlight.

### Edge cases

- Tapping an already-highlighted dive: no change (stays highlighted).
- Tapping a different dive: moves the highlight.
- Entering selection mode (long press): clears the single-dive highlight.
- Navigating away and back: highlight preserved (lives in provider, not local
  state).

## State Management

### New providers (in `highlight_providers.dart`)

**`highlightedDiveIdProvider`** -- `StateProvider<String?>`

Holds the currently highlighted dive ID. Shared across all view modes. Reset to
`null` when entering bulk selection mode.

**`showProfilePanelProvider`** -- `StateProvider<bool>`

Controls whether the profile chart panel is visible. Runtime toggle, not
persisted to the database (transient UI preference).

### Integration with existing providers

- The profile panel watches `highlightedDiveIdProvider` and uses the existing
  `diveProvider(id)` to load the dive, then `profileAnalysisProvider(id)` to get
  computed curves. No new data-fetching providers needed.
- `DiveListContent` reads `highlightedDiveIdProvider` and passes the highlighted
  state down to table rows and card tiles.
- The toolbar toggle button reads/writes `showProfilePanelProvider`.

### Interaction with master-detail

On desktop in master-detail mode, `highlightedDiveIdProvider` and the existing
`selectedId` (for the detail pane) are independent. Highlighting a dive updates
the profile panel preview; double-tap still opens the full detail pane.

## Profile Panel Widget

### `DiveProfilePanel` (new `ConsumerWidget`)

A standalone widget that:

- Watches `highlightedDiveIdProvider` to know which dive to display.
- When a dive is highlighted, loads data via existing `diveProvider(id)` and
  `profileAnalysisProvider(id)`.
- Renders the full `DiveProfileChart` widget (reused as-is from dive details)
  with all overlay toggles.
- Shows a compact header bar with dive number, site name, date, and key stats
  (max depth, duration).
- When no dive is highlighted, shows a minimal empty state: icon + "Select a
  dive to view its profile."

### Layout integration

The panel is placed in `DiveListContent`'s build method, above the list/table
body:

```dart
Column(
  children: [
    if (showProfilePanel) DiveProfilePanel(),
    Expanded(child: /* existing table/card list */),
  ],
)
```

### Panel sizing

- Fixed at approximately 30% of available height (using `LayoutBuilder`).
- Minimum ~150px, maximum ~250px for responsiveness across screen sizes.

### Toggle button

An `IconButton` with a chart icon added to the toolbar actions (both full AppBar
and compact master-detail toolbar). Uses `primaryContainer` tint when active,
consistent with other active toggles in the app.

## File Changes

### New files

| File                                                                  | Purpose                                                        |
| --------------------------------------------------------------------- | -------------------------------------------------------------- |
| `lib/features/dive_log/presentation/widgets/dive_profile_panel.dart`  | Profile panel widget with chart, header bar, empty state       |
| `lib/features/dive_log/presentation/providers/highlight_providers.dart` | `highlightedDiveIdProvider` and `showProfilePanelProvider`     |

### Modified files

| File                        | Change                                                                                                                                                     |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `dive_list_content.dart`    | Insert `DiveProfilePanel` above list/table. Change single-tap to highlight instead of navigate. Add double-tap to navigate. Add toggle button to toolbar. Clear highlight on entering selection mode. |
| `dive_table_view.dart`      | Add `onDiveDoubleTap` callback. Read highlight from provider instead of local `_tableHighlightedId`.                                                      |
| `compact_dive_list_tile.dart` | Add `onDoubleTap` callback, add highlight styling (left accent + tinted background).                                                                      |
| `dense_dive_list_tile.dart` | Same as compact -- add `onDoubleTap` and highlight styling.                                                                                                |

### Unchanged files

- `DiveProfileChart` -- reused as-is
- `DiveDetailPage` -- navigation target unchanged
- Database / Drift layer -- no persistence for these providers
- Router -- routes unchanged
