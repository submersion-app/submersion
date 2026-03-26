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
