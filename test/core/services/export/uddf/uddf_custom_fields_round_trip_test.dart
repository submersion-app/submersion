import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:xml/xml.dart';

/// A dive's custom fields survive a UDDF export and re-import from both
/// writers: each writes them as `<customfield key>` in the dive's inline
/// `<applicationdata>`, and the reader hands them to the importer as
/// `customFields`.
void main() {
  const fields = [
    DiveCustomField(id: 'f1', key: 'boat', value: 'Ocean Explorer'),
    DiveCustomField(
      id: 'f2',
      key: 'permit no.',
      value: 'A-17 & B',
      sortOrder: 1,
    ),
    DiveCustomField(id: 'f3', key: 'reviewed', sortOrder: 2),
  ];

  Dive dive({
    String id = 'dive-a',
    List<DiveCustomField> customFields = const [],
  }) => Dive(
    id: id,
    diveNumber: 1,
    dateTime: DateTime.utc(2026, 3, 1, 9),
    bottomTime: const Duration(minutes: 45),
    maxDepth: 25.0,
    tanks: const [DiveTank(id: 'tank-a', gasMix: GasMix(o2: 32))],
    customFields: customFields,
  );

  final writers = <String, Future<String> Function(List<Dive>)>{
    'full backup': (dives) =>
        UddfFullExportService().generateAllDataXmlForTest(dives: dives),
    'dives-only export': (dives) =>
        UddfExportService().generateDivesUddfContent(dives),
  };

  Future<List<Map<String, dynamic>>> restore(String xml) async =>
      (await UddfFullImportService().importAllDataFromUddf(xml)).dives;

  for (final MapEntry(key: name, value: write) in writers.entries) {
    group(name, () {
      test('restores every custom field in order', () async {
        final xml = await write([dive(customFields: fields)]);

        expect((await restore(xml)).single['customFields'], [
          {'key': 'boat', 'value': 'Ocean Explorer'},
          {'key': 'permit no.', 'value': 'A-17 & B'},
          {'key': 'reviewed', 'value': ''},
        ]);
      });

      test('keeps each dive\'s fields on its own dive', () async {
        final xml = await write([
          dive(id: 'dive-a', customFields: fields.take(1).toList()),
          dive(id: 'dive-b'),
        ]);

        final restored = {
          for (final d in await restore(xml)) d['sourceUuid']: d,
        };
        expect(restored['dive_dive-a']!['customFields'], [
          {'key': 'boat', 'value': 'Ocean Explorer'},
        ]);
        expect(restored['dive_dive-b']!.containsKey('customFields'), isFalse);
      });

      test('writes them in the dive\'s inline applicationdata', () async {
        final xml = await write([dive(customFields: fields)]);

        final appData = XmlDocument.parse(xml)
            .findAllElements('dive')
            .single
            .findAllElements('applicationdata')
            .single;
        expect(appData.getElement('name')?.innerText, 'Submersion');
        expect(
          appData.findElements('customfield').map((f) => f.getAttribute('key')),
          ['boat', 'permit no.', 'reviewed'],
        );
      });
    });
  }

  group('reader', () {
    test('skips a customfield without a key', () async {
      final xml =
          (await UddfExportService().generateDivesUddfContent([
            dive(customFields: fields.take(1).toList()),
          ])).replaceFirst(
            '<customfield key="boat">',
            '<customfield>orphan</customfield><customfield key="  ">blank'
                '</customfield><customfield key="boat">',
          );

      expect((await restore(xml)).single['customFields'], [
        {'key': 'boat', 'value': 'Ocean Explorer'},
      ]);
    });
  });
}
