import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// UDDF is hand-plumbed (unlike sync, which rides Drift's generated
/// serializer), so a dive's media time shift (issue #4539) needs an explicit
/// test: a restored backup that lost it would put every photo on the dive
/// back at the camera's own clock.
void main() {
  String exportOne(int mediaTimeOffsetSeconds) {
    final builder = XmlBuilder();
    builder.element(
      'root',
      nest: () {
        UddfExportBuilders.buildDiveElement(
          builder,
          Dive(
            id: 'dive-shift',
            diveNumber: 1,
            dateTime: DateTime(2026, 5, 6, 9, 4),
            maxDepth: 27.6,
            mediaTimeOffsetSeconds: mediaTimeOffsetSeconds,
          ),
          null,
          const [],
          const [],
          const [],
          const [],
          null,
          const [],
        );
      },
    );
    return builder.buildDocument().toXmlString();
  }

  String? readShift(String xml) => XmlDocument.parse(
    xml,
  ).findAllElements('mediatimeoffset').firstOrNull?.innerText;

  String backupWith(String afterDive) =>
      '''
<uddf version="3.2.0">
  <generator><name>Submersion</name></generator>
  <profiledata><repetitiongroup><dive id="d1">
    <informationbeforedive>
      <datetime>2026-05-06T09:04:00</datetime>
      <divenumber>1</divenumber>
    </informationbeforedive>
    <informationafterdive>
      <greatestdepth>27.6</greatestdepth>
      <diveduration>2220</diveduration>
      $afterDive
    </informationafterdive>
  </dive></repetitiongroup></profiledata>
</uddf>''';

  Future<Map<String, dynamic>> restore(String afterDive) async =>
      (await UddfFullImportService().importAllDataFromUddf(
        backupWith(afterDive),
      )).dives.single;

  test('a dive with no shift writes no mediatimeoffset element', () {
    expect(readShift(exportOne(0)), isNull);
  });

  test('a shifted dive writes its shift in seconds, signed', () {
    expect(readShift(exportOne(-47)), '-47');
    expect(readShift(exportOne(90)), '90');
  });

  test('a backup carrying mediatimeoffset reads it back', () async {
    final dive = await restore('<mediatimeoffset>-47</mediatimeoffset>');

    expect(dive['mediaTimeOffsetSeconds'], -47);
  });

  test('a backup without the element leaves the dive unshifted', () async {
    final dive = await restore('');

    expect(dive['mediaTimeOffsetSeconds'], isNull);
  });

  test('a value that is not a whole number is ignored', () async {
    final dive = await restore('<mediatimeoffset>soon</mediatimeoffset>');

    expect(dive['mediaTimeOffsetSeconds'], isNull);
  });
}
