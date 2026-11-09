import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_tank_ref_router.dart';

/// Shearwater Cloud's `<tankdata>` carry no id, so a sample's
/// `<tankpressure ref="T2">` has to be tied to its cylinder some other way
/// (issue #4347).
void main() {
  List<Map<String, dynamic>> tanks(List<double> starts) => [
    for (final s in starts) <String, dynamic>{'startPressure': s},
  ];

  test('ties each ref to the cylinder whose begin pressure equals its first '
      'reading', () {
    final list = tanks([132.93, 147.27]);
    final router = UddfTankRefRouter(list);

    expect(router.indexFor('T3', 147.27), 1);
    expect(router.indexFor('T2', 132.93), 0);
    router.writeSlots();

    expect(list[0][kUddfSourceSlotKey], 2);
    expect(list[1][kUddfSourceSlotKey], 3);
  });

  test('a repeated ref returns the index it was first given', () {
    final router = UddfTankRefRouter(tanks([132.93, 147.27]));

    final first = router.indexFor('T2', 147.27);

    expect(router.indexFor('T2', 100.0), first);
  });

  test('an ambiguous pressure gives no slot and falls back to first-seen '
      'order', () {
    final list = tanks([200.0, 200.0]);
    final router = UddfTankRefRouter(list);

    expect(router.indexFor('T2', 200.0), 0);
    expect(router.indexFor('T1', 200.0), 1);
    router.writeSlots();

    expect(list[0].containsKey(kUddfSourceSlotKey), isFalse);
    expect(list[1].containsKey(kUddfSourceSlotKey), isFalse);
  });

  test('a ref that names no T slot routes but records no slot', () {
    final list = tanks([132.93, 147.27]);
    final router = UddfTankRefRouter(list);

    expect(router.indexFor('tank_a', 147.27), 1);
    router.writeSlots();

    expect(list[1].containsKey(kUddfSourceSlotKey), isFalse);
  });

  test('slot refs are read case-insensitively and trimmed', () {
    final list = tanks([132.93]);
    final router = UddfTankRefRouter(list);

    router.indexFor(' t4 ', 132.93);
    router.writeSlots();

    expect(list[0][kUddfSourceSlotKey], 4);
  });

  test('more refs than cylinders returns null for the extra ref', () {
    final router = UddfTankRefRouter(tanks([132.93]));

    expect(router.indexFor('T1', 132.93), 0);
    expect(router.indexFor('T2', 147.27), isNull);
  });

  test('a cylinder with a UDDF id is never a fallback target', () {
    final list = [
      <String, dynamic>{'startPressure': 147.27, 'uddfTankId': 'tank_a'},
      <String, dynamic>{'startPressure': 132.93},
    ];
    final router = UddfTankRefRouter(list);

    expect(router.indexFor('T1', 147.27), 1);
    router.writeSlots();

    expect(list[0].containsKey(kUddfSourceSlotKey), isFalse);
    expect(list[1].containsKey(kUddfSourceSlotKey), isFalse);
  });

  test('a ref spelled differently later is still the same ref', () {
    final router = UddfTankRefRouter(tanks([132.93, 147.27]));

    final first = router.indexFor('T2', 132.93);

    expect(router.indexFor(' t2 ', 120.0), first);
    expect(router.indexFor('T3', 147.27), 1);
  });
}
