import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/models/equipment_default_view.dart';

/// The stored form of the diver's default equipment view (issue #2628).
void main() {
  test('the factory default is every status but retired, sold and wanted', () {
    expect(factoryDefaultEquipmentStatuses, {
      EquipmentStatus.active,
      EquipmentStatus.spare,
      EquipmentStatus.needsService,
      EquipmentStatus.inService,
      EquipmentStatus.loaned,
      EquipmentStatus.lost,
    });
    expect(
      isFactoryDefaultEquipmentStatuses({...factoryDefaultEquipmentStatuses}),
      isTrue,
    );
    expect(
      isFactoryDefaultEquipmentStatuses({EquipmentStatus.active}),
      isFalse,
    );
  });

  group('encode', () {
    test('the factory set and the empty set store nothing', () {
      expect(
        encodeEquipmentDefaultStatuses(factoryDefaultEquipmentStatuses),
        isNull,
      );
      expect(encodeEquipmentDefaultStatuses(const {}), isNull);
    });

    test('a custom set stores its names in enum order', () {
      expect(
        encodeEquipmentDefaultStatuses({
          EquipmentStatus.lost,
          EquipmentStatus.active,
        }),
        '["active","lost"]',
      );
    });
  });

  group('decode', () {
    test('null reads as the factory default', () {
      expect(
        decodeEquipmentDefaultStatuses(null),
        factoryDefaultEquipmentStatuses,
      );
      expect(tryDecodeEquipmentDefaultStatuses(null), isNull);
    });

    test('a custom set round-trips', () {
      final set = {EquipmentStatus.active, EquipmentStatus.retired};
      expect(
        decodeEquipmentDefaultStatuses(encodeEquipmentDefaultStatuses(set)),
        set,
      );
    });

    test('a decoded set cannot be changed in place', () {
      final set = decodeEquipmentDefaultStatuses('["active"]');
      expect(() => set.add(EquipmentStatus.lost), throwsUnsupportedError);
    });

    test('unknown names from a newer build are dropped', () {
      expect(decodeEquipmentDefaultStatuses('["active","hovercraft"]'), {
        EquipmentStatus.active,
      });
    });

    test('a value naming no known status reads as the factory default', () {
      for (final raw in ['["hovercraft"]', '[]', '[1, 2]']) {
        expect(tryDecodeEquipmentDefaultStatuses(raw), isNull, reason: raw);
        expect(
          decodeEquipmentDefaultStatuses(raw),
          factoryDefaultEquipmentStatuses,
          reason: raw,
        );
      }
    });

    test('unreadable JSON and non-lists read as the factory default', () {
      for (final raw in ['not json', '{"active": true}', '"active"', '']) {
        expect(
          decodeEquipmentDefaultStatuses(raw),
          factoryDefaultEquipmentStatuses,
          reason: raw,
        );
      }
    });
  });
}
