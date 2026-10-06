# Auto-Select New Dive Site on Creation Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a user creates a new dive site from within the dive edit page's site picker, auto-select that site upon return instead of requiring the user to re-open the picker and manually find it.

**Architecture:** Use go_router's `push<T>` / `pop(result)` to pass the newly created site ID from `SiteEditPage` back to `DiveEditPage`. The bottom sheet signals "create new" via a sentinel pop value, `DiveEditPage` owns the navigation and awaits the result, then looks up the site by ID from the repository.

**Tech Stack:** Flutter, go_router (`push<String>` / `pop`), Riverpod (`ref.read`), Drift (repository layer)

**Spec:** `docs/superpowers/specs/2026-03-15-site-autoselect-on-create-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `lib/features/dive_sites/presentation/pages/site_edit_page.dart` | Pop with `savedId` instead of bare `pop()` |
| Modify | `lib/features/dive_log/presentation/pages/dive_edit_page.dart` | Add sentinel constant, refactor `_showSitePicker` to async, add `onCreateNewSite` callback to `_SitePickerSheet`, look up site by ID on return |

---

## Chunk 1: Implementation

### Task 1: Make `SiteEditPage._saveSite()` pop with the saved ID

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart:1363`

- [ ] **Step 1: Change `context.pop()` to `context.pop(savedId)`**

In `_saveSite()`, the non-embedded success path currently calls `context.pop()` at line 1363. Change it to pass the saved site ID back to the caller:

```dart
// Before (line 1363):
          context.pop();

// After:
          context.pop(savedId);
```

This is the only change in this file. The snackbar on line 1364 continues to work -- `ScaffoldMessenger` resolves to the parent scaffold after the pop.

- [ ] **Step 2: Verify the app builds**

Run: `flutter analyze lib/features/dive_sites/presentation/pages/site_edit_page.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/features/dive_sites/presentation/pages/site_edit_page.dart
git commit -m "refactor: return saved site ID via context.pop in SiteEditPage"
```

---

### Task 2: Add `onCreateNewSite` callback to `_SitePickerSheet`

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart:3604-3615` (class definition)
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart:3677-3681` (header button)
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart:3708-3712` (empty state button)

- [ ] **Step 1: Add the callback field and constructor parameter**

Add `onCreateNewSite` to the `_SitePickerSheet` class. Find the class definition at line 3604:

```dart
// Before (lines 3604-3615):
class _SitePickerSheet extends ConsumerWidget {
  final ScrollController scrollController;
  final String? selectedSiteId;
  final LocationResult? currentLocation;
  final void Function(DiveSite) onSiteSelected;

  const _SitePickerSheet({
    required this.scrollController,
    required this.selectedSiteId,
    this.currentLocation,
    required this.onSiteSelected,
  });

// After:
class _SitePickerSheet extends ConsumerWidget {
  final ScrollController scrollController;
  final String? selectedSiteId;
  final LocationResult? currentLocation;
  final void Function(DiveSite) onSiteSelected;
  final VoidCallback onCreateNewSite;

