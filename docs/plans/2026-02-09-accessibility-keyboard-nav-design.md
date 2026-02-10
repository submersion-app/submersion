# Accessibility & Keyboard Navigation Design

> **Date:** 2026-02-09
> **Category:** 15.3 Accessibility & Localization
> **Scope:** All pages, both screen reader support and desktop keyboard navigation

---

## Overview

Add comprehensive accessibility support to Submersion covering two equal pillars:
1. **Screen reader support** -- semantic labels on all interactive elements for VoiceOver (iOS/macOS) and TalkBack (Android)
2. **Desktop keyboard navigation** -- global and page-specific shortcuts, focus traversal, and a shortcuts help overlay

## Current State

- Material 3 with light/dark themes provides baseline a11y
- FocusNode in 2 places only (tag input, PIN entry)
- 1 keyboard shortcut (photo viewer arrow keys)
- Zero `Semantics` widgets or `semanticsLabel` attributes
- Zero accessibility tests
- No keyboard shortcuts for navigation
- No focus traversal policies
- No high contrast theme

---

## Architecture

### 4 Pillars

| Pillar | What It Does | Key Files |
|--------|-------------|-----------|
| **Semantic Annotations** | Labels every interactive element for screen readers | Inline on existing widgets across all pages |
| **Keyboard Shortcuts** | Global + page-specific Cmd/Ctrl shortcuts for desktop | `ShortcutRegistry`, `CallbackShortcuts` at app + page level |
| **Focus Management** | Tab order, focus traversal policies, focus indicators | `FocusTraversalGroup` + `OrderedTraversalPolicy` per page |
| **Shortcuts Help Overlay** | Cmd+/ modal showing all available shortcuts by context | `ShortcutsHelpDialog` widget reading from `ShortcutRegistry` |

### File Structure

```
lib/core/accessibility/
  shortcut_registry.dart        -- Central registry of all shortcuts
  app_shortcuts.dart            -- Global shortcut definitions
  shortcuts_help_dialog.dart    -- Help overlay widget
  semantic_helpers.dart         -- Helper extensions for common patterns
  focus_helpers.dart            -- Focus traversal utilities
```

---

## Pillar 1: Semantic Annotations

### Approach: Inline on Existing Widgets

No wrapper widgets. Flutter's built-in widgets already support semantic properties.

### Widget Type Annotations

**Icon-only buttons** (~80+ instances):
```dart
// Use tooltip which doubles as semantic label
IconButton(icon: Icon(Icons.delete), tooltip: 'Delete dive', onPressed: _deleteDive)
```

**GestureDetector / InkWell taps** (~30 instances):
```dart
Semantics(
  button: true,
  label: 'View dive site: Blue Hole',
  child: GestureDetector(onTap: ..., child: Card(...)),
)
```

**Charts and graphs** (fl_chart profile charts, statistics):
```dart
Semantics(
  label: 'Dive profile chart. Maximum depth 32 meters at 14 minutes. '
         'Total duration 48 minutes.',
  child: ProfileChart(...),
)
```

**Images** (photo gallery, certification cards):
```dart
Image.file(photo, semanticLabel: 'Dive photo from Blue Hole, 12m depth')
```

**State indicators** (badges, status icons, warnings):
```dart
Semantics(
  label: 'Service status: overdue by 30 days',
  child: Icon(Icons.warning, color: Colors.red),
)
```

**Decorative elements** (dividers, background patterns):
```dart
Semantics(excludeSemantics: true, child: DecorativeDivider())
```

### Principle

Every interactive element gets a label. Every informational element gets a description. Every decorative element gets excluded.

---

## Pillar 2: Keyboard Shortcuts

### ShortcutRegistry

Central service tracking all shortcuts for the help overlay:

