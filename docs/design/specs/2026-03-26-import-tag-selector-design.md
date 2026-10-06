# Import Tag Selector Design

**Date:** 2026-03-26
**Status:** Draft

## Problem

The current import process has a batch tag feature only for file imports (universal adapter). It uses a toggle + single text field embedded in the universal-import-specific review step, with an auto-generated name like "Subsurface Import 2026-03-26". Dive computer imports have no tag support at all.

Users should be able to apply one or more tags to all imported dives at review time, regardless of import source. The tag field should support both creating new tags and selecting existing ones.

## Design

### Approach: Wizard-Level Tag State

Tags are a wizard-level concern, not an adapter concern. Tag state lives in `ImportWizardState`, and tags are applied to imported dives as a post-import step in the `ImportWizardNotifier`. This removes tag injection logic from individual adapters entirely.

### State Layer

**`ImportWizardState`** — add field:

```dart
final List<TagSelection> importTags; // defaults to []
```

**`TagSelection`** — new lightweight model in `import_wizard/domain/models/`:

```dart
class TagSelection extends Equatable {
  /// Non-null when selecting an existing tag.
  final String? existingTagId;

  /// Display name — for both new and existing tags.
  final String name;

  const TagSelection({this.existingTagId, required this.name});

  bool get isNew => existingTagId == null;
}
```

**`ImportSourceAdapter`** — add getter:

```dart
/// Default tag name for this import source.
/// Format: "{source name} Import {YYYY-MM-DD}"
String get defaultTagName;
```

Default tag name logic per adapter:

| Source | Name source | Example |
|---|---|---|
| Dive computer (custom name set) | `_customDeviceName` | `"My Perdix Import 2026-03-26"` |
| Dive computer (no custom name) | `device.displayName` | `"Perdix Import 2026-03-26"` |
| Universal file import | `_displayName` (filename) | `"divelog.uddf Import 2026-03-26"` |
| UDDF adapter | `_displayName` | `"dive_log.uddf Import 2026-03-26"` |
| FIT adapter | `_displayName` | `"activity.fit Import 2026-03-26"` |
| HealthKit adapter | `_displayName` | `"HealthKit Import 2026-03-26"` |

**`ImportWizardNotifier`** — new methods:

- `initializeDefaultTag()` — called when the bundle is set. Creates a `TagSelection(name: adapter.defaultTagName)` and adds it to `importTags`.
- `addImportTag(TagSelection tag)` — appends a tag to the list.
- `removeImportTag(int index)` — removes a tag by index.

### UI: ImportTagsField Widget

**New widget:** `lib/features/import_wizard/presentation/widgets/import_tags_field.dart`

**Placement:** Below the tab bar, above the entity list, in the shared `ReviewStep` widget. Appears in both single-type and multi-type layouts.

**Behavior:**

- Displays current tags as removable `InputChip` widgets.
- The default tag is pre-added as a chip on mount. User can remove it.
- An "Add tag..." text input area follows the chips.
- Typing filters existing tags from `TagRepository.getAllTags()` via Flutter's `RawAutocomplete` widget.
- Selecting an existing tag creates a `TagSelection` with `existingTagId` set.
- Pressing enter on unmatched text creates a `TagSelection` with `existingTagId = null` (new tag).
- If the user types a name that matches an existing tag and presses enter (instead of selecting from the dropdown), treat it as selecting that existing tag — create a `TagSelection` with the existing tag's ID.
- Duplicate prevention: `addImportTag` checks if a tag with the same name (case-insensitive) is already in the list and silently ignores duplicates.
- No external packages required — uses Flutter's built-in `RawAutocomplete` + `InputChip`.

**Layout:** The chip field is wrapped in a container with a label row ("Import Tags" with tag icon), matching the visual style of the existing "Retain dive numbers" toggle area.

### Import Flow Changes

After `performImport` returns a `UnifiedImportResult` (which contains created dive IDs), the `ImportWizardNotifier` applies tags:

1. For each `TagSelection` in `importTags`:
   - If `existingTagId` is set, use that tag directly.
   - If new, call `TagRepository.getOrCreateTag(name)` to create the tag.
2. For each imported dive ID from the result, call `TagRepository.addTagToDive(diveId, tagId)`.
3. This runs as a final phase within the existing import progress tracking (reported as "Applying tags..." phase).

### Cleanup

Remove the following from the codebase:

- `BatchTagField` widget (`lib/features/universal_import/presentation/widgets/batch_tag_field.dart`)
- `ImportOptions.batchTag` field and `ImportOptions.defaultTag()` static method (`lib/features/universal_import/data/models/import_options.dart`)
- `_injectBatchTag()` method from `UniversalAdapter` (`lib/features/import_wizard/data/adapters/universal_adapter.dart`)
- Batch tag UI references from `import_review_step.dart` (`lib/features/universal_import/presentation/widgets/import_review_step.dart`)
- Related localization keys (`universalImport_label_importTag`, `universalImport_hint_tagDescription`, `universalImport_hint_tagExample`, `universalImport_tooltip_clearTag`)

### Testing

- **Unit tests** for `TagSelection` model (equality, `isNew` getter).
- **Unit tests** for `ImportWizardNotifier` tag methods (`initializeDefaultTag`, `addImportTag`, `removeImportTag`).
- **Unit tests** for post-import tag application logic — verify `getOrCreateTag` and `addTagToDive` called with correct arguments.
- **Widget tests** for `ImportTagsField` — chip rendering, removal, autocomplete suggestions, new tag creation.
- **Integration test** for full import flow — verify tags appear on imported dives after import completes.

## Out of Scope

- Per-dive tag assignment (tags apply to all imported dives in the batch).
- Tag color selection during import (uses default color; can be edited later in tag management).
- Tag management UI changes (existing tag list/edit screens are unaffected).
