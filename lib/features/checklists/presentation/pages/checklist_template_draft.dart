import 'package:flutter/foundation.dart';

import 'package:submersion/features/checklists/presentation/pages/checklist_editable_item.dart';

/// A section as the checklist template editor shows it.
typedef ChecklistSectionDraft = ({String id, String title});

/// An item as the checklist template editor shows it: no stamps (the item
/// dialog stamps `updatedAt` on every OK) and no sort order (Save assigns
/// it from the order shown).
typedef ChecklistItemDraft = ({
  String id,
  String title,
  String? sectionId,
  String notes,
  int? dueOffsetDays,
});

/// The checklist template editor's form as shown (issue #4527, phase 4):
/// header texts as typed, sections in order, items in the order shown
/// (section by section, then the unsectioned ones). Two drafts are equal
/// when the diver would see the same form.
@immutable
class ChecklistTemplateDraft {
  const ChecklistTemplateDraft({
    required this.name,
    required this.description,
    required this.sections,
    required this.items,
  });

  /// As typed, untrimmed.
  final String name;
  final String description;
  final List<ChecklistSectionDraft> sections;
  final List<ChecklistItemDraft> items;

  @override
  bool operator ==(Object other) =>
      other is ChecklistTemplateDraft &&
      other.name == name &&
      other.description == description &&
      listEquals(other.sections, sections) &&
      listEquals(other.items, items);

  @override
  int get hashCode => Object.hash(
    name,
    description,
    Object.hashAll(sections),
    Object.hashAll(items),
  );
}

/// The draft of an item as its dialog would write it, confirmed unchanged:
/// title and notes trimmed, and no section when it names none of
/// [sectionIds] (the editor shows it unsectioned). A stored item in another
/// form (synced, or older data) so reads the same once confirmed.
ChecklistItemDraft checklistItemDraft(
  EditableChecklistItem item, {
  required Set<String> sectionIds,
}) => (
  id: item.id,
  title: item.title.trim(),
  sectionId: sectionIds.contains(item.sectionId) ? item.sectionId : null,
  notes: item.notes.trim(),
  dueOffsetDays: item.dueOffsetDays,
);

/// The draft of a section as the editor shows it.
ChecklistSectionDraft checklistSectionDraft(EditableChecklistSection section) =>
    (id: section.id, title: section.title);

/// The checklist template editor's form as it reads now.
ChecklistTemplateDraft checklistTemplateDraft({
  required String name,
  required String description,
  required List<EditableChecklistSection> sections,
  required List<EditableChecklistItem> itemsInDisplayOrder,
}) {
  final sectionIds = {for (final section in sections) section.id};
  return ChecklistTemplateDraft(
    name: name,
    description: description,
    sections: [for (final section in sections) checklistSectionDraft(section)],
    items: [
      for (final item in itemsInDisplayOrder)
        checklistItemDraft(item, sectionIds: sectionIds),
    ],
  );
}
