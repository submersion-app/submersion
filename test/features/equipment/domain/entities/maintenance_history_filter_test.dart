import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/maintenance_history_filter.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';

ServiceRecord record({
  String? kindId,
  ServiceCategory type = ServiceCategory.cleaning,
  int year = 2026,
}) {
  final date = DateTime(year, 3, 14);
  return ServiceRecord(
    id: 'r-$kindId-$year-${type.name}',
    equipmentId: 'e1',
    serviceCategory: type,
    serviceKindId: kindId,
    serviceDate: date,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  test('an empty filter is inactive and matches everything', () {
    const filter = MaintenanceHistoryFilter();
    expect(filter.isActive, isFalse);
    expect(filter.matches(record(kindId: 'disinfect')), isTrue);
    expect(filter.matches(record(kindId: null)), isTrue);
  });

  test('the kind filter selects one task', () {
    const filter = MaintenanceHistoryFilter(serviceKindId: 'disinfect');
    expect(filter.isActive, isTrue);
    expect(filter.matches(record(kindId: 'disinfect')), isTrue);
    expect(filter.matches(record(kindId: 'scrubber-repack')), isFalse);
    expect(filter.matches(record(kindId: null)), isFalse);
  });

  test('the untagged sentinel selects records with no kind', () {
    const filter = MaintenanceHistoryFilter(
      serviceKindId: MaintenanceHistoryFilter.untaggedSentinel,
    );
    expect(filter.matches(record(kindId: null)), isTrue);
    expect(filter.matches(record(kindId: 'disinfect')), isFalse);
  });

  test('type and year filters intersect with the kind filter', () {
    const filter = MaintenanceHistoryFilter(
      serviceKindId: 'disinfect',
      serviceCategory: ServiceCategory.cleaning,
      year: 2026,
    );
    expect(filter.matches(record(kindId: 'disinfect', year: 2026)), isTrue);
    expect(filter.matches(record(kindId: 'disinfect', year: 2025)), isFalse);
    expect(
      filter.matches(record(kindId: 'disinfect', type: ServiceCategory.repair)),
      isFalse,
    );
  });

  test('copyWith clears a dimension back to null', () {
    const filter = MaintenanceHistoryFilter(serviceKindId: 'disinfect');
    expect(filter.copyWith(serviceKindId: null).serviceKindId, isNull);
    expect(filter.copyWith(serviceKindId: null).isActive, isFalse);
  });

  test('equality covers every dimension', () {
    // The section rebuilds on filter changes, so two filters differing in any
    // one dimension must not compare equal.
    const base = MaintenanceHistoryFilter(
      serviceKindId: 'disinfect',
      serviceCategory: ServiceCategory.cleaning,
      year: 2026,
    );

    expect(
      base,
      const MaintenanceHistoryFilter(
        serviceKindId: 'disinfect',
        serviceCategory: ServiceCategory.cleaning,
        year: 2026,
      ),
    );
    expect(base, isNot(base.copyWith()));
    expect(
      base,
      isNot(
        const MaintenanceHistoryFilter(
          serviceKindId: 'disinfect',
          serviceCategory: ServiceCategory.repair,
          year: 2026,
        ),
      ),
    );
    expect(
      base,
      isNot(
        const MaintenanceHistoryFilter(
          serviceKindId: 'disinfect',
          serviceCategory: ServiceCategory.cleaning,
          year: 2025,
        ),
      ),
    );
  });
}
