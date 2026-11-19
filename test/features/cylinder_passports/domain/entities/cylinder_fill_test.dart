import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';

void main() {
  final now = DateTime(2026, 9, 25, 14, 3);
  final fill = CylinderFill(
    id: 'fill-1',
    passportId: 'p-1',
    equipmentId: 'eq-1',
    filledAt: now,
    o2Percent: 32,
    pressureBar: 220,
    stationName: 'Blue Water Fills',
    createdAt: now,
    updatedAt: now,
  );

  test('exposes the mix as a GasMix', () {
    expect(fill.gasMix.name, 'EAN32');
    expect(fill.isSigned, isFalse);
  });

  test('copyWith clears nullable fields on request', () {
    final cleared = fill.copyWith(
      clearEquipmentId: true,
      clearPressureBar: true,
    );
    expect(cleared.equipmentId, isNull);
    expect(cleared.pressureBar, isNull);
    expect(cleared.stationName, 'Blue Water Fills');
  });

  test('equality ignores timestamps', () {
    final later = fill.copyWith(updatedAt: now.add(const Duration(hours: 1)));
    expect(later, fill);
  });

  test('an unknown source name reads as manual', () {
    expect(FillSource.fromName('teleport'), FillSource.manual);
    expect(FillSource.fromName('issued'), FillSource.issued);
  });

  group('isPossibleMix', () {
    test('a fill holds some oxygen and at most 100% between its gases', () {
      expect(CylinderFill.isPossibleMix(32, 0), isTrue);
      expect(CylinderFill.isPossibleMix(21, 35), isTrue);
      expect(CylinderFill.isPossibleMix(100, 0), isTrue);
      expect(CylinderFill.isPossibleMix(0, 100), isFalse);
      expect(CylinderFill.isPossibleMix(60, 50), isFalse);
      expect(CylinderFill.isPossibleMix(3200, 0), isFalse);
      expect(CylinderFill.isPossibleMix(21, -1), isFalse);
    });

    // The same rule as a dive cylinder's mix (GasMix.isPossible, #4714),
    // so a fill analysed as fractions is not refused for binary noise.
    test('binary noise on a full mix is still a fill', () {
      expect(CylinderFill.isPossibleMix(21.0000000001, 79), isTrue);
    });
  });
}
