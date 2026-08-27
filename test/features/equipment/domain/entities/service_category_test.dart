import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';

void main() {
  test('ServiceCategory keeps the ten values and their wire names', () {
    expect(ServiceCategory.values, hasLength(10));
    expect(ServiceCategory.values.map((c) => c.name).toList(), const [
      'annual',
      'repair',
      'inspection',
      'overhaul',
      'replacement',
      'cleaning',
      'calibration',
      'warranty',
      'recall',
      'other',
    ]);
  });

  test('displayName stays the English export label', () {
    expect(ServiceCategory.annual.displayName, 'Annual Service');
    expect(ServiceCategory.replacement.displayName, 'Part Replacement');
  });

  test('ServiceRecord exposes serviceCategory', () {
    final record = ServiceRecord.empty('equip-1');
    expect(record.serviceCategory, ServiceCategory.annual);

    final edited = record.copyWith(serviceCategory: ServiceCategory.repair);
    expect(edited.serviceCategory, ServiceCategory.repair);
  });
}
