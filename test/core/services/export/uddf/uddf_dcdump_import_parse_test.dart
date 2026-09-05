import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_dump_codec.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';

String document({String applicationData = '', String control = ''}) {
  return '''
<uddf version="3.2.0" xmlns="http://www.streit.cc/uddf/3.2/">
  <profiledata>
    <repetitiongroup>
      <dive id="dive_d1">
        <informationbeforedive>
          <datetime>2019-06-02T10:00:00</datetime>
        </informationbeforedive>
      </dive>
    </repetitiongroup>
  </profiledata>
$applicationData
$control
</uddf>
''';
}

String sourcesBlock(String entries) =>
    '''
  <applicationdata>
    <submersion version="1.0">
      <datasources>
$entries
      </datasources>
    </submersion>
  </applicationdata>''';

String controlBlock(String payload) =>
    '''
  <divecomputercontrol>
    <divecomputerdump>
      <link ref="dive_d1"/>
      <datetime>2019-06-02T18:41:07</datetime>
      <dcdump>$payload</dcdump>
    </divecomputerdump>
  </divecomputercontrol>''';

void main() {
  final raw = Uint8List.fromList([9, 8, 7, 6, 5]);
  final payload = UddfDumpCodec.encodeOne(raw);

  test('pairs a dump with its source entry by diveref and ordinal', () async {
    final xml = document(
      applicationData: sourcesBlock('''
        <source diveref="dive_d1" ordinal="0" hasdump="true">
          <descriptor vendor="Shearwater" product="Perdix" model="5"/>
          <libdivecomputerversion>0.9.0-devel</libdivecomputerversion>
          <primary>true</primary>
          <fingerprint>A17F3C</fingerprint>
          <mergesourceslot>0</mergesourceslot>
          <importedat>2019-06-02T18:41:07.000</importedat>
          <createdat>2019-06-02T18:41:07.000</createdat>
          <computermodel>Perdix AI</computermodel>
          <computerserial>SN123</computerserial>
          <maxdepth>31.5</maxdepth>
          <decoalgorithm>ZHL16C</decoalgorithm>
        </source>'''),
      control: controlBlock(payload),
    );

    final result = await UddfFullImportService().importAllDataFromUddf(xml);
    final entries = result.dataSourcesByDiveRef['dive_d1']!;

    expect(entries, hasLength(1));
    expect(entries.single['rawData'], equals(raw));
    expect(entries.single['descriptorVendor'], 'Shearwater');
    expect(entries.single['descriptorProduct'], 'Perdix');
    expect(entries.single['descriptorModel'], 5);
    expect(entries.single['libdivecomputerVersion'], '0.9.0-devel');
    expect(entries.single['isPrimary'], isTrue);
    expect(entries.single['mergeSourceSlot'], 0);
    expect(entries.single['maxDepth'], 31.5);
    expect(entries.single['decoAlgorithm'], 'ZHL16C');
    expect(entries.single['computerModel'], 'Perdix AI');
    expect(entries.single['computerSerial'], 'SN123');
    expect(
      entries.single['rawFingerprint'],
      equals(Uint8List.fromList([0xA1, 0x7F, 0x3C])),
    );
    expect(
      entries.single['importedAt'],
      DateTime.parse('2019-06-02T18:41:07.000'),
    );
    expect(result.unpairedDumps, 0);
  });

  test(
    'an entry claiming a dump that is absent restores without bytes',
    () async {
      final xml = document(
        applicationData: sourcesBlock('''
        <source diveref="dive_d1" ordinal="0" hasdump="true">
          <primary>true</primary>
          <importedat>2019-06-02T18:41:07.000</importedat>
          <createdat>2019-06-02T18:41:07.000</createdat>
        </source>'''),
      );

      final result = await UddfFullImportService().importAllDataFromUddf(xml);
      final entries = result.dataSourcesByDiveRef['dive_d1']!;

      // It must not pair with some other dump further along.
      expect(entries.single['rawData'], isNull);
    },
  );

  test(
    'a spec shaped dump with no source entry still yields its bytes',
    () async {
      final xml = document(control: controlBlock(payload));

      final result = await UddfFullImportService().importAllDataFromUddf(xml);
      final entries = result.dataSourcesByDiveRef['dive_d1']!;

      expect(entries.single['rawData'], equals(raw));
      expect(entries.single['descriptorVendor'], isNull);
      expect(entries.single['isPrimary'], isTrue);
    },
  );

  test('a submersion block holding only datasources parses cleanly', () async {
    final xml = document(
      applicationData: sourcesBlock('''
        <source diveref="dive_d1" ordinal="0" hasdump="false">
          <primary>true</primary>
          <importedat>2019-06-02T18:41:07.000</importedat>
          <createdat>2019-06-02T18:41:07.000</createdat>
        </source>'''),
    );

    final result = await UddfFullImportService().importAllDataFromUddf(xml);
    expect(result.dataSourcesByDiveRef['dive_d1'], hasLength(1));
  });

  test('entries come back sorted by ordinal', () async {
    final xml = document(
      applicationData: sourcesBlock('''
        <source diveref="dive_d1" ordinal="1" hasdump="false">
          <primary>false</primary>
          <computermodel>Teric</computermodel>
          <importedat>2019-06-02T18:41:07.000</importedat>
          <createdat>2019-06-02T18:41:07.000</createdat>
        </source>
        <source diveref="dive_d1" ordinal="0" hasdump="false">
          <primary>true</primary>
          <computermodel>Perdix AI</computermodel>
          <importedat>2019-06-02T18:41:07.000</importedat>
          <createdat>2019-06-02T18:41:07.000</createdat>
        </source>'''),
    );

    final result = await UddfFullImportService().importAllDataFromUddf(xml);
    final entries = result.dataSourcesByDiveRef['dive_d1']!;

    expect(entries.map((e) => e['ordinal']), [0, 1]);
    expect(entries.map((e) => e['computerModel']), ['Perdix AI', 'Teric']);
  });

  test('a skipped dump does not shift bytes onto an earlier source', () async {
    // The export marks hasdump from what it actually wrote, so a source whose
    // encode failed says false. If it said true, this dump would pair with
    // ordinal 0 and source A would end up holding source B's bytes together
    // with A's own descriptor triple.
    final xml = document(
      applicationData: sourcesBlock('''
        <source diveref="dive_d1" ordinal="0" hasdump="false">
          <descriptor vendor="Shearwater" product="Perdix" model="5"/>
          <primary>true</primary>
          <computermodel>Perdix AI</computermodel>
          <importedat>2019-06-02T18:41:07.000</importedat>
          <createdat>2019-06-02T18:41:07.000</createdat>
        </source>
        <source diveref="dive_d1" ordinal="1" hasdump="true">
          <descriptor vendor="Shearwater" product="Teric" model="9"/>
          <primary>false</primary>
          <computermodel>Teric</computermodel>
          <importedat>2019-06-02T18:41:07.000</importedat>
          <createdat>2019-06-02T18:41:07.000</createdat>
        </source>'''),
      control: controlBlock(payload),
    );

    final result = await UddfFullImportService().importAllDataFromUddf(xml);
    final entries = result.dataSourcesByDiveRef['dive_d1']!;

    expect(entries, hasLength(2));
    expect(entries[0]['rawData'], isNull, reason: 'A claimed no dump');
    expect(entries[1]['rawData'], equals(raw));
    expect(entries[1]['descriptorProduct'], 'Teric');
    expect(result.unpairedDumps, 0);
  });

  test('the dump datetime does not become the dive time', () async {
    final xml = document(
      control:
          '''
  <divecomputercontrol>
    <divecomputerdump>
      <link ref="dive_d1"/>
      <datetime>2031-12-25T03:00:00</datetime>
      <dcdump>$payload</dcdump>
    </divecomputerdump>
  </divecomputercontrol>''',
    );

    final result = await UddfFullImportService().importAllDataFromUddf(xml);

    // Dive times are UTC-flagged wall clocks in this codebase, hence utc().
    // The point of the assertion is the date and time, which came from the
    // dive's own <datetime> and not from the dump's.
    expect(result.dives.single['dateTime'], DateTime.utc(2019, 6, 2, 10, 0));
  });

  test('an unreadable dump is skipped and counted, not thrown', () async {
    // The size ceiling itself is covered in uddf_dump_codec_test.dart. What
    // matters here is that any decode failure is contained: the import still
    // completes and reports the loss rather than throwing it at the user.
    final readable = UddfDumpCodec.encodeOne(
      Uint8List.fromList(List<int>.filled(1024, 0)),
    );

    // Sanity: this payload does pair, so the next assertion is about the
    // failure handling rather than about parsing in general.
    final ok = await UddfFullImportService().importAllDataFromUddf(
      document(control: controlBlock(readable)),
    );
    expect(ok.dataSourcesByDiveRef['dive_d1'], hasLength(1));
    expect(ok.unpairedDumps, 0);

    final result = await UddfFullImportService().importAllDataFromUddf(
      document(control: controlBlock('bm90IGJ6aXAy')),
    );

    expect(result.dataSourcesByDiveRef['dive_d1'] ?? const [], isEmpty);
    expect(result.unpairedDumps, 1);
  });
}
