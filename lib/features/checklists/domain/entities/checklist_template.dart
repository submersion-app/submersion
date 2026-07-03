import 'package:equatable/equatable.dart';

/// Reusable checklist template for trip planning
class ChecklistTemplate extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChecklistTemplate({
    required this.id,
    this.diverId,
    required this.name,
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
  });

  ChecklistTemplate copyWith({
    String? id,
    Object? diverId = _undefined,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChecklistTemplate(
      id: id ?? this.id,
      diverId: diverId == _undefined ? this.diverId : diverId as String?,
      name: name ?? this.name,
      description: description ?? this.description,
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
    createdAt,
    updatedAt,
  ];
}

/// Item belonging to a checklist template
class ChecklistTemplateItem extends Equatable {
  final String id;
  final String templateId;
  final String title;
  final String? category;
  final String notes;

  /// Days before trip start the item is due (null = no due date).
  final int? dueOffsetDays;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChecklistTemplateItem({
    required this.id,
    required this.templateId,
    required this.title,
    this.category,
    this.notes = '',
    this.dueOffsetDays,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  ChecklistTemplateItem copyWith({
    String? id,
    String? templateId,
    String? title,
    Object? category = _undefined,
    String? notes,
    Object? dueOffsetDays = _undefined,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChecklistTemplateItem(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      title: title ?? this.title,
      category: category == _undefined ? this.category : category as String?,
      notes: notes ?? this.notes,
      dueOffsetDays: dueOffsetDays == _undefined
          ? this.dueOffsetDays
          : dueOffsetDays as int?,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    templateId,
    title,
    category,
    notes,
    dueOffsetDays,
    sortOrder,
    createdAt,
    updatedAt,
  ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();
