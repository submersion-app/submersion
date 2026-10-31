import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/reports/idle_gear.dart';

final _now = DateTime(2026, 10, 31);

EquipmentItem _item(String id, {DateTime? bought, DateTime? created}) =>
    EquipmentItem(
      id: id,
      diverId: 'me',
      name: id,
      type: EquipmentType.mask,
      purchaseDate: bought,
      createdAt: created,
    );

List<IdleRow> _build(
  List<EquipmentItem> items, {
  Map<String, DateTime> lastDives = const {},
  IdlePeriod period = IdlePeriod.oneYear,
}) => buildIdleGear(
  items: items,
  lastDives: lastDives,
  diverId: 'me',
  period: period,
  now: _now,
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

  test('since is whole years and months between last dive and now', () {
    final rows = _build([_item('a')], lastDives: {'a': DateTime(2024, 6, 30)});
    expect(rows.single.since, (years: 2, months: 4));
  });

  test('a day short of a whole month does not round up', () {
    final rows = _build([_item('a')], lastDives: {'a': DateTime(2024, 11, 1)});
    expect(rows.single.since, (years: 1, months: 11));
  });
}
