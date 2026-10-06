# Tag Management Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a full tag management page under Settings > Manage > Tags with create, edit, delete, merge, and usage statistics.

**Architecture:** Full-page `TagManagePage` (ConsumerStatefulWidget) at route `/tags`, following the same Scaffold + ListView + FAB + selection mode pattern used by `SpeciesManagePage` and `DiveListContent`. Repository gains `mergeTags()` and public `getTagUsageCount()`. Auto-cleanup of unused tags is removed.

**Tech Stack:** Flutter, Drift ORM, Riverpod (StateNotifier), go_router, Material 3

**Design doc:** `docs/plans/2026-02-24-tag-management-design.md`

---

## Task 1: Remove Auto-Cleanup from TagRepository

Remove `_deleteTagIfUnused()`, `deleteUnusedTags()`, and all calls to them so tags persist until explicitly deleted.

**Files:**

- Modify: `lib/features/tags/data/repositories/tag_repository.dart`

**Step 1: Remove auto-cleanup call from `removeTagFromDive()`**

In `removeTagFromDive()` (around line 393), delete:

```dart
      // Clean up the tag if it's no longer used
      await _deleteTagIfUnused(tagId);
```text
**Step 2: Remove auto-cleanup call from `setTagsForDive()`**

In `setTagsForDive()`, delete the variables tracking removed tags (lines 261-265) and the cleanup loop (lines 313-316):

Remove from the top of the method:

```dart
      // Get existing tag IDs before deletion to check for cleanup later
      final existingTags = await getTagsForDive(diveId);
      final existingTagIds = existingTags.map((t) => t.id).toSet();
      final newTagIds = tags.map((t) => t.id).toSet();
      final removedTagIds = existingTagIds.difference(newTagIds);
```dart
Remove from the bottom of the method (before the final log line):

```dart
      // Clean up any tags that are no longer used
      for (final tagId in removedTagIds) {
        await _deleteTagIfUnused(tagId);
      }
```text
**Step 3: Delete the cleanup methods**

Delete the entire `_deleteTagIfUnused()` method (lines 407-418).

Delete the entire `deleteUnusedTags()` method (lines 434-447).

Delete the entire `_getTagUsageCount()` method (lines 421-431) — we will re-add it as public in the next task.

Delete the section header comment:

```dart
  // ============================================================================
  // Cleanup
  // ============================================================================
```text
**Step 4: Run tests**

Run: `flutter test`
Expected: All existing tests pass. The mock in `uddf_entity_importer_test.mocks.dart` will need regeneration later (Task 2).

**Step 5: Commit**

```bash
git add lib/features/tags/data/repositories/tag_repository.dart
git commit -m "refactor(tags): remove auto-cleanup of unused tags

Tags now persist until explicitly deleted by the user from the
tag management page. Removes _deleteTagIfUnused(), deleteUnusedTags(),
and their call sites in removeTagFromDive() and setTagsForDive()."
```text
---

## Task 2: Add `getTagUsageCount()` and `mergeTags()` to Repository

**Files:**

- Modify: `lib/features/tags/data/repositories/tag_repository.dart`

**Step 1: Add public `getTagUsageCount()`**

Add this method to the Statistics section (after `getTagStatistics()`):

```dart
  /// Get the number of dives using a specific tag
  Future<int> getTagUsageCount(String tagId) async {
    try {
      final result = await _db
          .customSelect(
            'SELECT COUNT(*) as count FROM dive_tags WHERE tag_id = ?',
            variables: [Variable.withString(tagId)],
          )
          .getSingle();
      return result.data['count'] as int;
    } catch (e, stackTrace) {
      _log.error('Failed to get tag usage count: $tagId', e, stackTrace);
      rethrow;
    }
  }

  /// Get combined dive count for multiple tags (union, not sum)
  Future<int> getMergedDiveCount(List<String> tagIds) async {
    if (tagIds.isEmpty) return 0;
    try {
      final placeholders = tagIds.map((_) => '?').join(',');
      final result = await _db
          .customSelect(
            'SELECT COUNT(DISTINCT dive_id) as count FROM dive_tags WHERE tag_id IN ($placeholders)',
            variables: tagIds.map((id) => Variable.withString(id)).toList(),
          )
          .getSingle();
      return result.data['count'] as int;
    } catch (e, stackTrace) {
      _log.error('Failed to get merged dive count', e, stackTrace);
      rethrow;
    }
  }
```text
**Step 2: Add `mergeTags()` method**

