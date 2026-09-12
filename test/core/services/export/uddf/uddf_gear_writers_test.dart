import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_gear_writers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';

XmlElement _write(void Function(XmlBuilder builder) body) {
  final builder = XmlBuilder();
  builder.element('root', nest: () => body(builder));
  return builder.buildDocument().rootElement;
}

const _reg = EquipmentItem(
  id: 'reg',
  name: 'Reg',
  type: EquipmentType.regulator,
);
const _bcd = EquipmentItem(id: 'bcd', name: 'BCD', type: EquipmentType.bcd);

Dive _dive(
  String id, {
  String? model,
  String? serial,
  List<EquipmentItem> gear = const [],
}) => Dive(
  id: id,
  dateTime: DateTime(2026, 3, 1),
  diveComputerModel: model,
  diveComputerSerial: serial,
  gear: looseGear(gear),
);

void main() {
  test('computerIds is one id per distinct computer, first seen first', () {
    expect(
      UddfGearWriters.computerIds([
        _dive('a', model: 'Perdix AI', serial: 'SN1'),
        _dive('b'),
        _dive('c', model: 'Teric'),
        _dive('d', model: 'Perdix AI', serial: 'SN1'),
      ]).toList(),
      ['dc_Perdix_AI_SN1', 'dc_Teric_unknown'],
    );
  });

  test('writeOwnerComputers declares each computer and returns the ids', () {
    late Set<String> declared;
    final root = _write(
      (b) => declared = UddfGearWriters.writeOwnerComputers(b, [
        _dive('a', model: 'Perdix AI', serial: 'SN1'),
        _dive('b', model: 'Teric'),
      ]),
    );
    final computers = root
        .findElements('equipment')
        .single
        .findElements('divecomputer')
        .toList();
    expect(computers.map((e) => e.getAttribute('id')), [
      'dc_Perdix_AI_SN1',
      'dc_Teric_unknown',
    ]);
    expect(computers.first.findElements('model').single.innerText, 'Perdix AI');
    expect(
      computers.first.findElements('serialnumber').single.innerText,
      'SN1',
    );
    expect(computers.last.findElements('serialnumber'), isEmpty);
    expect(declared, {'dc_Perdix_AI_SN1', 'dc_Teric_unknown'});
  });

  test('writeOwnerComputers writes nothing without a computer', () {
    late Set<String> declared;
    final root = _write(
      (b) => declared = UddfGearWriters.writeOwnerComputers(b, [_dive('a')]),
    );
    expect(root.childElements, isEmpty);
    expect(declared, isEmpty);
  });

  test('writeEquipmentUsed refs each item, then links the computer', () {
    final root = _write(
      (b) => UddfGearWriters.writeEquipmentUsed(
        b,
        _dive('a', model: 'Perdix AI', serial: 'SN1', gear: [_reg, _bcd]),
      ),
    );
    final used = root.findElements('equipmentused').single;
    expect(used.findElements('equipmentref').map((e) => e.innerText), [
      'equip_reg',
      'equip_bcd',
    ]);
    expect(
      used.findElements('link').single.getAttribute('ref'),
      'dc_Perdix_AI_SN1',
    );
  });

  test('writeEquipmentUsed writes nothing with no gear and no computer', () {
    final root = _write(
      (b) => UddfGearWriters.writeEquipmentUsed(b, _dive('a')),
    );
    expect(root.childElements, isEmpty);
  });
}
