import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/reports/idle_gear.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';

final _now = DateTime(2026, 10, 31);

EquipmentItem _item(
  String id, {
  DateTime? bought,
  DateTime? created,
  String? parent,
  EquipmentStatus status = EquipmentStatus.active,
}) => EquipmentItem(
  id: id,
  diverId: 'me',
  name: id,
  type: EquipmentType.mask,
  purchaseDate: bought,
  createdAt: created,
  parentEquipmentId: parent,
  status: status,
);

List<IdleRow> _build(
  List<EquipmentItem> items, {
  Map<String, DateTime> lastDives = const {},
  IdlePeriod period = IdlePeriod.oneYear,
  ComponentsIndex index = ComponentsIndex.empty,
  DateTime? now,
}) => buildIdleGear(
  items: items,
  lastDives: lastDives,
  diverId: 'me',
  period: period,
  now: now ?? _now,
  index: index,
);

void main() {
  test('lists an item last dived before the cutoff, longest idle first', () {
    final rows = _build(
      [_item('recent'), _item('old'), _item('older')],
      lastDives: {
        'recent': DateTime(2025, 1, 1),
        'old': DateTime(2024, 1, 1),
        'older': DateTime(2023, 1, 1),
      },
    );
    expect(rows.map((r) => r.item.id), ['older', 'old', 'recent']);
  });

  test('does not list an item dived inside the period', () {
    final rows = _build(
      [_item('fresh')],
      lastDives: {'fresh': DateTime(2026, 3, 1)},
    );
    expect(rows, isEmpty);
  });

  test('a longer period drops what a shorter one lists', () {
    final items = [_item('a')];
    final last = {'a': DateTime(2025, 6, 1)};
    expect(_build(items, lastDives: last), hasLength(1));
    expect(
      _build(items, lastDives: last, period: IdlePeriod.twoYears),
      isEmpty,
    );
  });

  test('six months reaches further back to the cutoff than one year', () {
    final rows = _build(
      [_item('a')],
      lastDives: {'a': DateTime(2026, 3, 1)},
      period: IdlePeriod.sixMonths,
    );
    expect(rows, hasLength(1));
  });

  test('never-dived gear past the period reads null and sorts last', () {
    final rows = _build(
      [_item('never', bought: DateTime(2020)), _item('dived')],
      lastDives: {'dived': DateTime(2023, 1, 1)},
    );
    expect(rows.map((r) => r.item.id), ['dived', 'never']);
    expect(rows.last.lastDive, isNull);
    expect(rows.last.since, isNull);
  });

  test('a dive on the cutoff day is judged by its wall clock', () {
    // Flagged UTC, as stored: the cutoff is the calendar day, whatever the
    // device's offset.
    expect(
      _build([_item('a')], lastDives: {'a': DateTime.utc(2025, 10, 31, 0, 30)}),
      isEmpty,
    );
    expect(
      _build(
        [_item('a')],
        lastDives: {'a': DateTime.utc(2025, 10, 30, 23, 30)},
      ),
      hasLength(1),
    );
  });

  test('never-dived gear bought last week is not idle', () {
    expect(_build([_item('new', bought: DateTime(2026, 10, 24))]), isEmpty);
  });

  test('falls back to createdAt with no purchase date', () {
    expect(_build([_item('a', created: DateTime(2026, 10, 1))]), isEmpty);
    expect(_build([_item('a', created: DateTime(2020))]), hasLength(1));
  });

  test('a root with no dives of its own goes by its latest part', () {
    final items = [
      _item('set', bought: DateTime(2020)),
      _item('first', parent: 'set'),
      _item('second', parent: 'set'),
    ];
    expect(
      _build(
        items,
        lastDives: {
          'first': DateTime(2026, 9, 1),
          'second': DateTime(2020, 1, 1),
        },
      ),
      isEmpty,
    );

    final idle = _build(items, lastDives: {'first': DateTime(2023, 1, 1)});
    expect(idle.single.lastDive, DateTime(2023, 1, 1));
  });

  test('a part dived after the root has the root in the water', () {
    final items = [
      _item('set', bought: DateTime(2020)),
      _item('first', parent: 'set'),
    ];
    expect(
      _build(
        items,
        lastDives: {'set': DateTime(2023, 1, 1), 'first': DateTime(2026, 9, 1)},
      ),
      isEmpty,
    );
  });

  test('a part of gear the diver has let go stands on its own', () {
    final rows = _build(
      [
        _item('sold', status: EquipmentStatus.sold, bought: DateTime(2020)),
        _item('second', parent: 'sold', bought: DateTime(2020)),
      ],
      lastDives: {'second': DateTime(2023, 1, 1)},
    );
    expect(rows.map((r) => r.item.id), ['second']);
  });

  test('a part stays under a parent the diver still holds', () {
    final rows = _build(
      [
        _item('spare', status: EquipmentStatus.spare),
        _item('second', parent: 'spare', bought: DateTime(2020)),
      ],
      lastDives: {'second': DateTime(2023, 1, 1)},
    );
    expect(rows, isEmpty);
  });

  test('a shared part keeps both of its assemblies in use', () {
    final items = [
      _item('a', bought: DateTime(2020)),
      _item('b', bought: DateTime(2020)),
      _item('part', parent: 'a'),
    ];
    final index = ComponentsIndex.fromRows([
      for (final parent in ['a', 'b'])
        EquipmentComponent(
          id: parent,
          parentEquipmentId: parent,
          componentEquipmentId: 'part',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
    ]);
    expect(
      _build(items, lastDives: {'part': DateTime(2026, 9, 1)}, index: index),
      isEmpty,
    );
  });

  test('gear last dived together falls to the name', () {
    final rows = _build(
      [_item('c'), _item('a'), _item('b')],
      lastDives: {
        'c': DateTime(2024, 1, 1),
        'a': DateTime(2024, 1, 1),
        'b': DateTime(2024, 1, 1),
      },
    );
    expect(rows.map((r) => r.item.id), ['a', 'b', 'c']);
  });

  test('the cutoff stops at the end of a shorter month', () {
    final aug31 = DateTime(2026, 8, 31);
    expect(
      _build(
        [_item('a')],
        lastDives: {'a': DateTime(2026, 3, 1)},
        period: IdlePeriod.sixMonths,
        now: aug31,
      ),
      isEmpty,
    );
    expect(
      _build(
        [_item('a')],
        lastDives: {'a': DateTime(2026, 2, 27)},
        period: IdlePeriod.sixMonths,
        now: aug31,
      ),
      hasLength(1),
    );
  });

  test('a leap day cutoff lands on the last day of February', () {
    expect(
      _build(
        [_item('a')],
        lastDives: {'a': DateTime(2027, 3, 1)},
        now: DateTime(2028, 2, 29),
      ),
      isEmpty,
    );
  });

  test('never-dived gear of unknown age is not called idle', () {
    expect(_build([_item('a')]), isEmpty);
  });

  test('since is whole years and months between last dive and now', () {
    final rows = _build([_item('a')], lastDives: {'a': DateTime(2024, 6, 30)});
    expect(rows.single.since, (years: 2, months: 4));
  });

  test('a day short of a whole month does not round up', () {
    final rows = _build([_item('a')], lastDives: {'a': DateTime(2024, 11, 1)});
    expect(rows.single.since, (years: 1, months: 11));
  });
}
