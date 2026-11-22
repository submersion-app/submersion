/// An item mid-edit on the checklist template editor page. The page holds a
/// list of these instead of [ChecklistTemplateItem] directly, since items
/// there are edited in memory and only persisted as a whole on Save.
/// Creating or renaming a section one at a time as a dialog closes would
/// touch the database for a section the diver then discards by not saving
/// the page.
class EditableChecklistItem {
  final String id;
  final String title;
  final String? sectionId;
  final String notes;
  final int? dueOffsetDays;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EditableChecklistItem({
    required this.id,
    required this.title,
    this.sectionId,
    this.notes = '',
    this.dueOffsetDays,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  EditableChecklistItem copyWith({Object? sectionId = _undefined}) =>
      EditableChecklistItem(
        id: id,
        title: title,
        sectionId: sectionId == _undefined
            ? this.sectionId
            : sectionId as String?,
        notes: notes,
        dueOffsetDays: dueOffsetDays,
        sortOrder: sortOrder,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

const _undefined = Object();

/// A section mid-edit on the checklist template editor page. See
/// [EditableChecklistItem] for why sections are held in memory there
/// instead of going through the repository's section calls directly.
class EditableChecklistSection {
  final String id;
  final String title;

  const EditableChecklistSection({required this.id, required this.title});

  EditableChecklistSection copyWith({String? title}) =>
      EditableChecklistSection(id: id, title: title ?? this.title);
}
