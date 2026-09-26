import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_ownership_event.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_share.dart';

/// The share and ownership event value types (issue #2046).
void main() {
  final t = DateTime(2026, 9, 1);

  group('EquipmentShare', () {
    final share = EquipmentShare(
      id: 's1',
      equipmentId: 'bcd',
      diverId: 'wife',
      createdAt: t,
    );

    test('copyWith replaces only the given fields', () {
      final moved = share.copyWith(diverId: 'son');
      expect(moved.diverId, 'son');
      expect(moved.id, 's1');
      expect(moved.equipmentId, 'bcd');
      expect(moved.createdAt, t);
      expect(share.copyWith(), share);
    });

    test('equality is by value', () {
      expect(
        share,
        EquipmentShare(
          id: 's1',
          equipmentId: 'bcd',
          diverId: 'wife',
          createdAt: t,
        ),
      );
      expect(share == share.copyWith(id: 's2'), isFalse);
    });
  });

  group('EquipmentOwnershipEvent', () {
    final event = EquipmentOwnershipEvent(
      id: 'e1',
      equipmentId: 'bcd',
      kind: EquipmentOwnershipEventKind.shared,
      fromDiverId: 'owner',
      toDiverId: 'wife',
      occurredAt: t,
    );

    test('copyWith replaces only the given fields', () {
      final unshared = event.copyWith(
        id: 'e2',
        kind: EquipmentOwnershipEventKind.unshared,
        occurredAt: DateTime(2026, 9, 2),
      );
      expect(unshared.kind, EquipmentOwnershipEventKind.unshared);
      expect(unshared.id, 'e2');
      expect(unshared.fromDiverId, 'owner');
      expect(unshared.toDiverId, 'wife');
      expect(unshared.equipmentId, 'bcd');
      expect(event.copyWith(), event);
      expect(
        event.copyWith(equipmentId: 'reg', fromDiverId: 'x', toDiverId: 'y'),
        isNot(event),
      );
    });

    test('kinds round-trip by name and an unknown name reads as null', () {
      for (final kind in EquipmentOwnershipEventKind.values) {
        expect(EquipmentOwnershipEventKind.fromName(kind.name), kind);
      }
      expect(EquipmentOwnershipEventKind.fromName('lent'), isNull);
    });
  });
}
