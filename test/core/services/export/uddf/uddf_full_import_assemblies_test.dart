import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';

/// Assemblies in the private block (issue #1487): components ride on the
/// parent item's map and gear links on the dive's, so the wizard's
/// flattening keeps both.
const _uddf = '''<?xml version="1.0" encoding="UTF-8"?>
<uddf version="3.2.0">
  <applicationdata><submersion version="1.0">
    <equipment>
      <item id="equip_reg"><name>Reg</name><type>regulator</type></item>
      <item id="equip_hose"><name>Hose</name><type>hose</type></item>
    </equipment>
    <equipmentsets>
      <set id="set_winter"><name>Winter</name><items><itemref>equip_reg</itemref></items></set>
    </equipmentsets>
    <components>
      <component parent="equip_reg" component="equip_hose" order="0"><role>Primary hose</role></component>
      <component parent="equip_missing" component="equip_hose" order="0"/>
      <component parent="equip_reg" component="" order="1"/>
    </components>
    <gearlinks>
      <dive ref="dive_d1">
        <link item="equip_reg" set="set_winter"/>
        <link item="equip_hose" via="equip_reg" set="set_winter"/>
      </dive>
      <dive ref="dive_other">
        <link item="equip_reg" set="set_winter"/>
      </dive>
    </gearlinks>
  </submersion></applicationdata>
  <profiledata><repetitiongroup id="rg1">
    <dive id="dive_d1">
      <informationbeforedive><datetime>2026-03-01T10:00:00</datetime></informationbeforedive>
      <informationafterdive><greatestdepth>18</greatestdepth><diveduration>2400</diveduration></informationafterdive>
    </dive>
    <dive id="dive_d2">
      <informationbeforedive><datetime>2026-03-02T10:00:00</datetime></informationbeforedive>
      <informationafterdive><greatestdepth>12</greatestdepth><diveduration>1800</diveduration></informationafterdive>
    </dive>
  </repetitiongroup></profiledata>
</uddf>''';

void main() {
  test(
    'attaches components to the parent item and gear links to the dive',
    () async {
      final result = await UddfFullImportService().importAllDataFromUddf(_uddf);

      final reg = result.equipment.firstWhere(
        (e) => e['uddfId'] == 'equip_reg',
      );
      final hose = result.equipment.firstWhere(
        (e) => e['uddfId'] == 'equip_hose',
      );
      final components = reg['components'] as List;
      expect(components, hasLength(1));
      expect(components.single['componentRef'], 'equip_hose');
      expect(components.single['role'], 'Primary hose');
      expect(components.single['sortOrder'], 0);
      // A part with no parent on file, or a blank ref, is dropped.
      expect(hose.containsKey('components'), isFalse);

      final d1 = result.dives.firstWhere((d) => d['sourceUuid'] == 'dive_d1');
      final links = d1['gearLinks'] as List;
      expect(links, hasLength(2));
      expect(links[0]['itemRef'], 'equip_reg');
      expect(links[0]['viaRef'], isNull);
      expect(links[0]['setRef'], 'set_winter');
      expect(links[1]['itemRef'], 'equip_hose');
      expect(links[1]['viaRef'], 'equip_reg');
      expect(links[1]['setRef'], 'set_winter');

      final d2 = result.dives.firstWhere((d) => d['sourceUuid'] == 'dive_d2');
      expect(d2.containsKey('gearLinks'), isFalse);
    },
  );
}
