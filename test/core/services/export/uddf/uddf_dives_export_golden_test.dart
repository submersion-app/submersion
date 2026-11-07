import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';

import 'uddf_full_export_fixture.dart';

/// The dives-only UDDF export of [UddfFullExportFixture], byte for byte, with
/// and without the gear and the raw data.
///
/// The goldens were written by the one-document builder the export used
/// before issue #4249. The streamed writer that replaced it must write the
/// same files, however the dives are split into runs.
///
/// Set `UPDATE_UDDF_GOLDEN=1` to rewrite the goldens after an intended
/// change to the document.
void main() {
  File golden(String name) => File(
    p.join(
      'test',
      'core',
      'services',
      'export',
      'uddf',
      'goldens',
      'dives_export_$name.uddf',
    ),
  );

  // The one value that changes from run to run.
  String stable(String xml) => xml.replaceFirst(
    RegExp(r'<datetime>[^<]*</datetime>'),
    '<datetime>GENERATED</datetime>',
  );

  const variants = {
    'everything': UddfExportOptions(),
    'no_gear_no_raw': UddfExportOptions(
      includeGear: false,
      includeRawData: false,
    ),
  };

  for (final MapEntry(key: name, value: options) in variants.entries) {
    test('the $name export matches its golden document', () async {
      final xml = stable(
        await UddfExportService().generateDivesUddfContent(
          UddfFullExportFixture.dives,
          sites: const [UddfFullExportFixture.site],
          diveTankPressures: UddfFullExportFixture.tankPressures,
          dataSources: UddfFullExportFixture.sources,
          options: options,
        ),
      );
      if (Platform.environment['UPDATE_UDDF_GOLDEN'] == '1') {
        await golden(name).writeAsString(xml);
      }
      expect(xml, await golden(name).readAsString());
    });

    for (final chunkSize in [1, 3]) {
      test('the $name export read $chunkSize dives at a time is the same '
          'document', () async {
        final xml = stable(
          await UddfExportService().generateDivesUddfContent(
            UddfFullExportFixture.leanDives,
            sites: const [UddfFullExportFixture.site],
            options: options,
            chunkSize: chunkSize,
            loadDiveChunk: UddfFullExportFixture.loadChunk,
          ),
        );
        expect(xml, await golden(name).readAsString());
      });
    }
  }

  test('an export of no dives still writes an empty <profiledata>', () async {
    final xml = await UddfExportService().generateDivesUddfContent(const []);
    expect(xml, contains('<profiledata/>'));
  });
}
