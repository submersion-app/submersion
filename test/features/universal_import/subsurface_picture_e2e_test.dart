import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';
import 'package:submersion/features/universal_import/domain/services/import_media_resolver.dart';

/// Parse -> resolve, on a logbook shaped like a real Subsurface export.
void main() {
  test(
    'a multi-dive logbook resolves its photos against a moved library',
    () async {
      final root = await Directory.systemTemp.createTemp('e2e_photos_');
      addTearDown(() async {
        if (root.existsSync()) await root.delete(recursive: true);
      });

      // The library moved from /home/jai/Pictures to this root, keeping shape.
      for (final rel in [
        p.join('2025', 'dive042.jpg'),
        p.join('2025', 'dive043.jpg'),
        p.join('2024', 'wreck.jpg'),
      ]) {
        final f = File(p.join(root.path, rel));
        await f.parent.create(recursive: true);
        await f.writeAsString('bytes');
      }

      const xml = '''
<divelog program='subsurface' version='3'>
<dives>
<trip date='2025-01-15' location='Bonaire'>
  <dive number='1' date='2025-01-15' time='10:00:00' duration='40:00 min'>
    <picture filename='/home/jai/Pictures/2025/dive042.jpg' offset='+3:20 min' gps='18.465562 -66.084902'/>
    <picture filename='/home/jai/Pictures/2025/dive043.jpg' offset='+12:00 min'/>
  </dive>
</trip>
<dive number='2' date='2024-06-02' time='09:30:00' duration='55:00 min'>
  <picture filename='/home/jai/Pictures/2024/wreck.jpg' offset='-0:30 min'/>
  <picture filename='/home/jai/Pictures/2024/gone.jpg' offset='+5:00 min'/>
</dive>
</dives>
</divelog>
''';

      final payload = await SubsurfaceXmlParser().parse(
        Uint8List.fromList(utf8.encode(xml)),
      );

      final dives = payload.entitiesOf(ImportEntityType.dives);
      final media = payload.entitiesOf(ImportEntityType.media);
      expect(dives, hasLength(2));
      expect(media, hasLength(4));

      final resolution = await const ImportMediaResolver().resolve(
        media: media,
        rootPath: root.path,
      );

      // Three of four resolve; the deleted one is reported, not dropped.
      expect(resolution.matchedCount, 3);
      expect(resolution.notFoundCount, 1);
      expect(resolution.reRootedCount, 3);

      // Each resolved photo points at the dive that referenced it.
      for (final entry in resolution.resolvedPathByIndex.entries) {
        final diveIndex = media[entry.key]['_diveIndex'] as int;
        final expectedYear = diveIndex == 0 ? '2025' : '2024';
        expect(entry.value, contains(expectedYear));
      }

      // The gps attribute survives only on the picture that carried one.
      expect(media[0]['latitude'], closeTo(18.465562, 1e-6));
      expect(media[1]['latitude'], isNull);

      // takenAt maths, as the adapter will compute it.
      final start = dives[0]['dateTime'] as DateTime;
      final offset = media[0]['offsetSeconds'] as int;
      expect(
        start.add(Duration(seconds: offset)).difference(start).inSeconds,
        200,
      );

      // A negative offset stays negative.
      expect(media[2]['offsetSeconds'], -30);
    },
  );
}
