import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';

/// A dives-only UDDF is shared with other people, so its gear carries no
/// tag identity and no clock list (issue #2651): an empty list would tell
/// the importer to remove the default clocks of the gear it creates, and a
/// tag would put the sender's physical cylinder on the reader's row.
void main() {
  final tank = EquipmentItem(
    id: 'tank-1',
    name: 'AL80',
    type: EquipmentType.tank,
    attributes: [
      EquipmentAttribute.curated(
        equipmentId: 'tank-1',
        key: EquipmentAttrKeys.passportId,
        valueText: 'pp-1',
      ),
    ],
  );

  test('dives-only gear writes neither passport id nor clock list', () async {
    final xml = await UddfExportService().generateDivesUddfContent([
      Dive(
        id: 'd1',
        dateTime: DateTime(2026, 3, 1, 9),
        gear: [GearLink(item: tank)],
      ),
    ]);
    final item = XmlDocument.parse(xml).findAllElements('item').single;
    expect(item.findElements('passportid'), isEmpty);
    expect(item.findElements('serviceschedules'), isEmpty);
  });
}
