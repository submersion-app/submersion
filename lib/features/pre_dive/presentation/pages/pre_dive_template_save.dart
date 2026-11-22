import 'package:flutter/foundation.dart';

import 'package:submersion/features/pre_dive/data/repositories/pre_dive_template_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template_section.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_editable_item.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_template_draft.dart';
import 'package:submersion/shared/widgets/record_editing/editor_row_merge.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

/// Writes a pre-dive template editor's Save, inside its sitting (issue
/// #4527, phase 4).
///
/// A new template ([start] null) is created under [templateId] and
/// [diverId] with every section and item. A stored one is read as stored
/// now; each header field (name, description, category, strict order) is
/// written only when it changed from [start]'s, the sections only when they
/// differ from [start]'s, the items only when they differ from [start]'s,
/// each list merged onto storage with [mergeEditorRows], so what the diver
/// left alone keeps what storage holds, a sync meanwhile included. An item
/// naming a section that is not written is written with no section, as the
/// editor shows it. Item sort order is its position. A blank category is
/// none.
///
/// Throws [RecordSittingRefusal] when the stored template is gone, and
/// [StateError] for a new template with no [diverId].
Future<void> writePreDiveTemplate({
  required PreDiveTemplateRepository repository,
  required String templateId,
  required String? diverId,
  required PreDiveTemplateDraft draft,
  required PreDiveTemplateDraft? start,
  required List<EditablePreDiveSection> sections,
  required List<EditablePreDiveItem> itemsInDisplayOrder,
}) async {
  final now = DateTime.now();
  final category = draft.category.trim();
  final formSections = [
    for (final section in sections)
      PreDiveChecklistTemplateSection(
        id: section.id,
        templateId: templateId,
        title: section.title,
        createdAt: now,
        updatedAt: now,
      ),
  ];
  final formItems = [
    for (var i = 0; i < itemsInDisplayOrder.length; i++)
      _templateItem(itemsInDisplayOrder[i], templateId: templateId, order: i),
  ];

  if (start == null) {
    // A null diver_id hides the template from a diver's list: a new one is
    // the active diver's, as every phase 4 editor's new record is.
    if (diverId == null) {
      throw StateError('A new pre-dive template needs an active diver');
    }
    await repository.createTemplate(
      PreDiveChecklistTemplate(
        id: templateId,
        diverId: diverId,
        name: draft.name.trim(),
        description: draft.description.trim(),
        category: category.isEmpty ? null : category,
        strictOrder: draft.strictOrder,
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
    throw RecordSittingRefusal((l10n) => l10n.preDive_edit_notFound);
  }
  final nameChanged = draft.name != start.name;
  final descriptionChanged = draft.description != start.description;
  final categoryChanged = draft.category != start.category;
  final strictOrderChanged = draft.strictOrder != start.strictOrder;
  if (nameChanged ||
      descriptionChanged ||
      categoryChanged ||
      strictOrderChanged) {
    await repository.updateTemplate(
      stored.copyWith(
        name: nameChanged ? draft.name.trim() : stored.name,
        description: descriptionChanged
            ? draft.description.trim()
            : stored.description,
        category: categoryChanged
            ? (category.isEmpty ? null : category)
            : stored.category,
        strictOrder: strictOrderChanged
            ? draft.strictOrder
            : stored.strictOrder,
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

PreDiveChecklistTemplateItem _templateItem(
  EditablePreDiveItem item, {
  required String templateId,
  required int order,
}) => PreDiveChecklistTemplateItem(
  id: item.id,
  templateId: templateId,
  sectionId: item.sectionId,
  title: item.title,
  notes: item.notes,
  sortOrder: order,
  itemType: item.itemType,
  valueLabel: item.valueLabel,
  valueUnit: item.valueUnit,
  valueMin: item.valueMin,
  valueMax: item.valueMax,
  isRequired: item.isRequired,
  equipmentId: item.equipmentId,
  sourceItemId: item.sourceItemId,
  createdAt: item.createdAt,
  updatedAt: item.updatedAt,
);

/// [items] with any section that is not among [sections] cleared: a
/// section removed elsewhere meanwhile would fail the items' foreign key.
List<PreDiveChecklistTemplateItem> _withinSections(
  List<PreDiveChecklistTemplateItem> items,
  List<PreDiveChecklistTemplateSection> sections,
) {
  final sectionIds = {for (final section in sections) section.id};
  return [
    for (final item in items)
      if (item.sectionId == null || sectionIds.contains(item.sectionId))
        item
      else
        item.copyWith(sectionId: null),
  ];
}
