import 'package:flutter/foundation.dart';

import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_editable_item.dart';

/// A section as the pre-dive template editor shows it.
typedef PreDiveSectionDraft = ({String id, String title});

/// A pre-dive item as the editor shows it: no stamps (the item dialog
/// stamps `updatedAt` on every OK), no sort order (Save assigns it from the
/// order shown), and the thresholds as the item dialog shows them, so one
/// read back from its text never reads as a change.
typedef PreDiveItemDraft = ({
  String id,
  String? sectionId,
  String title,
  String notes,
  PreDiveItemType itemType,
  String? valueLabel,
  String? valueUnit,
  String valueMin,
  String valueMax,
  bool isRequired,
  String? equipmentId,
  String? sourceItemId,
});

/// The pre-dive template editor's form as shown (issue #4527, phase 4):
/// header texts as typed, the strict order switch, sections in order, items
/// in the order shown. Two drafts are equal when the diver would see the
/// same form.
@immutable
class PreDiveTemplateDraft {
  const PreDiveTemplateDraft({
    required this.name,
    required this.description,
    required this.category,
    required this.strictOrder,
    required this.sections,
    required this.items,
  });

  /// As typed, untrimmed.
  final String name;
  final String description;
  final String category;
  final bool strictOrder;
  final List<PreDiveSectionDraft> sections;
  final List<PreDiveItemDraft> items;

  @override
  bool operator ==(Object other) =>
      other is PreDiveTemplateDraft &&
      other.name == name &&
      other.description == description &&
      other.category == category &&
      other.strictOrder == strictOrder &&
      listEquals(other.sections, sections) &&
      listEquals(other.items, items);

  @override
  int get hashCode => Object.hash(
    name,
    description,
    category,
    strictOrder,
    Object.hashAll(sections),
    Object.hashAll(items),
  );
}

/// A threshold as the item dialog shows it: blank for none.
String _thresholdText(double? value) =>
    value == null ? '' : formatDecimalForInput(value);

/// The draft of an item as the editor shows it.
PreDiveItemDraft preDiveItemDraft(EditablePreDiveItem item) => (
  id: item.id,
  sectionId: item.sectionId,
  title: item.title,
  notes: item.notes,
  itemType: item.itemType,
  valueLabel: item.valueLabel,
  valueUnit: item.valueUnit,
  valueMin: _thresholdText(item.valueMin),
  valueMax: _thresholdText(item.valueMax),
  isRequired: item.isRequired,
  equipmentId: item.equipmentId,
  sourceItemId: item.sourceItemId,
);

/// The pre-dive template editor's form as it reads now.
PreDiveTemplateDraft preDiveTemplateDraft({
  required String name,
  required String description,
  required String category,
  required bool strictOrder,
  required List<EditablePreDiveSection> sections,
  required List<EditablePreDiveItem> itemsInDisplayOrder,
}) => PreDiveTemplateDraft(
  name: name,
  description: description,
  category: category,
  strictOrder: strictOrder,
  sections: [
    for (final section in sections) (id: section.id, title: section.title),
  ],
  items: [for (final item in itemsInDisplayOrder) preDiveItemDraft(item)],
);
