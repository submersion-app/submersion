# Import Tag Selector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single-use batch tag toggle in file imports with a multi-tag selector on the shared review step, available for both file and dive computer imports.

**Architecture:** Tag state lives in `ImportWizardState` (wizard-level, not adapter-level). A new `ImportTagsField` widget with chip-based autocomplete sits in the shared `ReviewStep`. Tags are applied post-import via `TagRepository`. Old batch tag injection code is removed.

**Tech Stack:** Flutter, Riverpod (StateNotifier), Drift (SQLite), RawAutocomplete, InputChip, Mockito

---

## File Structure

**New files:**
- `lib/features/import_wizard/domain/models/tag_selection.dart` — TagSelection model
- `lib/features/import_wizard/presentation/widgets/import_tags_field.dart` — Multi-tag chip widget
- `test/features/import_wizard/domain/models/tag_selection_test.dart` — TagSelection tests
- `test/features/import_wizard/presentation/widgets/import_tags_field_test.dart` — Widget tests

**Modified files:**
- `lib/features/import_wizard/domain/adapters/import_source_adapter.dart` — Add `defaultTagName` getter
- `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart` — Implement `defaultTagName`
- `lib/features/import_wizard/data/adapters/universal_adapter.dart` — Implement `defaultTagName`, remove `_injectBatchTag`
- `lib/features/import_wizard/data/adapters/uddf_adapter.dart` — Implement `defaultTagName`
- `lib/features/import_wizard/data/adapters/fit_adapter.dart` — Implement `defaultTagName`
- `lib/features/import_wizard/data/adapters/healthkit_adapter.dart` — Implement `defaultTagName`
- `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart` — Add `importTags` to state, tag methods to notifier, post-import tag application
- `lib/features/import_wizard/presentation/widgets/review_step.dart` — Integrate `ImportTagsField`
- `test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart` — Add tag method tests
- `test/features/import_wizard/data/adapters/universal_adapter_test.dart` — Remove batch tag tests

**Deleted files:**
- `lib/features/universal_import/presentation/widgets/batch_tag_field.dart`

**Cleanup modifications:**
- `lib/features/universal_import/data/models/import_options.dart` — Remove `batchTag` field
- `lib/features/universal_import/presentation/widgets/import_review_step.dart` — Remove `BatchTagField` usage
- `lib/features/universal_import/presentation/providers/universal_import_providers.dart` — Remove `updateBatchTag`, `_injectBatchTag`, batch tag references

---

### Task 1: TagSelection Model

**Files:**
- Create: `lib/features/import_wizard/domain/models/tag_selection.dart`
- Create: `test/features/import_wizard/domain/models/tag_selection_test.dart`

- [ ] **Step 1: Write failing tests for TagSelection**

Create `test/features/import_wizard/domain/models/tag_selection_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/domain/models/tag_selection.dart';

void main() {
  group('TagSelection', () {
    test('isNew returns true when existingTagId is null', () {
      const tag = TagSelection(name: 'Vacation');
      expect(tag.isNew, isTrue);
    });

    test('isNew returns false when existingTagId is set', () {
      const tag = TagSelection(existingTagId: 'tag-123', name: 'Vacation');
      expect(tag.isNew, isFalse);
    });

    test('equality by name and existingTagId', () {
      const a = TagSelection(name: 'Vacation');
      const b = TagSelection(name: 'Vacation');
      expect(a, equals(b));
    });

    test('inequality when names differ', () {
      const a = TagSelection(name: 'Vacation');
      const b = TagSelection(name: 'Training');
      expect(a, isNot(equals(b)));
    });

    test('inequality when existingTagId differs', () {
      const a = TagSelection(existingTagId: 'id-1', name: 'Vacation');
      const b = TagSelection(existingTagId: 'id-2', name: 'Vacation');
      expect(a, isNot(equals(b)));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/import_wizard/domain/models/tag_selection_test.dart`
Expected: FAIL — `tag_selection.dart` does not exist.

- [ ] **Step 3: Implement TagSelection model**

Create `lib/features/import_wizard/domain/models/tag_selection.dart`:

