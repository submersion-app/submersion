import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';

void main() {
  group('EquipmentLocationKind.fromName', () {
    test('reads every stored name', () {
      for (final kind in EquipmentLocationKind.values) {
        expect(EquipmentLocationKind.fromName(kind.name), kind);
      }
    });

    test('an unknown or missing name reads as other', () {
      expect(
        EquipmentLocationKind.fromName('vault'),
        EquipmentLocationKind.other,
      );
      expect(EquipmentLocationKind.fromName(null), EquipmentLocationKind.other);
    });
  });

  group('compareMovesNewestFirst', () {
    EquipmentLocationMove move(String id, int movedAt, int createdAt) =>
        EquipmentLocationMove(
          id: id,
          equipmentId: 'e',
          locationId: 'l',
          movedAt: DateTime.fromMillisecondsSinceEpoch(movedAt),
          note: '',
          createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
        );

    test('orders by moved_at, then created_at, then id, newest first', () {
      final moves = [
        move('a', 100, 1),
        move('c', 200, 1),
        move('b', 200, 1),
        move('d', 200, 5),
      ]..sort(compareMovesNewestFirst);
      expect([for (final m in moves) m.id], ['d', 'c', 'b', 'a']);
    });
  });

  test('copyWith can clear the location', () {
    final m = EquipmentLocationMove(
      id: 'm',
      equipmentId: 'e',
      locationId: 'l',
      movedAt: DateTime(2026),
      note: '',
      createdAt: DateTime(2026),
    );
    expect(m.copyWith(clearLocation: true).locationId, isNull);
    expect(m.copyWith(note: 'x').locationId, 'l');
  });
}
