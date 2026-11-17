import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// The pair's volume in liters, or null when either cylinder has none.
double? twinPairVolume(EquipmentItem a, EquipmentItem b) {
  final va = a.volumeL;
  final vb = b.volumeL;
  return va == null || vb == null ? null : va + vb;
}

/// The lower of two working pressures: the pair fills to one pressure, and
/// cannot hold more than its weaker cylinder. Either alone when the other is
/// unknown.
double? twinPairWorkingPressure(EquipmentItem a, EquipmentItem b) {
  final pa = a.workingPressureBar;
  final pb = b.workingPressureBar;
  if (pa == null) return pb;
  if (pb == null) return pa;
  return pa < pb ? pa : pb;
}
