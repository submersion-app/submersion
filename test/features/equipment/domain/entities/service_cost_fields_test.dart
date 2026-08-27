import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

void main() {
  final now = DateTime(2026, 8, 18);

  test('ServiceKind.copyWith clears defaultCost to null', () {
    final kind = ServiceKind(
      id: 'k1',
      name: 'Disinfect',
      defaultCost: 12.5,
      defaultCurrency: 'EUR',
      createdAt: now,
      updatedAt: now,
    );

    expect(kind.copyWith(defaultCost: null).defaultCost, isNull);
    expect(kind.copyWith(defaultCurrency: null).defaultCurrency, isNull);
    // Omitting the argument leaves the value alone; that distinction is why
    // the _undefined sentinel exists.
    expect(kind.copyWith(name: 'Rinse').defaultCost, 12.5);
  });

  test('ServiceSchedule.copyWith clears defaultCost to null', () {
    final schedule = ServiceSchedule(
      id: 's1',
      equipmentId: 'e1',
      serviceKindId: 'k1',
      defaultCost: 45,
      defaultCurrency: 'EUR',
      createdAt: now,
      updatedAt: now,
    );

    expect(schedule.copyWith(defaultCost: null).defaultCost, isNull);
    expect(schedule.copyWith(defaultCurrency: null).defaultCurrency, isNull);
    expect(schedule.copyWith(enabled: false).defaultCost, 45);
  });
}
