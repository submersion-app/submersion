import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_xml_parser.dart';

/// MacDive XML writes `<date>` to the minute; `<identifier>` keeps the
/// seconds the computer reported (#2509).
void main() {
  Uint8List xml({required String date, required String identifier}) =>
      Uint8List.fromList(
        utf8.encode('''<?xml version="1.0" encoding="UTF-8"?>
<dives>
    <units>Metric</units>
    <dive>
        <date>$date</date>
        <identifier>$identifier</identifier>
        <maxDepth>25.40</maxDepth>
        <duration>2400</duration>
    </dive>
</dives>'''),
      );

  Future<DateTime?> startOf(Uint8List bytes) async {
    final payload = await const MacDiveXmlParser().parse(bytes);
    return payload.entitiesOf(ImportEntityType.dives).single['dateTime']
        as DateTime?;
  }

  test('restores the seconds from the identifier', () async {
    final start = await startOf(
      xml(date: '2025-01-02 10:30:00', identifier: '20250102103017-ABC123'),
    );
    expect(start, DateTime.utc(2025, 1, 2, 10, 30, 17));
  });

  test('keeps the minute when the identifier is not a timestamp', () async {
    final start = await startOf(
      xml(date: '2025-01-02 10:30:00', identifier: '2015122911130-822199'),
    );
    expect(start, DateTime.utc(2025, 1, 2, 10, 30));
  });
}
