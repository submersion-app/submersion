import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/services/service_due_engine.dart';

/// The date a clock's service was really last done: the newest record of its
/// kind, or a baseline the diver set that outranks the records. Null when
/// there is neither. The clock's own fallback to the purchase or creation
/// date is a reminder baseline, not a service, so the passport never shows
/// it as one and a tag never prints it (spec section 6.2).
DateTime? recordedServiceDate({
  required ServiceClockStatus? clock,
  required Iterable<ServiceRecord> records,
}) {
  if (clock == null) return null;
  return clockAnchorFromServices(
    serviceKindId: clock.kind.id,
    baseline: clock.schedule.anchorDate,
    baselineSetAt: clock.schedule.anchorSetAt,
    records: records,
  );
}

/// Why the passport warns about oxygen cleanliness (spec section 8).
enum O2CleanWarning { none, untracked, overdue }

/// Warns when the newest fill is richer than the diver's high-O2 threshold
/// (the same one the exposure clocks use) and the cylinder either has no O2
/// clean clock or that clock is overdue.
O2CleanWarning o2CleanWarning({
  required double? newestO2Percent,
  required ServiceClockStatus? o2CleanClock,
  required double highO2Fraction,
}) {
  if (newestO2Percent == null) return O2CleanWarning.none;
  if (newestO2Percent / 100 <= highO2Fraction) return O2CleanWarning.none;
  if (o2CleanClock == null) return O2CleanWarning.untracked;
  if (o2CleanClock.severity == ServiceClockSeverity.overdue) {
    return O2CleanWarning.overdue;
  }
  return O2CleanWarning.none;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// True when the row has moved on since the tag was written: a hydro or
/// VIP anchored after the write date, or a spec value that differs
/// (spec section 6.6). Unknown facts on either side never count.
bool tagIsStale({
  required CylinderPassportPayload tag,
  DateTime? hydroAnchor,
  DateTime? vipAnchor,
  double? volumeL,
  int? workingPressureBar,
  TankMaterial? material,
}) {
  final written = tag.writtenOn;
  if (written != null) {
    for (final anchor in [hydroAnchor, vipAnchor]) {
      if (anchor != null && _dateOnly(anchor).isAfter(_dateOnly(written))) {
        return true;
      }
    }
  }
  if (tag.volumeL != null &&
      volumeL != null &&
      (tag.volumeL! - volumeL).abs() > 0.05) {
    return true;
  }
  if (tag.workingPressureBar != null &&
      workingPressureBar != null &&
      tag.workingPressureBar != workingPressureBar) {
    return true;
  }
  if (tag.material != null && material != null && tag.material != material) {
    return true;
  }
  return false;
}

PassportValve? _valveOf(EquipmentItem item) =>
    switch (item.attrText('valve_type')) {
      'din' => PassportValve.din,
      'yoke' => PassportValve.yoke,
      'convertible' => PassportValve.convertible,
      _ => null,
    };

/// The payload a label or tag for [item] should carry right now.
/// [hydroAnchor] and [vipAnchor] are the clocks' anchors (last service or
/// baseline), which is what the tag means by "last hydro" and "last VIP".
CylinderPassportPayload payloadForItem({
  required EquipmentItem item,
  required String passportId,
  required DateTime writtenOn,
  DateTime? hydroAnchor,
  DateTime? vipAnchor,
  required bool o2Clean,
}) {
  final identifier = item.identifier;
  return CylinderPassportPayload(
    passportId: passportId,
    writtenOn: writtenOn,
    name: identifier != null && identifier.trim().isNotEmpty
        ? identifier.trim()
        : item.name,
    serial: (item.serialNumber ?? '').trim().isEmpty ? null : item.serialNumber,
    volumeL: item.volumeL,
    workingPressureBar: item.workingPressureBar?.round(),
    material: item.tankMaterial,
    valve: _valveOf(item),
    lastHydro: hydroAnchor,
    lastVip: vipAnchor,
    o2Clean: o2Clean,
  );
}
