import 'package:equatable/equatable.dart';

/// One entry of an item's location log. A null [locationId] records that
/// the location was cleared. The item's current location is its newest
/// move by [compareMovesNewestFirst].
class EquipmentLocationMove extends Equatable {
  final String id;
  final String equipmentId;
  final String? locationId;
  final DateTime movedAt;
  final String note;
  final DateTime createdAt;

  const EquipmentLocationMove({
    required this.id,
    required this.equipmentId,
    required this.locationId,
    required this.movedAt,
    this.note = '',
    required this.createdAt,
  });

  /// [clearLocation] records "no location"; a null [locationId] alone keeps
  /// the current one, as every copyWith in the app does.
  EquipmentLocationMove copyWith({
    String? locationId,
    bool clearLocation = false,
    DateTime? movedAt,
    String? note,
  }) => EquipmentLocationMove(
    id: id,
    equipmentId: equipmentId,
    locationId: clearLocation ? null : (locationId ?? this.locationId),
    movedAt: movedAt ?? this.movedAt,
    note: note ?? this.note,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [
    id,
    equipmentId,
    locationId,
    movedAt,
    note,
    createdAt,
  ];
}

/// Newest first: moved_at, then created_at, then id, each descending. The
/// SQL in `equipment_location_sql.dart` orders the same way, so the history
/// a card shows and the location the list reads always agree.
int compareMovesNewestFirst(EquipmentLocationMove a, EquipmentLocationMove b) {
  final byMoved = b.movedAt.compareTo(a.movedAt);
  if (byMoved != 0) return byMoved;
  final byCreated = b.createdAt.compareTo(a.createdAt);
  if (byCreated != 0) return byCreated;
  return b.id.compareTo(a.id);
}