Add this method after the statistics section, in a new Merge section:

```dart
  // ============================================================================
  // Merge
  // ============================================================================

  /// Merge multiple tags into one surviving tag.
  ///
  /// [sourceTagIds] are the tags to merge away (will be deleted).
  /// [survivingTagId] is the tag that remains, updated with [name] and [colorHex].
  /// All dive associations from source tags move to the surviving tag.
  /// Duplicate associations (dive already has surviving tag) are removed.
  Future<void> mergeTags({
    required List<String> sourceTagIds,
    required String survivingTagId,
    required String name,
    required String? colorHex,
  }) async {
    try {
      _log.info(
        'Merging ${sourceTagIds.length} tags into $survivingTagId',
      );
      final now = DateTime.now().millisecondsSinceEpoch;

      // Update surviving tag name and color
      await (_db.update(_db.tags)..where((t) => t.id.equals(survivingTagId)))
          .write(
        TagsCompanion(
          name: Value(name),
          color: Value(colorHex),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'tags',
        recordId: survivingTagId,
        localUpdatedAt: now,
      );

      for (final sourceId in sourceTagIds) {
        // Get all dive associations for this source tag
        final sourceDiveTags = await (_db.select(_db.diveTags)
              ..where((t) => t.tagId.equals(sourceId)))
            .get();

        for (final diveTag in sourceDiveTags) {
          // Check if this dive already has the surviving tag
          final existing = await (_db.select(_db.diveTags)
                ..where(
                  (t) =>
                      t.diveId.equals(diveTag.diveId) &
                      t.tagId.equals(survivingTagId),
                ))
              .getSingleOrNull();

          if (existing == null) {
            // Move association to surviving tag
            final newId = _uuid.v4();
            await _db.into(_db.diveTags).insert(
              DiveTagsCompanion(
                id: Value(newId),
                diveId: Value(diveTag.diveId),
                tagId: Value(survivingTagId),
                createdAt: Value(now),
              ),
            );
            await _syncRepository.markRecordPending(
              entityType: 'diveTags',
              recordId: newId,
              localUpdatedAt: now,
            );
          }

          // Delete the old association
          await (_db.delete(_db.diveTags)
                ..where((t) => t.id.equals(diveTag.id)))
              .go();
          await _syncRepository.logDeletion(
            entityType: 'diveTags',
            recordId: diveTag.id,
          );

          // Update the dive's updatedAt
          await (_db.update(_db.dives)
                ..where((t) => t.id.equals(diveTag.diveId)))
              .write(DivesCompanion(updatedAt: Value(now)));
          await _syncRepository.markRecordPending(
            entityType: 'dives',
            recordId: diveTag.diveId,
            localUpdatedAt: now,
          );
        }

        // Delete the source tag
        await deleteTag(sourceId);
      }

      SyncEventBus.notifyLocalChange();
      _log.info('Merged ${sourceTagIds.length} tags into $survivingTagId');
    } catch (e, stackTrace) {
      _log.error('Failed to merge tags', e, stackTrace);
      rethrow;
    }
  }
```text
**Step 3: Regenerate mocks**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Mocks regenerate successfully, picking up the removed `deleteUnusedTags` and new public methods.

**Step 4: Run tests**

Run: `flutter test`
Expected: All tests pass.

**Step 5: Commit**

```bash
git add lib/features/tags/data/repositories/tag_repository.dart
git add test/  # regenerated mocks
git commit -m "feat(tags): add mergeTags() and public getTagUsageCount()

mergeTags() reassigns dive associations from source tags to a surviving
tag, deduplicates, deletes sources, and syncs all affected records.
getTagUsageCount() and getMergedDiveCount() are public for the UI."
```text
---

## Task 3: Add `mergeTags()` and `deleteTags()` to TagListNotifier

**Files:**

- Modify: `lib/features/tags/presentation/providers/tag_providers.dart`

