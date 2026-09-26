import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;

/// What a ledger row records.
enum TripCylinderEventKind {
  /// Gas went in: pressure, the mix ordered, what the analyzer read, the
  /// bottle number now in the slot, where, and what it cost.
  fill,

  /// A correction: a pressure read off the gauge, or "mark empty".
  adjustment,
}

/// Reads a stored kind. A name this build does not know (a newer peer) is an
/// adjustment: it applies whatever pressure it carries and never throws.
TripCylinderEventKind tripCylinderEventKindFromName(String? name) =>
    TripCylinderEventKind.values.firstWhere(
      (k) => k.name == name,
      orElse: () => TripCylinderEventKind.adjustment,
    );

/// [local] as the frame `Dive.dateTime` and `TripCylinderEvent.occurredAt`
/// share: the wall-clock reading stamped UTC, so a fill at 08:15 and a dive
/// at 09:00 order correctly whatever zone the device is in.
DateTime tripCylinderWallClock(DateTime local) => DateTime.utc(
  local.year,
  local.month,
  local.day,
  local.hour,
  local.minute,
  local.second,
);

/// One row of a slot's ledger.
///
/// [occurredAt] is the diver's wall clock in the UTC frame `Dive.dateTime`
/// uses (see [tripCylinderWallClock]). Pressures in bar, percentages 0 to
/// 100. [currency] null means the diver's default currency.
class TripCylinderEvent extends Equatable {
  final String id;
  final String tripCylinderId;
  final TripCylinderEventKind kind;
  final DateTime occurredAt;

  /// The operator's number for the bottle now in the slot (fills).
  final String? bottleLabel;

  /// Fill pressure, or the corrected current pressure.
  final double? pressure;
  final double? o2Percent;
  final double? hePercent;
  final double? analyzedO2;
  final double? analyzedHe;
  final String? diveCenterId;
  final double? cost;
  final String? currency;
  final bool isPackage;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TripCylinderEvent({
    required this.id,
    required this.tripCylinderId,
    required this.kind,
    required this.occurredAt,
    this.bottleLabel,
    this.pressure,
    this.o2Percent,
    this.hePercent,
    this.analyzedO2,
    this.analyzedHe,
    this.diveCenterId,
    this.cost,
    this.currency,
    this.isPackage = false,
    this.note = '',
    required this.createdAt,
    required this.updatedAt,
  });

  /// The mix ordered, when the row carries one.
  GasMix? get orderedMix =>
      o2Percent == null ? null : GasMix(o2: o2Percent!, he: hePercent ?? 0);

  /// What the analyzer read, when the row carries it.
  GasMix? get analyzedMix =>
      analyzedO2 == null ? null : GasMix(o2: analyzedO2!, he: analyzedHe ?? 0);

  /// The mix the slot holds after this event: analyzed over ordered.
  GasMix? get effectiveMix => analyzedMix ?? orderedMix;

  TripCylinderEvent copyWith({
    String? id,
    String? tripCylinderId,
    TripCylinderEventKind? kind,
    DateTime? occurredAt,
    Object? bottleLabel = _undefined,
    Object? pressure = _undefined,
    Object? o2Percent = _undefined,
    Object? hePercent = _undefined,
    Object? analyzedO2 = _undefined,
    Object? analyzedHe = _undefined,
    Object? diveCenterId = _undefined,
    Object? cost = _undefined,
    Object? currency = _undefined,
    bool? isPackage,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TripCylinderEvent(
      id: id ?? this.id,
      tripCylinderId: tripCylinderId ?? this.tripCylinderId,
      kind: kind ?? this.kind,
      occurredAt: occurredAt ?? this.occurredAt,
      bottleLabel: bottleLabel == _undefined
          ? this.bottleLabel
          : bottleLabel as String?,
      pressure: pressure == _undefined ? this.pressure : pressure as double?,
      o2Percent: o2Percent == _undefined
          ? this.o2Percent
          : o2Percent as double?,
      hePercent: hePercent == _undefined
          ? this.hePercent
          : hePercent as double?,
      analyzedO2: analyzedO2 == _undefined
          ? this.analyzedO2
          : analyzedO2 as double?,
      analyzedHe: analyzedHe == _undefined
          ? this.analyzedHe
          : analyzedHe as double?,
      diveCenterId: diveCenterId == _undefined
          ? this.diveCenterId
          : diveCenterId as String?,
      cost: cost == _undefined ? this.cost : cost as double?,
      currency: currency == _undefined ? this.currency : currency as String?,
      isPackage: isPackage ?? this.isPackage,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tripCylinderId,
    kind,
    occurredAt,
    bottleLabel,
    pressure,
    o2Percent,
    hePercent,
    analyzedO2,
    analyzedHe,
    diveCenterId,
    cost,
    currency,
    isPackage,
    note,
    createdAt,
    updatedAt,
  ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();
