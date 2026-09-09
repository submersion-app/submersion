import 'package:equatable/equatable.dart';

/// Kind of checklist item.
enum PreDiveItemType {
  check,
  value,
  equipmentSet,
  equipment,

  /// Records a cell's millivolts in pure oxygen and derives its linearity
  /// against the air reading held by the item named in [sourceItemId]
  /// (issue #986).
  cellLinearity;

  /// The fallback to [check] is load-bearing forward compatibility: an older
  /// build that syncs a row of a type it does not know renders it as a plain
  /// tick-box instead of failing. Do not turn this into a throw.
  static PreDiveItemType parse(String raw) => PreDiveItemType.values.firstWhere(
    (e) => e.name == raw,
    orElse: () => PreDiveItemType.check,
  );
}

/// Reusable pre-dive checklist template (built-in or user-created).
class PreDiveChecklistTemplate extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final String description;
  final String? category;
  final bool strictOrder;
  final bool isBuiltIn;
  final String? builtinKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PreDiveChecklistTemplate({
    required this.id,
    this.diverId,
    required this.name,
    this.description = '',
    this.category,
    this.strictOrder = false,
    this.isBuiltIn = false,
    this.builtinKey,
    required this.createdAt,
    required this.updatedAt,
  });

  PreDiveChecklistTemplate copyWith({
    String? id,
    Object? diverId = _undefined,
    String? name,
    String? description,
    Object? category = _undefined,
    bool? strictOrder,
    bool? isBuiltIn,
    Object? builtinKey = _undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PreDiveChecklistTemplate(
      id: id ?? this.id,
      diverId: diverId == _undefined ? this.diverId : diverId as String?,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category == _undefined ? this.category : category as String?,
      strictOrder: strictOrder ?? this.strictOrder,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      builtinKey: builtinKey == _undefined
          ? this.builtinKey
          : builtinKey as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    name,
    description,
    category,
    strictOrder,
    isBuiltIn,
    builtinKey,
    createdAt,
    updatedAt,
  ];
}

/// Item belonging to a pre-dive checklist template.
class PreDiveChecklistTemplateItem extends Equatable {
  final String id;
  final String templateId;
  final String? section;
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

  /// For a [PreDiveItemType.cellLinearity] item, the id of the template item
  /// holding this cell's air reading (issue #986). Null on every other type.
  ///
  /// Tolerated as dangling: ids are remapped on clone and again at session
  /// start, and the editor lets a source item be deleted from under this
  /// one, so every reader degrades rather than assuming it resolves.
  final String? sourceItemId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PreDiveChecklistTemplateItem({
    required this.id,
    required this.templateId,
    this.section,
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

  PreDiveChecklistTemplateItem copyWith({
    String? id,
    String? templateId,
    Object? section = _undefined,
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
    return PreDiveChecklistTemplateItem(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      section: section == _undefined ? this.section : section as String?,
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

  @override
  List<Object?> get props => [
    id,
    templateId,
    section,
    title,
    notes,
    sortOrder,
    itemType,
    valueLabel,
    valueUnit,
    valueMin,
    valueMax,
    isRequired,
    equipmentId,
    sourceItemId,
    createdAt,
    updatedAt,
  ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();
