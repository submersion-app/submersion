import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// Whether a piece of an operator's rental gear is worth asking for again.
enum RentalVerdict { worked, avoid }

/// One thing a diver learned about a dive center's rental gear (issue
/// #2075): "their size-L wetsuit runs small", "regulator 14 breathes wet",
/// "their AL80 really holds 11.1 L", "I needed 2 kg more with their BCD".
///
/// A note belongs to the center, not to a dive: it survives the dive it was
/// written on and shows on every later visit. [diveId] only records where it
/// was noticed.
class DiveCenterGearNote extends Equatable {
  final String id;
  final String diveCenterId;
  final EquipmentType gearType;

  /// The operator's own mark for the item: "14", "AL80", "blue".
  final String? label;
  final String? size;
  final RentalVerdict verdict;

  /// Signed, in kg: how much more (positive) or less lead this gear needed
  /// than the diver's usual.
  final double? leadAdjustmentKg;

  /// The cylinder's true capacity, for tank notes.
  final double? volumeLiters;
  final String note;
  final String? diveId;
  final DateTime notedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DiveCenterGearNote({
    required this.id,
    required this.diveCenterId,
    required this.gearType,
    this.label,
    this.size,
    this.verdict = RentalVerdict.worked,
    this.leadAdjustmentKg,
    this.volumeLiters,
    this.note = '',
    this.diveId,
    required this.notedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// A stored verdict name, tolerating a value this build does not know.
  static RentalVerdict verdictFromName(String? name) => RentalVerdict.values
      .firstWhere((v) => v.name == name, orElse: () => RentalVerdict.worked);

  /// A stored gear type name; a type added by a newer peer reads as other.
  static EquipmentType gearTypeFromName(String? name) => EquipmentType.values
      .firstWhere((t) => t.name == name, orElse: () => EquipmentType.other);

  DiveCenterGearNote copyWith({
    String? id,
    String? diveCenterId,
    EquipmentType? gearType,
    String? label,
    bool clearLabel = false,
    String? size,
    bool clearSize = false,
    RentalVerdict? verdict,
    double? leadAdjustmentKg,
    bool clearLeadAdjustment = false,
    double? volumeLiters,
    bool clearVolume = false,
    String? note,
    String? diveId,
    bool clearDiveId = false,
    DateTime? notedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiveCenterGearNote(
      id: id ?? this.id,
      diveCenterId: diveCenterId ?? this.diveCenterId,
      gearType: gearType ?? this.gearType,
      label: clearLabel ? null : (label ?? this.label),
      size: clearSize ? null : (size ?? this.size),
      verdict: verdict ?? this.verdict,
      leadAdjustmentKg: clearLeadAdjustment
          ? null
          : (leadAdjustmentKg ?? this.leadAdjustmentKg),
      volumeLiters: clearVolume ? null : (volumeLiters ?? this.volumeLiters),
      note: note ?? this.note,
      diveId: clearDiveId ? null : (diveId ?? this.diveId),
      notedAt: notedAt ?? this.notedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diveCenterId,
    gearType,
    label,
    size,
    verdict,
    leadAdjustmentKg,
    volumeLiters,
    note,
    diveId,
    notedAt,
    createdAt,
    updatedAt,
  ];
}
