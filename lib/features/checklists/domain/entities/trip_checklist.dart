import 'package:equatable/equatable.dart';

/// One of a trip's named checklists (issue #3356). A trip can have several,
/// e.g. "Dive equipment", "Clothing", "Beach vacation"; each owns its own
/// sections ([TripChecklistSection]) and items ([TripChecklistItem]).
class TripChecklist extends Equatable {
  final String id;
  final String tripId;
  final String name;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TripChecklist({
    required this.id,
    required this.tripId,
    required this.name,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  TripChecklist copyWith({
    String? id,
    String? tripId,
    String? name,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TripChecklist(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tripId,
    name,
    sortOrder,
    createdAt,
    updatedAt,
  ];
}