**Step 1: Add `mergeTags()` to `TagListNotifier`**

Add after the existing `deleteTag()` method:

```dart
  Future<void> deleteTags(List<String> ids) async {
    for (final id in ids) {
      await _repository.deleteTag(id);
    }
    await _loadTags();
    _ref.invalidate(tagStatisticsProvider);
  }

  Future<void> mergeTags({
    required List<String> sourceTagIds,
    required String survivingTagId,
    required String name,
    required String? colorHex,
  }) async {
    await _repository.mergeTags(
      sourceTagIds: sourceTagIds,
      survivingTagId: survivingTagId,
      name: name,
      colorHex: colorHex,
    );
    await _loadTags();
    _ref.invalidate(tagStatisticsProvider);
  }
```text
**Step 2: Run tests**

Run: `flutter test`
Expected: All tests pass.

**Step 3: Commit**

```bash
git add lib/features/tags/presentation/providers/tag_providers.dart
git commit -m "feat(tags): add mergeTags() and deleteTags() to TagListNotifier"
```diff
---

## Task 4: Add l10n Strings

**Files:**

- Modify: `lib/l10n/arb/app_en.arb`

**Step 1: Add new l10n keys**

Add these entries to `app_en.arb` in the tags section (near the existing `tags_*` keys around line 6597):

```json
  "settings_manage_tags": "Tags",
  "settings_manage_tags_subtitle": "Manage, merge, and delete tags",

  "tags_manage_title": "Tags",
  "tags_manage_searchHint": "Search tags...",
  "tags_manage_diveCount": "{count, plural, =0{0 dives} =1{1 dive} other{{count} dives}}",
  "tags_manage_emptyState": "No tags yet. Create one to get started.",
  "tags_manage_selectedCount": "{count} selected",

  "tags_manage_createTitle": "Create Tag",
  "tags_manage_editTitle": "Edit Tag",
  "tags_manage_nameLabel": "Tag Name",
  "tags_manage_colorLabel": "Color",
  "tags_manage_nameRequired": "Tag name is required",

  "tags_manage_deleteTitle": "Delete Tag?",
  "tags_manage_deleteMessage": "\"{tagName}\" will be removed from {count, plural, =0{0 dives} =1{1 dive} other{{count} dives}}. This cannot be undone.",
  "tags_manage_bulkDeleteTitle": "Delete {count} Tags?",
  "tags_manage_bulkDeleteMessage": "These tags will be removed from {diveCount, plural, =0{0 dives} =1{1 dive} other{{diveCount} dives}} total. This cannot be undone.",

  "tags_manage_mergeTitle": "Merge {count} Tags",
  "tags_manage_mergeResultName": "Resulting tag name:",
  "tags_manage_mergeKeepFrom": "Or keep name from:",
  "tags_manage_mergeAffectedDives": "This will affect {count, plural, =0{0 dives} =1{1 dive} other{{count} dives}} total.",
  "tags_manage_mergeAction": "Merge",
```text
Also add the `@` metadata entries for parameterized strings (following the existing pattern in the file).

**Step 2: Run codegen**

Run: `flutter gen-l10n` (or `flutter pub get` if configured via build)
Expected: `app_localizations_en.dart` regenerates with new getters.

**Step 3: Commit**

```bash
git add lib/l10n/
git commit -m "feat(l10n): add tag management localization strings"
```text
---

## Task 5: Add `/tags` Route

**Files:**

- Modify: `lib/core/router/app_router.dart`

**Step 1: Add import**

Add at the top of the file with the other feature imports:

```dart
import 'package:submersion/features/tags/presentation/pages/tag_manage_page.dart';
```text
**Step 2: Add route**

Add the `/tags` route after the `/species` route block (around line 825):

```dart
          // Tag Management
          GoRoute(
            path: '/tags',
            name: 'tagManage',
            builder: (context, state) => const TagManagePage(),
          ),
```text
**Step 3: Add Tags row to settings manage section**

In `lib/features/settings/presentation/pages/settings_page.dart`, inside `_ManageSectionContent`, add a new `ListTile` after the Species entry (line 1718):

