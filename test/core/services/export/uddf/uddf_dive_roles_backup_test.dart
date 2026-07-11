import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:xml/xml.dart';

import '../../../../helpers/test_database.dart';

final _now = DateTime(2024, 1, 1);

final _customRole = DiveRole(
  id: 'uuid-1',
  name: 'Hekkensluiter',
  diverId: 'diver-1',
  sortOrder: 9,
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  test('buildApplicationData emits a diveroles section for custom roles', () {
    final builder = XmlBuilder();
    builder.element(
      'uddf',
      nest: () {
        UddfExportBuilders.buildApplicationData(
          builder,
          customDiveRoles: [_customRole],
        );
      },
    );
    final xml = builder.buildDocument().toXmlString();

    expect(xml, contains('<diverole id="uuid-1">'));
    expect(xml, contains('<name>Hekkensluiter</name>'));
    expect(xml, contains('<sortorder>9</sortorder>'));
  });

  group('full import', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    test('parses diveroles into customDiveRoles', () async {
      const uddf = '''
<?xml version="1.0" encoding="UTF-8"?>
<uddf version="3.2.1">
  <applicationdata>
    <submersion>
      <diveroles>
        <diverole id="uuid-1">
          <name>Hekkensluiter</name>
          <sortorder>9</sortorder>
          <isbuiltin>false</isbuiltin>
        </diverole>
      </diveroles>
    </submersion>
  </applicationdata>
</uddf>
''';

      final result = await UddfFullImportService().importAllDataFromUddf(uddf);

      expect(result.customDiveRoles, hasLength(1));
      expect(result.customDiveRoles.single['id'], 'uuid-1');
      expect(result.customDiveRoles.single['name'], 'Hekkensluiter');
      expect(result.customDiveRoles.single['sortOrder'], 9);
    });
  });
}
