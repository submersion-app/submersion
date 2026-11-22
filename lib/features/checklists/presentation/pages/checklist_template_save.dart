import 'package:flutter/foundation.dart';

import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template_section.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_editable_item.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_template_draft.dart';
import 'package:submersion/shared/widgets/record_editing/editor_row_merge.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

/// Writes a checklist template editor's Save, inside its sitting (issue
/// #4527, phase 4).
///
/// A new template ([start] null) is created under [templateId] and
/// [diverId] with every section and item. A stored one is read as stored
/// now; the name and description are written only when their text changed
/// from [start]'s, the sections only when they differ from [start]'s, the
/// items only when they differ from [start]'s, each list merged onto
/// storage with [mergeEditorRows], so what the diver left alone keeps what
/// storage holds, a sync meanwhile included. An item naming a section that
/// is not written is written with no section, as the editor shows it.
/// Item sort order is its position.
///
/// Throws [RecordSittingRefusal] when the stored template is gone, and
/// [StateError] for a new template with no [diverId].
Future<void> writeChecklistTemplate({
  required ChecklistTemplateRepository repository,
  required String templateId,
  required String? diverId,
  required ChecklistTemplateDraft draft,
  required ChecklistTemplateDraft? start,
  required List<EditableChecklistSection> sections,
  required List<EditableChecklistItem> itemsInDisplayOrder,
}) async {
  final now = DateTime.now();
  final formSections = [
    for (final section in sections)
      ChecklistTemplateSection(
        id: section.id,
        templateId: templateId,
        title: section.title,
        createdAt: now,
        updatedAt: now,
      ),
  ];
  final formItems = [
    for (var i = 0; i < itemsInDisplayOrder.length; i++)
      ChecklistTemplateItem(
        id: itemsInDisplayOrder[i].id,
        templateId: templateId,
        title: itemsInDisplayOrder[i].title,
        sectionId: itemsInDisplayOrder[i].sectionId,
        notes: itemsInDisplayOrder[i].notes,
        dueOffsetDays: itemsInDisplayOrder[i].dueOffsetDays,
        sortOrder: i,
        createdAt: itemsInDisplayOrder[i].createdAt,
        updatedAt: itemsInDisplayOrder[i].updatedAt,
      ),
  ];

  if (start == null) {
    // A null diver_id would show the template to every diver: a new one is
    // the active diver's, as every phase 4 editor's new record is.
    if (diverId == null) {
      throw StateError('A new checklist template needs an active diver');
    }
    await repository.createTemplate(
      ChecklistTemplate(
        id: templateId,
        diverId: diverId,
        name: draft.name.trim(),
        description: draft.description.trim(),
        createdAt: now,
        updatedAt: now,
      ),
    );
    // Sections first: the items' section_id is a foreign key.
    await repository.saveSections(templateId, formSections);
    await repository.saveItems(
      templateId,
      _withinSections(formItems, formSections),
    );
    return;
  }

  // The template as stored now, not as the page loaded it.
  final stored = await repository.getTemplateById(templateId);
  if (stored == null) {
    throw RecordSittingRefusal(
      (l10n) => l10n.checklists_template_edit_notFound,
    );
  }
  final nameChanged = draft.name != start.name;
  final descriptionChanged = draft.description != start.description;
  if (nameChanged || descriptionChanged) {
    await repository.updateTemplate(
      stored.copyWith(
        name: nameChanged ? draft.name.trim() : stored.name,
        description: descriptionChanged
            ? draft.description.trim()
            : stored.description,
      ),
    );
  }

  final sectionsChanged = !listEquals(draft.sections, start.sections);
  final itemsChanged = !listEquals(draft.items, start.items);
  if (!sectionsChanged && !itemsChanged) return;

  var writtenSections = await repository.getSectionsForTemplate(templateId);
  if (sectionsChanged) {
    writtenSections = mergeEditorRows(
      formRows: formSections,
      formDrafts: draft.sections,
      startDrafts: start.sections,
      storedRows: writtenSections,
      rowId: (section) => section.id,
      draftId: (section) => section.id,
    );
    await repository.saveSections(templateId, writtenSections);
  }
  if (!itemsChanged) return;

  final merged = mergeEditorRows(
    formRows: formItems,
    formDrafts: draft.items,
    startDrafts: start.items,
    storedRows: await repository.getItemsForTemplate(templateId),
    rowId: (item) => item.id,
    draftId: (item) => item.id,
  );
  await repository.saveItems(
    templateId,
    _withinSections(merged, writtenSections),
  );
}

/// [items] as Save writes them: numbered by position, the order shown, and
/// with any section that is not among [sections] cleared, since a section
/// removed elsewhere meanwhile would fail the items' foreign key.
List<ChecklistTemplateItem> _withinSections(
  List<ChecklistTemplateItem> items,
  List<ChecklistTemplateSection> sections,
) {
  final sectionIds = {for (final section in sections) section.id};
  return [
    for (final (i, item) in items.indexed)
      if (item.sectionId == null || sectionIds.contains(item.sectionId))
        item.copyWith(sortOrder: i)
      else
        item.copyWith(sectionId: null, sortOrder: i),
  ];
}