```dart
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sell),
                  title: Text(context.l10n.settings_manage_tags),
                  subtitle: Text(
                    context.l10n.settings_manage_tags_subtitle,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/tags'),
                ),
```text
Note: `Icons.sell` is the tag/label icon in Material 3 — distinct from `Icons.label` used for dive types.

**Step 4: Commit (will be combined with Task 6 after the page exists)**

Hold this commit until `TagManagePage` is created in Task 6.

---

## Task 6: Create Tag Management Page — Default Mode

**Files:**

- Create: `lib/features/tags/presentation/pages/tag_manage_page.dart`

**Step 1: Create the page file**

Create `lib/features/tags/presentation/pages/tag_manage_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class TagManagePage extends ConsumerStatefulWidget {
  const TagManagePage({super.key});

  @override
  ConsumerState<TagManagePage> createState() => _TagManagePageState();
}

class _TagManagePageState extends ConsumerState<TagManagePage> {
  String _searchQuery = '';
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(tagStatisticsProvider);

    return Scaffold(
      appBar: _isSelectionMode
          ? _buildSelectionAppBar()
          : _buildDefaultAppBar(),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => _showCreateDialog(context),
              child: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          if (!_isSelectionMode) _buildSearchBar(),
          Expanded(
            child: statsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (stats) => _buildTagList(stats),
            ),
          ),
        ],
      ),
    );
  }

  // ... (methods detailed in subsequent steps)
}
```text
**Step 2: Implement `_buildDefaultAppBar()`**

```dart
  AppBar _buildDefaultAppBar() {
    return AppBar(
      title: Text(context.l10n.tags_manage_title),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
    );
  }
```text
**Step 3: Implement `_buildSearchBar()`**

Follow the same pattern as `SpeciesManagePage._buildSearchBar()`:

```dart
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        decoration: InputDecoration(
          hintText: context.l10n.tags_manage_searchHint,
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }
```text
**Step 4: Implement `_buildTagList()`**

```dart
  Widget _buildTagList(List<TagStatistic> stats) {
    final filtered = _searchQuery.isEmpty
        ? stats
        : stats
            .where(
              (s) => s.tag.name.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ),
            )
            .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty
              ? context.l10n.tags_manage_emptyState
              : context.l10n.tags_empty,
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final stat = filtered[index];
        final isSelected = _selectedIds.contains(stat.tag.id);

        return ListTile(
          leading: _isSelectionMode
              ? Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(stat.tag.id),
                )
              : CircleAvatar(radius: 16, backgroundColor: stat.tag.color),
          title: Text(stat.tag.name),
          trailing: Text(
            context.l10n.tags_manage_diveCount(stat.diveCount),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(stat.tag.id);
            } else {
              _showEditDialog(context, stat.tag);
            }
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              _enterSelectionMode(stat.tag.id);
            }
          },
        );
      },
    );
  }
```text
**Step 5: Implement selection mode helpers**

```dart
  void _enterSelectionMode(String? initialId) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.clear();
      if (initialId != null) {
        _selectedIds.add(initialId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }
```text
**Step 6: Implement `_showCreateDialog()` and `_showEditDialog()`**

Reuse the same dialog pattern from the existing `TagManagementDialog._editTag()` in `tag_input_widget.dart`. The create dialog is the same but with empty initial values. Use l10n keys from Task 4.

**Step 7: Run the app to verify**

Run: `flutter run -d macos`
Navigate to Settings > Manage > Tags. Verify:

- Tag list renders with colors and dive counts
- Search filters the list
- Tap opens edit dialog
- FAB opens create dialog

**Step 8: Commit**

```bash
git add lib/features/tags/presentation/pages/tag_manage_page.dart
git add lib/core/router/app_router.dart
git add lib/features/settings/presentation/pages/settings_page.dart
git commit -m "feat(tags): add tag management page with CRUD and search

New TagManagePage at /tags with list view showing tag names, colors,
and usage counts. Tap to edit, FAB to create, long-press for selection
mode. Accessible from Settings > Manage > Tags."
```text
---

## Task 7: Add Selection Mode with Delete

**Files:**

- Modify: `lib/features/tags/presentation/pages/tag_manage_page.dart`

**Step 1: Implement `_buildSelectionAppBar()`**

