import 'package:equatable/equatable.dart';

/// Per-trip checklist item (copied from a template or added ad hoc)
class TripChecklistItem extends Equatable {
  final String id;
  final String tripId;
  final String title;
  final String? category;
  final String notes;

  /// Absolute due date, resolved from the template offset at apply time.
  final DateTime? dueDate;
  final bool isDone;
  final DateTime? completedAt;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TripChecklistItem({
    required this.id,
    required this.tripId,
    required this.title,
    this.category,
    this.notes = '',
    this.dueDate,
    this.isDone = false,
    this.completedAt,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Overdue when the due date has passed (date-only) and the item is
  /// not done. Callers must additionally gate on Trip.isUpcoming so past
  /// trips never nag.
  bool isOverdue(DateTime now) {
    final due = dueDate;
    if (due == null || isDone) return false;
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    return dueDay.isBefore(today);
  }

  TripChecklistItem copyWith({
    String? id,
    String? tripId,
    String? title,
    Object? category = _undefined,
    String? notes,
    Object? dueDate = _undefined,
    bool? isDone,
    Object? completedAt = _undefined,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TripChecklistItem(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      title: title ?? this.title,
      category: category == _undefined ? this.category : category as String?,
      notes: notes ?? this.notes,
      dueDate: dueDate == _undefined ? this.dueDate : dueDate as DateTime?,
      isDone: isDone ?? this.isDone,
      completedAt: completedAt == _undefined
          ? this.completedAt
          : completedAt as DateTime?,
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
    category,
    notes,
    dueDate,
    isDone,
    completedAt,
    sortOrder,
    createdAt,
    updatedAt,
  ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();