```dart
import 'package:equatable/equatable.dart';

/// A tag selected by the user during import review.
///
/// Can represent either an existing tag (with [existingTagId]) or a new tag
/// to be created (when [existingTagId] is null).
class TagSelection extends Equatable {
  /// Non-null when selecting an existing tag from the database.
  final String? existingTagId;

  /// Display name for both new and existing tags.
  final String name;

  const TagSelection({this.existingTagId, required this.name});

  /// True if this represents a new tag to be created.
  bool get isNew => existingTagId == null;

  @override
  List<Object?> get props => [existingTagId, name];
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/import_wizard/domain/models/tag_selection_test.dart`
Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/import_wizard/domain/models/tag_selection.dart test/features/import_wizard/domain/models/tag_selection_test.dart
git commit -m "feat: add TagSelection model for import tag selector"
```

---

### Task 2: Add defaultTagName to Adapter Interface

**Files:**
- Modify: `lib/features/import_wizard/domain/adapters/import_source_adapter.dart`
- Modify: `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart`
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart`
- Modify: `lib/features/import_wizard/data/adapters/uddf_adapter.dart`
- Modify: `lib/features/import_wizard/data/adapters/fit_adapter.dart`
- Modify: `lib/features/import_wizard/data/adapters/healthkit_adapter.dart`

- [ ] **Step 1: Add defaultTagName to the abstract adapter**

In `lib/features/import_wizard/domain/adapters/import_source_adapter.dart`, add after the `displayName` getter (line 17):

```dart
  /// Default tag name for this import source.
  ///
  /// Format: "{source name} Import {YYYY-MM-DD}".
  /// Used to pre-populate the import tag field in the review step.
  String get defaultTagName {
    final now = DateTime.now();
    final date =
        '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return '$displayName Import $date';
  }
```

This provides a default implementation using `displayName` that works for most adapters.

- [ ] **Step 2: Override defaultTagName in DiveComputerAdapter**

In `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart`, add after the `displayName` getter (after line 197):

```dart
  @override
  String get defaultTagName {
    final name = _customDeviceName ?? _displayName;
    final now = DateTime.now();
    final date =
        '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return '$name Import $date';
  }
```

The other adapters (universal, uddf, fit, healthkit) inherit the default implementation which already uses their `displayName`.

- [ ] **Step 3: Run existing tests to verify no regressions**

Run: `flutter test test/features/import_wizard/`
Expected: All existing tests PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/import_wizard/domain/adapters/import_source_adapter.dart lib/features/import_wizard/data/adapters/dive_computer_adapter.dart
git commit -m "feat: add defaultTagName getter to ImportSourceAdapter"
```

---

### Task 3: Add Import Tags to Wizard State and Notifier

**Files:**
- Modify: `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart`
- Modify: `test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart`

- [ ] **Step 1: Write failing tests for tag management methods**

Add to `test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart`, inside the `ImportWizardNotifier` group, after the `reset` group (before the closing `});` of the main group):

```dart
    // -------------------------------------------------------------------------
    // Import tags
    // -------------------------------------------------------------------------

    group('initializeDefaultTag', () {
      test('adds default tag from adapter when bundle is set', () {
        when(mockAdapter.defaultTagName).thenReturn('test.uddf Import 2026-03-26');
        final bundle = buildBundle(diveItems: [makeItem('Dive 1')]);
        notifier.setBundle(bundle);

        notifier.initializeDefaultTag();

        expect(notifier.state.importTags.length, equals(1));
        expect(notifier.state.importTags.first.name, equals('test.uddf Import 2026-03-26'));
        expect(notifier.state.importTags.first.isNew, isTrue);
      });

      test('does not add duplicate default tag on repeated calls', () {
        when(mockAdapter.defaultTagName).thenReturn('test.uddf Import 2026-03-26');
        final bundle = buildBundle(diveItems: [makeItem('Dive 1')]);
        notifier.setBundle(bundle);

        notifier.initializeDefaultTag();
        notifier.initializeDefaultTag();

        expect(notifier.state.importTags.length, equals(1));
      });
    });

    group('addImportTag', () {
      test('appends a tag to the list', () {
        const tag = TagSelection(name: 'Vacation');
        notifier.addImportTag(tag);

        expect(notifier.state.importTags, contains(tag));
      });

      test('ignores duplicate tag names case-insensitively', () {
        const tag1 = TagSelection(name: 'Vacation');
        const tag2 = TagSelection(name: 'vacation');
        notifier.addImportTag(tag1);
        notifier.addImportTag(tag2);

        expect(notifier.state.importTags.length, equals(1));
      });

      test('allows tags with different names', () {
        const tag1 = TagSelection(name: 'Vacation');
        const tag2 = TagSelection(name: 'Training');
        notifier.addImportTag(tag1);
        notifier.addImportTag(tag2);

        expect(notifier.state.importTags.length, equals(2));
      });
    });

    group('removeImportTag', () {
      test('removes tag at given index', () {
        const tag1 = TagSelection(name: 'Vacation');
        const tag2 = TagSelection(name: 'Training');
        notifier.addImportTag(tag1);
        notifier.addImportTag(tag2);

        notifier.removeImportTag(0);

        expect(notifier.state.importTags.length, equals(1));
        expect(notifier.state.importTags.first.name, equals('Training'));
      });

      test('no-op for out of range index', () {
        const tag = TagSelection(name: 'Vacation');
        notifier.addImportTag(tag);

        notifier.removeImportTag(5);

        expect(notifier.state.importTags.length, equals(1));
      });
    });
