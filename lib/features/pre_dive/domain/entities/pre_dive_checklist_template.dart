import 'package:equatable/equatable.dart';

/// Kind of checklist item.
enum PreDiveItemType {
  check,
  value,
  equipmentSet;

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
    createdAt,
    updatedAt,
  ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();
