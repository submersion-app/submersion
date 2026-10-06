# Buddy Merge Feature Design

## Overview

Add the ability to merge duplicate buddy entries, following the established sites merge pattern from PR #54. Users select 2+ buddies from the buddy list, merge them into a single survivor, and can undo the operation via a SnackBar.

## Decisions

- **Undo support:** Yes, snapshot-based reversal (like sites merge, not permanent like tags merge)
- **Entry point:** Multi-select from buddy list page
- **Merge UI:** Reuse BuddyEditPage with `isMerging` flag and per-field cycling
- **Role conflict resolution:** When two buddies being merged both appear on the same dive, keep the higher-ranked role (instructor > diveMaster > buddy)
- **Selection mode:** Includes both merge (2+ selected) and bulk delete (1+ selected) actions

## Data Layer

### BuddyMergeSnapshot

Captures pre-merge state for undo, stored in memory (not persisted):

```text
BuddyMergeSnapshot:
  originalSurvivor: Buddy              // survivor's field values before merge
  deletedBuddies: List<Buddy>          // absorbed buddies
  deletedDiveBuddyEntries: List<DiveBuddySnapshot>   // junction rows removed
  modifiedDiveBuddyEntries: List<DiveBuddySnapshot>  // junction rows whose role changed
```

`DiveBuddySnapshot` captures the original junction row fields: id, diveId, buddyId, role, and createdAt. Undo restores the original `createdAt` timestamp rather than using the current time, preserving association history.

### BuddyMergeResult

```text
BuddyMergeResult:
  survivorId: String
  snapshot: BuddyMergeSnapshot?
```

### Repository: mergeBuddies()

Signature: `Future<BuddyMergeResult?> mergeBuddies({required Buddy mergedBuddy, required List<String> buddyIds})`

Algorithm:

1. Deduplicate and validate: ensure all buddy IDs exist, require >= 2. All buddies must belong to the same diver (UI filtering ensures this, but the repository validates as a guard).
2. First ID is the survivor, remaining are duplicates
3. Capture snapshot: original survivor state, all duplicate buddies, all affected DiveBuddies entries
4. Within a single transaction:
   a. Update survivor with merged field values
   b. Relink DiveBuddies entries (see junction relinking below) -- **must fully complete before step 4c**
   c. Explicitly delete collision-loser junction rows and log each for sync
   d. Delete duplicate buddy records (CASCADE will remove any remaining junction rows for duplicates, but all meaningful rows should already be relinked or explicitly deleted by steps 4b-4c)
   e. Log buddy deletions for sync tracking
5. Notify SyncEventBus
6. Return BuddyMergeResult with snapshot

**CASCADE safety note:** The `DiveBuddies` table has `onDelete: KeyAction.cascade` on `buddyId`. Deleting a buddy row will auto-delete any remaining junction rows for that buddy. Steps 4b-4c must fully complete before step 4d to prevent data loss. After relinking, no meaningful junction rows should remain on duplicate buddies, so CASCADE only cleans up already-handled entries.

### Repository: undoMerge()

Signature: `Future<void> undoMerge(BuddyMergeSnapshot snapshot)`

Algorithm:

1. Within a transaction:
   a. Restore survivor to original field values
   b. Re-create deleted buddy records
   c. Restore deleted DiveBuddies junction entries
   d. Restore modified DiveBuddies entries (revert role changes)
   e. Mark all affected records as pending for sync
2. Notify SyncEventBus

## DiveBuddies Junction Relinking

### The Problem

Sites have a simple 1:many with dives (dive.siteId). Buddies have many:many via DiveBuddies, so merging can create collisions -- two entries for the same dive pointing to the survivor.

### Algorithm

For each duplicate buddy's DiveBuddies entries:

1. **No collision** -- survivor has no entry for that dive. Update `buddyId` to survivor's ID.
2. **Collision** -- survivor already has an entry for that dive. Apply role hierarchy:
   - instructor > diveMaster > buddy
   - If duplicate's role outranks survivor's existing role: update survivor's entry to the higher role (snapshot original role for undo)
   - Delete the duplicate's junction entry (snapshot for undo)

### Example

| Dive    | Buddy A (survivor) | Buddy B (duplicate) | Result                                           |
|---------|-------------------|---------------------|--------------------------------------------------|
| Dive 1  | buddy             | instructor          | Survivor keeps Dive 1, role upgraded to instructor |
| Dive 2  | diveMaster        | buddy               | Survivor keeps Dive 2, role stays diveMaster      |
| Dive 3  | (none)            | buddy               | Entry relinked to survivor as buddy               |

### Snapshot Categories

- `deletedDiveBuddyEntries`: junction rows removed (collision losers and relinked-then-deleted entries)
- `modifiedDiveBuddyEntries`: survivor junction rows whose role was upgraded (captures original role for undo)

## UI Layer

### Multi-select on Buddy List

Add to `buddy_list_content.dart`, mirroring the sites list pattern:

