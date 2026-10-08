# Auto-Select New Dive Site on Creation from Dive Edit

## Problem

When manually logging a dive and creating a new dive site, the user flow is clunky:

1. Tap "Select Dive Site" on the dive edit page
2. Tap "New Dive Site" in the site picker bottom sheet
3. Fill out and save the new site
4. Return to the dive edit page -- but the site field is still empty
5. Tap "Select Dive Site" again
6. Find and select the site just created

Steps 4-6 are unnecessary friction. The newly created site should be auto-selected.

## Solution

Use go_router's built-in `push<T>` / `pop(result)` pattern to pass the newly created site ID back to the dive edit page.

### Approach: Pop with Result

Instead of the site picker sheet navigating directly to `/sites/new`, it signals to `DiveEditPage` that the user wants to create a new site. `DiveEditPage` owns the `push<String>('/sites/new')` call and awaits the result. `SiteEditPage` pops with the saved site ID. On return, `DiveEditPage` looks up the site by ID and sets it as the selected site.

**Why this approach over alternatives:**
- Shared state provider: over-engineered, requires manual cleanup
- Route extra parameter: not type-safe, fragile with deep links
- Pop with result: uses go_router's native mechanism, minimal code, deterministic

## Design

### Files Modified

#### 1. `lib/features/dive_log/presentation/pages/dive_edit_page.dart`

**`_SitePickerSheet`** -- Add a callback `onCreateNewSite`:
- The "New Dive Site" button (in both the header and empty state) currently does `Navigator.of(context).pop()` followed by `context.push('/sites/new')`
- Change to: `Navigator.of(context).pop()` followed by calling the `onCreateNewSite` callback
- This lets `DiveEditPage` own the navigation so it can await the result

**`DiveEditPage._showSitePicker()`** -- change signature to `Future<void>` and make async:
- Await the bottom sheet result to distinguish "create new" from dismiss
- Add `onCreateNewSite` callback to `_SitePickerSheet`
- If result is the sentinel, call `await context.push<String>('/sites/new')`
- If a non-null site ID is returned, look up the full `DiveSite` via the repository and set `_selectedSite`

The bottom sheet result distinguishes "create new" from a plain dismiss. The `_SitePickerSheet` pops with a `_createNewSiteSentinel` constant when the user taps "New Dive Site"; a plain dismiss returns `null`. `DiveEditPage` checks the result and navigates accordingly.

Note: The current code in `_SitePickerSheet` calls `context.push('/sites/new')` after `Navigator.pop()`, which uses the bottom sheet's context after it has been deactivated. Moving navigation ownership to `DiveEditPage` fixes this latent issue.

```dart
// Sentinel constant (defined at file scope)
const _createNewSiteSentinel = '__create_new__';

Future<void> _showSitePicker() async {
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      // ... existing config ...
      builder: (context, scrollController) => _SitePickerSheet(
        scrollController: scrollController,
        selectedSiteId: _selectedSite?.id,
        currentLocation: _currentLocation,
        onSiteSelected: (site) {
          setState(() => _selectedSite = site);
          Navigator.of(context).pop();
        },
        onCreateNewSite: () {
          Navigator.of(context).pop(_createNewSiteSentinel);
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

#### 2. `lib/features/dive_sites/presentation/pages/site_edit_page.dart`

**`SiteEditPage._saveSite()`**:
- Change `context.pop()` to `context.pop(savedId)` in the non-embedded save path
- This is backward-compatible: callers that don't await a result ignore it
- The "Site added" snackbar from `SiteEditPage` still fires -- after `context.pop(savedId)`, `ScaffoldMessenger` resolves to the parent scaffold (`DiveEditPage`), so the snackbar appears there alongside the auto-selected site field

```dart
// Current (line ~1363):
context.pop();

// Updated:
context.pop(savedId);
```

### Data Lookup

When `DiveEditPage` receives the site ID, it reads the site from the repository:

```dart
final repo = ref.read(siteRepositoryProvider);
final site = await repo.getSiteById(siteId);
```

This is preferred over reading from `sitesProvider` because:
- The provider may still be rebuilding after `SiteEditPage` invalidated it
- A direct repository read is a single async call with no race condition
- It keeps the lookup simple and deterministic

### Edge Cases

| Scenario | Behavior |
|----------|----------|
| User creates site and saves | Site ID returned, auto-selected |
| User cancels site creation (back button) | `push` returns `null`, no change to `_selectedSite` |
| User dismisses bottom sheet without action | `showModalBottomSheet` returns `null`, no navigation |
| User selects existing site from picker | Existing flow unchanged (`onSiteSelected` callback) |
| Site creation accessed from Sites tab | `pop(savedId)` is harmless -- no caller awaits it |

### Scope

**In scope:**
- Auto-select from header "New Dive Site" button
- Auto-select from empty-state "Add Dive Site" button
- Both use the same `onCreateNewSite` callback

**Not in scope:**
- No changes to site editing flow
- No changes to site creation from the Sites tab
- No new providers, routes, or widgets

### Change Surface

- ~15 lines modified across 2 files
- Zero new files
- Backward-compatible changes only