  const _SitePickerSheet({
    required this.scrollController,
    required this.selectedSiteId,
    this.currentLocation,
    required this.onSiteSelected,
    required this.onCreateNewSite,
  });
```

- [ ] **Step 2: Update the header "New Dive Site" button to use the callback**

Find the header button at line 3677:

```dart
// Before (lines 3677-3681):
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/sites/new');
                },

// After:
              TextButton.icon(
                onPressed: onCreateNewSite,
```

- [ ] **Step 3: Update the empty-state "Add Dive Site" button to use the callback**

Find the empty state button at line 3708:

```dart
// Before (lines 3708-3712):
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push('/sites/new');
                        },

// After:
                      TextButton.icon(
                        onPressed: onCreateNewSite,
```

- [ ] **Step 4: Verify no analyzer issues**

Run: `flutter analyze lib/features/dive_log/presentation/pages/dive_edit_page.dart`
Expected: No issues found (the constructor call in `_showSitePicker` will show a missing parameter error until Task 3, so this step may show 1 error -- that's expected)

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_edit_page.dart
git commit -m "refactor: add onCreateNewSite callback to _SitePickerSheet"
```

---

### Task 3: Refactor `_showSitePicker()` to await result and auto-select

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart:1028-1048` (`_showSitePicker` method)

- [ ] **Step 1: Add the sentinel constant at file scope**

Add this near the top of the file, after the imports (around line 40, or wherever file-level constants live):

```dart
const _createNewSiteSentinel = '__create_new__';
```

- [ ] **Step 2: Rewrite `_showSitePicker()` to be async and handle the sentinel**

Replace the entire `_showSitePicker` method (lines 1028-1048):

```dart
// Before (lines 1028-1048):
  void _showSitePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _SitePickerSheet(
          scrollController: scrollController,
          selectedSiteId: _selectedSite?.id,
          currentLocation: _currentLocation,
          onSiteSelected: (site) {
            setState(() => _selectedSite = site);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

// After:
  Future<void> _showSitePicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (sheetContext, scrollController) => _SitePickerSheet(
          scrollController: scrollController,
          selectedSiteId: _selectedSite?.id,
          currentLocation: _currentLocation,
          onSiteSelected: (site) {
            setState(() => _selectedSite = site);
            Navigator.of(sheetContext).pop();
          },
          onCreateNewSite: () {
            Navigator.of(sheetContext).pop(_createNewSiteSentinel);
          },
        ),
      ),
    );

    if (result == _createNewSiteSentinel && mounted) {
      final siteId = await context.push<String>('/sites/new');
      if (siteId != null && mounted) {
        final repo = ref.read(siteRepositoryProvider);
        final site = await repo.getSiteById(siteId);
        if (site != null && mounted) {
          setState(() => _selectedSite = site);
        }
      }
    }
  }
```

Key details:
- Renamed the builder's `context` parameter to `sheetContext` to avoid shadowing the widget's `context` (needed for the `context.push` call after the sheet closes)
- `showModalBottomSheet<String>` is now typed to return a `String?`
- `onSiteSelected` uses `Navigator.of(sheetContext).pop()` (no value -- returns `null`)
- `onCreateNewSite` uses `Navigator.of(sheetContext).pop(_createNewSiteSentinel)`
- After the sheet closes, if the sentinel was returned, `DiveEditPage` owns the `push<String>('/sites/new')` navigation
- `mounted` checks after every `await` prevent setState on a disposed widget

- [ ] **Step 3: Verify the app builds cleanly**

Run: `flutter analyze lib/features/dive_log/presentation/pages/dive_edit_page.dart`
Expected: No issues found

- [ ] **Step 4: Run existing tests to ensure nothing is broken**

Run: `flutter test`
Expected: All existing tests pass

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_edit_page.dart
git commit -m "fix: auto-select newly created dive site in dive edit page"
```

---

### Task 4: Format and final verification

**Files:**
- All modified files

- [ ] **Step 1: Format code**

Run: `dart format lib/features/dive_log/presentation/pages/dive_edit_page.dart lib/features/dive_sites/presentation/pages/site_edit_page.dart`
Expected: No formatting changes (or applies formatting)

- [ ] **Step 2: Run full analyzer**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 3: Run full test suite**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 4: Manual smoke test**

Test these scenarios on a running device/simulator:
1. Open dive edit page > tap "Select Dive Site" > tap "New Dive Site" > fill and save > verify site auto-selected on return
2. Open dive edit page > tap "Select Dive Site" > tap "New Dive Site" > press back > verify no site selected
3. Open dive edit page > tap "Select Dive Site" > select existing site > verify existing flow works
4. Open dive edit page > tap "Select Dive Site" > dismiss sheet by swiping down > verify no change
5. Open Sites tab > tap "+" > create site > verify normal flow (no regression)

- [ ] **Step 5: Commit any formatting fixes**

```bash
git add lib/features/dive_log/presentation/pages/dive_edit_page.dart lib/features/dive_sites/presentation/pages/site_edit_page.dart
git commit -m "chore: format code"
```

(Skip if no changes from formatting step.)
