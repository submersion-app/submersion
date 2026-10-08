import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_colors.dart';

void main() {
  test('a colour code comes back trimmed and uppercase', () {
    expect(normalizeEquipmentColor('#ef4444'), '#EF4444');
    expect(normalizeEquipmentColor('  #3b82F6 '), '#3B82F6');
  });

  test('anything that is not #RRGGBB is not a colour', () {
    for (final value in [
      null,
      '',
      'red',
      '#12G',
      '#1234567',
      '#-00001',
      'EF4444',
      '#fff',
    ]) {
      expect(normalizeEquipmentColor(value), isNull, reason: '$value');
    }
  });
}
