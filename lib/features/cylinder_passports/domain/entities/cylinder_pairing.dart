import 'package:equatable/equatable.dart';

/// The calendar date of [any] as UTC midnight: the one form pairing days are
/// stored and compared in (issue #4242). A fill's local time and a dive's
/// shown date both reduce to their year, month and day, so "the pairing on
/// the 14th" means the same day on every device and in every time zone.
DateTime calendarDay(DateTime any) =>
    DateTime.utc(any.year, any.month, any.day);

/// Two cylinders manifolded as a twin set over a range of whole days
/// (issue #4242). The range is half open: it covers [pairedOn] up to the day
/// before [unpairedOn], and is still current while [unpairedOn] is null. On a
/// swap day the new pairing counts, because the old one ends that day.
///
/// A pairing belongs to the two cylinders rather than to a diver profile, so
/// every profile that sees either cylinder sees it. It never moves fills or
/// rewrites dives; it only records which two cylinders were together when.
class CylinderPairing extends Equatable {
  final String id;
  final String cylinderAId;
  final String cylinderBId;

  /// The first day of the pairing, as [calendarDay] gives it.
  final DateTime pairedOn;

  /// The first day the cylinders were no longer paired, or null while they
  /// still are.
  final DateTime? unpairedOn;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CylinderPairing({
    required this.id,
    required this.cylinderAId,
    required this.cylinderBId,
    required this.pairedOn,
    this.unpairedOn,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOpen => unpairedOn == null;

  bool involves(String equipmentId) =>
      cylinderAId == equipmentId || cylinderBId == equipmentId;

  /// The other cylinder of the pair. Throws [ArgumentError] when
  /// [equipmentId] is not one of the two.
  String partnerOf(String equipmentId) {
    if (equipmentId == cylinderAId) return cylinderBId;
    if (equipmentId == cylinderBId) return cylinderAId;
    throw ArgumentError.value(equipmentId, 'equipmentId', 'not in the pair');
  }

  /// Whether the pair was together on the calendar day of [day].
  bool coversDay(DateTime day) {
    final date = calendarDay(day);
    final end = unpairedOn;
    return !date.isBefore(pairedOn) && (end == null || date.isBefore(end));
  }

  CylinderPairing copyWith({
    String? id,
    String? cylinderAId,
    String? cylinderBId,
    DateTime? pairedOn,
    DateTime? unpairedOn,
    bool clearUnpairedOn = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CylinderPairing(
    id: id ?? this.id,
    cylinderAId: cylinderAId ?? this.cylinderAId,
    cylinderBId: cylinderBId ?? this.cylinderBId,
    pairedOn: pairedOn ?? this.pairedOn,
    unpairedOn: clearUnpairedOn ? null : (unpairedOn ?? this.unpairedOn),
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Timestamps are left out, as on CylinderFill: they churn on every write.
  @override
  List<Object?> get props => [
    id,
    cylinderAId,
    cylinderBId,
    pairedOn,
    unpairedOn,
  ];
}
