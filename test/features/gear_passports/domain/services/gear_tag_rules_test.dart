import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_rules.dart';

const _id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';

EquipmentItem _item({String name = 'Primary', String? brand = 'Apeks'}) =>
    EquipmentItem(
      id: 'eq',
      name: name,
      type: EquipmentType.firstStage,
      brand: brand,
      model: 'XTX50',
      serialNumber: 'AB12345',
    );

ServiceRecord _record(DateTime date) => ServiceRecord(
  id: 'r${date.millisecondsSinceEpoch}',
  equipmentId: 'eq',
  serviceCategory: ServiceCategory.annual,
  serviceDate: date,
  createdAt: date,
  updatedAt: date,
);

void main() {
  test('last service is the newest record date, as a calendar date', () {
    expect(lastServiceDate(const []), isNull);
    expect(
      lastServiceDate([
        _record(DateTime(2025, 3, 1, 15)),
        _record(DateTime(2026, 3, 2, 9, 30)),
      ]),
      DateTime(2026, 3, 2),
    );
  });

  test('the payload carries the row and the date written', () {
    final p = gearPayloadForItem(
      item: _item(),
      passportId: _id,
      now: DateTime(2026, 10, 10, 14, 5),
      lastService: DateTime(2026, 3, 2),
    );
    expect(p.passportId, _id);
    expect(p.typeCode, 'firstStage');
    expect(p.writtenOn, DateTime(2026, 10, 10));
    expect(p.name, 'Primary');
    expect(p.brand, 'Apeks');
    expect(p.model, 'XTX50');
    expect(p.serial, 'AB12345');
    expect(p.lastService, DateTime(2026, 3, 2));
  });

  test('blank text fields are left off', () {
    final p = gearPayloadForItem(
      item: _item(brand: '  '),
      passportId: _id,
      now: DateTime(2026, 10, 10),
    );
    expect(p.brand, isNull);
  });

  group('staleness', () {
    final tag = gearPayloadForItem(
      item: _item(),
      passportId: _id,
      now: DateTime(2026, 10, 10),
      lastService: DateTime(2026, 3, 2),
    );

    test('a tag that matches the row is current', () {
      expect(
        gearTagIsStale(
          tag: tag,
          item: _item(),
          lastService: DateTime(2026, 3, 2),
        ),
        isFalse,
      );
    });

    test('a service after the tag was written makes it stale', () {
      expect(
        gearTagIsStale(
          tag: tag,
          item: _item(),
          lastService: DateTime(2026, 10, 11),
        ),
        isTrue,
      );
    });

    test('a service on the day it was written does not', () {
      expect(
        gearTagIsStale(
          tag: tag,
          item: _item(),
          lastService: DateTime(2026, 10, 10),
        ),
        isFalse,
      );
    });

    test(
      'a renamed item makes it stale; a field the tag left off does not',
      () {
        expect(
          gearTagIsStale(
            tag: tag,
            item: _item(name: 'Backup'),
            lastService: null,
          ),
          isTrue,
        );
        expect(
          gearTagIsStale(
            tag: tag.copyWith(clearBrand: true),
            item: _item(),
            lastService: DateTime(2026, 3, 2),
          ),
          isFalse,
        );
      },
    );

    test('a retyped item makes it stale', () {
      const retyped = EquipmentItem(
        id: 'eq',
        name: 'Primary',
        type: EquipmentType.secondStage,
        brand: 'Apeks',
        model: 'XTX50',
        serialNumber: 'AB12345',
      );
      expect(
        gearTagIsStale(
          tag: tag,
          item: retyped,
          lastService: DateTime(2026, 3, 2),
        ),
        isTrue,
      );
    });

    test('a long name capped on the tag is not a difference', () {
      final long = 'x' * 50;
      final capped = gearPayloadForItem(
        item: _item(name: long),
        passportId: _id,
        now: DateTime(2026, 10, 10),
      );
      expect(
        gearTagIsStale(
          tag: capped,
          item: _item(name: long),
          lastService: null,
        ),
        isFalse,
      );
    });
  });
}