```dart
  AppBar _buildSelectionAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _exitSelectionMode,
      ),
      title: Text(
        context.l10n.tags_manage_selectedCount(_selectedIds.length),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.merge),
          onPressed: _selectedIds.length >= 2
              ? () => _showMergeSheet(context)
              : null,
          tooltip: context.l10n.tags_manage_mergeAction,
        ),
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: _selectedIds.isNotEmpty
              ? () => _confirmDelete(context)
              : null,
          tooltip: context.l10n.common_action_delete,
        ),
      ],
    );
  }
```text
**Step 2: Implement `_confirmDelete()`**

```dart
  Future<void> _confirmDelete(BuildContext context) async {
    final repository = ref.read(tagRepositoryProvider);
    final statsAsync = ref.read(tagStatisticsProvider);
    final stats = statsAsync.valueOrNull ?? [];

    if (_selectedIds.length == 1) {
      final tagId = _selectedIds.first;
      final stat = stats.firstWhere((s) => s.tag.id == tagId);
      final count = stat.diveCount;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.tags_manage_deleteTitle),
          content: Text(
            context.l10n.tags_manage_deleteMessage(stat.tag.name, count),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.common_action_cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(context.l10n.common_action_delete),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await ref.read(tagListNotifierProvider.notifier).deleteTag(tagId);
        _exitSelectionMode();
      }
    } else {
      // Bulk delete
      final totalDives = await repository.getMergedDiveCount(
        _selectedIds.toList(),
      );

      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            context.l10n.tags_manage_bulkDeleteTitle(_selectedIds.length),
          ),
          content: Text(
            context.l10n.tags_manage_bulkDeleteMessage(totalDives),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.common_action_cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(context.l10n.common_action_delete),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await ref
            .read(tagListNotifierProvider.notifier)
            .deleteTags(_selectedIds.toList());
        _exitSelectionMode();
      }
    }
  }
```sql
**Step 3: Run the app and test selection mode**

Run: `flutter run -d macos`

- Long-press a tag to enter selection mode
- Verify app bar shows count, merge icon (disabled with 1), delete icon
- Tap delete on 1 tag -> confirmation shows dive count -> deletes
- Select 2+ tags -> delete -> bulk confirmation

**Step 4: Commit**

```bash
git add lib/features/tags/presentation/pages/tag_manage_page.dart
git commit -m "feat(tags): add selection mode with single and bulk delete

Long-press enters selection mode with checkmarks. Delete action shows
confirmation with affected dive count for single or bulk deletion."
```text
---

## Task 8: Create Merge Bottom Sheet

**Files:**

- Create: `lib/features/tags/presentation/widgets/tag_merge_sheet.dart`
- Modify: `lib/features/tags/presentation/pages/tag_manage_page.dart`

**Step 1: Create the merge sheet widget**

