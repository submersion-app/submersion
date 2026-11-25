import 'package:flutter/foundation.dart';

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

/// A threshold as the item dialog shows it, blank for none: rounded to the
/// 15 significant digits `formatDecimalForInput` shows, but with no locale
/// separator, so a change of number locale during the sitting is no change.
String _thresholdText(double? value) {
  if (value == null || !value.isFinite) return '';
  return double.parse(value.toStringAsPrecision(15)).toString();
}

/// The draft of an item as its dialog would write it, confirmed unchanged
/// (`PreDiveItemDialog._submit`): title and notes trimmed; no section when
/// it names none of [sectionIds]; label, unit and thresholds only on a
/// value or cell linearity item, blank label and unit as none; the
/// remembered device only on an equipment item; and a source only on a cell
/// linearity item, when it names another of [valueItemIds]. A stored item in
/// another form (synced, or older data) so reads the same once confirmed.
PreDiveItemDraft preDiveItemDraft(
  EditablePreDiveItem item, {
  required Set<String> sectionIds,
  required Set<String> valueItemIds,
}) {
  final type = item.itemType;
  final isValue =
      type == PreDiveItemType.value || type == PreDiveItemType.cellLinearity;
  String? text(String? value) {
    final trimmed = value?.trim();
    return isValue && trimmed != null && trimmed.isNotEmpty ? trimmed : null;
  }

  final source = item.sourceItemId;
  return (
    id: item.id,
    sectionId: sectionIds.contains(item.sectionId) ? item.sectionId : null,
    title: item.title.trim(),
    notes: item.notes.trim(),
    itemType: type,
    valueLabel: text(item.valueLabel),
    valueUnit: text(item.valueUnit),
    valueMin: isValue ? _thresholdText(item.valueMin) : '',
    valueMax: isValue ? _thresholdText(item.valueMax) : '',
    isRequired: item.isRequired,
    equipmentId: type == PreDiveItemType.equipment ? item.equipmentId : null,
    sourceItemId:
        type == PreDiveItemType.cellLinearity &&
            source != item.id &&
            valueItemIds.contains(source)
        ? source
        : null,
  );
}

/// The pre-dive template editor's form as it reads now.
PreDiveTemplateDraft preDiveTemplateDraft({
  required String name,
  required String description,
  required String category,
  required bool strictOrder,
  required List<EditablePreDiveSection> sections,
  required List<EditablePreDiveItem> itemsInDisplayOrder,
}) {
  final sectionIds = {for (final section in sections) section.id};
  final valueItemIds = {
    for (final item in itemsInDisplayOrder)
      if (item.itemType == PreDiveItemType.value) item.id,
  };
  return PreDiveTemplateDraft(
    name: name,
    description: description,
    category: category,
    strictOrder: strictOrder,
    sections: [
      for (final section in sections) (id: section.id, title: section.title),
    ],
    items: [
      for (final item in itemsInDisplayOrder)
        preDiveItemDraft(
          item,
          sectionIds: sectionIds,
          valueItemIds: valueItemIds,
        ),
    ],
  );
}
