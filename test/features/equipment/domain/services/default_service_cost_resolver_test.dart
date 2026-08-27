import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/domain/services/default_service_cost_resolver.dart';

void main() {
  final now = DateTime(2026, 8, 18);

  ServiceKind kind({double? cost, String? currency}) => ServiceKind(
    id: 'scrubber-repack',
    name: 'Scrubber repack',
    defaultCost: cost,
    defaultCurrency: currency,
    createdAt: now,
    updatedAt: now,
  );

  ServiceSchedule schedule({double? cost, String? currency}) => ServiceSchedule(
    id: 's1',
    equipmentId: 'e1',
    serviceKindId: 'scrubber-repack',
    defaultCost: cost,
    defaultCurrency: currency,
    createdAt: now,
    updatedAt: now,
  );

  test('the per-item schedule wins over the catalog kind', () {
    final result = resolveDefaultServiceCost(
      serviceKindId: 'scrubber-repack',
      schedules: [schedule(cost: 45, currency: 'EUR')],
      kinds: [kind(cost: 60, currency: 'USD')],
    );
    expect(result.cost, 45);
    expect(result.currency, 'EUR');
  });

  test('the kind is used when the schedule has no cost', () {
    final result = resolveDefaultServiceCost(
      serviceKindId: 'scrubber-repack',
      schedules: [schedule()],
      kinds: [kind(cost: 60, currency: 'USD')],
    );
    expect(result.cost, 60);
    expect(result.currency, 'USD');
  });

  test('cost and currency resolve independently', () {
    // A schedule that prices the job but says nothing about currency should
    // still inherit the kind's currency rather than dropping it.
    final result = resolveDefaultServiceCost(
      serviceKindId: 'scrubber-repack',
      schedules: [schedule(cost: 45)],
      kinds: [kind(cost: 60, currency: 'EUR')],
    );
    expect(result.cost, 45);
    expect(result.currency, 'EUR');
  });

  test('nothing resolves when neither defines a cost', () {
    final result = resolveDefaultServiceCost(
      serviceKindId: 'scrubber-repack',
      schedules: [schedule()],
      kinds: [kind()],
    );
    expect(result.cost, isNull);
    expect(result.currency, isNull);
  });

  test('an untagged record resolves nothing', () {
    final result = resolveDefaultServiceCost(
      serviceKindId: null,
      schedules: [schedule(cost: 45)],
      kinds: [kind(cost: 60)],
    );
    expect(result.cost, isNull);
  });

  test('an unknown kind id resolves nothing', () {
    final result = resolveDefaultServiceCost(
      serviceKindId: 'deleted-kind',
      schedules: [schedule(cost: 45)],
      kinds: [kind(cost: 60)],
    );
    expect(result.cost, isNull);
  });

  test('a schedule for another kind is ignored', () {
    final other = ServiceSchedule(
      id: 's2',
      equipmentId: 'e1',
      serviceKindId: 'disinfect',
      defaultCost: 5,
      createdAt: now,
      updatedAt: now,
    );
    final result = resolveDefaultServiceCost(
      serviceKindId: 'scrubber-repack',
      schedules: [other, schedule(cost: 45)],
      kinds: [kind(cost: 60)],
    );
    expect(result.cost, 45);
  });
}
