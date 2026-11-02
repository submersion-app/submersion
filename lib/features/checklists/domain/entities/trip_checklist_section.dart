import 'package:equatable/equatable.dart';

/// A visual grouping header for one checklist's items (issue #3360, scoped
/// to a single checklist since issue #3356). Unlike the free-text `category`
/// it replaces, a section is a row with its own identity: it can be created
/// empty, renamed once instead of per item, and reordered independently of
/// the items inside it.
class TripChecklistSection extends Equatable {
  final String id;
  final String checklistId;
  final String title;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TripChecklistSection({
    required this.id,
    required this.checklistId,
    required this.title,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  TripChecklistSection copyWith({
    String? id,
    String? checklistId,
    String? title,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TripChecklistSection(
      id: id ?? this.id,
      checklistId: checklistId ?? this.checklistId,
      title: title ?? this.title,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    checklistId,
    title,
    sortOrder,
    createdAt,
    updatedAt,
  ];
}
