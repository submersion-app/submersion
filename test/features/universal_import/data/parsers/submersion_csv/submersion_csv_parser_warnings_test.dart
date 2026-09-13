import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_dives_writer.dart';
import 'package:submersion/core/services/export/csv/csv_equipment_writer.dart';
import 'package:submersion/core/services/export/csv/csv_sites_writer.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_dives_csv_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_equipment_csv_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_sites_csv_parser.dart';

import '../../../../../core/services/export/csv/csv_test_fixtures.dart';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

/// The warning paths of the three Submersion CSV parsers: a hand-edited
/// file that cannot be read in full says so instead of importing blanks.
void main() {
  test('each parser declares its own format', () {
    expect(const SubmersionDivesCsvParser().supportedFormats, [
      ImportFormat.submersionDivesCsv,
    ]);
    expect(const SubmersionSitesCsvParser().supportedFormats, [
      ImportFormat.submersionSitesCsv,
    ]);
    expect(const SubmersionEquipmentCsvParser().supportedFormats, [
      ImportFormat.submersionEquipmentCsv,
    ]);
  });

  test('a unit a column cannot hold is reported once, for dives', () async {
    final csv = CsvDivesWriter(
      CsvExportUnits.metric,
    ).write(goldenDives()).replaceFirst('Max Depth (m)', 'Max Depth (psi)');
    final payload = await const SubmersionDivesCsvParser().parse(_bytes(csv));
    final unitWarnings = payload.warnings.where(
      (w) => w.message.contains('Max Depth (psi)') && w.itemIndex == null,
    );
    expect(unitWarnings, hasLength(1));
    expect(
      payload.entitiesOf(ImportEntityType.dives).first.containsKey('maxDepth'),
      isFalse,
    );
  });

  test('a unit a column cannot hold is reported, for sites', () async {
    final csv = CsvSitesWriter(
      CsvExportUnits.metric,
    ).write(goldenSites()).replaceFirst('Max Depth (m)', 'Max Depth (kts)');
    final payload = await const SubmersionSitesCsvParser().parse(_bytes(csv));
    expect(
      payload.warnings.where((w) => w.message.contains('Max Depth (kts)')),
      isNotEmpty,
    );
  });

  test('equipment: a bad unit, a nameless row, an unreadable attribute and '
      'an ambiguous part are each reported', () async {
    final written = CsvEquipmentWriter(CsvExportUnits.metric).write(
      goldenEquipment(),
      componentNames: {
        'e-reg': ['Twin'],
      },
    );
    final lines = written.split('\r\n');
    final edited = [
      lines.first.replaceFirst('Buoyancy (kg)', 'Buoyancy (bar)'),
      ...lines
          .skip(1)
          .map(
            (l) => l
                .replaceFirst('hose_length_m=0.5588', 'hose_length_m=long')
                .replaceFirst('Scooter,', 'Twin,')
                .replaceFirst('Cell A,', 'Twin,'),
          ),
      // A row with no name.
      ',Hose,,,,,,,,,,,,,Yes,',
    ].join('\r\n');
    final payload = await const SubmersionEquipmentCsvParser().parse(
      _bytes(edited),
    );
    final messages = payload.warnings.map((w) => w.message).toList();
    expect(messages.any((m) => m.contains('Buoyancy (bar)')), isTrue);
    expect(messages.any((m) => m.contains('no equipment name')), isTrue);
    expect(messages.any((m) => m.contains('hose_length_m=long')), isTrue);
    expect(messages.any((m) => m.contains('matches several items')), isTrue);
    expect(
      payload.warnings
          .where((w) => w.message.contains('no equipment name'))
          .single
          .severity,
      ImportWarningSeverity.error,
    );
  });
}
