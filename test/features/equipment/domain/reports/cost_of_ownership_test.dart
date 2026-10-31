import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/reports/cost_of_ownership.dart';

EquipmentItem _item(
  String id, {
  double? price,
  String currency = 'USD',
  DateTime? bought,
  String? parent,
  String? diverId = 'me',
  EquipmentStatus status = EquipmentStatus.active,
}) => EquipmentItem(
  id: id,
  diverId: diverId,
  name: id,
  type: EquipmentType.regulator,
  purchasePrice: price,
  purchaseCurrency: currency,
  purchaseDate: bought,
  parentEquipmentId: parent,
  status: status,
);

ServiceRecord _record(
  String equipmentId, {
  double? cost,
  String currency = 'USD',
  DateTime? date,
}) => ServiceRecord(
  id: 'r-$equipmentId-$cost',
  equipmentId: equipmentId,
  serviceCategory: ServiceCategory.annual,
  serviceDate: date ?? DateTime(2024, 6, 1),
  cost: cost,
  currency: currency,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

CostOfOwnership _build(
  List<EquipmentItem> items, {
  Map<String, List<ServiceRecord>> records = const {},
  Map<String, GearUsageTotals> usage = const {},
  int totalDives = 100,
  String? diverId = 'me',
  String fallback = 'USD',
}) => buildCostOfOwnership(
  items: items,
  recordsByItem: records,
  usage: usage,
  totalDives: totalDives,
  diverId: diverId,
  fallbackCurrency: fallback,
);

void main() {
  test('item cost is price plus service costs, in each currency', () {
    final report = _build(
      [_item('reg', price: 1000)],
      records: {
        'reg': [_record('reg', cost: 145), _record('reg')],
      },
    );
    final usd = report.byCurrency.single;
    expect(usd.currency, 'USD');
    expect(usd.total, 1145);
    expect(usd.rows.single.cost, 1145);
  });

  test('a part rolls into its parent row, and the total is unchanged', () {
    final report = _build(
      [_item('set', price: 1290), _item('first', price: 300, parent: 'set')],
      records: {
        'first': [_record('first', cost: 145), _record('first', cost: 130)],
      },
      usage: {'set': const GearUsageTotals(diveCount: 340, hours: 400)},
    );
    final row = report.byCurrency.single.rows.single;
    expect(row.item.id, 'set');
    expect(row.cost, 1865);
    expect(row.diveCount, 340);
    expect(report.byCurrency.single.total, 1865);
  });

  test('a root with no dives of its own takes its busiest part', () {
    final row = _build(
      [
        _item('set', price: 100),
        _item('first', parent: 'set'),
        _item('second', parent: 'set'),
      ],
      usage: {
        'first': const GearUsageTotals(diveCount: 40, hours: 50),
        'second': const GearUsageTotals(diveCount: 10, hours: 12),
      },
    ).byCurrency.single.rows.single;

    expect(row.diveCount, 40);
    expect(row.hours, 50);
  });

  test('a root with its own dives keeps them over a busier part', () {
    final row = _build(
      [_item('set', price: 100), _item('first', parent: 'set')],
      usage: {
        'set': const GearUsageTotals(diveCount: 5, hours: 6),
        'first': const GearUsageTotals(diveCount: 40, hours: 50),
      },
    ).byCurrency.single.rows.single;

    expect(row.diveCount, 5);
  });

  test('a part whose parent is not ever owned keeps its own row', () {
    final report = _build([
      _item('first', price: 300, parent: 'wish'),
      _item('wish', price: 900, status: EquipmentStatus.wanted),
    ]);
    expect(report.byCurrency.single.rows.single.item.id, 'first');
    expect(report.byCurrency.single.total, 300);
  });

  test('wishlist gear counts nowhere, sold gear counts', () {
    final report = _build([
      _item('wish', price: 900, status: EquipmentStatus.wanted),
      _item('sold', price: 200, status: EquipmentStatus.sold),
    ]);
    expect(report.byCurrency.single.total, 200);
    expect(report.leftOutCount, 0);
  });

  test('shared gear counts nowhere', () {
    final report = _build([_item('theirs', price: 500, diverId: 'them')]);
    expect(report.byCurrency, isEmpty);
    expect(report.leftOutCount, 0);
  });

  test('price in USD and service in EUR gives a row under each', () {
    final report = _build(
      [_item('reg', price: 1000)],
      records: {
        'reg': [_record('reg', cost: 90, currency: 'EUR')],
      },
    );
    expect(report.byCurrency.map((c) => c.currency), ['USD', 'EUR']);
    expect(report.byCurrency[0].rows.single.cost, 1000);
    expect(report.byCurrency[1].rows.single.cost, 90);
  });

  test('usd, " USD" and blank with default USD land in one bucket', () {
    final report = _build([
      _item('a', price: 1, currency: 'usd'),
      _item('b', price: 2, currency: ' USD'),
      _item('c', price: 3, currency: ''),
    ]);
    expect(report.byCurrency.single.currency, 'USD');
    expect(report.byCurrency.single.total, 6);
  });

  test('years run first to last with a zero bar for an empty middle year', () {
    final report = _build(
      [_item('reg', price: 1000, bought: DateTime(2022, 3))],
      records: {
        'reg': [_record('reg', cost: 100, date: DateTime(2024, 2))],
      },
    );
    expect(report.byCurrency.single.byYear, [
      (year: 2022, amount: 1000.0),
      (year: 2023, amount: 0.0),
      (year: 2024, amount: 100.0),
    ]);
  });

  test('a price with no date is in the total, not the bars, and counted', () {
    final report = _build([_item('reg', price: 1000)]);
    final usd = report.byCurrency.single;
    expect(usd.total, 1000);
    expect(usd.byYear, isEmpty);
    expect(usd.undatedPurchases, 1);
  });

  test('headline per dive divides by total dives, null at zero dives', () {
    expect(
      _build([
        _item('a', price: 500),
      ], totalDives: 100).byCurrency.single.perDive,
      5,
    );
    expect(
      _build([_item('a', price: 500)], totalDives: 0).byCurrency.single.perDive,
      isNull,
    );
  });

  test('per dive sort puts no-dive rows last', () {
    final rows = _build(
      [_item('unused', price: 9000), _item('used', price: 100)],
      usage: {'used': const GearUsageTotals(diveCount: 10, hours: 8)},
    ).byCurrency.single.rows;
    expect(sortCostRows(rows, CostMetric.perDive).map((r) => r.item.id), [
      'used',
      'unused',
    ]);
  });

  test('dives with zero hours sort last under per hour, perHour is null', () {
    final rows = _build(
      [_item('notime', price: 9000), _item('timed', price: 100)],
      usage: {
        'notime': const GearUsageTotals(diveCount: 5, hours: 0),
        'timed': const GearUsageTotals(diveCount: 5, hours: 10),
      },
    ).byCurrency.single.rows;
    final sorted = sortCostRows(rows, CostMetric.perHour);
    expect(sorted.map((r) => r.item.id), ['timed', 'notime']);
    expect(sorted.last.perHour, isNull);
    expect(sorted.first.perHour, 10);
  });

  test('total sort ranks by cost', () {
    final rows = _build([
      _item('small', price: 1),
      _item('big', price: 2),
    ]).byCurrency.single.rows;
    expect(sortCostRows(rows, CostMetric.total).map((r) => r.item.id), [
      'big',
      'small',
    ]);
  });

  test('per dive ties keep a stable order by name', () {
    final rows = _build(
      [_item('zed', price: 100), _item('abe', price: 100)],
      usage: {
        'zed': const GearUsageTotals(diveCount: 10, hours: 1),
        'abe': const GearUsageTotals(diveCount: 10, hours: 1),
      },
    ).byCurrency.single.rows;
    expect(sortCostRows(rows, CostMetric.perDive).map((r) => r.item.id), [
      'abe',
      'zed',
    ]);
  });

  test('an item with no price and no service cost only adds to leftOut', () {
    final report = _build([
      _item('priced', price: 10),
      _item('bare'),
      _item('part', parent: 'bare'),
    ]);
    expect(report.byCurrency.single.rows.map((r) => r.item.id), ['priced']);
    expect(report.leftOutCount, 1);
  });

  test('a parent loop with no cost still counts as left out', () {
    final report = _build([_item('a', parent: 'b'), _item('b', parent: 'a')]);
    expect(report.leftOutCount, 2);
  });

  test('parent loop finishes and counts each cost once', () {
    final report = _build([
      _item('a', price: 1, parent: 'b'),
      _item('b', price: 2, parent: 'a'),
    ]);
    expect(report.byCurrency.single.total, 3);
    expect(
      report.byCurrency.single.rows.fold<double>(0, (s, r) => s + r.cost),
      3,
    );
  });
}
