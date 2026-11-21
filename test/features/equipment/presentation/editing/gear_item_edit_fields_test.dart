import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The gear item page's fields and the rules its form keeps (issue #4527,
/// phase 3, plan 6).
void main() {
  const regulator = EquipmentItem(
    id: 'g1',
    diverId: 'd1',
    name: 'Apex',
    type: EquipmentType.regulator,
    brand: 'Apex',
    serialNumber: 'A1',
  );

  EquipmentItem item({
    EquipmentType type = EquipmentType.regulator,
    EquipmentStatus status = EquipmentStatus.active,
    bool isActive = true,
    List<EquipmentAttribute> attributes = const [],
  }) => EquipmentItem(
    id: 'g1',
    name: 'Apex',
    type: type,
    status: status,
    isActive: isActive,
    attributes: attributes,
  );

  group('status', () {
    for (final status in [
      EquipmentStatus.retired,
      EquipmentStatus.sold,
      EquipmentStatus.wanted,
    ]) {
      test('Wanted, Retired and Sold store the item inactive: $status', () {
        final session = EditSession(regulator)..set(gearStatusField, status);

        expect(session.working.isActive, isFalse);
        expect(session.working.status, status);
        // The values a Wanted item hides are kept, not cleared.
        expect(session.working.serialNumber, 'A1');
      });
    }

    test('a purchase date stays while the item is Wanted', () {
      final session = EditSession(
        regulator.copyWith(purchaseDate: DateTime(2020, 5, 1)),
      )..set(gearStatusField, EquipmentStatus.wanted);

      expect(session.working.purchaseDate, DateTime(2020, 5, 1));
    });

    test('an owned status stores the item active', () {
      final session = EditSession(
        item(status: EquipmentStatus.retired, isActive: false),
      )..set(gearStatusField, EquipmentStatus.active);

      expect(session.working.isActive, isTrue);
    });

    test('a legacy inactive Active row shows as Retired', () {
      expect(gearShownStatus(item(isActive: false)), EquipmentStatus.retired);
      expect(
        gearShownStatus(item(status: EquipmentStatus.sold, isActive: false)),
        EquipmentStatus.sold,
      );
      expect(gearShownStatus(item()), EquipmentStatus.active);
      // A Wanted row is inactive by design, and stays Wanted.
      expect(
        gearShownStatus(item(status: EquipmentStatus.wanted, isActive: false)),
        EquipmentStatus.wanted,
      );
    });

    test('an untouched legacy status is not written', () {
      final legacy = item(isActive: false);
      final session = EditSession(legacy)..set(gearNotesField, 'Note');

      expect(session.working.isActive, isFalse);
      expect(session.working.status, EquipmentStatus.active);
    });
  });

  group('parent', () {
    const rebreather = EquipmentItem(
      id: 'r1',
      name: 'Loop',
      type: EquipmentType.rebreather,
    );
    const mask = EquipmentItem(
      id: 'm1',
      name: 'Mask',
      type: EquipmentType.mask,
    );

    test('a type the parent cannot hold clears the parent', () {
      expect(
        gearParentAfterType(EquipmentType.regulator, 'r1', const [rebreather]),
        isNull,
      );
    });

    test('a type the parent can hold keeps it', () {
      expect(
        gearParentAfterType(EquipmentType.o2Cell, 'r1', const [rebreather]),
        'r1',
      );
    });

    test('a parent is kept while the candidates load', () {
      expect(gearParentAfterType(EquipmentType.o2Cell, 'r1', null), 'r1');
      expect(gearParentAfterType(EquipmentType.mask, 'r1', null), isNull);
    });

    test('a parent that is not a candidate of the right type is dropped', () {
      expect(
        gearParentAfterType(EquipmentType.o2Cell, 'm1', const [mask]),
        isNull,
      );
    });
  });

  group('attributes', () {
    EquipmentAttribute curated(String key, {double? number, String? text}) =>
        EquipmentAttribute.curated(
          equipmentId: 'g1',
          key: key,
          valueNum: number,
          valueText: text,
        );
    EquipmentAttribute custom(String key, String value, int order) =>
        EquipmentAttribute(
          id: 'c$order',
          equipmentId: 'g1',
          key: key,
          isCustom: true,
          valueText: value,
          sortOrder: order,
        );

    test('attributes outside the new type\'s catalogue are dropped', () {
      final regulatorKey = EquipmentAttributeCatalog.attributesFor(
        EquipmentType.regulator,
      ).first.key;
      final maskKeys = {
        for (final d in EquipmentAttributeCatalog.attributesFor(
          EquipmentType.mask,
        ))
          d.key,
      };
      expect(maskKeys, isNot(contains(regulatorKey)));

      final kept = gearAttributesToSave(EquipmentType.mask, [
        curated(regulatorKey, text: 'x', number: 1),
      ], const []);

      expect(kept, isEmpty);
    });

    test('custom fields are de-duplicated by key, first wins', () {
      final kept = gearAttributesToSave(EquipmentType.regulator, const [], [
        custom(' Hose ', 'blue', 0),
        custom('Hose', 'red', 1),
        custom('Mouthpiece', 'soft', 2),
        custom('Empty', '', 3),
      ]);

      expect(
        [for (final a in kept) (a.key, a.valueText, a.sortOrder)],
        [('Hose', 'blue', 0), ('Mouthpiece', 'soft', 1)],
      );
    });

    test('a stray colour on a type without one is kept as a custom field', () {
      final withColour = item(
        type: EquipmentType.battery,
        attributes: [curated(EquipmentAttrKeys.color, text: '#FF0000')],
      );

      final custom = EditSession(withColour).valueOf(gearCustomFieldsField);

      expect(custom.single.key, EquipmentAttrKeys.color);
      expect(custom.single.isCustom, isTrue);
    });

    test('a stray colour saved after a custom field edit is one custom '
        'field', () {
      final battery = item(
        type: EquipmentType.battery,
        attributes: [curated(EquipmentAttrKeys.color, text: '#FF0000')],
      );
      final session = EditSession(battery);
      session.set(gearCustomFieldsField, [
        ...session.valueOf(gearCustomFieldsField),
        const EquipmentAttribute(
          id: 'c-note',
          equipmentId: 'g1',
          key: 'Note',
          isCustom: true,
          valueText: 'spare',
          sortOrder: 1,
        ),
      ]);

      final saved = gearItemToSave(battery, session.applyTo(battery));

      final colours = saved.attributes.where(
        (a) => a.key == EquipmentAttrKeys.color,
      );
      expect(colours, hasLength(1));
      expect(colours.single.isCustom, isTrue);
      expect(colours.single.valueText, '#FF0000');
      expect(saved.attributes.where((a) => a.key == 'Note'), hasLength(1));
    });

    test('an attribute set to none is gone from the saved item', () {
      final wetsuit = item(
        type: EquipmentType.wetsuit,
        attributes: [curated('buoyancy_kg', number: 5)],
      );
      final session = EditSession(wetsuit)
        ..set(gearAttributeField('buoyancy_kg'), null);

      final saved = gearItemToSave(wetsuit, session.applyTo(wetsuit));

      expect(saved.attrNum('buoyancy_kg'), isNull);
    });

    test('one catalogue attribute set leaves the others as stored', () {
      final keys = EquipmentAttributeCatalog.attributesFor(
        EquipmentType.regulator,
      ).map((d) => d.key).toList();
      final stored = item(attributes: [curated(keys[0], text: 'a')]);
      final session = EditSession(stored)
        ..set(gearAttributeField(keys[1]), curated(keys[1], text: 'b'));
      final newer = item(attributes: [curated(keys[0], text: 'newer')]);

      final merged = session.applyTo(newer);

      expect(merged.attrText(keys[0]), 'newer');
      expect(merged.attrText(keys[1]), 'b');
    });
  });

  group('rules', () {
    test('a name of spaces is invalid', () {
      expect(gearNameValid('   '), isFalse);
      expect(gearNameValid(''), isFalse);
      expect(gearNameValid(' Apex '), isTrue);
    });

    test('the last reminder day cannot be removed', () {
      expect(gearReminderDaysToggled(const [7], 7), [7]);
      expect(gearReminderDaysToggled(const [7, 14], 7), [14]);
      expect(gearReminderDaysToggled(const [7], 30), [7, 30]);
    });

    test('a day ticked off and on again leaves the reminder unchanged', () {
      final stored = regulator.copyWith(
        customReminderEnabled: true,
        customReminderDays: const [7, 14, 30],
      );
      final off = gearReminderDaysToggled(const [7, 14, 30], 14);
      final on = gearReminderDaysToggled(off, 14);
      final session = EditSession(stored)
        ..set(gearCustomReminderField, (enabled: true, days: on));

      expect(on, [7, 14, 30]);
      expect(session.isDirty, isFalse);
      // Stored out of order (an older build), the same days are no change.
      final unsorted = regulator.copyWith(
        customReminderEnabled: true,
        customReminderDays: const [30, 7],
      );
      final again = EditSession(unsorted)
        ..set(gearCustomReminderField, (enabled: true, days: const [7, 30]));
      expect(again.isDirty, isFalse);
    });

    test('a blank currency falls back to the default', () {
      expect(gearCurrencyOrDefault('  ', 'EUR'), 'EUR');
      expect(gearCurrencyOrDefault(' gbp ', 'EUR'), 'gbp');
    });

    test('blank optional text stores none', () {
      final session = EditSession(regulator)
        ..set(gearBrandField, '  ')
        ..set(gearSerialField, '');

      expect(session.working.brand, isNull);
      expect(session.working.serialNumber, isNull);
    });

    test('the price and its currency are one change', () {
      final session = EditSession(regulator)
        ..set(gearPriceField, (price: 120.0, currency: 'EUR'));

      expect(session.working.purchasePrice, 120);
      expect(session.working.purchaseCurrency, 'EUR');
      expect(session.changedCardIds, {'details'});
    });

    test('the custom reminder belongs to Service clocks', () {
      final session = EditSession(regulator)
        ..set(gearCustomReminderField, (enabled: true, days: const [7, 30]));

      expect(session.working.customReminderEnabled, isTrue);
      expect(session.working.customReminderDays, [7, 30]);
      expect(session.changedCardIds, {'serviceClocks'});
    });

    test('the cover belongs to Photos and can be cleared', () {
      final covered = regulator.copyWith(coverMediaId: 'p1');
      final session = EditSession(covered)..set(gearCoverField, null);

      expect(session.working.coverMediaId, isNull);
      expect(session.changedCardIds, {'photos'});
    });
  });

  group('gearItemToSave', () {
    test('an unchanged item is returned as it is', () {
      expect(
        identical(gearItemToSave(regulator, regulator), regulator),
        isTrue,
      );
    });

    test(
      'an attribute the sitting never touched survives a change elsewhere',
      () {
        // A key this build's catalogue lacks: a newer peer's, say.
        final stored = item(
          attributes: [
            EquipmentAttribute.curated(
              equipmentId: 'g1',
              key: 'from_a_newer_build',
              valueText: 'kept',
            ),
          ],
        );
        final merged = (EditSession(
          stored,
        )..set(gearNotesField, 'Rinse')).applyTo(stored);

        final saved = gearItemToSave(stored, merged);

        expect(saved.attrText('from_a_newer_build'), 'kept');
      },
    );

    test('custom fields edited are de-duplicated, the rest kept', () {
      final stored = item(
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: 'g1',
            key: 'from_a_newer_build',
            valueText: 'kept',
          ),
        ],
      );
      final session = EditSession(stored)
        ..set(gearCustomFieldsField, const [
          EquipmentAttribute(
            id: '',
            equipmentId: 'g1',
            key: 'Hose',
            isCustom: true,
            valueText: 'blue',
          ),
          EquipmentAttribute(
            id: '',
            equipmentId: 'g1',
            key: 'Hose ',
            isCustom: true,
            valueText: 'red',
            sortOrder: 1,
          ),
        ]);

      final saved = gearItemToSave(stored, session.applyTo(stored));

      expect(saved.attrText('from_a_newer_build'), 'kept');
      expect(saved.attributes.where((a) => a.isCustom), hasLength(1));
    });

    test('a changed item keeps only its type\'s catalogue attributes', () {
      final key = EquipmentAttributeCatalog.attributesFor(
        EquipmentType.regulator,
      ).first.key;
      final stored = item(
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: 'g1',
            key: key,
            valueText: 'x',
          ),
        ],
      );
      final merged = EditSession(stored)
        ..set(gearTypeField, EquipmentType.mask);

      final saved = gearItemToSave(stored, merged.applyTo(stored));

      expect(saved.type, EquipmentType.mask);
      expect(saved.attributes.where((a) => a.key == key), isEmpty);
    });
  });
}