```dart
class ShortcutEntry {
  final String label;               // "New dive"
  final String category;            // "Navigation", "Editing", "Search"
  final SingleActivator activator;  // Cmd+N
}

class ShortcutRegistry {
  final List<ShortcutEntry> _entries = [];
  void register(ShortcutEntry entry);
  List<ShortcutEntry> get entries => List.unmodifiable(_entries);
  Map<String, List<ShortcutEntry>> get byCategory;
}
```

### Global Shortcuts (at MaterialApp.router level)

| Shortcut | Action | Category |
|----------|--------|----------|
| Cmd+N | New dive | Navigation |
| Cmd+F | Open search | Search |
| Cmd+, | Open settings | Navigation |
| Cmd+/ | Show shortcuts help | Help |
| Cmd+1 through Cmd+5 | Switch tabs (Dives, Sites, Gear, Stats, Settings) | Navigation |
| Cmd+W | Close current detail page (go back) | Navigation |
| Escape | Close dialogs, deselect, cancel edit | General |

### Page-Specific Shortcuts

| Page | Shortcut | Action |
|------|----------|--------|
| Dive List | Cmd+E | Export selected |
| Dive List | Cmd+A | Select all |
| Dive List | Delete | Delete selected |
| Dive Edit | Cmd+S | Save dive |
| Dive Detail | E | Edit dive |
| Dive Detail | Cmd+D | Duplicate dive |
| Search | Enter | Execute search |
| Any List | Up/Down arrows | Navigate list items |
| Any List | Enter | Open selected item |

### Implementation

Global shortcuts via `CallbackShortcuts` wrapping the app's root router:

```dart
// In shell route builder:
CallbackShortcuts(
  bindings: appShortcuts.globalBindings(context, ref),
  child: child,
)
```

Page-specific shortcuts via `CallbackShortcuts` in each page:

```dart
// In dive_list_page.dart:
CallbackShortcuts(
  bindings: { SingleActivator(LogicalKeyboardKey.keyE, meta: true): _export },
  child: FocusScope(autofocus: true, child: ...),
)
```

Platform detection: use `meta` key on macOS, `control` key on Windows/Linux. Helper:

```dart
SingleActivator shortcut(LogicalKeyboardKey key) {
  final isMac = defaultTargetPlatform == TargetPlatform.macOS;
  return SingleActivator(key, meta: isMac, control: !isMac);
}
```

---

## Pillar 3: Focus Management

### Focus Traversal Groups

Every page wraps content in `FocusTraversalGroup`:

```dart
FocusTraversalGroup(
  policy: OrderedTraversalPolicy(),
  child: Scaffold(...)
)
```

### Traversal Order (consistent pattern)

Standard pages:
1. App bar actions (back, title, action buttons)
2. Primary content (list items, form fields, charts)
3. Secondary actions (FAB, bottom bar actions)

Master-detail layout (desktop):
1. Sidebar / navigation rail
2. Main content area
3. Action buttons / FAB

### Focus Indicators

Material 3 handles focus rings on built-in widgets. Custom widgets need explicit focus visuals:

```dart
Focus(
  child: Builder(builder: (context) {
    final focused = Focus.of(context).hasFocus;
    return Container(
      decoration: BoxDecoration(
        border: focused
            ? Border.all(color: theme.colorScheme.primary, width: 2)
            : null,
      ),
      child: existingCard,
    );
  }),
)
```

### Autofocus Rules

| Page Type | Autofocus Target |
|-----------|-----------------|
| List pages | First list item |
| Detail pages | First content section |
| Edit pages | First form field |
| Dialogs | Primary action or first input |

### Focus Restoration

When returning from detail to list, focus restores to the previously selected item via Flutter's built-in `FocusNode` restoration.

---

## Pillar 4: Shortcuts Help Overlay

Triggered by Cmd+/ (or Ctrl+/ on Windows/Linux):

