import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_xml_parser.dart';

void main() {
  test('MacDiveXmlParser emits imageRefs from <photos>', () async {
    final content = await File(
      'test/fixtures/macdive_xml/metric_small.xml',
    ).readAsString();
    final bytes = Uint8List.fromList(utf8.encode(content));

    final payload = await const MacDiveXmlParser().parse(bytes);

    expect(payload.imageRefs.length, 2);
    final first = payload.imageRefs.first;
    expect(first.caption, 'Shark');
    expect(first.originalPath, '/Users/test/Pictures/a.jpg');
    expect(first.diveSourceUuid, isNotEmpty);
    expect(
      payload.imageRefs.every((r) => r.diveSourceUuid == first.diveSourceUuid),
      isTrue,
    );
  });
}
