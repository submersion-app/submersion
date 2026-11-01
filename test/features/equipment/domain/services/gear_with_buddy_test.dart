import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/equipment/domain/services/gear_with_buddy.dart';

void main() {
  EquipmentLocation place(
    String id, {
    String? buddyId,
    bool archived = false,
    EquipmentLocationKind kind = EquipmentLocationKind.person,
  }) => EquipmentLocation(
    id: id,
    name: id,
    kind: kind,
    buddyId: buddyId,
    isArchived: archived,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  EquipmentItem item(String id, String name) =>
      EquipmentItem(id: id, name: name, type: EquipmentType.bcd);

  EquipmentLocationMove move(String id, String? locationId) =>
      EquipmentLocationMove(
        id: id,
        equipmentId: 'item',
        locationId: locationId,
        movedAt: DateTime(2026),
        createdAt: DateTime(2026),
      );

  group('gearWithBuddy', () {
    final hers = place('hers', buddyId: 'anna');
    final old = place('old', buddyId: 'anna', archived: true);
    final his = place('his', buddyId: 'sam');

    test('lists gear at places linked to the buddy, by item name', () {
      final rows = gearWithBuddy(
        'anna',
        [item('z', 'Zip bag'), item('a', 'Apeks reg'), item('s', 'Sam fins')],
        {'z': hers, 'a': hers, 's': his},
      );
      expect(rows.map((r) => r.item.id), ['a', 'z']);
      expect(rows.first.place, hers);
    });

    test('counts an archived place: the gear is still with them', () {
      final rows = gearWithBuddy('anna', [item('a', 'A')], {'a': old});
      expect(rows.single.place, old);
    });

    test('leaves out gear with no current place', () {
      expect(gearWithBuddy('anna', [item('a', 'A')], const {}), isEmpty);
    });
  });

  group('placeBeforeLoan', () {
    final shelf = place('shelf', kind: EquipmentLocationKind.storage);
    final hers = place('hers', buddyId: 'anna');
    final alsoHers = place('alsoHers', buddyId: 'anna');
    final his = place('his', buddyId: 'sam');
    final places = {
      for (final p in [shelf, hers, alsoHers, his]) p.id: p,
    };

    test('is the newest move at a place not linked to the buddy', () {
      expect(
        placeBeforeLoan(
          [move('3', 'hers'), move('2', 'shelf'), move('1', 'his')],
          places,
          'anna',
        ),
        shelf,
      );
    });

    test('skips every place linked to the buddy', () {
      expect(
        placeBeforeLoan(
          [move('3', 'hers'), move('2', 'alsoHers'), move('1', 'shelf')],
          places,
          'anna',
        ),
        shelf,
      );
    });

    test('is another buddy\'s place when the gear came from them', () {
      expect(
        placeBeforeLoan([move('2', 'hers'), move('1', 'his')], places, 'anna'),
        his,
      );
    });

    test('is null when the move before was a cleared location', () {
      expect(
        placeBeforeLoan(
          [move('3', 'hers'), move('2', null), move('1', 'shelf')],
          places,
          'anna',
        ),
        isNull,
      );
    });

    test('is null with no move before the loan', () {
      expect(placeBeforeLoan([move('1', 'hers')], places, 'anna'), isNull);
    });

    test('is null when that place was archived since', () {
      final archived = place(
        'locker',
        kind: EquipmentLocationKind.storage,
        archived: true,
      );
      expect(
        placeBeforeLoan(
          [move('2', 'hers'), move('1', 'locker')],
          {...places, 'locker': archived},
          'anna',
        ),
        isNull,
      );
    });

    test('is null when that place is gone', () {
      expect(
        placeBeforeLoan(
          [move('2', 'hers'), move('1', 'deleted')],
          places,
          'anna',
        ),
        isNull,
      );
    });
  });

  group('notBeforeCurrentMove', () {
    final loan = DateTime(2026, 10, 12, 14);

    test('holds an earlier time at the current move', () {
      expect(notBeforeCurrentMove(DateTime(2026, 10, 12, 12), loan), loan);
    });

    test('keeps a later time', () {
      final later = DateTime(2026, 10, 13);
      expect(notBeforeCurrentMove(later, loan), later);
    });
  });
}
