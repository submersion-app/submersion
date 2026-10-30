import 'package:equatable/equatable.dart';

/// A visual grouping header for a checklist template's items (issue #3360).
/// Unlike the free-text `category` it replaces, a section is a row with its
/// own identity: it can be created empty, renamed once instead of per item,
/// and reordered independently of the items inside it.
class ChecklistTemplateSection extends Equatable {
  final String id;
  final String templateId;
  final String title;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChecklistTemplateSection({
    required this.id,
    required this.templateId,
    required this.title,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  ChecklistTemplateSection copyWith({
    String? id,
    String? templateId,
    String? title,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChecklistTemplateSection(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      title: title ?? this.title,
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
    sortOrder,
    createdAt,
    updatedAt,
  ];
}
