import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_service.dart';

/// UDDF names the vendor in `<manufacturer><name>`, but the dive-attribution
/// map only ever carried model/serial/firmware, so an imported computer was
/// registered with a null manufacturer and could not match a downloaded row
/// that stores vendor and product separately (#1288).
const _uddf = '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
  <diver>
    <owner id="owner-1">
      <personal>
        <firstname>Test</firstname>
        <lastname>Diver</lastname>
      </personal>
      <equipment>
        <divecomputer id="dc-1">
          <name>Shearwater Perdix 2</name>
          <manufacturer>
            <name>Shearwater</name>
          </manufacturer>
          <model>Perdix 2</model>
          <serialnumber>2013766D</serialnumber>
        </divecomputer>
      </equipment>
    </owner>
  </diver>
  <profiledata>
    <repetitiongroup id="repgrp-1">
      <dive id="dive-1">
        <informationbeforedive>
          <datetime>2024-03-01T10:00:00</datetime>
          <link ref="dc-1" />
        </informationbeforedive>
        <samples>
          <waypoint>
            <depth>10.0</depth>
            <divetime>0</divetime>
          </waypoint>
          <waypoint>
            <depth>20.0</depth>
            <divetime>600</divetime>
          </waypoint>
        </samples>
        <informationafterdive>
          <greatestdepth>20.0</greatestdepth>
          <diveduration>1800</diveduration>
        </informationafterdive>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';

/// UDDF's `<manufacturer>` legitimately carries `<address>`/`<contact>`
/// siblings of `<name>`. Reading the element's whole subtree would splice
/// those into the vendor string.
const _uddfManufacturerWithoutName = '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
  <diver>
    <owner id="owner-1">
      <personal>
        <firstname>Test</firstname>
        <lastname>Diver</lastname>
      </personal>
      <equipment>
        <divecomputer id="dc-1">
          <name>Perdix 2</name>
          <manufacturer>
            <address>
              <city>Vancouver</city>
              <country>Canada</country>
            </address>
            <contact>
              <email>support@example.com</email>
            </contact>
          </manufacturer>
          <model>Perdix 2</model>
        </divecomputer>
      </equipment>
    </owner>
  </diver>
  <profiledata>
    <repetitiongroup id="repgrp-1">
      <dive id="dive-1">
        <informationbeforedive>
          <datetime>2024-03-01T10:00:00</datetime>
          <link ref="dc-1" />
        </informationbeforedive>
        <samples>
          <waypoint>
            <depth>10.0</depth>
            <divetime>0</divetime>
          </waypoint>
        </samples>
        <informationafterdive>
          <greatestdepth>20.0</greatestdepth>
          <diveduration>1800</diveduration>
        </informationafterdive>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';

void main() {
  test('UddfImportService carries the dive computer manufacturer', () async {
    final result = await UddfImportService().importDivesFromUddf(_uddf);
    final dive = result['dives']!.single;

    expect(dive['diveComputerModel'], 'Perdix 2');
    expect(dive['diveComputerManufacturer'], 'Shearwater');
  });

  test(
    'UddfFullImportService carries the dive computer manufacturer',
    () async {
      final result = await UddfFullImportService().importAllDataFromUddf(_uddf);
      final dive = result.dives.single;

      expect(dive['diveComputerModel'], 'Perdix 2');
      expect(dive['diveComputerManufacturer'], 'Shearwater');
    },
  );

  test('ignores a manufacturer element that carries no name', () async {
    final result = await UddfImportService().importDivesFromUddf(
      _uddfManufacturerWithoutName,
    );
    final dive = result['dives']!.single;

    // Never 'VancouverCanada': the address and contact subtrees are not the
    // vendor name.
    expect(dive['diveComputerManufacturer'], isNull);
  });
}
