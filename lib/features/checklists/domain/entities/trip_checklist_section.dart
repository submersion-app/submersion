import 'package:equatable/equatable.dart';

/// A visual grouping header for a trip's checklist items (issue #3360).
/// Unlike the free-text `category` it replaces, a section is a row with its
/// own identity: it can be created empty, renamed once instead of per item,
/// and reordered independently of the items inside it.
class TripChecklistSection extends Equatable {
  final String id;
  final String tripId;
  final String title;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TripChecklistSection({
    required this.id,
    required this.tripId,
    required this.title,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  TripChecklistSection copyWith({
    String? id,
    String? tripId,
    String? title,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TripChecklistSection(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      title: title ?? this.title,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tripId,
    title,
    sortOrder,
    createdAt,
    updatedAt,
  ];
}
