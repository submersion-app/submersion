import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';

/// An item mid-edit on the pre-dive template editor page. See
/// checklist_template_edit_page.dart's `_EditableTemplateItem` for why
/// sections and items are held in memory here instead of going through the
/// repository directly: resolving a section one at a time as each item
/// dialog closes would touch the database for a section the diver then
/// discards by not saving the page.
class EditablePreDiveItem {
  final String id;
  final String? sectionId;
  final String title;
  final String notes;
  final int sortOrder;
  final PreDiveItemType itemType;
  final String? valueLabel;
  final String? valueUnit;
  final double? valueMin;
  final double? valueMax;
  final bool isRequired;
  final String? equipmentId;
  final String? sourceItemId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EditablePreDiveItem({
    required this.id,
    this.sectionId,
    required this.title,
    this.notes = '',
    this.sortOrder = 0,
    this.itemType = PreDiveItemType.check,
    this.valueLabel,
    this.valueUnit,
    this.valueMin,
    this.valueMax,
    this.isRequired = false,
    this.equipmentId,
    this.sourceItemId,
    required this.createdAt,
    required this.updatedAt,
  });

  EditablePreDiveItem copyWith({
    String? id,
    Object? sectionId = _undefined,
    String? title,
    String? notes,
    int? sortOrder,
    PreDiveItemType? itemType,
    Object? valueLabel = _undefined,
    Object? valueUnit = _undefined,
    Object? valueMin = _undefined,
    Object? valueMax = _undefined,
    bool? isRequired,
    Object? equipmentId = _undefined,
    Object? sourceItemId = _undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EditablePreDiveItem(
      id: id ?? this.id,
      sectionId: sectionId == _undefined
          ? this.sectionId
          : sectionId as String?,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
      itemType: itemType ?? this.itemType,
      valueLabel: valueLabel == _undefined
          ? this.valueLabel
          : valueLabel as String?,
      valueUnit: valueUnit == _undefined
          ? this.valueUnit
          : valueUnit as String?,
      valueMin: valueMin == _undefined ? this.valueMin : valueMin as double?,
      valueMax: valueMax == _undefined ? this.valueMax : valueMax as double?,
      isRequired: isRequired ?? this.isRequired,
      equipmentId: equipmentId == _undefined
          ? this.equipmentId
          : equipmentId as String?,
      sourceItemId: sourceItemId == _undefined
          ? this.sourceItemId
          : sourceItemId as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const _undefined = Object();

/// A section mid-edit on the pre-dive template editor page -- see
/// [EditablePreDiveItem] for why.
class EditablePreDiveSection {
  final String id;
  final String title;

  const EditablePreDiveSection({required this.id, required this.title});

  EditablePreDiveSection copyWith({String? title}) =>
      EditablePreDiveSection(id: id, title: title ?? this.title);
}
