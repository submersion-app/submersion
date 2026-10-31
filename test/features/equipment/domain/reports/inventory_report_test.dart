import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/reports/inventory_report.dart';

EquipmentItem _item(
  String id, {
  EquipmentType type = EquipmentType.regulator,
  double? price,
  String currency = 'USD',
  String? parent,
  EquipmentStatus status = EquipmentStatus.active,
  String? diverId = 'me',
}) => EquipmentItem(
  id: id,
  diverId: diverId,
  name: id,
  type: type,
  purchasePrice: price,
  purchaseCurrency: currency,
  parentEquipmentId: parent,
  status: status,
);

EquipmentLocation _place(
  String id, {
  EquipmentLocationKind kind = EquipmentLocationKind.storage,
}) => EquipmentLocation(
  id: id,
  name: id,
  kind: kind,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

InventoryReport _build(
  List<EquipmentItem> items, {
  Map<String, EquipmentLocation> locations = const {},
  InventoryReportOptions options = const InventoryReportOptions(),
}) => buildInventoryReport(
  items: items,
  locations: locations,
  options: options,
  diverId: 'me',
  fallbackCurrency: 'USD',
);

void main() {
  test('groups by type in enum order, with a subtotal per currency', () {
    final report = _build([
      _item('wing', type: EquipmentType.bcd, price: 840),
      _item('reg', price: 1000),
      _item('reg2', price: 100, currency: 'EUR'),
    ]);

    expect(report.groups.map((g) => g.type), [
      EquipmentType.regulator,
      EquipmentType.bcd,
    ]);
    final regs = report.groups.first;
    expect(regs.subtotals.map((e) => (e.key, e.value)), [
      ('USD', 1000.0),
      ('EUR', 100.0),
    ]);
  });

  test('sorts rows by name inside a group', () {
    final report = _build([_item('zed'), _item('abe')]);
    expect(report.groups.single.rows.map((r) => r.item.id), ['abe', 'zed']);
  });

  test('leaves out gear not owned now', () {
    final report = _build([
      _item('keep'),
      _item('gone', status: EquipmentStatus.sold),
      _item('theirs', diverId: 'them'),
    ]);
    expect(report.itemCount, 1);
  });

  test('groups by location, kinds in order, with No location set last', () {
    final report = _build(
      [_item('a'), _item('b'), _item('c')],
      locations: {
        'a': _place('Shop', kind: EquipmentLocationKind.serviceShop),
        'b': _place('Garage'),
      },
      options: const InventoryReportOptions(
        grouping: InventoryGrouping.location,
      ),
    );

    expect(report.groups.map((g) => g.location?.name), [
      'Garage',
      'Shop',
      null,
    ]);
  });

  test('a part stays under its parent even when its own place differs', () {
    final report = _build(
      [_item('set'), _item('first', parent: 'set')],
      locations: {'set': _place('Garage'), 'first': _place('Shop')},
      options: const InventoryReportOptions(
        grouping: InventoryGrouping.location,
      ),
    );

    final group = report.groups.single;
    expect(group.location?.name, 'Garage');
    expect(group.rows.map((r) => (r.item.id, r.depth)), [
      ('set', 0),
      ('first', 1),
    ]);
  });

  test('a location filter keeps top-level items there and their parts', () {
    final bag = _place('Bag');
    final report = _build(
      [_item('set'), _item('first', parent: 'set'), _item('other')],
      locations: {'set': bag, 'other': _place('Garage')},
      options: const InventoryReportOptions(locationId: 'Bag'),
    );

    expect(report.groups.single.rows.map((r) => r.item.id), ['set', 'first']);
    expect(report.itemCount, 2);
  });

  test('a part counts in the item count and its price in the totals', () {
    final report = _build([
      _item('set', price: 1000),
      _item('first', price: 300, parent: 'set'),
    ]);
    expect(report.itemCount, 2);
    expect(report.totals.single.value, 1300);
  });

  test('a parent price stays its own', () {
    final report = _build([
      _item('set', price: 1000),
      _item('first', price: 300, parent: 'set'),
    ]);
    expect(report.groups.single.rows.first.item.purchasePrice, 1000);
  });

  test('an orphan part is a top-level row', () {
    final report = _build([
      _item('first', parent: 'gone'),
      _item('gone', status: EquipmentStatus.sold),
    ]);
    expect(report.groups.single.rows.single.depth, 0);
  });

  test('unpriced count covers top-level rows only, not parts', () {
    final report = _build([
      _item('set'),
      _item('hose', parent: 'set'),
      _item('priced', price: 5),
    ]);
    expect(report.unpricedCount, 1);
  });

  test('mixed currency codes merge', () {
    final report = _build([
      _item('a', price: 1, currency: 'usd'),
      _item('b', price: 2, currency: ' USD'),
      _item('c', price: 3, currency: ''),
    ]);
    expect(report.totals.single.key, 'USD');
    expect(report.totals.single.value, 6);
  });

  test('an empty location gives an empty report', () {
    final report = _build([
      _item('a'),
    ], options: const InventoryReportOptions(locationId: 'nowhere'));
    expect(report.isEmpty, isTrue);
  });

  test('options compare by value', () {
    expect(
      const InventoryReportOptions(showPrices: false),
      const InventoryReportOptions(showPrices: false),
    );
  });
}
