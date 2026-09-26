import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_ownership_event.dart';
import 'package:submersion/features/equipment/domain/services/equipment_history_builder.dart';

void main() {
  DateTime d(int day) => DateTime.utc(2026, 1, day);
  EquipmentUsageDive dive(String id, String? diver, int day) =>
      (diveId: id, diverId: diver, date: d(day));
  EquipmentOwnershipEvent event(
    EquipmentOwnershipEventKind kind,
    int day, {
    String? from,
    String? to,
  }) => EquipmentOwnershipEvent(
    id: 'e$day',
    equipmentId: 'x',
    kind: kind,
    fromDiverId: from,
    toDiverId: to,
    occurredAt: d(day),
  );

  test('folds consecutive dives by diver into runs, A B A is three runs', () {
    final history = buildEquipmentHistory(
      // fed out of date order on purpose
      dives: [
        dive('3', 'bill', 5),
        dive('1', 'bill', 1),
        dive('4', 'bill', 6),
        dive('2', 'anna', 3),
        dive('0', 'bill', 2),
      ],
      events: const [],
      currentOwnerId: 'bill',
      createdAt: null,
    );
    final runs = history.whereType<EquipmentUsageRun>().toList();
    expect(runs.map((r) => (r.diverId, r.diveCount)), [
      ('bill', 2), // days 5-6, newest first
      ('anna', 1),
      ('bill', 2), // days 1-2
    ]);
    expect(runs.first.first, d(5));
    expect(runs.first.last, d(6));
  });

  test('interleaves events and runs newest first, added entry last', () {
    final history = buildEquipmentHistory(
      dives: [dive('1', 'bill', 2), dive('2', 'anna', 8)],
      events: [
        event(EquipmentOwnershipEventKind.shared, 5, from: 'bill', to: 'anna'),
      ],
      currentOwnerId: 'bill',
      createdAt: d(1),
    );
    expect(history.map((e) => e.runtimeType), [
      EquipmentUsageRun,
      EquipmentEventEntry,
      EquipmentUsageRun,
      EquipmentAddedEntry,
    ]);
    expect((history.last as EquipmentAddedEntry).ownerId, 'bill');
  });

  test('the original owner is the first transfer from side', () {
    final history = buildEquipmentHistory(
      dives: const [],
      events: [
        event(
          EquipmentOwnershipEventKind.transferred,
          4,
          from: 'bill',
          to: 'tom',
        ),
        event(
          EquipmentOwnershipEventKind.transferred,
          9,
          from: 'tom',
          to: 'anna',
        ),
      ],
      currentOwnerId: 'anna',
      createdAt: d(1),
    );
    expect((history.last as EquipmentAddedEntry).ownerId, 'bill');
  });

  test('an event naming the same profile on both sides is skipped', () {
    final history = buildEquipmentHistory(
      dives: const [],
      events: [
        event(EquipmentOwnershipEventKind.shared, 3, from: 'bill', to: 'bill'),
      ],
      currentOwnerId: 'bill',
      createdAt: d(1),
    );
    expect(history.whereType<EquipmentEventEntry>(), isEmpty);
  });

  test('no created date gives no added entry; no dives gives no runs', () {
    expect(
      buildEquipmentHistory(
        dives: const [],
        events: const [],
        currentOwnerId: 'bill',
        createdAt: null,
      ),
      isEmpty,
    );
  });

  test('same-day dives order by dive id for a stable fold', () {
    final history = buildEquipmentHistory(
      dives: [dive('b', 'anna', 1), dive('a', 'bill', 1), dive('c', 'bill', 1)],
      events: const [],
      currentOwnerId: 'bill',
      createdAt: null,
    );
    expect(history.whereType<EquipmentUsageRun>().map((r) => r.diverId), [
      'bill',
      'anna',
      'bill',
    ]);
  });
}
