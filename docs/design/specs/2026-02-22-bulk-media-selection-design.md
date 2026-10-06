# Bulk Media Selection & Unlink Design

**Date:** 2026-02-22
**Status:** Approved

## Problem

When linking photos to a dive, users can only tap-to-toggle individual photos. There is no way to select all or select a range quickly. When unlinking media from a dive, users must long-press each thumbnail individually. There is no bulk unlink.

## Solution

Build a shared `DragSelectGridView` widget that provides long-press-to-start + drag-to-range-select behavior. Use it on both the PhotoPickerPage (linking) and DiveMediaSection (unlinking).

## Design

### 1. Shared DragSelectGridView Widget

**File:** `lib/shared/widgets/drag_select_grid_view.dart`

```dart
class DragSelectGridView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext, T, bool isSelected) itemBuilder;
  final SliverGridDelegate gridDelegate;
  final Set<int> initialSelection;
  final ValueChanged<Set<int>> onSelectionChanged;
  final ValueChanged<bool> onSelectionModeChanged;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
}
```sql
**Interaction model:**

1. Normal mode: Taps pass through to itemBuilder's own gesture handling.
2. Long-press any item: enters selection mode, that item becomes the anchor.
3. Drag from long-press: all items from anchor to current finger position are selected.
4. In selection mode, taps toggle individual items.
5. Selection mode exits when selection becomes empty or parent clears it.

**Auto-scroll:** When finger is within 50px of grid top/bottom edge during drag, auto-scroll proportionally.

### 2. PhotoPickerPage Enhancement (Linking)

Replace `_PhotoGrid` with `DragSelectGridView<AssetInfo>`, wired to existing `PhotoPickerNotifier`.

**Toolbar additions** (below date range header, visible in selection mode):

- "Select All" button (uses existing `selectAll()`)
- "Clear" button (uses existing `clearSelection()`)
- Selection count badge: "X selected"

**Flow:**

1. Open photo picker from dive detail - see grid of photos in time range.
2. Tap any photo: toggles selection (same as today).
3. Long-press + drag: range-select from anchor to finger.
4. Select All button: selects every photo.
5. Done button: confirms selection, proceeds to import.

**No changes needed to:** `PhotoPickerNotifier`, `PhotoImportHelper`, `MediaImportService`.

### 3. DiveMediaSection Enhancement (Unlinking)

Convert `DiveMediaSection` to `ConsumerStatefulWidget` with local selection state (`isSelectionMode`, `selectedMediaIds`).

Replace `_MediaGrid` with `DragSelectGridView<MediaItem>`.

**Interaction model:**

1. Normal mode: Tap opens PhotoViewerPage. Long-press enters multi-select mode.
2. Selection mode: Header transforms to show selection count, Select All, Unlink Selected (trash icon), Cancel (X). Tap toggles items. Long-press + drag: range-select.
3. Unlink Selected: confirmation dialog, then batch delete, exit selection mode.
4. Cancel: clear selection, exit selection mode.

**Visual indicators in selection mode:**

- Selected thumbnails: checkmark overlay + colored border (consistent with PhotoPickerPage).
- Unselected thumbnails: subtle dimming overlay.

### 4. Batch Delete in Repository

Add `deleteMultipleMedia(List<String> ids)` to `MediaRepository`:

```dart
Future<void> deleteMultipleMedia(List<String> ids) async {
  await _db.transaction(() async {
    for (final id in ids) {
      await (_db.delete(_db.media)..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(entityType: 'media', recordId: id);
    }
  });
  SyncEventBus.notifyLocalChange();
}
```

Add corresponding `deleteMultipleMedia()` on `MediaListNotifier`.

### 5. Localization

| Key | Value |
|-----|-------|
| `media_photoPicker_selectAllButton` | "Select All" |
| `media_photoPicker_clearSelectionButton` | "Clear" |
| `media_photoPicker_selectedCount` | "{count} selected" |
| `media_diveMediaSection_unlinkSelectedTitle` | "Unlink {count} items?" |
| `media_diveMediaSection_unlinkSelectedContent` | "This will remove {count} media items from this dive. The original files won't be deleted." |
| `media_diveMediaSection_unlinkSelectedButton` | "Unlink {count}" |
| `media_diveMediaSection_unlinkSelectedSuccess` | "Unlinked {count} items" |
| `media_diveMediaSection_selectAllButton` | "Select All" |
| `media_diveMediaSection_cancelSelectionButton` | "Cancel" |

### 6. Accessibility

- Selection mode changes announced via `Semantics` with `liveRegion`.
- Haptic feedback on each new item entering selection during drag.
- All buttons have tooltips.

## Files Touched

| File | Change |
|------|--------|
| `lib/shared/widgets/drag_select_grid_view.dart` | New - shared drag-select grid widget |
| `lib/features/media/presentation/pages/photo_picker_page.dart` | Replace _PhotoGrid with DragSelectGridView, add toolbar |
| `lib/features/media/presentation/widgets/dive_media_section.dart` | Convert to ConsumerStatefulWidget, add multi-select mode |
| `lib/features/media/data/repositories/media_repository.dart` | Add deleteMultipleMedia() |
| `lib/features/media/presentation/providers/media_providers.dart` | Add deleteMultipleMedia() to MediaListNotifier |
| `lib/l10n/arb/app_en.arb` | Add new l10n strings |
