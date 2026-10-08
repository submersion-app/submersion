# Tag Management Page Design

## Summary

Add a dedicated tag management page accessible from Settings > Manage > Tags. Provides full CRUD operations (create, rename, recolor, delete) plus multi-tag merge, with usage statistics per tag. Removes the current auto-cleanup behavior so tags persist until explicitly deleted.

## Requirements

- Full-page management UI at route `/tags`
- Entry point: Settings > Manage > Tags (alongside Dive Types, Tank Presets, Species)
- Create new tags with name + color
- Edit tags (rename, change color)
- Delete tags globally (removes from all dives, with confirmation showing affected count)
- Merge 2+ tags into one (reassign all dive associations, deduplicate, delete source tags)
- View usage count per tag
- Search/filter tags by name
- Remove auto-cleanup (`_deleteTagIfUnused`) so tags with 0 dives persist

## Architecture

### New Files

| File | Purpose |
|------|---------|
| `lib/features/tags/presentation/pages/tag_manage_page.dart` | Full-page tag management (ConsumerStatefulWidget) |
| `lib/features/tags/presentation/widgets/tag_merge_sheet.dart` | Bottom sheet for merge flow |

### Modified Files

| File | Change |
|------|--------|
| `lib/features/tags/data/repositories/tag_repository.dart` | Add `mergeTags()`, make `getTagUsageCount()` public, remove `_deleteTagIfUnused()` and `deleteUnusedTags()` |
| `lib/features/tags/presentation/providers/tag_providers.dart` | Add `mergeTags()` to `TagListNotifier` |
| `lib/features/settings/presentation/pages/settings_page.dart` | Add Tags row to `_ManageSectionContent` |
| `lib/core/router/app_router.dart` | Add `/tags` route |
| `lib/features/tags/presentation/widgets/tag_input_widget.dart` | Remove orphaned `TagManagementDialog` |
| `lib/l10n/arb/app_en.arb` (+ other locales) | New l10n strings |

## UI Design

### Default Mode

- Scaffold with AppBar title "Tags", back button, search bar
- ListView of tags, each row: colored CircleAvatar, tag name, right-aligned dive count in muted text
- FAB (+) opens create dialog (name text field + color picker)
- Tap a row opens edit dialog (rename + recolor, reuse existing pattern from `_editTag`)
- Long-press a row enters selection mode

### Selection Mode

- AppBar swaps to show: X (exit) + selected count + merge icon + delete icon
- Merge icon enabled when 2+ tags selected
- Delete icon enabled when 1+ tags selected
- Tapping rows toggles checkmark selection
- X or system back exits selection mode

### Merge Bottom Sheet

- Header: "Merge N Tags"
- Text field pre-populated with the name of the tag with the most dives
- Radio buttons listing each selected tag (with dive counts) for quick name selection
- Color picker pre-selecting the most-used tag's color
- Summary line: "This will affect N dives total." (union count)
- Cancel + Merge action buttons

### Delete Confirmation

- Single: "'{name}' will be removed from N dives. This cannot be undone."
- Bulk: "These tags will be removed from N dives total. This cannot be undone."
- Cancel + Delete (red) action buttons

## Data Layer

### `mergeTags()` Repository Method

1. Determine or create the surviving tag with chosen name + color
2. For each source tag being merged:
   a. Query all `dive_tags` rows for the source tag
   b. For each association, check if the dive already has the surviving tag
   c. If not, update the `dive_tags` row to point to the surviving tag ID
   d. If duplicate, delete the `dive_tags` row
   e. Delete the source tag (cascade handles remaining junction rows)
3. Update surviving tag's `updatedAt`
4. Mark all affected records as pending for sync
5. Log deletions for sync

### `getTagUsageCount()` — Made Public

Returns the count of dives using a given tag. Used by the UI to show usage counts and deletion confirmation messages.

### Auto-Cleanup Removal

- Delete `_deleteTagIfUnused()` method
- Delete `deleteUnusedTags()` method
- Remove cleanup calls from `removeTagFromDive()` and `setTagsForDive()`

## Testing

### Unit Tests

| Test | What it verifies |
|------|-----------------|
| `mergeTags()` basic | Associations move correctly to surviving tag |
| `mergeTags()` dedup | Duplicate associations skipped (dive already has target tag) |
| `mergeTags()` cleanup | Source tags deleted after merge |
| `mergeTags()` sync | Sync records created for affected entities |
| `deleteTag()` cascade | Deleting tag removes dive_tags junction rows |
| `getTagUsageCount()` | Returns correct count |
| No auto-cleanup | `removeTagFromDive` on last dive leaves tag in `tags` table |

### Widget Tests

| Test | What it verifies |
|------|-----------------|
| Page renders list | Tags displayed with names, colors, usage counts |
| Search filters | Typing filters visible tags |
| Tap opens edit | Edit dialog appears with current name/color |
| Long-press enters selection | Selection mode UI appears |
| Selection actions | Merge disabled with <2, delete shows confirmation with count |
| Merge sheet | Pre-populates most-used name, radio buttons work, color picker works |
| Create dialog | FAB opens dialog, creating adds tag to list |

### Integration Tests

| Test | What it verifies |
|------|-----------------|
| Tag lifecycle | Create from management -> assign to dive -> rename -> verify on dive |
| Merge end-to-end | Create 3 tags on overlapping dives -> merge -> single tag on all, no duplicates |
| No auto-delete | Remove tag from last dive -> tag still in management page |
