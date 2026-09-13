import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_dives_writer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/parser_registry.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_dives_csv_parser.dart';

import '../../../../../core/services/export/csv/csv_dives_writer_test.dart'
    show imperial;
import '../../../../../core/services/export/csv/csv_test_fixtures.dart';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  test('the registry routes the format to this parser', () {
    expect(
      parserForFormat(ImportFormat.submersionDivesCsv),
      isA<SubmersionDivesCsvParser>(),
    );
  });

  for (final units in [
    CsvExportUnits.metric,
    CsvExportUnits.fromSettings(imperial),
  ]) {
    final label = units.isMetric ? 'metric' : 'my units';

    test('reads every column back ($label)', () async {
      final csv = CsvDivesWriter(units).write(goldenDives());
      final payload = await const SubmersionDivesCsvParser().parse(_bytes(csv));
      expect(payload.warnings, isEmpty);
      final dives = payload.entitiesOf(ImportEntityType.dives);
      expect(dives, hasLength(2));
      final d = dives.first;
      expect(d['dateTime'], DateTime.utc(2025, 3, 15, 9, 5));
      expect(d['diveNumber'], 12);
      expect(d['name'], 'Morning dive');
      expect(d['maxDepth'] as double, closeTo(30.48, 0.06));
      expect(d['waterTemp'] as double, closeTo(26.4, 0.6));
      expect(d['duration'], const Duration(minutes: 41));
      expect(d['runtime'], const Duration(minutes: 47));
      expect(d['visibilityMeters'] as double, closeTo(21.3, 0.06));
      expect(d['diveTypeIds'], ['boat', 'deep_wreck']);
      expect(d['buddy'], 'Ana Reyes');
      expect(d['diveMaster'], 'Tom Lee');
      expect(d['rating'], 4);
      expect(d['notes'], 'Great viz saw turtles');
      expect(d['diveComputerModel'], 'Perdix AI');
      expect(d['windSpeed'] as double, closeTo(4.2, 0.06));
      expect(d['windDirection'], 'northEast');
      expect(d['cloudCover'], 'partlyCloudy');
      expect(d['precipitation'], 'none');
      expect(d['humidity'], 71.0);
      expect(d['weatherDescription'], 'Sunny');
      expect(d['customFields'], [
        {'key': 'Boat', 'value': 'Sea Dog'},
        {'key': 'Formula', 'value': '=1+1'},
      ]);

      final tank = (d['tanks'] as List<Map<String, dynamic>>).single;
      // Metric writes whole litres; My units writes the rated cuft, which
      // maps back to the AL80 preset exactly.
      expect(
        tank['volume'] as double,
        closeTo(11.1, units.isMetric ? 0.5 : 1e-9),
      );
      expect(tank['startPressure'] as double, closeTo(206.843, 0.06));
      expect(tank['endPressure'] as double, closeTo(50.5, 0.06));
      expect((tank['gasMix'] as GasMix).o2, 32);
      if (!units.isMetric) {
        expect(tank['workingPressure'] as double, closeTo(206.843, 0.04));
      }

      final sites = payload.entitiesOf(ImportEntityType.sites);
      expect(sites.single['name'], 'Blue Hole');
      expect(sites.single['region'], 'Lighthouse Reef');
      expect(sites.single['country'], 'Belize');
      expect(d['site'], {'uddfId': sites.single['uddfId']});

      final second = dives.last;
      expect(second['visibility'], 'good');
      expect(second['diveTypeIds'], ['recreational']);
      expect(second.containsKey('tanks'), isFalse);
      expect(second.containsKey('site'), isFalse);
      expect(
        payload.entitiesOf(ImportEntityType.diveTypes).map((t) => t['id']),
        ['boat', 'deep_wreck', 'recreational'],
      );
    });
  }

  test('a row with no readable date is skipped with an error', () async {
    final csv = CsvDivesWriter(
      CsvExportUnits.metric,
    ).write(goldenDives()).replaceFirst('2025-03-15', 'someday');
    final payload = await const SubmersionDivesCsvParser().parse(_bytes(csv));
    expect(payload.entitiesOf(ImportEntityType.dives), hasLength(1));
    expect(payload.warnings.single.severity, ImportWarningSeverity.error);
  });

  test('a hand-edited unreadable number is left out with a warning', () async {
    final csv = CsvDivesWriter(
      CsvExportUnits.metric,
    ).write(goldenDives()).replaceFirst(',30.5,', ',oops,');
    final payload = await const SubmersionDivesCsvParser().parse(_bytes(csv));
    final dive = payload.entitiesOf(ImportEntityType.dives).first;
    expect(dive.containsKey('maxDepth'), isFalse);
    expect(payload.warnings.single.field, 'Max Depth');
    expect(payload.warnings.single.severity, ImportWarningSeverity.warning);
  });

  test('a tank carrying only a working pressure is kept', () async {
    final header = CsvDivesWriter(CsvExportUnits.metric)
        .write(goldenDives())
        .split('\r\n')
        .first
        .replaceFirst(
          'Tank Volume (L),',
          'Tank Volume (L),Working Pressure (bar),',
        );
    // Dive Number, Name, Date, Time; everything else blank except the
    // working pressure column.
    final row = [
      '1',
      '',
      '2025-03-15',
      '09:05',
      ...List.filled(17, ''),
      '232.0',
      ...List.filled(12, ''),
    ].join(',');
    final payload = await const SubmersionDivesCsvParser().parse(
      _bytes('$header\r\n$row'),
    );
    final dive = payload.entitiesOf(ImportEntityType.dives).single;
    final tank = (dive['tanks'] as List<Map<String, dynamic>>).single;
    expect(tank['workingPressure'], 232.0);
  });

  test(
    'reads the site place columns, helium and ordered custom fields',
    () async {
      // The #1814 columns carry what Location and the per-key custom columns
      // cannot: an island, a trimix tank, an empty field and the diver's order.
      final dive = goldenDives().first.copyWith(
        site: goldenSite.copyWith(island: 'Ambergris Caye'),
        tanks: const [
          DiveTank(id: 't1', volume: 12, gasMix: GasMix(o2: 18, he: 45)),
        ],
        customFields: const [
          DiveCustomField(id: 'a', key: 'Zeta', value: 'first', sortOrder: 0),
          DiveCustomField(id: 'b', key: 'Alpha', value: '', sortOrder: 1),
        ],
      );
      for (final units in [
        CsvExportUnits.metric,
        CsvExportUnits.fromSettings(imperial),
      ]) {
        final payload = await const SubmersionDivesCsvParser().parse(
          _bytes(CsvDivesWriter(units).write([dive])),
        );
        final site = payload.entitiesOf(ImportEntityType.sites).single;
        expect(site['city'], 'San Pedro');
        expect(site['island'], 'Ambergris Caye');
        expect(site['region'], 'Lighthouse Reef');
        expect(site['country'], 'Belize');
        final parsed = payload.entitiesOf(ImportEntityType.dives).single;
        final tank = (parsed['tanks'] as List<Map<String, dynamic>>).single;
        expect((tank['gasMix'] as GasMix).he, 45);
        expect(parsed['customFields'], [
          {'key': 'Zeta', 'value': 'first'},
          {'key': 'Alpha', 'value': ''},
        ]);
      }
    },
  );

  test('a file without the place columns still parses Location', () async {
    final payload = await const SubmersionDivesCsvParser().parse(
      _bytes(
        'Dive Number,Date,Time,Site,Location\n'
        '1,2025-03-15,09:05,Reef,"Town · Bay, Egypt"\n',
      ),
    );
    final site = payload.entitiesOf(ImportEntityType.sites).single;
    expect(site['region'], 'Bay');
    expect(site['country'], 'Egypt');
    expect(site.containsKey('city'), isFalse);
  });

  test('dive types come back under their own ids and names (#1834)', () async {
    final custom = DiveTypeEntity(
      id: 'search_recovery_1a2b3c4d',
      diverId: 'me',
      name: 'Search & Recovery',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final dive = goldenDives().first.copyWith(diveTypeIds: ['boat', custom.id]);
    for (final units in [
      CsvExportUnits.metric,
      CsvExportUnits.fromSettings(imperial),
    ]) {
      final csv = CsvDivesWriter(
        units,
        diveTypesById: {custom.id: custom},
      ).write([dive]);
      final payload = await const SubmersionDivesCsvParser().parse(_bytes(csv));
      final parsed = payload.entitiesOf(ImportEntityType.dives).single;
      expect(parsed['diveTypeIds'], ['boat', custom.id]);
      final types = payload.entitiesOf(ImportEntityType.diveTypes);
      expect(
        types.firstWhere((t) => t['id'] == custom.id)['name'],
        'Search & Recovery',
      );
    }
  });

  test('a name ending in ";" still pairs with its id', () async {
    // "Rec;" joined with "; " reads "Rec;; Night"; splitting on the real
    // separator gives the two names back.
    final payload = await const SubmersionDivesCsvParser().parse(
      _bytes(
        'Dive Number,Date,Time,Dive Type,Dive Type IDs\n'
        '1,2025-03-15,09:05,"Rec;; Night",rec_1; night\n',
      ),
    );
    final parsed = payload.entitiesOf(ImportEntityType.dives).single;
    expect(parsed['diveTypeIds'], ['rec_1', 'night']);
    expect(
      payload.entitiesOf(ImportEntityType.diveTypes).map((t) => t['name']),
      ['Rec;', 'Night'],
    );
  });

  test('ids that cannot pair with the names keep a rebuilt name', () async {
    final payload = await const SubmersionDivesCsvParser().parse(
      _bytes(
        'Dive Number,Date,Time,Dive Type,Dive Type IDs\n'
        '1,2025-03-15,09:05,A; B; C,rec_1; night\n',
      ),
    );
    expect(
      payload.entitiesOf(ImportEntityType.diveTypes).map((t) => t['name']),
      ['Rec 1', 'Night'],
    );
  });
}
