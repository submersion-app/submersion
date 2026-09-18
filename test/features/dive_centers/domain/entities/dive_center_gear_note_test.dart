import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';

void main() {
  final now = DateTime.utc(2026, 9, 18, 10);

  DiveCenterGearNote note() => DiveCenterGearNote(
    id: 'n1',
    diveCenterId: 'c1',
    gearType: EquipmentType.regulator,
    label: '14',
    size: null,
    verdict: RentalVerdict.avoid,
    leadAdjustmentKg: null,
    volumeLiters: null,
    note: 'Breathed wet below 20 m',
    diveId: 'd1',
    notedAt: now,
    createdAt: now,
    updatedAt: now,
  );

  test('copyWith replaces only the given fields', () {
    final changed = note().copyWith(
      verdict: RentalVerdict.worked,
      leadAdjustmentKg: 2.0,
    );
    expect(changed.verdict, RentalVerdict.worked);
    expect(changed.leadAdjustmentKg, 2.0);
    expect(changed.label, '14');
    expect(changed.diveId, 'd1');
    expect(changed.note, 'Breathed wet below 20 m');
  });

  test('copyWith clear flags null a nullable field', () {
    final cleared = note().copyWith(clearLabel: true, clearDiveId: true);
    expect(cleared.label, isNull);
    expect(cleared.diveId, isNull);
    // The untouched nullable stays.
    expect(cleared.copyWith(size: 'L').size, 'L');
  });

  test('verdictFromName falls back to worked for unknown text', () {
    expect(DiveCenterGearNote.verdictFromName('avoid'), RentalVerdict.avoid);
    expect(DiveCenterGearNote.verdictFromName('worked'), RentalVerdict.worked);
    expect(DiveCenterGearNote.verdictFromName('later'), RentalVerdict.worked);
    expect(DiveCenterGearNote.verdictFromName(null), RentalVerdict.worked);
  });

  test('gearTypeFromName falls back to other for a newer peer type', () {
    expect(DiveCenterGearNote.gearTypeFromName('bcd'), EquipmentType.bcd);
    expect(
      DiveCenterGearNote.gearTypeFromName('hoverboard'),
      EquipmentType.other,
    );
    expect(DiveCenterGearNote.gearTypeFromName(null), EquipmentType.other);
  });

  test('equality is by value', () {
    expect(note(), note());
    expect(note() == note().copyWith(note: 'x'), isFalse);
  });
}
