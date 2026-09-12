import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';

import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  test('carries custom dive role definitions in the metadata', () async {
    // Issue #1737: per-dive links name custom roles by id, so the wizard
    // must restore the definitions too, or the links point at nothing.
    const uddf = '''
<?xml version="1.0" encoding="UTF-8"?>
<uddf version="3.2.0">
  <applicationdata>
    <submersion>
      <diveroles>
        <diverole id="custom-uuid">
          <name>Photographer</name>
          <sortorder>10</sortorder>
          <isbuiltin>false</isbuiltin>
        </diverole>
      </diveroles>
    </submersion>
  </applicationdata>
</uddf>
''';

    final payload = await UddfImportParser().parse(
      Uint8List.fromList(utf8.encode(uddf)),
    );

    final roles = payload.metadata[ImportPayload.customDiveRolesKey] as List;
    expect(roles, hasLength(1));
    expect((roles.single as Map)['id'], 'custom-uuid');
    expect((roles.single as Map)['name'], 'Photographer');
  });
}
