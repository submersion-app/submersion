import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_editable_item.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_template_draft.dart';

EditableChecklistItem _item(
  String id, {
  String title = 'Fins',
  String? sectionId,
  DateTime? updatedAt,
}) => EditableChecklistItem(
  id: id,
  title: title,
  sectionId: sectionId,
  sortOrder: 0,
  createdAt: DateTime(2026),
  updatedAt: updatedAt ?? DateTime(2026),
);

ChecklistTemplateDraft _draft({
  String name = 'Packing',
  List<EditableChecklistSection> sections = const [],
  List<EditableChecklistItem> items = const [],
}) => checklistTemplateDraft(
  name: name,
  description: '',
  sections: sections,
  itemsInDisplayOrder: items,
);

void main() {
  test('items differing only in their stamps are equal', () {
    expect(
      _draft(items: [_item('a', updatedAt: DateTime(2026, 1, 1, 0, 0, 1))]),
      _draft(items: [_item('a')]),
    );
  });

  test('items in another order are not equal', () {
    expect(
      _draft(items: [_item('a'), _item('b')]),
      isNot(_draft(items: [_item('b'), _item('a')])),
    );
  });

  test('a renamed section is a change', () {
    expect(
      _draft(
        sections: [const EditableChecklistSection(id: 's', title: 'A')],
      ),
      isNot(
        _draft(
          sections: [const EditableChecklistSection(id: 's', title: 'B')],
        ),
      ),
    );
  });

  test('a name with a trailing space is a change', () {
    expect(_draft(name: 'Packing '), isNot(_draft()));
  });

  test('an item drafts as its dialog writes it: title and notes trimmed', () {
    final spaced = EditableChecklistItem(
      id: 'a',
      title: 'Fins ',
      notes: ' straps',
      sortOrder: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final trimmed = EditableChecklistItem(
      id: 'a',
      title: 'Fins',
      notes: 'straps',
      sortOrder: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    expect(_draft(items: [spaced]), _draft(items: [trimmed]));
  });

  test('an item naming a section the form lacks drafts as unsectioned', () {
    expect(
      _draft(items: [_item('a', sectionId: 'gone')]),
      _draft(items: [_item('a')]),
    );
  });

  test('equal drafts share a hash code', () {
    expect(
      _draft(items: [_item('a', sectionId: 's')]).hashCode,
      _draft(items: [_item('a', sectionId: 's')]).hashCode,
    );
  });
}