```

Also add the import at the top of the test file:

```dart
import 'package:submersion/features/import_wizard/domain/models/tag_selection.dart';
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart`
Expected: FAIL — `importTags` does not exist on `ImportWizardState`.

- [ ] **Step 3: Add importTags to ImportWizardState**

In `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart`:

Add import at top:

```dart
import 'package:submersion/features/import_wizard/domain/models/tag_selection.dart';
```

Add field to `ImportWizardState` constructor (after `retainSourceDiveNumbers`):

```dart
    this.importTags = const [],
```

Add field declaration (after `retainSourceDiveNumbers` field):

```dart
  /// Tags to apply to all imported dives.
  final List<TagSelection> importTags;
```

Add to `copyWith` method — new parameter:

```dart
    List<TagSelection>? importTags,
```

And in the return body:

```dart
      importTags: importTags ?? this.importTags,
```

- [ ] **Step 4: Add tag management methods to ImportWizardNotifier**

In `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart`, add a new section after the `setRetainSourceDiveNumbers` method (after line 215):

```dart
  // -------------------------------------------------------------------------
  // Import tags
  // -------------------------------------------------------------------------

  /// Pre-populate [importTags] with the adapter's default tag.
  ///
  /// Safe to call multiple times — skips if a tag with the same name already
  /// exists.
  void initializeDefaultTag() {
    final defaultName = _adapter.defaultTagName;
    final alreadyExists = state.importTags.any(
      (t) => t.name.toLowerCase() == defaultName.toLowerCase(),
    );
    if (alreadyExists) return;

    state = state.copyWith(
      importTags: [...state.importTags, TagSelection(name: defaultName)],
    );
  }

  /// Add a tag to the import list.
  ///
  /// Silently ignores duplicates (case-insensitive name match).
  void addImportTag(TagSelection tag) {
    final alreadyExists = state.importTags.any(
      (t) => t.name.toLowerCase() == tag.name.toLowerCase(),
    );
    if (alreadyExists) return;

    state = state.copyWith(importTags: [...state.importTags, tag]);
  }

  /// Remove a tag from the import list by index.
  void removeImportTag(int index) {
    if (index < 0 || index >= state.importTags.length) return;
    final updated = List<TagSelection>.from(state.importTags)..removeAt(index);
    state = state.copyWith(importTags: updated);
  }
```

- [ ] **Step 5: Update reset method to clear importTags**

The `reset()` method already creates a fresh `ImportWizardState()`, which defaults `importTags` to `const []`. No change needed — but verify the test:

Add to the existing `reset` test group (inside the `'returns to initial state'` test body, after the `error` assertion):

```dart
        expect(notifier.state.importTags, isEmpty);
```

- [ ] **Step 6: Regenerate mocks**

Run: `dart run build_runner build --delete-conflicting-outputs`

This regenerates `import_wizard_notifier_test.mocks.dart` to include the new `defaultTagName` getter on `MockImportSourceAdapter`.

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart`
Expected: All tests PASS including the new tag management tests.

- [ ] **Step 8: Commit**

```bash
git add lib/features/import_wizard/presentation/providers/import_wizard_providers.dart test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart test/features/import_wizard/presentation/providers/import_wizard_notifier_test.mocks.dart
git commit -m "feat: add import tag state and management to wizard notifier"
```

---

### Task 4: Post-Import Tag Application

**Files:**
- Modify: `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart`
- Modify: `test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart`

- [ ] **Step 1: Write failing test for post-import tag application**

Add to the `performImport` group in the notifier test file:

```dart
      test('applies import tags to all imported dives after import', () async {
        final bundle = buildBundle(diveItems: [makeItem('Dive 1')]);
        notifier.setBundle(bundle);

        const tag = TagSelection(name: 'Vacation');
        notifier.addImportTag(tag);

        const importResult = UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 1},
          consolidatedCount: 0,
          skippedCount: 0,
          importedDiveIds: ['dive-1'],
        );

        when(
          mockAdapter.performImport(
            any,
            any,
            any,
            retainSourceDiveNumbers: anyNamed('retainSourceDiveNumbers'),
            onProgress: anyNamed('onProgress'),
          ),
        ).thenAnswer((_) async => importResult);

        when(mockTagRepo.getOrCreateTag('Vacation'))
            .thenAnswer((_) async => Tag(
                  id: 'tag-new',
                  name: 'Vacation',
                  createdAt: DateTime(2026),
                  updatedAt: DateTime(2026),
                ));
        when(mockTagRepo.addTagToDive(any, any)).thenAnswer((_) async {});

        await notifier.performImport();

        verify(mockTagRepo.getOrCreateTag('Vacation')).called(1);
        verify(mockTagRepo.addTagToDive('dive-1', 'tag-new')).called(1);
      });

      test('uses existing tag ID directly without calling getOrCreateTag', () async {
        final bundle = buildBundle(diveItems: [makeItem('Dive 1')]);
        notifier.setBundle(bundle);

        const tag = TagSelection(existingTagId: 'tag-existing', name: 'Existing');
        notifier.addImportTag(tag);

        const importResult = UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 1},
          consolidatedCount: 0,
          skippedCount: 0,
          importedDiveIds: ['dive-1'],
        );

        when(
          mockAdapter.performImport(
            any,
            any,
            any,
            retainSourceDiveNumbers: anyNamed('retainSourceDiveNumbers'),
            onProgress: anyNamed('onProgress'),
          ),
        ).thenAnswer((_) async => importResult);

        when(mockTagRepo.addTagToDive(any, any)).thenAnswer((_) async {});

        await notifier.performImport();

        verifyNever(mockTagRepo.getOrCreateTag(any));
        verify(mockTagRepo.addTagToDive('dive-1', 'tag-existing')).called(1);
      });

      test('skips tag application when importTags is empty', () async {
        final bundle = buildBundle(diveItems: [makeItem('Dive 1')]);
        notifier.setBundle(bundle);
        // No tags added

        const importResult = UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 1},
          consolidatedCount: 0,
          skippedCount: 0,
          importedDiveIds: ['dive-1'],
        );

        when(
          mockAdapter.performImport(
            any,
            any,
            any,
            retainSourceDiveNumbers: anyNamed('retainSourceDiveNumbers'),
            onProgress: anyNamed('onProgress'),
          ),
        ).thenAnswer((_) async => importResult);

        await notifier.performImport();

        verifyNever(mockTagRepo.getOrCreateTag(any));
        verifyNever(mockTagRepo.addTagToDive(any, any));
      });
```

Also add the required imports and mock setup. At the top of the test file, update the `@GenerateNiceMocks` annotation:

```dart
@GenerateNiceMocks([
  MockSpec<ImportSourceAdapter>(),
  MockSpec<TagRepository>(),
])
```

Add imports:

```dart
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
```

Update `setUp` to create the mock tag repo:

```dart
    late MockTagRepository mockTagRepo;

    setUp(() {
      mockAdapter = MockImportSourceAdapter();
      mockTagRepo = MockTagRepository();
      when(mockAdapter.sourceType).thenReturn(ImportSourceType.uddf);
      when(mockAdapter.displayName).thenReturn('test.uddf');
      when(mockAdapter.acquisitionSteps).thenReturn([]);
      when(
        mockAdapter.supportedDuplicateActions,
      ).thenReturn({DuplicateAction.skip, DuplicateAction.importAsNew});
      notifier = ImportWizardNotifier(mockAdapter, tagRepository: mockTagRepo);
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart`
Expected: FAIL — `ImportWizardNotifier` constructor does not accept `tagRepository`.

- [ ] **Step 3: Update ImportWizardNotifier to accept TagRepository**

In `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart`:

Add import:

```dart
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
```

Update the constructor:

```dart
class ImportWizardNotifier extends StateNotifier<ImportWizardState> {
  ImportWizardNotifier(this._adapter, {TagRepository? tagRepository})
      : _tagRepository = tagRepository,
        super(const ImportWizardState());

  final ImportSourceAdapter _adapter;
  final TagRepository? _tagRepository;
```

- [ ] **Step 4: Add post-import tag application to performImport**