- `_isSelectionMode`, `_selectedIds`, `_mergeSnapshot` state fields
- Long-press a buddy tile enters selection mode
- Selection mode top bar shows:
  - Count label ("X selected")
  - Select All / Deselect All
  - Merge button (enabled when 2+ selected, merge icon)
  - Delete button (enabled when 1+ selected, with confirmation dialog)
- Merge button navigates to `/buddies/merge` with selected IDs via `context.push<BuddyMergeResult>`
- On return, shows undo SnackBar (5 second duration) that calls `undoMerge()`

### BuddyEditPage Merge Mode

Add to `buddy_edit_page.dart`:

- New parameter: `List<String>? mergeBuddyIds` (mutually exclusive with `buddyId`, via assert)
- `bool get isMerging => mergeBuddyIds != null && mergeBuddyIds!.length > 1`
- `_loadMergeData()`: fetches all buddies by ID, ordered by selection order
- Per-field cycling for text fields: name, email, phone, notes
- Per-field cycling for enum fields: certificationLevel, certificationAgency
- Photo handling: per-field cycling for `photoPath` is **not** implemented yet. The merge UI continues to show the existing "photo coming soon" placeholder, and an initial `mergedPhotoPath` is chosen automatically (the first non-null photo from the merged buddies) without any user-facing photo cycling controls or thumbnail previews.
- Uses `_MergeFieldCandidate<T>`, `_buildDistinctCandidates()`, `_initializeMergeTextField()`, `_buildMergeCycleButton()` patterns from sites
- Title changes to "Merge Buddies" when `isMerging`
- Save triggers `_confirmMerge()` confirmation dialog before executing
- Merge save path pops with `BuddyMergeResult` (not the `Buddy` object used by the normal save path)

### BuddyMergePage Wrapper

New file `buddy_merge_page.dart` -- thin wrapper:

```dart
class BuddyMergePage extends StatelessWidget {
  final List<String> buddyIds;
  const BuddyMergePage({super.key, required this.buddyIds});

  @override
  Widget build(BuildContext context) {
    return BuddyEditPage(mergeBuddyIds: buddyIds);
  }
}
```

### Routing

Add route `/buddies/merge` in go_router config:

- Receives `extra` as `List<String>` (buddy IDs)
- Returns `BuddyMergeResult` via `context.pop(result)`

### Provider Updates

- Add `undoMerge(BuddyMergeSnapshot)` method to `BuddyListNotifier`
- Merge operation is called through the repository via `buddyRepositoryProvider`
- After merge and undo, invalidate affected providers: `allBuddiesProvider`, `allBuddiesWithDiveCountProvider`, `buddyByIdProvider` (for each affected buddy ID), `buddiesForDiveProvider` (for affected dives), `buddyStatsProvider` (for affected buddies)

## Localization

New l10n keys following existing naming conventions:

- `buddies_list_selection_mergeTooltip` -- merge button tooltip
- `buddies_list_selection_deleteTooltip` -- delete button tooltip
- `buddies_list_selection_count` -- "X selected" label
- `buddies_list_selection_selectAll` -- "Select All" label
- `buddies_list_selection_deselectAll` -- "Deselect All" label
- `buddies_list_merge_snackbar` -- "Merged X buddies" message
- `buddies_list_merge_undo` -- "Undo" label
- `buddies_list_merge_restored` -- "Merge undone" message
- `buddies_list_delete_confirm_title` / `_message` -- bulk delete confirmation
- `buddies_edit_merge_title` -- "Merge Buddies" page title
- `buddies_edit_merge_fieldSourceCycleTooltip` -- cycle button tooltip
- `buddies_edit_merge_fieldSourceLabel` -- "From: {name} ({n}/{total})"
- `buddies_edit_merge_confirmTitle` / `_message` -- merge confirmation dialog

## Testing

- **Unit tests** for `mergeBuddies()`: survivor update, junction relinking, role conflict resolution, duplicate deletion, sync metadata
- **Unit tests** for `undoMerge()`: full state restoration including junction entries and roles
- **Unit tests** for role hierarchy logic (instructor > diveMaster > buddy)
- **Unit tests** for edge cases: merging when one buddy has zero dives, merging 3+ buddies simultaneously, collision across 3+ buddies on the same dive
- **Widget tests** for selection mode toggle, merge flow navigation, undo SnackBar, bulk delete

## Files to Create

- `lib/features/buddies/presentation/pages/buddy_merge_page.dart`

## Files to Modify

- `lib/features/buddies/data/repositories/buddy_repository.dart` -- add mergeBuddies(), undoMerge(), bulkDeleteBuddies(), snapshot classes
- `lib/features/buddies/presentation/pages/buddy_edit_page.dart` -- add merge mode
- `lib/features/buddies/presentation/widgets/buddy_list_content.dart` -- add selection mode with merge + delete
- `lib/features/buddies/presentation/providers/buddy_providers.dart` -- add undoMerge to notifier
- `lib/core/router/router.dart` (or equivalent) -- add /buddies/merge route
- ARB localization files -- add new l10n keys
