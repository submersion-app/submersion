import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// The firmware fields of electronic gear (issue #5104): their own group,
/// so the Firmware card shows them rather than the Details spec rows.
void main() {
  const firmwareTypes = {
    EquipmentType.computer,
    EquipmentType.transmitter,
    EquipmentType.rebreather,
    EquipmentType.dpv,
    EquipmentType.light,
    EquipmentType.camera,
    EquipmentType.housing,
    EquipmentType.strobe,
  };

  test('exactly the electronic types carry firmware', () {
    for (final type in EquipmentType.values) {
      expect(
        EquipmentAttributeCatalog.hasFirmware(type),
        firmwareTypes.contains(type),
        reason: type.name,
      );
    }
  });

  test('a firmware type offers the version and the page link', () {
    final defs = {
      for (final d in EquipmentAttributeCatalog.attributesFor(
        EquipmentType.dpv,
      ))
        d.key: d,
    };
    expect(defs[EquipmentAttrKeys.firmwareVersion]!.kind, AttributeKind.text);
    expect(defs[EquipmentAttrKeys.firmwarePageUrl]!.kind, AttributeKind.url);
    expect(
      defs[EquipmentAttrKeys.firmwareVersion]!.group,
      AttributeGroup.firmware,
    );
    expect(
      defs[EquipmentAttrKeys.firmwarePageUrl]!.group,
      AttributeGroup.firmware,
    );

    final fins = EquipmentAttributeCatalog.attributesFor(EquipmentType.fins);
    expect(fins.map((d) => d.key), isNot(contains('firmware_version')));
    expect(fins.map((d) => d.key), isNot(contains('firmware_page_url')));
  });

  test('the keys are curated, so a custom field of that name is not them', () {
    expect(
      EquipmentAttributeCatalog.defFor('firmware_version')?.group,
      AttributeGroup.firmware,
    );

    const item = EquipmentItem(
      id: 'perdix',
      name: 'Perdix 2',
      type: EquipmentType.computer,
      attributes: [
        EquipmentAttribute(
          id: 'attr_perdix_firmware_version',
          equipmentId: 'perdix',
          key: 'firmware_version',
          valueText: 'V92',
        ),
        EquipmentAttribute(
          id: 'attr_perdix_firmware_page_url',
          equipmentId: 'perdix',
          key: 'firmware_page_url',
          valueText: 'shearwater.com/firmware',
        ),
      ],
    );
    expect(item.firmwareVersion, 'V92');
    expect(item.firmwarePageUrl, 'shearwater.com/firmware');

    const custom = EquipmentItem(
      id: 'light',
      name: 'Light',
      type: EquipmentType.light,
      attributes: [
        EquipmentAttribute(
          id: 'c1',
          equipmentId: 'light',
          key: 'firmware_version',
          isCustom: true,
          valueText: '1.0',
        ),
      ],
    );
    expect(custom.firmwareVersion, isNull);
  });

  test('no type shows firmware among its spec rows', () {
    for (final type in EquipmentType.values) {
      final specKeys = EquipmentAttributeCatalog.attributesFor(
        type,
      ).where((d) => d.group == AttributeGroup.spec).map((d) => d.key);
      expect(specKeys, isNot(contains('firmware_version')), reason: type.name);
    }
  });
}
