import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_fills_writer.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/parser_registry.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_fills_csv_parser.dart';

import '../../../../../core/services/export/csv/csv_dives_writer_test.dart'
    show imperial;
import '../../../../../core/services/export/csv/csv_test_fixtures.dart';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

/// The fills CSV parser (cylinder passports phase 5, issue #2339).
void main() {
  test('the registry routes the format to this parser', () {
    expect(
      parserForFormat(ImportFormat.submersionFillsCsv),
      isA<SubmersionFillsCsvParser>(),
    );
  });

  for (final units in [
    CsvExportUnits.metric,
    CsvExportUnits.fromSettings(imperial),
  ]) {
    test(
      'reads every column back (${units.isMetric ? 'metric' : 'my units'})',
      () async {
        final csv = CsvFillsWriter(
          units,
        ).write(goldenFills(), equipmentById: goldenFillEquipment());
        final payload = await const SubmersionFillsCsvParser().parse(
          _bytes(csv),
        );
        expect(payload.warnings, isEmpty);
        final items = payload.entitiesOf(ImportEntityType.fills);
        expect(items, hasLength(2));

        final first = items.first;
        final want = goldenFills().first;
        expect(first['id'], want.id);
        expect(first['uddfId'], want.id);
        expect(first['passportId'], 'pp-al80');
        // A wall clock, stored local like the equipment dates.
        expect(first['filledAt'], DateTime(2025, 3, 15, 9, 5));
        expect(first['o2Percent'], 32.0);
        expect(first['hePercent'], 0.0);
        expect(first['pressureBar'] as double, closeTo(206.843, 0.06));
        expect(first['temperatureC'] as double, closeTo(22.0, 0.6));
        expect(first['stationName'], 'Blue Hole Dive Center');
        expect(first['analyzer'], 'Analox O2EII');
        expect(first['source'], 'manual');
        expect(first['notes'], 'Topped off after analysis');
        // Display columns are not read back.
        expect(first.containsKey('cylinderName'), isFalse);
        expect(first.containsKey('serialNumber'), isFalse);

        final second = items[1];
        expect(second['passportId'], 'pp-foreign');
        expect(second['hePercent'], 45.0);
        expect(second['pressureBar'] as double, closeTo(180, 0.06));
        expect(second.containsKey('temperatureC'), isFalse);
        expect(second.containsKey('stationName'), isFalse);
        expect(second['source'], 'nfc');
      },
    );
  }

  test(
    'a row without a passport id, date or O2 is skipped with an error',
    () async {
      final csv = CsvFillsWriter(CsvExportUnits.metric).write(goldenFills());
      final lines = csv.split('\r\n');
      // Row 2: blank passport id. Row 3: unreadable O2.
      lines[1] = lines[1].replaceFirst(',pp-al80,', ',,');
      lines[2] = lines[2].replaceFirst(',18,45,', ',eighteen,45,');
      final payload = await const SubmersionFillsCsvParser().parse(
        _bytes(lines.join('\r\n')),
      );
      expect(payload.entitiesOf(ImportEntityType.fills), isEmpty);
      final errors = payload.warnings
          .where((w) => w.severity == ImportWarningSeverity.error)
          .toList();
      expect(errors, hasLength(2));
      expect(errors[0].message, 'Row 2 has no passport id and was skipped');
      expect(errors[0].field, 'Passport ID');
      expect(errors[1].message, 'Row 3 has no readable O2 % and was skipped');
      expect(errors[1].field, 'O2 %');
    },
  );

  test('a gas mix the Log fill sheet would refuse is skipped with an '
      'error', () async {
    final csv = CsvFillsWriter(CsvExportUnits.metric).write(goldenFills());
    final lines = csv.split('\r\n');
    // Row 2: O2 above 100. Row 3: O2 plus He above 100.
    lines[1] = lines[1].replaceFirst(',32,0,', ',320,0,');
    lines[2] = lines[2].replaceFirst(',18,45,', ',18,90,');
    final payload = await const SubmersionFillsCsvParser().parse(
      _bytes(lines.join('\r\n')),
    );
    expect(payload.entitiesOf(ImportEntityType.fills), isEmpty);
    final errors = payload.warnings
        .where((w) => w.severity == ImportWarningSeverity.error)
        .toList();
    expect(errors.map((e) => e.message), [
      'Row 2 has an impossible gas mix (O2 320 %, He 0 %) and was skipped',
      'Row 3 has an impossible gas mix (O2 18 %, He 90 %) and was skipped',
    ]);
    expect(errors.map((e) => e.field), ['O2 %', 'O2 %']);
  });

  test('a blank fill id is the same on every read, so re-importing a '
      'hand-made file adds nothing new', () async {
    final csv = CsvFillsWriter(CsvExportUnits.metric).write(goldenFills());
    final lines = csv.split('\r\n');
    lines[1] = lines[1].replaceFirst(
      '3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11,',
      ',',
    );
    lines[2] = lines[2].replaceFirst(
      '8a1d4c47-9e2a-4b7d-8c9e-0f113f0c2b8e,',
      ',',
    );
    Future<List<String>> ids(String text) async => [
      for (final item in (await const SubmersionFillsCsvParser().parse(
        _bytes(text),
      )).entitiesOf(ImportEntityType.fills))
        item['id'] as String,
    ];
    final first = await ids(lines.join('\r\n'));
    expect(await ids(lines.join('\r\n')), first);
    // Two different fills never share an id.
    expect(first.toSet(), hasLength(2));
    // A changed reading is a different fill.
    lines[1] = lines[1].replaceFirst(',32,0,', ',33,0,');
    expect((await ids(lines.join('\r\n'))).first, isNot(first.first));
  });

  test('a blank fill id is minted, so a hand-added row imports', () async {
    final csv = CsvFillsWriter(CsvExportUnits.metric).write(goldenFills());
    final lines = csv.split('\r\n');
    lines[1] = lines[1].replaceFirst(
      '3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11,',
      ',',
    );
    final payload = await const SubmersionFillsCsvParser().parse(
      _bytes(lines.join('\r\n')),
    );
    final items = payload.entitiesOf(ImportEntityType.fills);
    expect(items, hasLength(2));
    final minted = items.first['id'] as String;
    expect(minted, isNotEmpty);
    expect(minted, isNot(goldenFills().first.id));
    expect(items.first['uddfId'], minted);
    expect(payload.warnings, isEmpty);
  });

  test(
    'an unknown source reads as manual downstream and a blank He is 0',
    () async {
      final csv = CsvFillsWriter(CsvExportUnits.metric).write(goldenFills());
      final lines = csv.split('\r\n');
      lines[2] = lines[2]
          .replaceFirst(',18,45,', ',18,,')
          .replaceFirst(',nfc,', ',Teleport,');
      final payload = await const SubmersionFillsCsvParser().parse(
        _bytes(lines.join('\r\n')),
      );
      final second = payload.entitiesOf(ImportEntityType.fills)[1];
      expect(second['hePercent'], 0.0);
      // The parser keeps the text; FillSource.fromName maps it to manual.
      expect(second['source'], 'teleport');
    },
  );
}
