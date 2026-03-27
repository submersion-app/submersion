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

      // Chip delete button is the close icon
      await tester.tap(find.byIcon(Icons.close));
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
      expect(find.text('Tags'), findsOneWidget);
    });

    testWidgets('ignores empty text submission', (tester) async {
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

      // Submit with empty text
      await tester.enterText(find.byType(TextField), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(addedTag, isNull);
    });

    testWidgets('shows hint "Add tag..." when no tags are present', (
      tester,
    ) async {
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

      expect(find.text('Add tag...'), findsOneWidget);
    });

    testWidgets('shows hint "Add another..." when tags are present', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImportTagsField(
              tags: const [TagSelection(name: 'Existing')],
              existingTags: const [],
              onAdd: (_) {},
              onRemove: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Add another...'), findsOneWidget);
    });

    testWidgets('chip uses existing tag color when tag matches by ID', (
      tester,
    ) async {
      final existingTags = [
        Tag(
          id: 'tag-1',
          name: 'Vacation',
          colorHex: '#FF0000',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImportTagsField(
              tags: const [
                TagSelection(existingTagId: 'tag-1', name: 'Vacation'),
              ],
              existingTags: existingTags,
              onAdd: (_) {},
              onRemove: (_) {},
            ),
          ),
        ),
      );

      // Chip should render with the tag's color
      final chip = tester.widget<Chip>(find.byType(Chip));
      expect(chip.side?.color, equals(const Color(0xFFFF0000)));
    });

    testWidgets('chip falls back to blue for new tags', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImportTagsField(
              tags: const [TagSelection(name: 'Brand New Tag')],
              existingTags: const [],
              onAdd: (_) {},
              onRemove: (_) {},
            ),
          ),
        ),
      );

      final chip = tester.widget<Chip>(find.byType(Chip));
      expect(chip.side?.color, equals(Colors.blue));
    });

    testWidgets('shows autocomplete suggestions matching query', (
      tester,
    ) async {
      final existingTags = [
        Tag(
          id: 'tag-1',
          name: 'Vacation',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        Tag(
          id: 'tag-2',
          name: 'Training',
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
              onAdd: (_) {},
              onRemove: (_) {},
            ),
          ),
        ),
      );

      // Type to trigger autocomplete
      await tester.enterText(find.byType(TextField), 'Vac');
      await tester.pump();

      // Should show 'Vacation' in the dropdown
      expect(find.text('Vacation'), findsOneWidget);
      // Should not show 'Training' as it doesn't match
      expect(find.text('Training'), findsNothing);
    });

    testWidgets('excludes already-selected tags from suggestions', (
      tester,
    ) async {
      final existingTags = [
        Tag(
          id: 'tag-1',
          name: 'Vacation',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        Tag(
          id: 'tag-2',
          name: 'Various Dives',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImportTagsField(
              tags: const [
                TagSelection(existingTagId: 'tag-1', name: 'Vacation'),
              ],
              existingTags: existingTags,
              onAdd: (_) {},
              onRemove: (_) {},
            ),
          ),
        ),
      );

      // Type 'Va' which could match both tags
      await tester.enterText(find.byType(TextField), 'Va');
      await tester.pump();

      // 'Vacation' should not appear (already selected)
      // 'Various Dives' should appear (not selected, matches query)
      expect(find.text('Various Dives'), findsOneWidget);
    });

    testWidgets('tapping autocomplete suggestion calls onAdd', (tester) async {
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

      // Type to show autocomplete
      await tester.enterText(find.byType(TextField), 'Vac');
      await tester.pump();

      // Tap the suggestion
      await tester.tap(find.text('Vacation'));
      await tester.pump();

      expect(addedTag, isNotNull);
      expect(addedTag!.existingTagId, equals('tag-1'));
      expect(addedTag!.name, equals('Vacation'));
    });
  });
}