In the `performImport` method, after the `_adapter.performImport` call succeeds and before setting the final state, add tag application. Replace the success block:

```dart
      final result = await _adapter.performImport(
        bundle,
        state.selections,
        state.duplicateActions,
        retainSourceDiveNumbers: state.retainSourceDiveNumbers,
        onProgress: (phase, current, total) {
          state = state.copyWith(
            importPhase: phase,
            importCurrent: current,
            importTotal: total,
          );
        },
      );

      // Apply import tags to all imported dives.
      if (state.importTags.isNotEmpty &&
          result.importedDiveIds.isNotEmpty &&
          _tagRepository != null) {
        state = state.copyWith(
          importPhase: 'Applying tags',
          importCurrent: 0,
          importTotal: result.importedDiveIds.length,
        );

        // Resolve tag selections to tag IDs.
        final tagIds = <String>[];
        for (final tagSelection in state.importTags) {
          if (tagSelection.isNew) {
            final tag = await _tagRepository!.getOrCreateTag(tagSelection.name);
            tagIds.add(tag.id);
          } else {
            tagIds.add(tagSelection.existingTagId!);
          }
        }

        // Apply each tag to each imported dive.
        for (var i = 0; i < result.importedDiveIds.length; i++) {
          final diveId = result.importedDiveIds[i];
          for (final tagId in tagIds) {
            await _tagRepository!.addTagToDive(diveId, tagId);
          }
          state = state.copyWith(
            importCurrent: i + 1,
          );
        }
      }

      state = state.copyWith(
        isImporting: false,
        importResult: result,
        currentStep: state.currentStep + 1,
      );
```

- [ ] **Step 5: Update the provider to pass TagRepository**

In the same file, update the `importWizardNotifierProvider` — it's a placeholder that throws, so no change needed there. But update the ProviderScope override in `unified_import_wizard.dart`.

In `lib/features/import_wizard/presentation/pages/unified_import_wizard.dart`, update the provider override to pass the tag repository. Find the ProviderScope (around line 38-45) and update:

Add import:

```dart
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
```

The override needs access to the WidgetRef. Check how the wizard page is structured — it likely uses `ConsumerStatefulWidget`. The tag repository can be read from the ref:

```dart
      importWizardNotifierProvider.overrideWith(
        (ref) => ImportWizardNotifier(
          adapter,
          tagRepository: ref.read(tagRepositoryProvider),
        ),
      ),
```

- [ ] **Step 6: Regenerate mocks and run tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Then: `flutter test test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart`
Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/import_wizard/presentation/providers/import_wizard_providers.dart lib/features/import_wizard/presentation/pages/unified_import_wizard.dart test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart test/features/import_wizard/presentation/providers/import_wizard_notifier_test.mocks.dart
git commit -m "feat: apply import tags to dives after import completes"
```

---

### Task 5: ImportTagsField Widget

**Files:**
- Create: `lib/features/import_wizard/presentation/widgets/import_tags_field.dart`
- Create: `test/features/import_wizard/presentation/widgets/import_tags_field_test.dart`

- [ ] **Step 1: Write failing widget tests**

Create `test/features/import_wizard/presentation/widgets/import_tags_field_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/domain/models/tag_selection.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/import_tags_field.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

