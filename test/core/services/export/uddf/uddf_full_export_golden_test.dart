import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/export/uddf/uddf_dive_chunk.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';

import 'uddf_full_export_fixture.dart';

/// The full UDDF backup of [UddfFullExportFixture], byte for byte.
///
/// The golden was written by the one-document builder the export used before
/// issue #4249, which held every sample, the whole XML tree, its string and
/// its bytes in memory at once. The streamed writer that replaced it must
/// write the same file, however the dives are split into chunks.
///
/// Set `UPDATE_UDDF_GOLDEN=1` to rewrite the golden after an intended
/// change to the document.
void main() {
  final golden = File(
    p.join(
      'test',
      'core',
      'services',
      'export',
      'uddf',
      'goldens',
      'full_export_fixture.uddf',
    ),
  );

  // The one value that changes from run to run.
  String stable(String xml) => xml.replaceFirst(
    RegExp(r'<datetime>[^<]*</datetime>'),
    '<datetime>GENERATED</datetime>',
  );

  Future<String> export() async => stable(
    await UddfFullExportService().generateAllDataXmlForTest(
      dives: UddfFullExportFixture.dives,
      sites: const [UddfFullExportFixture.site],
      owner: UddfFullExportFixture.owner,
      equipment: UddfFullExportFixture.equipment,
      diveTankPressures: UddfFullExportFixture.tankPressures,
      dataSources: UddfFullExportFixture.sources,
    ),
  );

  /// The backup of the lean dives, their heavy data read [chunkSize] dives
  /// at a time through a loader, which records every id list it is given.
  Future<String> streamed(int chunkSize, List<List<String>> reads) async =>
      stable(
        await UddfFullExportService().generateAllDataXmlForTest(
          dives: UddfFullExportFixture.leanDives,
          sites: const [UddfFullExportFixture.site],
          owner: UddfFullExportFixture.owner,
          equipment: UddfFullExportFixture.equipment,
          chunkSize: chunkSize,
          loadDiveChunk: UddfFullExportFixture.recordingLoader(reads),
        ),
      );

  test('the backup matches the golden document', () async {
    final xml = await export();
    if (Platform.environment['UPDATE_UDDF_GOLDEN'] == '1') {
      await golden.parent.create(recursive: true);
      await golden.writeAsString(xml);
    }
    expect(xml, await golden.readAsString());
  });

  for (final chunkSize in [1, 2, 3, 50]) {
    test('a backup read $chunkSize dives at a time is the same '
        'document', () async {
      final reads = <List<String>>[];
      expect(await streamed(chunkSize, reads), await golden.readAsString());
    });
  }

  test('a run size below one is refused', () async {
    await expectLater(streamed(0, []), throwsArgumentError);
  });

  test('a loader that drops a dive from its run fails the backup', () async {
    // A backup that quietly left a dive out would be found only on restore.
    final export = UddfFullExportService().generateAllDataXmlForTest(
      dives: UddfFullExportFixture.leanDives,
      loadDiveChunk: (lean) async =>
          UddfDiveChunk(dives: lean.sublist(0, lean.length - 1)),
    );
    await expectLater(export, throwsStateError);
  });

  test('the build lets timers run between dives', () async {
    // A frame needs the event loop; a build that held it from the first
    // dive to the last froze the app for the whole export.
    var ticks = 0;
    final timer = Timer.periodic(Duration.zero, (_) => ticks++);
    addTearDown(timer.cancel);

    await streamed(50, []);

    expect(ticks, greaterThanOrEqualTo(UddfFullExportFixture.dives.length));
  });

  test('each dive\'s heavy data is read once, in document order, no more '
      'than one chunk at a time', () async {
    final reads = <List<String>>[];
    await streamed(3, reads);

    expect(reads, [
      ['dive-d', 'dive-c', 'dive-b'],
      ['dive-a'],
    ]);
  });
}