Create `lib/features/tags/presentation/widgets/tag_merge_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class TagMergeSheet extends ConsumerStatefulWidget {
  final List<TagStatistic> selectedStats;

  const TagMergeSheet({super.key, required this.selectedStats});

  @override
  ConsumerState<TagMergeSheet> createState() => _TagMergeSheetState();
}

class _TagMergeSheetState extends ConsumerState<TagMergeSheet> {
  late final TextEditingController _nameController;
  late String _selectedColor;
  late String _selectedNameFromTag;
  int? _totalAffectedDives;
  bool _isMerging = false;

  @override
  void initState() {
    super.initState();
    // Sort by dive count descending to pick the most-used as default
    final sorted = [...widget.selectedStats]
      ..sort((a, b) => b.diveCount.compareTo(a.diveCount));
    final mostUsed = sorted.first;

    _nameController = TextEditingController(text: mostUsed.tag.name);
    _selectedColor = mostUsed.tag.colorHex ?? TagColors.predefined.first;
    _selectedNameFromTag = mostUsed.tag.id;

    _loadMergedDiveCount();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadMergedDiveCount() async {
    final repository = ref.read(tagRepositoryProvider);
    final count = await repository.getMergedDiveCount(
      widget.selectedStats.map((s) => s.tag.id).toList(),
    );
    if (mounted) {
      setState(() => _totalAffectedDives = count);
    }
  }

  Future<void> _performMerge() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isMerging = true);

    final survivingId = _selectedNameFromTag;
    final sourceIds = widget.selectedStats
        .map((s) => s.tag.id)
        .where((id) => id != survivingId)
        .toList();

    await ref.read(tagListNotifierProvider.notifier).mergeTags(
          sourceTagIds: sourceIds,
          survivingTagId: survivingId,
          name: _nameController.text.trim(),
          colorHex: _selectedColor,
        );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.selectedStats]
      ..sort((a, b) => b.diveCount.compareTo(a.diveCount));

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.tags_manage_mergeTitle(widget.selectedStats.length),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),

          // Resulting name text field
          Text(context.l10n.tags_manage_mergeResultName),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: context.l10n.tags_manage_nameLabel,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Radio buttons for quick name selection
          Text(context.l10n.tags_manage_mergeKeepFrom),
          const SizedBox(height: 4),
          ...sorted.map(
            (stat) => RadioListTile<String>(
              dense: true,
              title: Text(stat.tag.name),
              subtitle: Text(
                context.l10n.tags_manage_diveCount(stat.diveCount),
              ),
              value: stat.tag.id,
              groupValue: _selectedNameFromTag,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedNameFromTag = value;
                    _nameController.text = stat.tag.name;
                    _selectedColor =
                        stat.tag.colorHex ?? TagColors.predefined.first;
                  });
                }
              },
            ),
          ),
          const SizedBox(height: 16),

          // Color picker
          Text(context.l10n.tags_manage_colorLabel),
          const SizedBox(height: 8),
          TagColorPicker(
            selectedColor: _selectedColor,
            onColorSelected: (color) =>
                setState(() => _selectedColor = color),
          ),
          const SizedBox(height: 16),

          // Affected dives count
          if (_totalAffectedDives != null)
            Text(
              context.l10n.tags_manage_mergeAffectedDives(_totalAffectedDives!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isMerging ? null : () => Navigator.pop(context),
                child: Text(context.l10n.common_action_cancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isMerging ||
                        _nameController.text.trim().isEmpty
                    ? null
                    : _performMerge,
                child: _isMerging
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.l10n.tags_manage_mergeAction),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```text
**Step 2: Wire up `_showMergeSheet()` in `tag_manage_page.dart`**

Add this method to `_TagManagePageState`:

```dart
  Future<void> _showMergeSheet(BuildContext context) async {
    final statsAsync = ref.read(tagStatisticsProvider);
    final stats = statsAsync.valueOrNull ?? [];

    final selectedStats = stats
        .where((s) => _selectedIds.contains(s.tag.id))
        .toList();

    if (selectedStats.length < 2) return;

    final merged = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => TagMergeSheet(selectedStats: selectedStats),
    );

    if (merged == true) {
      _exitSelectionMode();
    }
  }
```typescript
Add the import at the top:

```dart
import 'package:submersion/features/tags/presentation/widgets/tag_merge_sheet.dart';
```sql
**Step 3: Run the app and test merge flow**

Run: `flutter run -d macos`

- Select 2+ tags -> tap merge icon
- Verify bottom sheet shows names, radio buttons, color picker, affected count
- Pick a name and merge -> tags combine

**Step 4: Commit**

```bash
git add lib/features/tags/presentation/widgets/tag_merge_sheet.dart
git add lib/features/tags/presentation/pages/tag_manage_page.dart
git commit -m "feat(tags): add merge bottom sheet for combining tags

Select 2+ tags and merge into one. Bottom sheet lets user pick name
(from existing or custom), choose color, shows affected dive count.
All dive associations deduplicated during merge."
```text
---

## Task 9: Remove Orphaned TagManagementDialog

**Files:**

- Modify: `lib/features/tags/presentation/widgets/tag_input_widget.dart`

**Step 1: Delete `TagManagementDialog`**

Remove the entire `TagManagementDialog` class (lines 278-437) from `tag_input_widget.dart`. Keep `TagInputWidget`, `TagChips`, and `TagColorPicker`.

**Step 2: Run tests**

Run: `flutter test`
Expected: All tests pass (no code references `TagManagementDialog`).