void main() {
  group('ImportTagsField', () {
    testWidgets('renders existing tag chips', (tester) async {
      const tags = [
        TagSelection(name: 'Perdix Import 2026-03-26'),
        TagSelection(existingTagId: 'id-1', name: 'Vacation'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImportTagsField(
              tags: tags,
              existingTags: const [],
              onAdd: (_) {},
              onRemove: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Perdix Import 2026-03-26'), findsOneWidget);
      expect(find.text('Vacation'), findsOneWidget);
    });

    testWidgets('calls onRemove when chip delete is tapped', (tester) async {
      int? removedIndex;
      const tags = [TagSelection(name: 'Test Tag')];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImportTagsField(
              tags: tags,
              existingTags: const [],
              onAdd: (_) {},
              onRemove: (i) => removedIndex = i,
            ),
          ),
        ),
      );

      // InputChip delete button is the cancel icon
      await tester.tap(find.byIcon(Icons.cancel));
      await tester.pump();

      expect(removedIndex, equals(0));
    });

    testWidgets('calls onAdd when new tag is submitted', (tester) async {
      TagSelection? addedTag;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImportTagsField(
              tags: const [],
              existingTags: const [],
              onAdd: (t) => addedTag = t,
              onRemove: (_) {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'New Tag');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(addedTag, isNotNull);
      expect(addedTag!.name, equals('New Tag'));
      expect(addedTag!.isNew, isTrue);
    });

    testWidgets('matches existing tag by name on submit', (tester) async {
      TagSelection? addedTag;
      final existingTags = [
        Tag(
          id: 'tag-1',
          name: 'Vacation',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImportTagsField(
              tags: const [],
              existingTags: existingTags,
              onAdd: (t) => addedTag = t,
              onRemove: (_) {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Vacation');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(addedTag, isNotNull);
      expect(addedTag!.existingTagId, equals('tag-1'));
      expect(addedTag!.name, equals('Vacation'));
    });

    testWidgets('shows label row with tag icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImportTagsField(
              tags: const [],
              existingTags: const [],
              onAdd: (_) {},
              onRemove: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.label_outline), findsOneWidget);
      expect(find.text('Import Tags'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/import_wizard/presentation/widgets/import_tags_field_test.dart`
Expected: FAIL — `import_tags_field.dart` does not exist.

- [ ] **Step 3: Implement ImportTagsField widget**

Create `lib/features/import_wizard/presentation/widgets/import_tags_field.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/import_wizard/domain/models/tag_selection.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// Multi-tag chip field with autocomplete for the import review step.
///
/// Displays current tags as removable [InputChip]s and provides an
/// autocomplete text field for adding existing or new tags.
class ImportTagsField extends StatefulWidget {
  const ImportTagsField({
    super.key,
    required this.tags,
    required this.existingTags,
    required this.onAdd,
    required this.onRemove,
  });

  /// Currently selected tags.
  final List<TagSelection> tags;

  /// All existing tags from the database for autocomplete suggestions.
  final List<Tag> existingTags;

  /// Called when the user adds a tag (existing or new).
  final ValueChanged<TagSelection> onAdd;

  /// Called when the user removes a tag by index.
  final ValueChanged<int> onRemove;

  @override
  State<ImportTagsField> createState() => _ImportTagsFieldState();
}

class _ImportTagsFieldState extends State<ImportTagsField> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitTag(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Check if it matches an existing tag by name (case-insensitive).
    final match = widget.existingTags.cast<Tag?>().firstWhere(
          (t) => t!.name.toLowerCase() == trimmed.toLowerCase(),
          orElse: () => null,
        );

    if (match != null) {
      widget.onAdd(TagSelection(existingTagId: match.id, name: match.name));
    } else {
      widget.onAdd(TagSelection(name: trimmed));
    }

    _textController.clear();
  }

  /// Filter existing tags that match the query and aren't already selected.
  List<Tag> _filteredSuggestions(String query) {
    if (query.isEmpty) return [];

    final selectedNames =
        widget.tags.map((t) => t.name.toLowerCase()).toSet();

    return widget.existingTags.where((tag) {
      final matchesQuery =
          tag.name.toLowerCase().contains(query.toLowerCase());
      final notAlreadySelected = !selectedNames.contains(tag.name.toLowerCase());
      return matchesQuery && notAlreadySelected;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.label_outline, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Import Tags',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RawAutocomplete<Tag>(
            textEditingController: _textController,
            focusNode: _focusNode,
            optionsBuilder: (textEditingValue) {
              return _filteredSuggestions(textEditingValue.text);
            },
            onSelected: (tag) {
              widget.onAdd(
                TagSelection(existingTagId: tag.id, name: tag.name),
              );
              _textController.clear();
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              return Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < widget.tags.length; i++)
                    InputChip(
                      label: Text(widget.tags[i].name),
                      onDeleted: () => widget.onRemove(i),
                    ),
                  IntrinsicWidth(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: widget.tags.isEmpty
                            ? 'Add tag...'
                            : 'Add another...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                        ),
                      ),
                      onSubmitted: (text) {
                        _submitTag(text);
                        onSubmitted();
                      },
                    ),
                  ),
                ],
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final tag = options.elementAt(index);
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.label,
                            color: tag.color,
                            size: 20,
                          ),
                          title: Text(tag.name),
                          onTap: () => onSelected(tag),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/import_wizard/presentation/widgets/import_tags_field_test.dart`
Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/import_wizard/presentation/widgets/import_tags_field.dart test/features/import_wizard/presentation/widgets/import_tags_field_test.dart
git commit -m "feat: add ImportTagsField widget with autocomplete"
```

---

### Task 6: Integrate ImportTagsField into ReviewStep

**Files:**
- Modify: `lib/features/import_wizard/presentation/widgets/review_step.dart`
- Modify: `lib/features/import_wizard/presentation/pages/unified_import_wizard.dart`

- [ ] **Step 1: Add ImportTagsField to ReviewStep**

In `lib/features/import_wizard/presentation/widgets/review_step.dart`, add imports:

```dart
import 'package:submersion/features/import_wizard/presentation/widgets/import_tags_field.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
```

In the `ReviewStep.build` method, fetch existing tags from the provider. Add after the `projectedDiveNumbers` computation (around line 52):

```dart
    final existingTags = ref.watch(allTagsProvider).valueOrNull ?? const <Tag>[];
```

Check if `allTagsProvider` exists. If not, it will need to be created — a `FutureProvider` that calls `tagRepository.getAllTags()`. Add the `existingTags` parameter to both `_SingleTypeLayout` and `_MultiTypeLayout`.

Pass it through:

```dart
    if (types.length == 1) {
      return _SingleTypeLayout(
        // ... existing params ...
        existingTags: existingTags,
      );
    }

    return _MultiTypeLayout(
      // ... existing params ...
      existingTags: existingTags,
    );
```

- [ ] **Step 2: Add ImportTagsField to _SingleTypeLayout**

In `_SingleTypeLayout`, add the field and insert the widget. Add to the class fields:

```dart
  final List<Tag> existingTags;
```

Add to constructor (in the required parameters). In the `build` method, insert `ImportTagsField` after the `_RetainDiveNumbersToggle` and before the `Expanded` containing the entity list:

```dart
    return Column(
      children: [
        if (hasDives)
          _RetainDiveNumbersToggle(state: state, notifier: notifier),
        ImportTagsField(
          tags: state.importTags,
          existingTags: existingTags,
          onAdd: (tag) => notifier.addImportTag(tag),
          onRemove: (index) => notifier.removeImportTag(index),
        ),
        Expanded(
          child: SingleChildScrollView(
            // ... existing content ...
          ),
        ),
        _BottomBar(counts: counts, onImport: onImport, onBack: onBack),
      ],
    );
```

- [ ] **Step 3: Add ImportTagsField to _MultiTypeLayout**

Same pattern. Add `existingTags` field and constructor parameter. Insert the widget between the `TabBar` and `Expanded(child: TabBarView(...))`:

```dart
        TabBar(
          tabs: [
            for (final type in types)
              Tab(text: _tabLabel(type, bundle.groups[type]!.items.length)),
          ],
        ),
        ImportTagsField(
          tags: state.importTags,
          existingTags: existingTags,
          onAdd: (tag) => notifier.addImportTag(tag),
          onRemove: (index) => notifier.removeImportTag(index),
        ),
        Expanded(
          child: TabBarView(
            // ... existing content ...
          ),
        ),
```

- [ ] **Step 4: Create allTagsProvider**

`allTagsProvider` does not exist yet. Add it to `lib/features/tags/presentation/providers/tag_providers.dart`:

```dart
/// All tags for the active diver, used for autocomplete suggestions.
final allTagsProvider = FutureProvider<List<Tag>>((ref) {
  final repo = ref.watch(tagRepositoryProvider);
  return repo.getAllTags();
});
```

Add the required import for the `Tag` entity if not already present.

- [ ] **Step 5: Call initializeDefaultTag when bundle is ready**

In `lib/features/import_wizard/presentation/pages/unified_import_wizard.dart` at line 136, `setBundle` is called when transitioning to the review step:

```dart
        ref
            .read(importWizardNotifierProvider.notifier)
            .setBundle(checkedBundle);
```

Add `initializeDefaultTag()` immediately after:

```dart
        ref
            .read(importWizardNotifierProvider.notifier)
            .setBundle(checkedBundle);
        ref
            .read(importWizardNotifierProvider.notifier)
            .initializeDefaultTag();
```

- [ ] **Step 6: Run all import wizard tests**

Run: `flutter test test/features/import_wizard/`
Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/import_wizard/presentation/widgets/review_step.dart lib/features/import_wizard/presentation/pages/unified_import_wizard.dart lib/features/tags/presentation/providers/tag_providers.dart
git commit -m "feat: integrate ImportTagsField into shared review step"
```

---

### Task 7: Remove Old Batch Tag Code

**Files:**
- Delete: `lib/features/universal_import/presentation/widgets/batch_tag_field.dart`
- Modify: `lib/features/universal_import/data/models/import_options.dart`
- Modify: `lib/features/universal_import/presentation/widgets/import_review_step.dart`
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart`
- Modify: `lib/features/universal_import/presentation/providers/universal_import_providers.dart`
- Modify: `test/features/import_wizard/data/adapters/universal_adapter_test.dart`

- [ ] **Step 1: Delete BatchTagField widget file**

```bash
git rm lib/features/universal_import/presentation/widgets/batch_tag_field.dart
```

- [ ] **Step 2: Remove batchTag from ImportOptions**

In `lib/features/universal_import/data/models/import_options.dart`:

Remove the `batchTag` field (line 9), its constructor parameter (line 18), and its presence in `props` (line 34). Also remove the `defaultTag` static method (lines 24-31).

The file should become:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';

/// Configuration options for an import operation.
class ImportOptions extends Equatable {
  /// The detected/confirmed source app.
  final SourceApp sourceApp;

  /// The detected/confirmed format.
  final ImportFormat format;

  const ImportOptions({
    required this.sourceApp,
    required this.format,
  });

  @override
  List<Object?> get props => [sourceApp, format];
}
```

- [ ] **Step 3: Remove BatchTagField usage from import_review_step.dart**

In `lib/features/universal_import/presentation/widgets/import_review_step.dart`:

- Remove the import of `batch_tag_field.dart` (line 8)
- Remove the `Padding` wrapping `BatchTagField` (lines 77-86)

- [ ] **Step 4: Remove _injectBatchTag from universal_adapter.dart**

In `lib/features/import_wizard/data/adapters/universal_adapter.dart`:

- Remove the batch tag injection block (lines ~385-391):
  ```dart
  // Inject batch tag if present so it flows through the import pipeline.
  final batchTag = notifierState.options?.batchTag;
  if (batchTag != null && batchTag.isNotEmpty) {
    final injected = _injectBatchTag(uddfData, uddfSelections, batchTag);
    uddfData = injected.$1;
    uddfSelections = injected.$2;
  }
  ```
- Remove the entire `_injectBatchTag` static method (lines ~737-791)

- [ ] **Step 5: Remove batch tag code from universal_import_providers.dart**

In `lib/features/universal_import/presentation/providers/universal_import_providers.dart`:

- Remove the `updateBatchTag` method (lines ~502-511)
- Remove the batch tag injection block (lines ~553-561)
- Remove the `_injectBatchTag` method (lines ~656+)
- Update the `ImportOptions` construction (line ~306-310) to remove `batchTag`:
  ```dart
  final options = ImportOptions(
    sourceApp: sourceApp,
    format: format,
  );
  ```

- [ ] **Step 6: Remove batch tag tests from universal_adapter_test.dart**

In `test/features/import_wizard/data/adapters/universal_adapter_test.dart`:

- Remove the batch tag test group at lines ~1807-2077 (the `_injectBatchTag` tests and the `performImport -- _injectBatchTag` tests)
- Update any test that constructs `ImportOptions` with `batchTag` to remove that parameter

- [ ] **Step 7: Remove unused localization keys from ARB files**

Remove the following keys from `lib/l10n/arb/app_en.arb` and all other language ARB files (`app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_it.arb`, `app_pt.arb`, `app_hu.arb`, `app_nl.arb`, `app_ar.arb`, `app_he.arb`):

- `universalImport_label_importTag`
- `universalImport_hint_tagDescription`
- `universalImport_hint_tagExample`
- `universalImport_tooltip_clearTag`

Then regenerate localizations:

Run: `flutter gen-l10n` (or `dart run build_runner build --delete-conflicting-outputs`)

- [ ] **Step 8: Run full test suite**

Run: `flutter test`
Expected: All tests PASS. Fix any compilation errors from leftover `batchTag` references.

- [ ] **Step 9: Run dart format**

Run: `dart format lib/ test/`

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "refactor: remove old batch tag injection code

Replaced by wizard-level import tag selector in the shared review step."
```

---

### Task 8: Final Verification

- [ ] **Step 1: Run full test suite**

Run: `flutter test`
Expected: All tests PASS.

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 3: Run formatter**

Run: `dart format --set-exit-if-changed lib/ test/`
Expected: No formatting changes needed.

- [ ] **Step 4: Verify no leftover batch tag references**

Run: `grep -r "batchTag\|BatchTagField\|_injectBatchTag\|updateBatchTag" lib/ test/ --include="*.dart"`
Expected: No matches (zero results).
