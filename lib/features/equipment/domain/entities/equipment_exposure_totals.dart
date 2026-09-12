import 'package:equatable/equatable.dart';

import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';

/// What an item has been through, summed over its exposure samples with
/// the diver's current thresholds. Derived on read, never stored, so a
/// threshold change shows on the next build.
class EquipmentExposureTotals extends Equatable {
  /// Every unit except [ExposureUnit.days] (a date trigger has no usage);
  /// a unit with a zero total is absent.
  final Map<ExposureUnit, double> byUnit;
  final int diveCount;
  final DateTime? firstDive;
  final DateTime? lastDive;

  const EquipmentExposureTotals({
    required this.byUnit,
    required this.diveCount,
    this.firstDive,
    this.lastDive,
  });

  static const empty = EquipmentExposureTotals(byUnit: {}, diveCount: 0);

  @override
  List<Object?> get props => [byUnit, diveCount, firstDive, lastDive];
}