```
+-------------------------------------------+
|  Keyboard Shortcuts                    [X] |
|-------------------------------------------|
|  Navigation                                |
|    Cmd+N          New dive                 |
|    Cmd+1-5        Switch tabs              |
|    Cmd+W          Go back                  |
|    Cmd+,          Settings                 |
|                                            |
|  Search                                    |
|    Cmd+F          Open search              |
|    Enter          Execute search           |
|                                            |
|  Editing                                   |
|    Cmd+S          Save                     |
|    Cmd+D          Duplicate                |
|    E              Edit (on detail page)    |
|    Delete         Delete selected          |
|                                            |
|  Help                                      |
|    Cmd+/          Show this dialog         |
|    Escape         Close dialog             |
+-------------------------------------------+
```

- Reads from `ShortcutRegistry` (always in sync)
- Context-aware: highlights shortcuts available on current page
- Dismissed by Escape or clicking outside

---

## Pages to Annotate

All pages across the app (comprehensive pass):

### Core Navigation
- Dashboard / Home page
- Bottom navigation bar / Navigation rail
- Shell route scaffold

### Dive Log
- Dive list page (main list, selection mode, filters)
- Dive detail page (all cards, actions, profile chart)
- Dive edit page (all form fields, tank editor, gear selector)
- Advanced search page (all filter controls)

### Dive Sites
- Site list page
- Site detail page (map, stats, marine life)
- Site edit page

### Equipment
- Equipment list page
- Equipment detail page (service records, dive history)
- Equipment edit page

### Statistics
- All 9+ statistics sub-pages (charts, records)

### Transfer / Import
- Transfer page (all sections)
- Universal import wizard (all 6 steps)
- Wearable import pages

### Settings
- Settings page (all toggles, selections)
- Diver profile pages
- Species management
- Dive types management

### Other Pages
- Buddies (list, detail, edit)
- Certifications (list, detail, edit)
- Courses (list, detail, edit)
- Dive centers (list, detail, edit)
- Trips (list, detail, edit)
- Dive planner
- Gas calculators
- Deco calculator
- Photo viewer

---

## Testing Strategy

### Test Files

```
test/accessibility/
  semantic_labels_test.dart        -- Labels exist on all pages
  keyboard_shortcuts_test.dart     -- Global + page shortcuts work
  focus_traversal_test.dart        -- Tab order is correct
  shortcuts_help_dialog_test.dart  -- Help overlay renders correctly
```

### Test Types

**1. Semantic label tests** -- verify interactive widgets have labels:
```dart
testWidgets('dive list items have semantic labels', (tester) async {
  await tester.pumpWidget(buildApp());
  final semantics = tester.getSemantics(find.byType(DiveListTile).first);
  expect(semantics.label, contains('Dive'));
});
```

**2. Keyboard navigation tests** -- verify shortcuts trigger actions:
```dart
testWidgets('Cmd+N opens new dive page', (tester) async {
  await tester.pumpWidget(buildApp());
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  expect(find.byType(DiveEditPage), findsOneWidget);
});
```

**3. Focus traversal tests** -- verify tab order:
```dart
testWidgets('tab order follows expected sequence', (tester) async {
  await tester.pumpWidget(buildApp());
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  expect(Focus.of(tester.element(find.byType(SearchBar))).hasFocus, isTrue);
});
```

---

## Error Handling

- Shortcuts that reference unavailable actions (e.g., Cmd+S on a read-only page) are no-ops
- Missing semantic labels caught by test suite, not runtime errors
- Focus traversal gracefully falls back to default order if `OrderedTraversalPolicy` encounters issues
- Platform detection for Cmd vs Ctrl handled via helper function

---

## Dependencies

No new packages required. Uses Flutter's built-in:
- `Semantics`, `MergeSemantics`, `ExcludeSemantics`
- `CallbackShortcuts`, `SingleActivator`, `LogicalKeyboardKey`
- `FocusTraversalGroup`, `OrderedTraversalPolicy`, `FocusNode`
- `showDialog` for shortcuts help overlay
