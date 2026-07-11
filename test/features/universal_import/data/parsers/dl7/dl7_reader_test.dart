import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/parsers/dl7/dl7_reader.dart';

const _multiLineZar = '''
FSH|^~<>{}|OCI201^^|ZXU|20220604000837|
ZRH|^~<>{}||13960|MSWG|ThM|C|BAR|L|
ZAR{
<AQUALUNG>
<APP>DiverLog+</APP>
<DUID>7168_13960_20220224130600_1</DUID>
</AQUALUNG>
}
ZDH|1|1|I|Q1S|20220224130600|27.2||FO2|
ZDP{
|0.00|0.00|1.00|
|0.50|1.52||||||27.2|||
|1.00|5.49|||||||||
ZDP}
ZDT|1|1|15.54|20220224140300|0.000000|0|
''';

const _multiDiveNoZar = '''
FSH|^~\\&{}|ANST01^12X456^A|ZXU|20180106163705+02:00|
ZRH|^~\\&{}|||MFWG|ThM|C|bar|L|
ZDH|1|1|M|QS|20240301100000|22|||
ZDT|1|1|12.0|20240301102500|21||
ZDH|2|2|I|V|20240302110000|24|||
ZDP{
|0|1|1||||
|60|15|||||
|1800|0|||||
ZDP}
ZDT|1|2|15.0|20240302113000|21||
''';

void main() {
  const reader = Dl7Reader();

  group('Dl7Reader', () {
    test('parses header segments with tag at index 0', () {
      final doc = reader.read(_multiLineZar);
      expect(doc.fshFields[0], 'FSH');
      expect(doc.fshFields[3], 'ZXU');
      expect(doc.zrhFields[0], 'ZRH');
      expect(doc.zrhFields[3], '13960');
      expect(doc.zrhFields[4], 'MSWG');
      expect(doc.zrhFields[7], 'BAR');
    });

    test('captures multi-line ZAR content between braces', () {
      final doc = reader.read(_multiLineZar);
      expect(doc.zarContent, contains('<AQUALUNG>'));
      expect(
        doc.zarContent,
        contains('<DUID>7168_13960_20220224130600_1</DUID>'),
      );
      expect(doc.zarContent, isNot(contains('ZDH')));
    });

    test('captures single-line ZAR content', () {
      final doc = reader.read(
        'FSH|^~<>{}|X^^|ZXU|20240501120000|\n'
        'ZAR{More Mobile Software, DiveLogDT, version 4.144}\n'
        'ZDH|1|1|I|Q1M|20240501100000|25|||\n'
        'ZDT|1|1|10.0|20240501100200|24||\n',
      );
      expect(doc.zarContent, 'More Mobile Software, DiveLogDT, version 4.144');
      expect(doc.dives, hasLength(1));
    });

    test('groups ZDH + ZDP rows + ZDT into one dive record', () {
      final doc = reader.read(_multiLineZar);
      expect(doc.dives, hasLength(1));
      final dive = doc.dives.first;
      expect(dive.zdhFields[5], '20220224130600');
      expect(dive.zdtFields[3], '15.54');
      expect(dive.zdpRows, hasLength(3));
      // Leading empty token removed: column 1 (time) is index 0.
      expect(dive.zdpRows[1][0], '0.50');
      expect(dive.zdpRows[1][1], '1.52');
      expect(dive.zdpRows[1][7], '27.2');
    });

    test('parses multiple dives, including profile-less dives', () {
      final doc = reader.read(_multiDiveNoZar);
      expect(doc.zarContent, isEmpty);
      expect(doc.dives, hasLength(2));
      expect(doc.dives[0].zdpRows, isEmpty);
      expect(doc.dives[0].zdtFields[3], '12.0');
      expect(doc.dives[1].zdpRows, hasLength(3));
      expect(doc.dives[1].zdpRows[1][0], '60');
    });

    test('tolerates CR-only line endings and a UTF-8 BOM', () {
      final crContent = _multiDiveNoZar.replaceAll('\n', '\r');
      final doc = reader.read('﻿$crContent');
      expect(doc.dives, hasLength(2));
    });

    test('emits a warning and keeps the dive when ZDT is missing at EOF', () {
      final doc = reader.read(
        'FSH|^~<>{}|X^^|ZXU|20240501120000|\n'
        'ZDH|1|1|I|Q1S|20240501100000|25|||\n'
        'ZDP{\n'
        '|0.00|0.00|1.00|\n'
        'ZDP}\n',
      );
      expect(doc.dives, hasLength(1));
      expect(doc.dives.first.zdtFields, isEmpty);
      expect(doc.readerWarnings, isNotEmpty);
    });

    test('ignores unknown segments (ZXL demographics) without error', () {
      final doc = reader.read(
        'FSH|^~<>{}|X^^|ZXL|20240501120000|\n'
        'ZPD|1|Jane Diver|\n'
        'ZDH|1|1|I|Q1S|20240501100000|25|||\n'
        'ZDT|1|1|9.0|20240501100500|24||\n',
      );
      expect(doc.dives, hasLength(1));
    });
  });
}