**Step 3: Commit**

```bash
git add lib/features/tags/presentation/widgets/tag_input_widget.dart
git commit -m "refactor(tags): remove orphaned TagManagementDialog

Replaced by the full TagManagePage. The dialog was defined but never
used anywhere in the app."
```text
---

## Task 10: Write Repository Unit Tests

**Files:**

- Create: `test/features/tags/data/repositories/tag_repository_test.dart`

**Step 1: Write test file**

Create `test/features/tags/data/repositories/tag_repository_test.dart` with tests for:

1. `getTagUsageCount()` returns correct count
2. `getMergedDiveCount()` returns union count (not sum)
3. `mergeTags()` moves associations to surviving tag
4. `mergeTags()` skips duplicate associations
5. `mergeTags()` deletes source tags
6. `removeTagFromDive()` does NOT delete the tag when it was the last dive (no auto-cleanup)
7. `setTagsForDive()` does NOT delete removed tags (no auto-cleanup)

Use an in-memory Drift database for these tests (same pattern as other repository tests in the project). Each test should:

- Set up tags and dive_tags in the database
- Call the repository method
- Assert the expected database state

**Step 2: Run tests to verify they fail**

Run: `flutter test test/features/tags/data/repositories/tag_repository_test.dart`
Expected: Tests should pass since implementation already exists from Tasks 1-2.

**Step 3: Commit**

```bash
git add test/features/tags/data/repositories/tag_repository_test.dart
git commit -m "test(tags): add repository tests for merge, delete, and no auto-cleanup"
```dart
---

## Task 11: Write Widget Tests for Tag Management Page

**Files:**

- Create: `test/features/tags/presentation/pages/tag_manage_page_test.dart`

**Step 1: Write test file**

Create widget tests covering:

1. Page renders tag list with names, colors, and usage counts
2. Search bar filters visible tags
3. Tapping a tag opens edit dialog
4. Long-press enters selection mode with correct UI
5. Delete button shows confirmation with dive count
6. Merge button disabled when fewer than 2 selected
7. FAB opens create dialog
8. Empty state shows when no tags exist

Mock `TagListNotifier` and `tagStatisticsProvider` using Riverpod overrides.

**Step 2: Run tests**

Run: `flutter test test/features/tags/presentation/pages/tag_manage_page_test.dart`
Expected: All pass.

**Step 3: Commit**

```bash
git add test/features/tags/presentation/pages/tag_manage_page_test.dart
git commit -m "test(tags): add widget tests for TagManagePage"
```dart
---

## Task 12: Write Widget Tests for Merge Sheet

**Files:**

- Create: `test/features/tags/presentation/widgets/tag_merge_sheet_test.dart`

**Step 1: Write test file**

Create widget tests covering:

1. Pre-populates name field with most-used tag
2. Radio buttons switch the name field
3. Color picker selects color
4. Merge button disabled with empty name
5. Merge button calls notifier with correct params

**Step 2: Run tests**

Run: `flutter test test/features/tags/presentation/widgets/tag_merge_sheet_test.dart`
Expected: All pass.

**Step 3: Commit**

```bash
git add test/features/tags/presentation/widgets/tag_merge_sheet_test.dart
git commit -m "test(tags): add widget tests for TagMergeSheet"
```sql
---

## Task 13: Format, Analyze, and Final Verification

**Files:** All modified/created files

**Step 1: Format**

Run: `dart format lib/features/tags/ test/features/tags/`

**Step 2: Analyze**

Run: `flutter analyze`
Expected: No issues.

**Step 3: Run all tests**

Run: `flutter test`
Expected: All tests pass.

**Step 4: Manual smoke test**

Run: `flutter run -d macos`
Test the full flow:

1. Settings > Manage > Tags
2. Create a new tag
3. Edit its name and color
4. Assign it to a dive, then remove it from that dive -> verify tag persists
5. Create 3 tags, assign to overlapping dives
6. Select 2 tags -> merge -> verify result
7. Select a tag -> delete -> verify removed from dives

**Step 5: Final commit if any formatting changes**

```bash
git add -A
git commit -m "chore(tags): format and cleanup tag management feature"
```
